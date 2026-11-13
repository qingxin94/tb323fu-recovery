#!/system/bin/sh
# AERA WLAN loader for Lenovo TB323FU (WCN786x "peach v2").
#
# One-shot init service started by init.recovery.wifi.rc when the AERA UI
# enables Wi-Fi (sys.aera.wlan.up=1). It loads the stock driver module closure
# staged under /AERA/modules/wlan (extracted from stock vendor_dlkm and
# system_dlkm), points the kernel firmware loader at the modem firmware
# partition (/firmware/image), recreates the vendor cfg/MAC symlink tree,
# signals cnss2 that firmware is ready, then lets init.recovery.wifi.rc start
# wpa_supplicant once wlan0 appears.
#
# Module list/order was derived from the stock /lib/modules/modules.dep
# dependency closure of qca_cld3_peach_v2.ko.
#
# Everything is logged to /tmp/aera-wlan.log for adb-side diagnosis.

PATH=/system/bin:/vendor/bin:/sbin
LOG=/tmp/aera-wlan.log
MODDIR=/AERA/modules/wlan
CFGDIR=/vendor/etc/wifi/peach_v2
QCADIR=/vendor/firmware/wlan/qca_cld/peach_v2
FWIMAGE=/firmware/image

log() { echo "aera-wlan: $*" >> "$LOG"; }

mkdir -p /tmp 2>/dev/null
: > "$LOG" 2>/dev/null
log "start $(date)"
log "kernel: $(uname -r)"

# --- 0. /firmware (stock modem_a vfat) holds the only real WLAN firmware ---
if ! grep -q ' /firmware ' /proc/mounts 2>/dev/null; then
    mkdir -p /firmware
    mount -t vfat -o ro /dev/block/bootdevice/by-name/modem_a /firmware >>"$LOG" 2>&1 \
        || log "mount /firmware failed"
fi
for f in image/peach/bdwlan.elf image/peach/amss20.bin image/peach/regdb.bin image/tmel_peach_20.elf; do
    [ -r "/firmware/$f" ] || log "missing /firmware/$f"
done

# --- 1. kernel firmware search root: cnss2 names are "peach/<file>" ---
echo "$FWIMAGE" > /sys/module/firmware_class/parameters/path 2>>"$LOG" \
    && log "firmware_class.path=$FWIMAGE" || log "cannot set firmware_class.path"
echo 1 > /proc/sys/kernel/firmware_config/force_sysfs_fallback 2>/dev/null

# ueventd fallback first-choice directory (init's own symlink did not take).
[ -e /vendor/firmware_mnt ] || ln -sfn /firmware /vendor/firmware_mnt
mkdir -p /lib/firmware 2>/dev/null
[ -e /lib/firmware/peach ] || ln -sfn /firmware/image/peach /lib/firmware/peach
[ -e /lib/firmware/tmel_peach_20.elf ] || \
    ln -sfn /firmware/image/tmel_peach_20.elf /lib/firmware/tmel_peach_20.elf

# --- 2. qca_cld3 expects the vendor cfg/MAC symlink tree ---
mkdir -p "$CFGDIR" "$QCADIR" 2>>"$LOG"
[ -f "$CFGDIR/WCNSS_qcom_cfg.ini" ] || log "missing $CFGDIR/WCNSS_qcom_cfg.ini"
ln -sfn "$CFGDIR/WCNSS_qcom_cfg.ini" "$QCADIR/WCNSS_qcom_cfg.ini"
if [ -e /mnt/vendor/persist/peach_v2/wlan_mac.bin ]; then
    ln -sfn /mnt/vendor/persist/peach_v2/wlan_mac.bin "$QCADIR/wlan_mac.bin"
    log "factory mac: $(cat /mnt/vendor/persist/peach_v2/wlan_mac.bin 2>/dev/null)"
else
    log "persist MAC missing; AERA will derive a stable MAC"
fi
command -v restorecon >/dev/null 2>&1 && \
    restorecon -R /vendor/firmware /vendor/etc/wifi >/dev/null 2>&1

# --- 2b. factory MAC: AERA's MAC preparation writes a derived MAC into
# /system/etc/firmware; the driver's request_firmware() lookup hits that copy
# (ueventd resolved it before /vendor/firmware_mnt existed). Keep the factory
# MAC from /persist (single Intf0MacAddress line, no "END" marker) for the
# actual driver load.
PERSIST_MAC=/mnt/vendor/persist/peach_v2/wlan_mac.bin
ETC_MAC=/system/etc/firmware/wlan/qca_cld/peach_v2/wlan_mac.bin
if [ -r "$PERSIST_MAC" ] && ! grep -q 'END' "$PERSIST_MAC" 2>/dev/null; then
    mkdir -p "$(dirname "$ETC_MAC")" 2>>"$LOG"
    cp -f "$PERSIST_MAC" "$ETC_MAC" 2>>"$LOG" && log "factory MAC staged to /etc/firmware"
fi

# --- 3. module closure (dependency order from stock modules.dep) ---
# name:path entries; retried in up to 4 passes so ordering tolerates
# already-loaded/unloaded combinations.
MODULES="
rfkill:$MODDIR/rfkill.ko
pcie-pdc:/lib/modules/pcie-pdc.ko
pci-msm-drv:/lib/modules/pci-msm-drv.ko
dwc3-msm:/lib/modules/dwc3-msm.ko
smem-mailbox:$MODDIR/smem-mailbox.ko
cnss_prealloc:$MODDIR/cnss_prealloc.ko
cnss_utils:$MODDIR/cnss_utils.ko
cnss_nl:$MODDIR/cnss_nl.ko
cnss_plat_ipc_qmi_svc:$MODDIR/cnss_plat_ipc_qmi_svc.ko
wlan_firmware_service:$MODDIR/wlan_firmware_service.ko
cnss2:$MODDIR/cnss2.ko
rmnet_mem:$MODDIR/rmnet_mem.ko
gsim:$MODDIR/gsim.ko
ipam:$MODDIR/ipam.ko
cfg80211:/lib/modules/cfg80211.ko
qca_cld3_peach_v2:$MODDIR/qca_cld3_peach_v2.ko
"

is_loaded() {
    local n="$1" alt
    alt=$(echo "$n" | tr '-' '_')
    grep -qE "^(${n}|${alt}) " /proc/modules 2>/dev/null
}

load_one() {
    local n="$1" p="$2"
    if is_loaded "$n"; then log "already loaded: $n"; return 0; fi
    if [ ! -f "$p" ]; then log "missing module file: $p"; return 1; fi
    /system/bin/insmod "$p" >>"$LOG" 2>&1 && { log "loaded: $n"; return 0; }
    # EEXIST when a race loaded it between the check and insmod
    if is_loaded "$n"; then log "loaded (race): $n"; return 0; fi
    return 1
}

pass=1
remaining="$MODULES"
while [ -n "$remaining" ] && [ "$pass" -le 4 ]; do
    log "module pass $pass"
    still=""
    for entry in $remaining; do
        n=${entry%%:*}; p=${entry#*:}
        load_one "$n" "$p" || still="$still $entry"
    done
    remaining=$(echo $still)
    pass=$((pass + 1))
done
[ -n "$remaining" ] && log "FAILED to load:$remaining"

# --- 4. tell cnss2 the firmware filesystem is ready (retry timer exists) ---
if [ -e /sys/kernel/cnss/fs_ready ]; then
    echo 1 > /sys/kernel/cnss/fs_ready 2>>"$LOG" && log "cnss fs_ready=1"
else
    log "fs_ready node not present yet"
fi

log "done $(date)"
