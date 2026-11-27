#!/system/bin/sh
# Own compatibility chain: stock dependency order, adapted to recovery.
# All binaries are the real /vendor originals; this script only starts them.

# v15: one-shot chain. Repeated starts were caused by the crypto.ready ->
# audit -> aera.stock.mounted -> base -> v13 -> twrp.modules.loaded loop.
if [ "$(getprop aera.chain.done)" = "1" ]; then
    exit 0
fi

LOG=/tmp/aera-crypto-chain.log
exec >>"$LOG" 2>&1
echo "=== aera-crypto-chain $(date 2>/dev/null)"

wait_dev() {
    dev="$1"; tries="${2:-10}"
    for i in $(seq 1 "$tries"); do
        [ -e "$dev" ] && return 0
        sleep 1
    done
    echo "missing $dev after ${tries}s"
    return 1
}

wait_svc() {
    svc="$1"; tries="${2:-10}"
    for i in $(seq 1 "$tries"); do
        state=$(getprop "init.svc.$svc")
        [ "$state" = "running" ] && return 0
        sleep 1
    done
    echo "service $svc state=$(getprop init.svc.$svc)"
    return 1
}

# Real /vendor/build.prop is mounted after property loading, so these two
# stock switches must be applied explicitly before the TEE services start.
setprop vendor.gatekeeper.is_security_level_spu 1
setprop vendor.spu.rkp_enabled true

# Stock init.spdaemon.rc creates these before starting spdaemon/sec_nvm.
mkdir -p /mnt/vendor/persist/secnvm /mnt/vendor/persist/spudc /mnt/vendor/persist/iar_db /mnt/vendor/spunvm 2>/dev/null || true
chown system:system /mnt/vendor/persist/secnvm /mnt/vendor/persist/spudc /mnt/vendor/persist/iar_db /mnt/vendor/spunvm 2>/dev/null || true
chmod 0770 /mnt/vendor/persist/secnvm /mnt/vendor/persist/spudc /mnt/vendor/persist/iar_db 2>/dev/null || true
chmod 0660 /mnt/vendor/spunvm 2>/dev/null || true

# TWRP/base both restore labels on persist before SPU NVM access.
restorecon -R /persist /mnt/vendor/persist 2>/dev/null || true

# v18: switch to the stock A16 vendor-domain binder context manager before
# any vendor HAL (keymint/weaver/spu) registers a service.
/system/bin/aera-vnd-switch.sh

# v11: device VINTF fragment overlay (framework manifest must stay valid).
/system/bin/aera-vintf-overlay.sh

# Load the exact stock TEE subset before qseecomd starts.
/system/bin/sh /system/bin/aera-load-tee-modules.sh

# Stock/TWRP order: qseecomd -> mink -> keymint -> keymint-spu -> spu ->
# gatekeeper/weaver. Waits are explicit because recovery has no class start.
start vendor.qseecomd
wait_svc vendor.qseecomd 10
# qseecomd uses /dev/smcinvoke; /dev/qseecom is not required by this daemon.
wait_dev /dev/smcinvoke 5
start vendor.secretkeeper

# v13 fallback: if boot-time force load did not create /dev/spss_utils, retry
# once after qseecomd is alive. This is a retry, not a reorder.
if [ ! -e /dev/spss_utils ]; then
    MODDIR=/vendor_dlkm/lib/modules
    [ -f "$MODDIR/spss_utils.ko" ] || MODDIR=/vendor/lib/modules
    [ -e /sys/module/qce50_dlkm ] || insmod "$MODDIR/qce50_dlkm.ko" 2>/dev/null
    [ -e /sys/module/spss_utils ] || insmod "$MODDIR/spss_utils.ko" 2>/dev/null
    wait_dev /dev/spss_utils 20
fi

start vendor.minkdaemon
start vendor.keymint
wait_svc vendor.keymint 10

# v12: keep default gatekeeper as the working IGatekeeper/default.
start vendor.gatekeeper_default
wait_svc vendor.gatekeeper_default 10

# SPU NVM must be prepared before the SPU HAL starts.
start vendor.spdaemon
wait_svc vendor.spdaemon 10
start vendor.sec_nvm
wait_svc vendor.sec_nvm 10

# v16: match AERA R1.0's working SPU chain. AERA10 starts keymint-spu,
# gatekeeper_spu and the qti SPU HAL before weaver; the old V15 chain
# explicitly stopped all three, which left SPU weaver with -5338.
start vendor.keymint-spu-qti
wait_svc vendor.keymint-spu-qti 15
start vendor.gatekeeper_spu
wait_svc vendor.gatekeeper_spu 15
start vendor.qti.hardware.spu.service
wait_svc vendor.qti.hardware.spu.service 15
wait_dev /dev/spcom 10
sleep 2
start vendor.spu_weaver
wait_svc vendor.spu_weaver 15

# v14 evidence: capture weaver's open fds and kernel-side SPU lines.
pid=$(getprop init.svc_debug_pid.vendor.spu_weaver)
if [ -n "$pid" ] && [ -d "/proc/$pid/fd" ]; then
    ls -l "/proc/$pid/fd" > /tmp/aera-weaver-fd.log 2>&1 || true
fi
dmesg > /tmp/aera-dmesg.log 2>&1 || true

echo "final: qseecomd=$(getprop init.svc.vendor.qseecomd) keymint=$(getprop init.svc.vendor.keymint) spdaemon=$(getprop init.svc.vendor.spdaemon) sec_nvm=$(getprop init.svc.vendor.sec_nvm) qti=$(getprop init.svc.vendor.qti.hardware.spu.service) keymint-spu=$(getprop init.svc.vendor.keymint-spu-qti) gatekeeper-default=$(getprop init.svc.vendor.gatekeeper_default) gatekeeper=$(getprop init.svc.vendor.gatekeeper_spu) weaver=$(getprop init.svc.vendor.spu_weaver)"
setprop aera.chain.done 1
setprop crypto.ready 1
echo "=== chain done"
