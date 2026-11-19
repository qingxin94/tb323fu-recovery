#!/system/bin/sh
# v12: load the stock WCN786x closure, but release cnss2 fs_ready BEFORE qca.
# Skyward (working) writes cnss2 fs_ready before qca probe; V15 rc wrote it
# only after qca, which is too late for stock qca and ends in 900E.
# mac80211 is not in qca modules.dep and is not loaded here.
# Modules still come from real vendor_dlkm/system_dlkm; nothing in ramdisk.

STAGEFILE=/metadata/aera-wifi.stage
LOG=/metadata/aera-wifi.log
[ -w /metadata ] || { STAGEFILE=/cache/aera-wifi.stage; LOG=/cache/aera-wifi.log; }
[ -d /cache ] || LOG=/tmp/aera-wifi.log
exec >>"$LOG" 2>&1
STAGE=$(cat "$STAGEFILE" 2>/dev/null | tr -dc '0-9')
[ -n "$STAGE" ] || STAGE=3
echo "=== aera-wifi-prep v12 $(date 2>/dev/null) stage=$STAGE"
echo "stage file: $STAGEFILE"
setprop aera.wifi.loaded false 2>/dev/null || true
mkdir -p /tmp/recovery/sockets /tmp/recovery/wifi 2>/dev/null || true
chmod 0777 /tmp/recovery /tmp/recovery/sockets 2>/dev/null || true

MODDIR=/vendor_dlkm/lib/modules
SYSDIR=/system_dlkm/lib/modules
FWDIR=/vendor/firmware_mnt/image
[ -d "$FWDIR/peach" ] || FWDIR=/firmware/image
echo "firmware dir: $FWDIR"
if [ -w /sys/module/firmware_class/parameters/path ]; then
    echo "$FWDIR" > /sys/module/firmware_class/parameters/path 2>/dev/null \
        && echo "firmware_class.path=$FWDIR"
fi
echo 1 > /proc/sys/kernel/firmware_config/force_sysfs_fallback 2>/dev/null || true
mkdir -p /lib/firmware 2>/dev/null || true
[ -e /lib/firmware/peach ] || ln -sfn "$FWDIR/peach" /lib/firmware/peach 2>/dev/null || true
[ -e /lib/firmware/tmel_peach_20.elf ] || \
    ln -sfn "$FWDIR/tmel_peach_20.elf" /lib/firmware/tmel_peach_20.elf 2>/dev/null || true

QCADIR=/vendor/firmware/wlan/qca_cld/peach_v2
CFGDIR=/vendor/etc/wifi/peach_v2
mkdir -p "$QCADIR" 2>/dev/null && {
    [ -f "$CFGDIR/WCNSS_qcom_cfg.ini" ] && \
        ln -sfn "$CFGDIR/WCNSS_qcom_cfg.ini" "$QCADIR/WCNSS_qcom_cfg.ini" 2>/dev/null || true
    [ -r /mnt/vendor/persist/peach_v2/wlan_mac.bin ] && \
        ln -sfn /mnt/vendor/persist/peach_v2/wlan_mac.bin "$QCADIR/wlan_mac.bin" 2>/dev/null || true
} || echo "cannot write $QCADIR; skip cfg links"

path_of() { case "$1" in rfkill) echo "$SYSDIR/rfkill.ko" ;; *) echo "$MODDIR/$1.ko" ;; esac; }
loaded() { n="$1"; grep -qE "^(${n}|$(echo "$n" | tr '-' '_')) " /proc/modules 2>/dev/null; }
load() {
    name="$1"; path="$(path_of "$name")"
    loaded "$name" && { echo "already loaded: $name"; return 0; }
    [ -f "$path" ] || { echo "missing: $path"; return 1; }
    echo "try: $name ($path)"; sync 2>/dev/null || true
    insmod "$path" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ] || loaded "$name"; then
        echo "loaded: $name"; sync 2>/dev/null || true; return 0
    fi
    echo "FAILED ($rc): $path"; sync 2>/dev/null || true; return 1
}

# Stock qca dependency closure, in modules.dep order. No mac80211.
DEPS="qmi_helpers pcie-pdc pci-msm-drv mhi rproc_qcom_common qcom_smd qcom_glink_smem qcom_glink qcom_ramdump qcom_va_minidump ucsi_qti_glink qti_pmic_glink pdr_interface qcom_pdr_msg usb_f_gsi dwc3-msm repeater redriver lenovo_kallsyms smem-mailbox cnss_prealloc cnss_utils cnss_nl cnss_plat_ipc_qmi_svc wlan_firmware_service cnss2 rmnet_mem gsim ipam cfg80211"
case "$STAGE" in
    0) LIST="rfkill" ;;
    1) LIST="rfkill cfg80211" ;;
    2) LIST="rfkill cfg80211 $DEPS" ;;
    3|*) LIST="rfkill cfg80211 $DEPS qca_cld3_peach_v2" ;;
esac
echo "stage=$STAGE list=$LIST"
for m in $LIST; do
    load "$m" || true
    if [ "$m" = "cnss2" ] && [ "$STAGE" -ge 3 ]; then
        # qca must not probe until cnss2 says firmware fs is ready.
        FS=/sys/bus/platform/drivers/cnss2/b0000000.qcom,cnss-peach/fs_ready
        OLD=/sys/kernel/cnss/fs_ready
        for i in 1 2 3 4 5; do [ -e "$FS" ] && break; sleep 1; done
        if [ -e "$FS" ]; then
            chmod 222 "$FS" 2>/dev/null || true
            echo 1 > "$FS" 2>/dev/null && echo "cnss2 fs_ready=1 ($FS)"
        else
            echo "cnss2 fs_ready node missing ($FS)"
        fi
        if [ -e "$OLD" ]; then
            echo 1 > "$OLD" 2>/dev/null && echo "cnss fs_ready=1 ($OLD)"
        fi
        start cnss-daemon 2>/dev/null || true
        setprop aera.wifi.loaded true
        sleep 2
    fi
done

echo "modules after wifi:"
grep -E '^(cfg80211|cnss2|qca_cld3_peach_v2) ' /proc/modules 2>/dev/null || true
setprop aera.wifi.loaded true
echo "=== prep done"
