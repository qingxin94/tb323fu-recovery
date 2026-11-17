#!/system/bin/sh
# Load the TB323FU Wi-Fi/audio/haptics modules from the real partitions.
#
# Nothing is copied or staged into /tmp.  Every module is insmod'ed in place
# from /vendor_dlkm or /system_dlkm after aera-stock-mount.sh has mounted and
# verified those filesystems.  This deliberately does not wait for /data
# decryption: recovery can bring up Wi-Fi, audio and vibrator without decrypting
# userdata, which is required when the PIN path is still being debugged.

PATH=/system/bin:/vendor/bin
export PATH

LOG=/tmp/aera-real-modules.log
LIST=/system/etc/aera-real-modules.list
: > "$LOG" 2>/dev/null || true

log() { echo "$*" >> "$LOG" 2>/dev/null || true; }

normalize() {
    echo "$1" | tr '-' '_' | sed 's/\.ko$//'
}

module_loaded() {
    name="$(normalize "$1")"
    grep -q "^${name} " /proc/modules 2>/dev/null
}

find_module() {
    wanted="$1"
    for dir in /vendor_dlkm/lib/modules /system_dlkm/lib/modules /vendor/lib/modules; do
        [ -d "$dir" ] || continue
        if [ -f "$dir/$wanted" ]; then
            echo "$dir/$wanted"
            return 0
        fi
        for sub in "$dir"/*; do
            if [ -f "$sub/$wanted" ]; then
                echo "$sub/$wanted"
                return 0
            fi
        done
    done
    return 1
}

# system_dlkm is optional in aera-stock-mount.sh, but rfkill.ko and
# libarc4.ko only exist there.  Try the real mapper/by-name devices directly
# rather than copying anything; without these two the cfg80211 chain cannot
# load and Wi-Fi will never produce wlan0.
if [ ! -f /system_dlkm/lib/modules/rfkill.ko ]; then
    mkdir -p /system_dlkm 2>/dev/null || true
    for src in /dev/block/mapper/system_dlkm /dev/block/by-name/system_dlkm_a /dev/block/by-name/system_dlkm /dev/block/bootdevice/by-name/system_dlkm_a /dev/block/bootdevice/by-name/system_dlkm; do
        [ -e "$src" ] || continue
        for fs in ext4 erofs f2fs; do
            if mount -t "$fs" -o ro "$src" /system_dlkm 2>>"$LOG"; then
                log "mounted real system_dlkm from $src ($fs)"
                break 2
            fi
        done
    done
fi

log "loading real-partition modules from $LIST"
if [ ! -f "$LIST" ]; then
    log "missing module list $LIST"
    setprop aera.modules.loaded true
    exit 1
fi

for pass in 1 2; do
    while read -r mod; do
        [ -n "$mod" ] || continue
        case "$mod" in \#*) continue;; esac
        if module_loaded "$mod"; then
            continue
        fi
        path="$(find_module "$mod")" || path=""
        if [ -z "$path" ]; then
            log "module not present on real partitions: $mod"
            continue
        fi

        # cnss-daemon must be alive before the Peach WLAN driver is loaded.
        if [ "$mod" = "qca_cld3_peach_v2.ko" ] && [ ! -d /sys/module/qca_cld3_peach_v2 ]; then
            setprop ctl.start cnss-daemon 2>/dev/null || true
            sleep 1
        fi

        log "insmod $path"
        insmod "$path" 2>>"$LOG"
        rc=$?
        if [ "$rc" -eq 0 ]; then
            log "loaded $mod"
        elif module_loaded "$mod"; then
            log "already loaded $mod"
        else
            log "insmod failed ($rc): $mod"
        fi
    done < "$LIST"
done

# Do not block the UI if an optional module failed.  Services that need it will
# report their own failure in their logs; the property still releases the
# WiFi/audio init blocks so they do not wait for a /data decryption that is not
# part of this recovery path.
setprop aera.modules.loaded true
log "real-partition module pass finished"
exit 0
