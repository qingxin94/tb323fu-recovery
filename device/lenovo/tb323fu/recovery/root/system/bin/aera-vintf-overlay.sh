#!/system/bin/sh
# v11: add the stock canoe device-manifest fragment without breaking the
# framework manifest. A device fragment must live under /vendor/etc/vintf/manifest,
# never under /system/etc/vintf/manifest (that directory is framework).
LOG=/tmp/aera-vintf-overlay.log
exec >>"$LOG" 2>&1
echo "=== aera-vintf-overlay $(date 2>/dev/null)"
if grep -q ' /vendor/etc/vintf/manifest ' /proc/mounts 2>/dev/null; then
    echo "already overlaid"
    exit 0
fi
STOCK=/vendor/etc/vintf/manifest
SRC=/system/etc/vintf/aera-canoe-hal.xml
DST=/mnt/aera-vintf
[ -d "$STOCK" ] || { echo "missing $STOCK"; exit 1; }
[ -f "$SRC" ] || { echo "missing $SRC"; exit 1; }
mkdir -p "$DST"
mount -t tmpfs -o size=8m tmpfs "$DST" || { echo "tmpfs failed"; exit 1; }
cp -R "$STOCK"/. "$DST"/ || { echo "copy failed"; exit 1; }
cp "$SRC" "$DST/aera-canoe-hal.xml" || { echo "fragment copy failed"; exit 1; }
chmod 0644 "$DST/aera-canoe-hal.xml"
mount --bind "$DST" "$STOCK" || { echo "bind failed"; exit 1; }
echo "overlay ok: $(ls "$STOCK/aera-canoe-hal.xml")"
