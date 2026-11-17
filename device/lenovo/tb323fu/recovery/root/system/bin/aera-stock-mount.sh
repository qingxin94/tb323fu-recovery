#!/system/bin/sh
# AERA stock-partition mount only.
# No file is copied into the recovery ramdisk.  Every stock dependency is
# mounted from its real partition and used in place.

PATH=/system/bin:/vendor/bin
export PATH

LOG=/tmp/aera-stock-mount.log
mkdir -p /vendor /vendor_dlkm /odm /system_dlkm /mnt/aera-stock
: > "$LOG"

log() { echo "$*" >> "$LOG"; }

mounted() { grep -q " $1 " /proc/mounts; }

mount_one() {
    part="$1"; mp="$2"
    mkdir -p "$mp" 2>/dev/null
    if mounted "$mp"; then log "already mounted $mp"; return 0; fi
    for src in /dev/block/mapper/$part                /dev/block/by-name/${part}_a /dev/block/by-name/$part                /dev/block/bootdevice/by-name/${part}_a /dev/block/bootdevice/by-name/$part; do
        [ -e "$src" ] || continue
        for fs in ext4 erofs f2fs; do
            if mount -t "$fs" -o ro "$src" "$mp" 2>>"$LOG"; then
                log "mounted $src -> $mp ($fs)"
                return 0
            fi
        done
    done
    # Last resort: bind an already-mounted scan tree, never copy.
    for src in /mnt/aera_scan/${part}_a /mnt/aera_scan/$part; do
        if mounted "$src"; then
            if mount -o bind "$src" "$mp" 2>>"$LOG"; then
                log "bound $src -> $mp"
                return 0
            fi
        fi
    done
    log "FAILED mount $part -> $mp"
    return 1
}

i=0
while [ "$i" -lt 90 ]; do
    ok=1
    mount_one vendor /vendor || ok=0
    mount_one vendor_dlkm /vendor_dlkm || ok=0
    mount_one odm /odm || ok=0
    # system_dlkm is optional for display/touch/crypto; keep it if present.
    mount_one system_dlkm /system_dlkm || true

    if [ "$ok" = 1 ] && [ -d /vendor/lib64 ] && [ -d /vendor/bin ] && \
       { [ -d /vendor_dlkm/lib/modules ] || [ -d /lib/modules ]; } && [ -d /odm/etc ]; then
        # Firmware must be visible to the kernel firmware loader; bind, never copy.
        if [ -d /vendor/firmware ] && ! mounted /lib/firmware; then
            mount -o bind /vendor/firmware /lib/firmware 2>>"$LOG" || true
            log "bind /vendor/firmware -> /lib/firmware"
        fi
        # AERA audio bootstrap expects the stock vendor root here.
        if [ ! -e /mnt/aera-stock/vendor ] && [ -d /vendor ]; then
            mkdir -p /mnt/aera-stock
            mount -o bind /vendor /mnt/aera-stock/vendor 2>>"$LOG" || true
        fi
        # Real /odm would otherwise hide the AERA device VINTF root manifest.
        # qseecomd/KeyMint read the modem firmware image from this mount.
        if [ ! -e /vendor/firmware_mnt/image ]; then
            mkdir -p /vendor/firmware_mnt
            for src in /dev/block/by-name/modem_a /dev/block/by-name/modem                        /dev/block/bootdevice/by-name/modem_a /dev/block/bootdevice/by-name/modem; do
                [ -e "$src" ] || continue
                mount -t vfat -o ro "$src" /vendor/firmware_mnt 2>>"$LOG" && break
                mount -t ext4 -o ro "$src" /vendor/firmware_mnt 2>>"$LOG" && break
            done
        fi
        # Persist and SPU NVM are required by gatekeeper/weaver/sec_nvm.
        # Mount the real partitions first; never bind a stale empty directory.
        if ! mounted /persist; then
            mount_one persist /persist || true
        fi
        if ! mounted /mnt/vendor/spunvm; then
            mkdir -p /mnt/vendor/spunvm
            for src in /dev/block/by-name/spunvm_a /dev/block/by-name/spunvm                        /dev/block/bootdevice/by-name/spunvm_a /dev/block/bootdevice/by-name/spunvm; do
                [ -e "$src" ] || continue
                mount -t vfat -o ro "$src" /mnt/vendor/spunvm 2>>"$LOG" && break
            done
        fi
        if mounted /persist && ! mounted /mnt/vendor/persist; then
            mkdir -p /mnt/vendor/persist
            mount -o bind /persist /mnt/vendor/persist 2>>"$LOG" || true
        fi
        # Real /odm would otherwise hide the AERA device VINTF root manifest.
        if [ -f /system/etc/vintf/device-manifest.xml ]; then
            mkdir -p /odm/etc/vintf
            touch /odm/etc/vintf/manifest.xml 2>/dev/null || true
            mount -o bind /system/etc/vintf/device-manifest.xml \
                /odm/etc/vintf/manifest.xml 2>>"$LOG" || true
        fi
        # Verify the paths that display, touch and crypto actually need.
        for f in \
            /vendor/bin/hw/vendor.qti.hardware.display.allocator-service \
            /vendor/lib64/egl/libEGL_adreno.so \
            /vendor/lib64/libQSEEComAPI.so \
            /vendor/firmware/novatek_ts_fw.bin \
            /odm/etc/vintf/manifest.xml; do
            [ -e "$f" ] || { log "missing $f"; ok=0; }
        done
        # Modules may come from vendor_dlkm or the real vendor_boot ramdisk.
        if [ ! -d /vendor_dlkm/lib/modules ] && [ ! -d /lib/modules ]; then
            log "missing module directory"
            ok=0
        fi
        if [ "$ok" = 1 ]; then
            # Load touch before the UI is allowed to come up.
            /system/bin/sh /system/bin/aera-touch-load.sh >>"$LOG" 2>&1 || true
            log "stock partitions mounted and verified"
            setprop aera.stock.mounted true
            exit 0
        fi
    fi
    i=$((i + 1))
    sleep 1
done

log "stock mount failed after retries"
setprop aera.stock.mount_failed true
exit 1
