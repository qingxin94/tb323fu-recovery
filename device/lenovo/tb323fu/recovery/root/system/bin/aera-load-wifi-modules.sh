#!/system/bin/sh
# Load the stock WCN7750 WiFi stack only when WiFi is requested.
# Module files are read from the real vendor_dlkm/vendor and system partitions.

LOG=/tmp/aera-wifi.log
exec >>"$LOG" 2>&1
echo "=== aera-load-wifi-modules $(date 2>/dev/null)"

MODDIR=""
for d in /vendor_dlkm/lib/modules /vendor/lib/modules; do
    if [ -f "$d/modules.dep" ]; then MODDIR="$d"; break; fi
done
[ -n "$MODDIR" ] || { echo "no modules.dep"; exit 1; }
DEP="$MODDIR/modules.dep"
SYSDIR=/system/lib/modules

loaded() { grep -q "^$1 " /proc/modules 2>/dev/null; }

find_mod() {
    for d in "$MODDIR" "$SYSDIR"; do
        [ -f "$d/$1.ko" ] && { echo "$d/$1.ko"; return 0; }
    done
    return 1
}

load_one() {
    name="${1%.ko}"
    loaded "$name" && return 0
    path=$(find_mod "$name") || { echo "missing $name.ko"; return 1; }

    deps=$(grep "/$name.ko:" "$DEP" | head -1 | cut -d: -f2- | tr ' ' '\n')
    for dep in $deps; do
        [ -n "$dep" ] || continue
        load_one "$(basename "$dep")"
    done

    insmod "$path" && echo "insmod $path" || echo "FAILED insmod $path"
}

# Stock modules.load order for WCN7750 station mode.
for m in cfg80211.ko mac80211.ko qca_cld3_wcn7750.ko; do
    load_one "$m"
done

echo "wifi modules: cfg80211=$(loaded cfg80211 && echo yes || echo no) mac80211=$(loaded mac80211 && echo yes || echo no) wcn7750=$(loaded qca_cld3_wcn7750 && echo yes || echo no)"
