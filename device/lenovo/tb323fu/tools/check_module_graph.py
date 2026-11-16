#!/usr/bin/env python3
#
# Dependency audit for the TB323FU module lists.
#
# AERA's startup loader uses libmodprobe with a copied module directory, but
# its post-decrypt loader flattens the requested modules into
# /tmp/post_decrypt_modules and calls finit_module() in list order.  That means
# a post-decrypt module cannot pull in a dependency that lives in another
# partition or folder unless that dependency is already loaded or appears
# earlier in the same list.
#
# This script reads the real modules.dep from vendor_dlkm, system_dlkm and
# vendor_boot, then checks both lists for:
#   - missing requested modules
#   - cross-partition dependencies
#   - cross-directory dependencies
#   - ambiguous duplicate names
#   - post-decrypt dependencies that are neither in startup nor earlier post
#
# Usage:
#   python3 tools/check_module_graph.py \
#       --vendor-dlkm /path/vendor_dlkm_a.img \
#       --system-dlkm /path/system_dlkm_a.img \
#       --vendor-boot-modules /path/vendor_ramdisk/lib/modules
#
import argparse
import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def board_list(name):
    text = (ROOT / "BoardConfig.mk").read_text(encoding="utf-8", errors="replace")
    match = re.search(name + r"\s*:=\s*\"(.*?)\"", text, re.S)
    if not match:
        return []
    raw = match.group(1).replace("\\", " ")
    return [token for token in raw.split() if token.endswith(".ko")]


def parse_dep(text, source):
    providers = {}
    graph = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        left, right = line.split(":", 1)
        module = left.strip()
        if not module.endswith(".ko"):
            continue
        base = module.rsplit("/", 1)[-1]
        providers.setdefault(base, []).append((source, module))
        deps = []
        for item in right.split():
            if item.endswith(".ko"):
                deps.append(item.rsplit("/", 1)[-1])
        graph[base] = deps
    return providers, graph


def read_image_dep(image):
    proc = subprocess.run(
        ["debugfs", "-R", "cat /lib/modules/modules.dep", str(image)],
        capture_output=True, text=True,
    )
    return parse_dep(proc.stdout, image.name)


def read_dir_dep(directory):
    dep = directory / "modules.dep"
    if not dep.is_file():
        return {}, {}
    return parse_dep(dep.read_text(encoding="utf-8", errors="replace"), directory.name)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--vendor-dlkm", type=Path)
    parser.add_argument("--system-dlkm", type=Path)
    parser.add_argument("--vendor-boot-modules", type=Path)
    args = parser.parse_args()

    providers = defaultdict(list)
    graph = defaultdict(list)
    sources = []
    for image, label in ((args.vendor_dlkm, "vendor_dlkm"),
                         (args.system_dlkm, "system_dlkm")):
        if image:
            p, g = read_image_dep(image)
            for key in p:
                providers[key].extend((label, path) for _, path in p[key])
            for key in g:
                graph[key].extend(g[key])
            sources.append(label)
    if args.vendor_boot_modules and args.vendor_boot_modules.is_dir():
        p, g = read_dir_dep(args.vendor_boot_modules)
        for key in p:
            providers[key].extend(("vendor_boot", path) for _, path in p[key])
        for key in g:
            graph[key].extend(g[key])
        sources.append("vendor_boot")

    startup = board_list("AERA_LOAD_VENDOR_MODULES")
    post = board_list("AERA_POST_DECRYPT_MODULES")
    startup_set = set(startup)
    post_set = set(post)
    failures = []
    warnings = []

    if not providers:
        print("FAIL  没有读到任何 modules.dep")
        return 1

    def provider_key(name):
        return providers.get(name, [])

    def closure(names):
        seen = set()
        def walk(name):
            if name in seen:
                return
            seen.add(name)
            for dep in graph.get(name, []):
                walk(dep)
        for name in names:
            walk(name)
        return seen

    startup_closure = closure(startup)

    for name in startup + post:
        if not provider_key(name):
            failures.append(f"{name}: 三处分区都找不到")

    for name in startup:
        entries = provider_key(name)
        if len({src for src, _ in entries}) > 1:
            warnings.append(f"{name}: 在多个分区同名（{', '.join(sorted({s for s,_ in entries}))}）")
        for dep in graph.get(name, []):
            if not provider_key(dep):
                warnings.append(f"{name}: 依赖 {dep} 未在 modules.dep 中找到（可能是内建）")
            parent_src = entries[0][0] if entries else "?"
            dep_srcs = {src for src, _ in provider_key(dep)}
            if dep_srcs and parent_src not in dep_srcs:
                warnings.append(
                    f"跨分区: {parent_src}/{name} -> {','.join(sorted(dep_srcs))}/{dep}"
                )

    post_index = {}
    for index, name in enumerate(post):
        post_index.setdefault(name, index)

    for name in post:
        entries = provider_key(name)
        parent_src = entries[0][0] if entries else "?"
        for dep in graph.get(name, []):
            if dep in startup_closure:
                continue
            if dep not in post_index:
                failures.append(
                    f"{name}: post 依赖 {dep} 不在 startup，也不在 post 列表"
                )
                continue
            if post_index[dep] > post_index[name]:
                failures.append(
                    f"{name}: post 顺序错误，依赖 {dep} 排在后面"
                )
            dep_srcs = {src for src, _ in provider_key(dep)}
            if dep_srcs and parent_src not in dep_srcs:
                if "vendor_boot" in dep_srcs and "vendor_boot" not in startup_closure:
                    failures.append(
                        f"{name}: 依赖 {dep} 只在 vendor_boot，而 post 不会从 vendor_boot 暂存"
                    )
                else:
                    warnings.append(
                        f"跨分区(post): {parent_src}/{name} -> {','.join(sorted(dep_srcs))}/{dep}"
                    )

    # Directory crossing inside the same partition.
    for name in startup + post:
        for _, path in provider_key(name):
            if "/lib/modules/" in path:
                rel = path.split("/lib/modules/", 1)[1]
                if "/" in rel:
                    warnings.append(f"{name}: 模块位于子目录 {path}")

    print(f"模块源: {', '.join(sources)}")
    print(f"启动列表: {len(startup)} 项，post 列表: {len(post)} 项")
    print(f"启动闭包: {len(startup_closure)} 个模块")
    for warning in warnings:
        print("WARN  " + warning)
    for failure in failures:
        print("FAIL  " + failure)
    print(f"\n结果: {len(failures)} FAIL, {len(warnings)} WARN")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
