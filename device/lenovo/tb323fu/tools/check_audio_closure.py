#!/usr/bin/env python3
#
# Static audio-closure audit for TB323FU.
#
# It only checks that the stock pieces exist in the vendor images and that no
# .ko was copied into the recovery tree.  It never mounts or executes the
# stock audio services.
#
# Usage:
#   python3 tools/check_audio_closure.py \
#       --vendor /path/vendor_a.img \
#       --vendor-dlkm /path/vendor_dlkm_a.img
#
import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

MODULES = [
    "adsp_loader_dlkm.ko", "spf_core_dlkm.ko", "adsp_sleepmon.ko", "audio_pkt_dlkm.ko",
    "audio_prm_dlkm.ko", "pinctrl_lpi_dlkm.ko", "aw882xx_dlkm.ko", "btfmcodec.ko",
    "btfm_slim_codec.ko", "bt_fm_swr.ko", "btpower.ko", "frpc-adsprpc.ko",
    "lpass_bt_swr_dlkm.ko", "lpass_cdc_dlkm.ko", "lpass_cdc_rx_macro_dlkm.ko",
    "lpass_cdc_tx_macro_dlkm.ko", "lpass_cdc_va_macro_dlkm.ko",
    "lpass_cdc_wsa2_macro_dlkm.ko", "lpass_cdc_wsa_macro_dlkm.ko",
    "machine_dlkm.ko", "q6_dlkm.ko", "q6_notifier_dlkm.ko", "q6_pdr_dlkm.ko",
    "qcom_q6v5.ko", "qcom_q6v5_pas.ko", "simple_amp_dlkm.ko",
    "snd_event_dlkm.ko", "snd-usb-audio-qmi.ko", "spk_id_dlkm.ko",
    "swr_ctrl_dlkm.ko", "swr_dlkm.ko", "swr_dmic_dlkm.ko",
    "swr_haptics_dlkm.ko", "wcd9378_dlkm.ko", "wcd9378_slave_dlkm.ko",
    "wcd938x_dlkm.ko", "wcd938x_slave_dlkm.ko", "wcd939x_dlkm.ko",
    "wcd939x_slave_dlkm.ko", "wcd9xxx_dlkm.ko", "wcd_core_dlkm.ko",
    "wsa883x_dlkm.ko", "wsa884x_dlkm.ko", "wsa885x_i2c_dlkm.ko",
]

RUNTIME = [
    "/bin/agmplay", "/bin/agmcap", "/bin/audioadsprpcd", "/bin/pd-mapper",
    "/bin/hw/audiohalservice.qti",
    "/lib64/libagmipcservice.so", "/lib64/libpalipcservice.so",
    "/lib64/libar-pal.so", "/lib64/libagmclient.so", "/lib64/libagmmixer.so",
    "/lib64/libtinyalsa.so", "/lib64/libadsprpc.so",
    "/lib64/libadsp_default_listener.so", "/lib64/libstream_contextproxy.so",
    "/lib64/libstream_common.so",
]

CONFIG = [
    "/etc/audio/audio_module_config_primary.xml",
    "/etc/audio/sku_canoe/mixer_paths_canoe_mtp.xml",
    "/etc/audio/sku_canoe/resourcemanager_canoe_mtp.xml",
    "/etc/audio/sku_canoe/plugin_manager.xml",
    "/etc/acdbdata/canoe_mtp",
    "/firmware/aw882xx_acf.bin", "/firmware/aw22xxx_fw.bin",
    "/lib/rfsa/adsp",
]

AUDIO_SERVICES = [
    "aera-audio-pd-mapper", "aera-audio-adsprpcd",
    "aera-agm-service", "aera-audio-bootstrap",
]


def make_list(text, name):
    match = re.search(rf'{name}\s*:=\s*"(.*?)"', text, re.S)
    if not match:
        return []
    return [line.strip().rstrip("\\").strip() for line in match.group(1).splitlines()
            if line.strip().rstrip("\\").strip()]


