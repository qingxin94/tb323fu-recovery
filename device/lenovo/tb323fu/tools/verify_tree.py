#!/usr/bin/env python3
#
# Static audit for the TB323FU AERA device tree.
#
# It verifies the invariants that matter for this port without copying any
# Skyward/TWRP recipe:
#   - recovery.img is kernel-less (BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE)
#   - no vendor .ko is bundled in recovery/root
#   - the startup module list contains spss_utils/spcom and does NOT bundle
#     nvt_36xxx (touch is loaded from the real vendor_dlkm after mount)
#   - requested modules exist in the device's vendor_dlkm image
#   - sampled modules have a __versions section and their vermagic tail
#     matches the boot kernel tail (the part same_magic() compares when
#     CONFIG_MODVERSIONS is enabled)
#
# Usage:
#   python3 tools/verify_tree.py \
#       --vendor-dlkm /path/to/vendor_dlkm_a.img \
#       --boot-kernel /path/to/unpacked/boot/kernel
#
import argparse
import hashlib
import re
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FAILS = []
PASSES = []


def ok(msg):
    PASSES.append(msg)
    print(f"PASS  {msg}")


def fail(msg):
    FAILS.append(msg)
    print(f"FAIL  {msg}")


def info(msg):
    print(f"INFO  {msg}")


def sha256_prefix(path, size=16):
    return hashlib.sha256(path.read_bytes()).hexdigest()[:size]


def board_list(name):
    text = (ROOT / "BoardConfig.mk").read_text(encoding="utf-8", errors="replace")
    match = re.search(name + r"\s*:?=\s*\"(.*?)\"", text, re.S)
    if not match:
        return []
    raw = match.group(1).replace("\\", " ")
    return [token for token in raw.split() if token.endswith(".ko")]


def elf_sections(path):
    data = path.read_bytes()
    if data[:4] != b"\x7fELF" or data[4] != 2 or data[5] != 1:
        raise ValueError(f"{path}: not a little-endian ELF64 file")
    e_shoff = struct.unpack_from("<Q", data, 40)[0]
    e_shentsize = struct.unpack_from("<H", data, 58)[0]
    e_shnum = struct.unpack_from("<H", data, 60)[0]
    e_shstrndx = struct.unpack_from("<H", data, 62)[0]
    shstr = e_shoff + e_shstrndx * e_shentsize
    shstr_off = struct.unpack_from("<Q", data, shstr + 24)[0]
    shstr_size = struct.unpack_from("<Q", data, shstr + 32)[0]
    names = data[shstr_off:shstr_off + shstr_size]
    sections = {}
    for i in range(e_shnum):
        base = e_shoff + i * e_shentsize
        name_off = struct.unpack_from("<I", data, base)[0]
        name = names[name_off:names.find(b"\x00", name_off)].decode("utf-8", "replace")
        off = struct.unpack_from("<Q", data, base + 24)[0]
        size = struct.unpack_from("<Q", data, base + 32)[0]
        sections[name] = data[off:off + size]
    return sections


def module_modinfo(path):
    sections = elf_sections(path)
    if "__versions" not in sections or not sections["__versions"]:
        return None, None
    blob = sections.get(".modinfo", b"")
    magic = None
    for chunk in blob.split(b"\x00"):
        if chunk.startswith(b"vermagic="):
            magic = chunk[len(b"vermagic="):].decode("utf-8", "replace")
            break
    return magic, len(sections["__versions"])


def kernel_magic(path):
    data = path.read_bytes()
    matches = re.findall(
        rb"6\.12\.30-[^\x00\n]+? SMP preempt mod_unload modversions aarch64", data
    )
    return matches[0].decode("utf-8", "replace") if matches else None


