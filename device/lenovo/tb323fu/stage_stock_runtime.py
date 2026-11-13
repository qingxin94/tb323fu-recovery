#!/usr/bin/env python3
"""Stage the stock vendor runtime bits that AERA needs inside the recovery ramdisk.

Everything is copied from the extracted retail firmware (super_*.img), not from
any older build.  Only the early-boot set lives in the ramdisk; the rest of
vendor/odm is staged from the installed ROM at runtime by AERA_COPY_RUNTIME_TO_RAM.
"""
import os, re, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
STOCK = "/home/user/tb323fu_stock/tree"
REF = "/home/user/aera_infiniti/recovery/root"
OUT = os.path.join(ROOT, "recovery/root")
V, O, D = STOCK + "/vendor", STOCK + "/odm", STOCK + "/vendor_dlkm"

def cp(src, dst, mode=None):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    if mode is not None:
        os.chmod(dst, mode)

HALS = [
    "android.hardware.boot-service.qti",
    "android.hardware.gatekeeper-rust-service-qti",
    "android.hardware.health-service.qti",
    "android.hardware.security.onekeymint-service-qti",
    "vendor.qti.hardware.display.allocator-service",
]
EXTRA_BINS = ["qseecomd"]

# ---- binaries -------------------------------------------------------------
staged = 0
for b in HALS:
    src = os.path.join(V, "bin/hw", b)
    if not os.path.exists(src):
        print("MISSING HAL", b); sys.exit(1)
    cp(src, os.path.join(OUT, "vendor/bin/hw", b), 0o755); staged += 1
for b in EXTRA_BINS:
    cp(os.path.join(V, "bin", b), os.path.join(OUT, "vendor/bin", b), 0o755); staged += 1

# AERA generic scripts (same AERA/TWRP release as the recovery source)
for b in ["prepdecrypt.sh", "aera-runtime-firmware"]:
    cp(os.path.join(REF, "vendor/bin", b), os.path.join(OUT, "vendor/bin", b), 0o755); staged += 1

# stock post-boot module tunables
pb = os.path.join(V, "bin/init.kernel.post_boot-canoe_default_6_2.sh")
if os.path.exists(pb):
    cp(pb, os.path.join(OUT, "vendor/bin/init.kernel.post_boot-canoe_default_6_2.sh"), 0o755); staged += 1

# ---- rc files -------------------------------------------------------------
for rc in ["android.hardware.boot-service.qti.rc",
           "android.hardware.health-service.qti.rc",
           "vendor.qti.hardware.display.allocator-service.rc",
           "qseecomd.rc",
           "android.hardware.gatekeeper-service-qti.rc",
           "android.hardware.security.onekeymint-service-qti.rc"]:
    src = os.path.join(V, "etc/init", rc)
    if not os.path.exists(src):
        print("MISSING rc", rc); sys.exit(1)
    cp(src, os.path.join(OUT, "vendor/etc/init", rc), 0o644)

# onekeymint: never start at "on init" - wait until the runtime + TEE are staged
p = os.path.join(OUT, "vendor/etc/init/android.hardware.security.onekeymint-service-qti.rc")
s = open(p).read()
s = s.replace("on init\n    start vendor.keymint\n", "")
if "start vendor.keymint" in s:
    s = re.sub(r"on init\s*\n\s*start vendor.keymint\s*\n", "", s)
s += "\n# Started by init.recovery.qcom.rc on crypto.ready=1, after prepdecrypt\n# has mounted the installed vendor runtime and the security world is up.\n"
open(p, "w").write(s)

cp(os.path.join(REF, "vendor/etc/init/init.recovery.aera-gpu.rc"),
   os.path.join(OUT, "vendor/etc/init/init.recovery.aera-gpu.rc"), 0o644)
cp(os.path.join(REF, "vendor/etc/init/prepdecrypt.rc"),
   os.path.join(OUT, "vendor/etc/init/prepdecrypt.rc"), 0o644)

# ---- vintf fragments ------------------------------------------------------
vintf_files = [
    "boot-service.qti.xml",
    "android.hardware.health-service.qti.xml",
    "android.hardware.security.onekeymint-service-qti.xml",
    "android.hardware.gatekeeper-service-qti.xml",
    "vendor.qti.hardware.qseecom@1.0-service.xml",
    "mapper.qti.xml",
    "android.hardware.wifi.supplicant.xml",
]
for f in vintf_files:
    src = os.path.join(V, "etc/vintf/manifest", f)
    if os.path.exists(src):
        cp(src, os.path.join(OUT, "vendor/etc/vintf/manifest", f), 0o644)
    else:
        print("note: vintf fragment absent:", f)

# ---- display alignments (gralloc/mapper) ---------------------------------
disp = os.path.join(V, "etc/display")
if os.path.isdir(disp):
    for f in os.listdir(disp):
        if f.endswith(".json"):
            cp(os.path.join(disp, f), os.path.join(OUT, "vendor/etc/display", f), 0o644)

# ---- firmware -------------------------------------------------------------
for f in ["gen80200_aqe.fw", "gen80200_gmu.bin", "gen80200_sqe.fw", "gen80200_zap.mbn",
          "novatek_ts_fw.bin", "novatek_ts_mp.bin"]:
    src = os.path.join(V, "firmware", f)
    if os.path.exists(src):
        cp(src, os.path.join(OUT, "vendor/firmware", f), 0o644)
    else:
        print("note: firmware absent:", f)

