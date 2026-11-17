#!/system/bin/sh
# Load Novatek touch only after the real vendor/vendor_dlkm partition is mounted.
# No .ko and no touch firmware are stored in the recovery ramdisk.
LOG=/tmp/aera-touch.log
if grep -q 'nvt_36xxx' /proc/modules 2>/dev/null; then
    echo 'nvt_36xxx already loaded' >>"$LOG"
    setprop aera.touch.loaded true
    exit 0
fi
for base in /vendor_dlkm/lib/modules /vendor_dlkm/lib/modules/* /vendor/lib/modules /vendor/lib/modules/* /lib/modules /lib/modules/* /vendor_boot/lib/modules /vendor_boot/lib/modules/*; do
    [ -d "$base" ] || continue
    if [ -f "$base/nvt_36xxx.ko" ]; then
        insmod "$base/nvt_36xxx.ko" >>"$LOG" 2>&1 && {
            echo "loaded $base/nvt_36xxx.ko" >>"$LOG"
            setprop aera.touch.loaded true
            exit 0
        }
    fi
done
echo "nvt_36xxx.ko not found under real partitions" >>"$LOG"
exit 1
