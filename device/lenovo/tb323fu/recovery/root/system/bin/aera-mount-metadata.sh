#!/system/bin/sh
# Wait for ueventd to publish the metadata by-name link; never block init.
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    [ -e /dev/block/by-name/metadata ] && break
    /system/bin/toybox sleep 0.5
done
[ -e /dev/block/by-name/metadata ] || exit 0
mkdir -p /metadata
mountpoint=/metadata
/system/bin/toybox mount -t f2fs -o noatime,nosuid,nodev,discard /dev/block/by-name/metadata /metadata