def debugfs_dump(image, src, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run(
        ["debugfs", "-R", f"dump {src} {dest}", str(image)],
        capture_output=True, text=True,
    )
    return dest.exists() and dest.stat().st_size > 0


def module_names(image):
    with tempfile.TemporaryDirectory() as tmp:
        dep = Path(tmp) / "modules.dep"
        if not debugfs_dump(image, "/lib/modules/modules.dep", dep):
            return set()
        names = set()
        for line in dep.read_text(encoding="utf-8", errors="replace").splitlines():
            if ":" in line:
                left = line.split(":", 1)[0].strip()
                names.add(left.rsplit("/", 1)[-1])
        return names


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--vendor-dlkm", type=Path)
    parser.add_argument("--vendor-boot-modules", type=Path,
                        help="extracted vendor_boot lib/modules directory")
    parser.add_argument("--boot-kernel", type=Path)
    args = parser.parse_args()

    text = (ROOT / "BoardConfig.mk").read_text(encoding="utf-8", errors="replace")
    if "BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true" in text:
        ok("recovery 是 kernel-less（BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true）")
    else:
        fail("BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE 不是 true")

    kos = list((ROOT / "recovery/root").rglob("*.ko"))
    if kos:
        fail(f"recovery/root 里发现 {len(kos)} 个 .ko")
    else:
        ok("recovery/root 里没有预置任何 .ko")

    module_metadata = []
    for pattern in (
        "modules.dep",
        "modules.alias",
        "modules.softdep",
        "modules.load",
        "modules.load.twrp",
        "modules.builtin",
    ):
        module_metadata.extend((ROOT / "recovery/root").rglob(pattern))
    if module_metadata:
        fail(f"recovery/root 里有 {len(module_metadata)} 个模块索引/清单文件")
    else:
        ok("recovery/root 里没有 modules.* 模块索引/清单")

    firmware_dir = ROOT / "recovery/root/system/etc/firmware"
    if firmware_dir.exists() and any(firmware_dir.glob("novatek_ts_*.bin")):
        fail("recovery/root/system/etc/firmware 仍有 novatek_ts_* 副本")
    else:
        ok("触摸固件由真实 /vendor/firmware 提供，ramdisk 未预置")

    vendor_fw = list((ROOT / "recovery/root/vendor/firmware").glob("novatek_ts_*.bin"))
    if vendor_fw:
        fail("vendor/firmware 里仍有 novatek_ts_* 副本，会遮住真实 /vendor/firmware")
    else:
        ok("vendor/firmware 没有 novatek_ts_* 副本，固件只从真实分区加载")

    # An empty lib/modules in the recovery ramdisk shadows the real
    # vendor_boot /lib/modules, so the loader would never see the device's
    # actual GKI modules.  Keep the path absent and let vendor_boot provide it.
    if (ROOT / "recovery/root/lib/modules").exists():
        fail("recovery/root/lib/modules 存在，会遮住 vendor_boot 的真实 /lib/modules")
    else:
        ok("recovery/root 不占位 /lib/modules，vendor_boot 的真实目录可直接暴露")

    startup = board_list("AERA_LOAD_VENDOR_MODULES")
    for required in ("spss_utils.ko", "spcom.ko"):
        if required in startup:
            ok(f"启动期模块列表包含 {required}")
        else:
            fail(f"启动期模块列表缺 {required}")

    if "nvt_36xxx.ko" in startup:
        fail("nvt_36xxx.ko 不应在启动期列表；它必须由 aera-touch-load 从真实分区加载")
    else:
        ok("nvt_36xxx.ko 不在启动期列表，由 aera-touch-load 从真实 /vendor_dlkm 加载")

    path_tokens = [name for name in startup if "/" in name]
    if path_tokens:
        fail("AERA_LOAD_VENDOR_MODULES 只能写模块名，不能写路径: "
             + ", ".join(path_tokens))
    else:
        ok("AERA_LOAD_VENDOR_MODULES 只写模块名，不含 ramdisk/分区路径")

    fstab = (ROOT / "recovery/root/system/etc/recovery.fstab").read_text(
        encoding="utf-8", errors="replace"
    )
    for part in ("/vendor_dlkm", "/system_dlkm"):
        if part in fstab:
            ok(f"recovery.fstab 包含 {part}")
        else:
            fail(f"recovery.fstab 缺 {part}")

    if args.vendor_dlkm:
        names = module_names(args.vendor_dlkm)
        if args.vendor_boot_modules and args.vendor_boot_modules.is_dir():
            names |= {path.name for path in args.vendor_boot_modules.rglob("*.ko")}
        if not names:
            fail(f"无法读取 {args.vendor_dlkm} 的 modules.dep")
        else:
            missing = sorted(set(startup) - names)
            if missing:
                fail(f"vendor_dlkm/vendor_boot 缺启动模块: {', '.join(missing)}")
            else:
                ok(f"启动期 {len(startup)} 个模块在 vendor_dlkm/vendor_boot 中都存在")

        sample = Path(tempfile.mkdtemp()) / "nvt_36xxx.ko"
        if debugfs_dump(args.vendor_dlkm, "/lib/modules/nvt_36xxx.ko", sample):
            magic, versions_size = module_modinfo(sample)
            if magic and versions_size:
                ok(f"nvt_36xxx.ko 带 __versions（{versions_size} bytes），vermagic={magic}")
            else:
                fail("nvt_36xxx.ko 缺 __versions 或 vermagic")

    kernel = None
    if args.boot_kernel:
        kernel = kernel_magic(args.boot_kernel)
        if kernel:
            ok(f"boot kernel vermagic={kernel}")
        else:
            fail(f"无法从 {args.boot_kernel} 提取 vermagic")

    if kernel and args.vendor_dlkm:
        sample = Path(tempfile.mkdtemp()) / "nvt_36xxx.ko"
        if not sample.exists() and debugfs_dump(args.vendor_dlkm, "/lib/modules/nvt_36xxx.ko", sample):
            pass
        if sample.exists():
            magic, _ = module_modinfo(sample)
            if magic:
                ktail = kernel.split(" ", 1)[1] if " " in kernel else kernel
                mtail = magic.split(" ", 1)[1] if " " in magic else magic
                if ktail == mtail:
                    ok(f"vermagic 尾部一致: {mtail}")
                else:
                    fail(f"vermagic 尾部不一致: kernel={ktail} module={mtail}")


    # Configuration invariants that caused real build/runtime failures.
    text_all = "\n".join(
        (ROOT / name).read_text(encoding="utf-8", errors="replace")
        for name in ("BoardConfig.mk", "vendorsetup.sh", "twrp_tb323fu.mk")
    )
    if "AERA_USE_DMCTL := 1" in text:
        ok("AERA_USE_DMCTL 使用 1，能被 aera_build.mk 的 ifeq 识别")
    else:
        fail("AERA_USE_DMCTL 不是 1（AERA 后端会静默不启用 DMCTL）")
    if not re.search(r"(?m)^\s*(?:export\s+)?AERA_USE_DMSETUP\s*=", text_all):
        ok("未同时启用 AERA_USE_DMSETUP，避免与 DMCTL 冲突")
    else:
        fail("AERA_USE_DMSETUP 仍被赋值/导出，会与 AERA_USE_DMCTL 冲突")
    if "AERA_VIRTUAL_AB_DEVICE" not in text_all and "virtual_ab_ota/compression.mk" not in text_all:
        ok("未把带独立 recovery 分区的设备误配为 virtual A/B")
    else:
        fail("设备有 recovery_a/b，却仍启用 virtual A/B 配置")

    vintf = (ROOT / "recovery/root/system/etc/vintf/manifest")
    for orphan in (
        "android.hardware.health-service.qti.xml",
        "android.hardware.fastboot-service.example.xml",
    ):
        if not (vintf / orphan).exists():
            ok(f"已移除无实现的 VINTF 声明 {orphan}")
        else:
            fail(f"存在无实现的 VINTF 声明 {orphan}")

    bins = list((ROOT / "recovery/root/vendor/bin").rglob("*"))
    bad_modes = [p for p in bins if p.is_file() and not (p.stat().st_mode & 0o111)]
    if bad_modes:
        fail(f"vendor/bin 中有 {len(bad_modes)} 个不可执行的 ELF/守护进程")
    else:
        ok("vendor/bin 下所有原生 HAL/守护进程都有可执行位")

    flags = (ROOT / "recovery/root/system/etc/twrp.flags").read_text(
        encoding="utf-8", errors="replace"
    )
    dataext = [line for line in flags.splitlines() if line.split() and line.split()[0] == "/dataext"]
    if dataext and "slotselect" in dataext[0]:
        ok("twrp.flags 的 /dataext 带 slotselect")
    else:
        fail("twrp.flags 的 /dataext 缺 slotselect（A/B 分区会挂错槽）")

    for lib in ("libvmmem.so", "libqcbor.so", "libxml2.so"):
        if (ROOT / "recovery/root/vendor/lib64" / lib).is_file():
            fail(f"{lib} 不应预置在 recovery/root，必须从真实 /vendor/lib64 加载")
        else:
            ok(f"{lib} 由真实 /vendor/lib64 提供，ramdisk 未预置")

    # Wi-Fi/audio/haptics must not depend on post-decrypt staging.  The module
    # list is consumed by aera-real-modules.sh directly from the real dlkm
    # partitions; AERA_POST_DECRYPT_MODULES must stay empty.
    if 'AERA_POST_DECRYPT_MODULES := ""' in text:
        ok("AERA_POST_DECRYPT_MODULES 为空，不再向 /tmp 暂存模块")
    else:
        fail("AERA_POST_DECRYPT_MODULES 仍非空，会把模块暂存到 /tmp")

    module_list = ROOT / "recovery/root/system/etc/aera-real-modules.list"
    if module_list.is_file():
        entries = [line.strip() for line in module_list.read_text().splitlines()
                   if line.strip() and not line.strip().startswith("#")]
        bad = [line for line in entries if "/" in line or not line.endswith(".ko")]
        if bad:
            fail(f"aera-real-modules.list 含路径或非 .ko 项: {bad[:3]}")
        elif len(entries) < 50:
            fail(f"aera-real-modules.list 只有 {len(entries)} 项，Wi-Fi/音频/振动模块链不完整")
        else:
            ok(f"aera-real-modules.list 有 {len(entries)} 个真实分区模块名")
    else:
        fail("缺 recovery/root/system/etc/aera-real-modules.list")

    wifi_rc = (ROOT / "recovery/root/init.recovery.wifi.rc").read_text()
    if "/system/bin/wpa_supplicant" in wifi_rc:
        fail("WiFi 服务仍指向 ramdisk 的 /system/bin/wpa_supplicant")
    elif "/vendor/bin/hw/wpa_supplicant" in wifi_rc:
        ok("WiFi supplicant 使用真实 /vendor/bin/hw/wpa_supplicant")
    else:
        fail("WiFi supplicant 服务路径缺失")

    audio_rc = (ROOT / "recovery/root/init.recovery.audio.rc").read_text()
    if "post.decrypt.modules" in audio_rc:
        fail("audio 仍依赖 post.decrypt.modules（PIN 失败时不会启动）")
    elif "aera.modules.loaded" in audio_rc:
        ok("audio 不再等待 /data 解密，改由 aera.modules.loaded 启动")
    else:
        fail("audio 启动触发缺失")

    manifest = (ROOT / "recovery/root/system/etc/vintf/manifest.xml").read_text()
    for hal in ("android.hardware.vibrator",
                "android.hardware.wifi.supplicant",
                "vendor.lenovo.hardware.vibrator_dual"):
        if hal in manifest:
            ok(f"VINTF 清单声明 {hal}")
        else:
            fail(f"VINTF 清单缺 {hal}，HAL 注册会被拒绝")

    print()
    print(f"结果: {len(PASSES)} PASS, {len(FAILS)} FAIL")
    return 1 if FAILS else 0


if __name__ == "__main__":
    raise SystemExit(main())
