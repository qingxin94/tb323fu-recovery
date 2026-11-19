#!/system/bin/sh
# Load only the stock TEE subset, resolving modules.dep.
# Module files are read from the real vendor_dlkm/vendor partition; never copied.

LOG=/tmp/aera-stock-mount.log
exec >>"$LOG" 2>&1

MODDIR=""
for d in /vendor_dlkm/lib/modules /vendor/lib/modules; do
    if [ -f "$d/modules.dep" ]; then MODDIR="$d"; break; fi
done
[ -n "$MODDIR" ] || { echo "no modules.dep"; exit 1; }
DEP="$MODDIR/modules.dep"

loaded() { grep -q "^$1 " /proc/modules 2>/dev/null; }

load_one() {
    name="${1%.ko}"
    loaded "$name" && return 0
    [ -f "$MODDIR/$name.ko" ] || { echo "missing $name.ko"; return 1; }

    # Resolve direct dependencies from the stock modules.dep.
    deps=$(grep "/$name.ko:" "$DEP" | head -1 | cut -d: -f2- | tr ' ' '\n')
    for dep in $deps; do
        [ -n "$dep" ] || continue
        load_one "$(basename "$dep")"
    done

    insmod "$MODDIR/$name.ko" && echo "insmod $name.ko" || echo "FAILED insmod $name.ko"
}

# Exact stock modules.load order for the TEE/SPU path.
for m in \
    qcom_q6v5.ko qcom_q6v5_pas.ko \
    qcom_spss.ko qcom_sysmon.ko rproc_qcom_common.ko \
    glink_pkt.ko qcom_glink.ko qcom_glink_smem.ko qcom_glink_spss.ko qcom_smd.ko \
    sps_drv.ko qmi_helpers.ko qsee_ipc_irq_bridge.ko \
    qce50_dlkm.ko hdcp_qseecom_dlkm.ko smcinvoke_dlkm.ko \
    spcom.ko spss_utils.ko \
    nvt_36xxx.ko; do
    load_one "$m"
done

# v9: qce50_dlkm and spss_utils must be forced. load_one() can return early
# because /proc/modules does not expose them at this point in recovery.
force_load() {
    name="$1"
    if [ -e "/sys/module/$name" ]; then
        echo "already loaded $name"
        return 0
    fi
    [ -f "$MODDIR/$name.ko" ] || { echo "missing $name.ko"; return 1; }
    insmod "$MODDIR/$name.ko" && echo "force insmod $name.ko" || echo "force FAILED $name.ko"
}
force_load qce50_dlkm
force_load spss_utils
for i in $(seq 1 10); do
    [ -e /dev/spss_utils ] && break
    sleep 1
done
[ -e /dev/spss_utils ] || echo "still missing /dev/spss_utils"

echo "modules: spss_utils=$(loaded spss_utils && echo yes || echo no) qce50_dlkm=$(loaded qce50_dlkm && echo yes || echo no) spcom=$(loaded spcom && echo yes || echo no)"
echo "devices: smcinvoke=$([ -e /dev/smcinvoke ] && echo yes || echo no) spss_utils=$([ -e /dev/spss_utils ] && echo yes || echo no)"