# ---- wifi config ----------------------------------------------------------
for d in ["kiwi_v2", "peach_v2", "wcn7750"]:
    s = os.path.join(V, "etc/wifi", d)
    if os.path.isdir(s):
        for f in os.listdir(s):
            cp(os.path.join(s, f), os.path.join(OUT, "vendor/etc/wifi", d, f), 0o644)
for f in ["wpa_supplicant.conf", "wpa_supplicant_overlay.conf", "p2p_supplicant_overlay.conf",
          "vendor_cmd.xml", "sar-vendor-cmd.xml"]:
    src = os.path.join(V, "etc/wifi", f)
    if os.path.exists(src):
        cp(src, os.path.join(OUT, "vendor/etc/wifi", f), 0o644)

wlan_ini = os.path.join(V, "firmware/wlan/qca_cld/wcn7750/WCNSS_qcom_cfg.ini")
if os.path.exists(wlan_ini):
    cp(wlan_ini, os.path.join(OUT, "system/etc/firmware/wlan/WCNSS_qcom_cfg.ini"), 0o644)

# ueventd rules for recovery
u = os.path.join(V, "etc/ueventd.rc")
if os.path.exists(u):
    cp(u, os.path.join(OUT, "system/etc/ueventd.rc"), 0o644)

# ---- kernel modules (early stage only) -----------------------------------
EARLY_KO = ["panel_event_notifier.ko", "spi-msm-geni.ko", "i3c-master-msm-geni.ko",
            "nvt_36xxx.ko", "msm_kgsl.ko", "qmi_helpers.ko", "qcom_glink.ko",
            "qcom_glink_smem.ko", "qcom_smd.ko", "qcom_pdr_msg.ko", "pdr_interface.ko",
            "rproc_qcom_common.ko", "qti_pmic_glink.ko", "qcom-hv-haptics.ko",
            "swr_dlkm.ko", "swr_haptics_dlkm.ko", "aw882xx_dlkm.ko",
            "leds-qpnp-vibrator-ldo.ko"]
for k in EARLY_KO:
    src = os.path.join(D, "lib/modules", k)
    if os.path.exists(src):
        cp(src, os.path.join(OUT, "lib/modules", k), 0o644)
    else:
        print("note: module absent:", k)

# ---- ELF closure ----------------------------------------------------------
search = [V + "/lib64", V + "/lib64/hw", O + "/lib64", O + "/lib64/hw",
          V + "/lib", O + "/lib"]
index = {}
for d in search:
    if os.path.isdir(d):
        for f in os.listdir(d):
            if f.endswith(".so"):
                index.setdefault(f, os.path.join(d, f))

def needed(p):
    try:
        out = subprocess.check_output(["readelf", "-d", p], stderr=subprocess.DEVNULL, text=True)
    except Exception:
        return []
    return re.findall(r"NEEDED.*?\[(.+?)\]", out)

SYSTEM_LIBS = {"libc.so", "libm.so", "libdl.so", "liblog.so", "libbinder.so",
               "libbinder_ndk.so", "libc++.so", "libvndksupport.so", "libapexsupport.so",
               "libutils.so", "libcutils.so", "libbase.so", "libhardware.so",
               "libhidlbase.so", "libhidltransport.so", "libsync.so", "libui.so",
               "libEGL.so", "libGLESv1_CM.so", "libGLESv2.so", "libvulkan.so",
               "libandroid_runtime.so", "libnativewindow.so", "libhardware_legacy.so"}
roots = [os.path.join(OUT, "vendor/bin/hw", b) for b in HALS] + \
        [os.path.join(OUT, "vendor/bin", b) for b in EXTRA_BINS]
seen, missing, picked, queue = set(), set(), set(), list(roots)
while queue:
    p = queue.pop()
    for n in needed(p):
        if n in seen:
            continue
        seen.add(n)
        if n in SYSTEM_LIBS:
            continue
        src = index.get(n)
        if not src:
            missing.add(n)
            continue
        picked.add(src)
        queue.append(src)

# gralloc/mapper closure is not pulled by the HALs above but the AERA renderer needs it
GRALLOC = ["libgralloccore.so", "libgralloc.qti.so", "libgralloctypes.so", "libgrallocutils.so",
           "libmapperutils.so", "libdmabufheap.so", "android.hardware.graphics.mapper@4.0.so",
           "android.hardware.graphics.allocator@4.0.so", "android.hardware.graphics.common@1.2.so"]
for n in GRALLOC:
        for d in search:
            s = os.path.join(d, n)
            if os.path.exists(s):
                picked.add(s)
                for dep in needed(s):
                    s2 = index.get(dep)
                    if s2 and dep not in SYSTEM_LIBS:
                        picked.add(s2)
                break

for src in sorted(picked):
    rel = os.path.relpath(src, STOCK)            # vendor/lib64/... or odm/lib64/...
    dst = os.path.join(OUT, rel)
    cp(src, dst, 0o644)

print("binaries staged:", staged)
print("libs staged:", len(picked), "size MB:", round(sum(os.path.getsize(x) for x in picked) / 1048576, 1))
print("unresolved (expected from system image):", sorted(missing))