def check_sources(failures):
    before = len(failures)
    board = (ROOT / "BoardConfig.mk").read_text()
    startup = make_list(board, "AERA_LOAD_VENDOR_MODULES")
    post = make_list(board, "AERA_POST_DECRYPT_MODULES")
    for module in MODULES:
        if module not in startup and module not in post:
            failures.append(f"音频模块 {module} 既不在启动列表也不在 post-decrypt 列表")
    if not post:
        failures.append("AERA_POST_DECRYPT_MODULES 为空或无法解析")

    init_rc = (ROOT / "recovery/root/init.recovery.audio.rc").read_text()
    for service in AUDIO_SERVICES:
        if f"service {service} " not in init_rc:
            failures.append(f"init.recovery.audio.rc 缺服务 {service}")
    if "on property:post.decrypt.modules=true" not in init_rc:
        failures.append("init.recovery.audio.rc 缺 post.decrypt.modules 触发")
    qcom_rc = (ROOT / "recovery/root/init.recovery.qcom.rc").read_text()
    if "import /init.recovery.audio.rc" not in qcom_rc:
        failures.append("init.recovery.qcom.rc 没有 import 音频 rc")

    bootstrap = ROOT / "recovery/root/system/bin/aera-audio-bootstrap"
    if not bootstrap.is_file() or not bootstrap.stat().st_mode & 0o111:
        failures.append("aera-audio-bootstrap 不存在或不可执行")
    elif "aera-agm-service" not in bootstrap.read_text():
        failures.append("aera-audio-bootstrap 没有启动 aera-agm-service")

    device_mk = (ROOT / "device.mk").read_text()
    for package in ("aera-audio-bridge", "aera-audio-service"):
        if package not in device_mk:
            failures.append(f"device.mk 缺 PRODUCT_PACKAGES {package}")
    android_bp = (ROOT / "audio/Android.bp").read_text()
    for package in ("aera-audio-bridge", "aera-audio-service"):
        if f'name: "{package}"' not in android_bp:
            failures.append(f"audio/Android.bp 缺 {package}")

    if len(failures) == before:
        print("PASS  音频源码、init 服务、产品包和模块列表已接线")


def debugfs_stat(image, path):
    out = subprocess.run(
        ["debugfs", "-R", f"stat {path}", str(image)],
        capture_output=True, text=True,
    ).stdout
    return "Type: regular" in out or "Type: directory" in out


def debugfs_modules(image):
    out = subprocess.run(
        ["debugfs", "-R", "ls -l /lib/modules", str(image)],
        capture_output=True, text=True,
    ).stdout
    names = set()
    for line in out.splitlines():
        fields = line.split()
        if fields:
            names.add(fields[-1])
    return names


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--vendor", type=Path)
    parser.add_argument("--vendor-dlkm", type=Path)
    args = parser.parse_args()

    failures = []

    kos = list((ROOT / "recovery/root").rglob("*.ko"))
    if kos:
        failures.append(f"recovery/root 里有 {len(kos)} 个 .ko")
    else:
        print("PASS  recovery/root 没有 .ko")

    if args.vendor_dlkm:
        present = debugfs_modules(args.vendor_dlkm)
        missing = [m for m in MODULES if m not in present]
        if missing:
            failures.append("vendor_dlkm 缺音频模块: " + ", ".join(missing))
        else:
            print(f"PASS  {len(MODULES)} 个音频模块都在 vendor_dlkm")
    else:
        print("SKIP  vendor_dlkm 未提供")

    if args.vendor:
        missing = [p for p in RUNTIME + CONFIG if not debugfs_stat(args.vendor, p)]
        if missing:
            failures.append("vendor 缺音频运行件/配置: " + ", ".join(missing))
        else:
            print(f"PASS  {len(RUNTIME)} 个运行件、{len(CONFIG)} 个配置都在 vendor")
    else:
        print("SKIP  vendor 未提供")

    check_sources(failures)

    for failure in failures:
        print("FAIL  " + failure)
    print(f"\n结果: {len(failures)} FAIL")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
