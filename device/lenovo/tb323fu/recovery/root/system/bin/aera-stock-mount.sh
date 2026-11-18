#!/system/bin/sh
# AERA stock-partition mount only.
#
# Every binary, library, firmware file and kernel module is used in place on
# the real partitions.  Nothing is copied into the recovery ramdisk or /tmp.
#
# Mount order:
#   vendor / vendor_dlkm / odm / system_dlkm   (read-only)
#   persist (read-write) -> /mnt/vendor/persist
#   spunvm (read-write)
#   metadata (read-write, for FBE)
#
set -u

PATH=/system/bin:/vendor/bin
export PATH

LOG=/tmp/aera-stock-mount.log
mkdir -p /vendor /vendor_dlkm /odm /system_dlkm /mnt/aera-stock /mnt/vendor/persist /mnt/vendor/spunvm
: > "$LOG" 2>/dev/null || true

log() { echo "$*" >> "$LOG" 2>/dev/null || true; }
mounted() { grep -q " $1 " /proc/mounts 2>/dev/null; }

# Find a partition by logical name, active slot, or by-name path.
find_part() {
    name="$1"
    for src in \
        "/dev/block/mapper/${name}" \
        "/dev/block/mapper/${name}_a" \
        "/dev/block/mapper/${name}_b" \
        "/dev/block/by-name/${name}" \
        "/dev/block/by-name/${name}_a" \
        "/dev/block/by-name/${name}_b" \
        "/dev/block/bootdevice/by-name/${name}" \
        "/dev/block/bootdevice/by-name/${name}_a" \
        "/dev/block/bootdevice/by-name/${name}_b"; do
        [ -b "$src" ] && { echo "$src"; return 0; }
    done
    return 1
}

mount_read_only() {
    part="$1"; mp="$2"
    mounted "$mp" && { log "already mounted $mp"; return 0; }
    src="$(find_part "$part")" || { log "missing partition $part"; return 1; }
    mkdir -p "$mp" 2>/dev/null || true
    for fs in ext4 erofs f2fs; do
        if mount -t "$fs" -o ro "$src" "$mp" 2>>"$LOG"; then
            log "mounted $src -> $mp ($fs, ro)"
            return 0
        fi
    done
    log "FAILED ro mount $part ($src) -> $mp"
    return 1
}

# Mount read-write.  If AERA already mounted it read-only, remount rw and
# leave the existing mount alone when remount is denied.  Do not unmount a
# partition AERA may already be using just to force a fresh mount.
mount_read_write() {
    part="$1"; mp="$2"; shift 2
    if mounted "$mp"; then
        if grep -q " $mp ro," /proc/mounts 2>/dev/null; then
            if mount -o remount,rw "$mp" 2>>"$LOG"; then
                log "remounted $mp rw"
                return 0
            fi
            log "remount rw denied for $mp; keeping existing mount"
            return 1
        else
            log "already mounted rw $mp"
            return 0
        fi
    fi
    src="$(find_part "$part")" || { log "missing partition $part"; return 1; }
    mkdir -p "$mp" 2>/dev/null || true
    for fs in "$@"; do
        if mount -t "$fs" "$src" "$mp" 2>>"$LOG"; then
            log "mounted rw $src -> $mp ($fs)"
            return 0
        fi
    done
    log "FAILED rw mount $part ($src) -> $mp"
    return 1
}

# Bind a directory only if the source exists.
bind_dir() {
    src="$1"; dst="$2"
    [ -d "$src" ] || return 0
    mounted "$dst" && return 0
    mkdir -p "$dst" 2>/dev/null || return 1
    mount -o bind "$src" "$dst" 2>>"$LOG" && log "bind $src -> $dst"
}

wait_count=0
while [ "$wait_count" -lt 180 ]; do
    vendor_ok=1
    mount_read_only vendor /vendor || vendor_ok=0
    mount_read_only vendor_dlkm /vendor_dlkm || vendor_ok=0
    mount_read_only odm /odm || vendor_ok=0
    mount_read_only system_dlkm /system_dlkm || true

    if [ "$vendor_ok" = 1 ]; then
        # /vendor/firmware must be visible to the kernel firmware loader.
        bind_dir /vendor/firmware /lib/firmware

        # Modem firmware for qseecomd / WLAN; optional for basic UI.
        if [ ! -d /vendor/firmware_mnt/image ]; then
            src="$(find_part modem)" || true
            if [ -n "${src:-}" ]; then
                mkdir -p /vendor/firmware_mnt 2>/dev/null || true
                for fs in vfat ext4; do
                    mount -t "$fs" -o ro "$src" /vendor/firmware_mnt 2>>"$LOG" && break
                done
            fi
        fi

        # persist must be writable: spdaemon/sec_nvm create secnvm/spudc/iar_db.
        mount_read_write persist /persist ext4 f2fs || true
        if mounted /persist; then
            for d in secnvm spudc iar_db; do
                if [ ! -d "/persist/$d" ]; then
                    mkdir -p "/persist/$d" 2>>"$LOG" || true
                    chown system:system "/persist/$d" 2>>"$LOG" || true
                    chmod 0770 "/persist/$d" 2>>"$LOG" || true
                    log "created /persist/$d"
                fi
            done
            if ! mounted /mnt/vendor/persist; then
                bind_dir /persist /mnt/vendor/persist
            fi
        fi

        # SPU NVM state; read-write vfat.
        mount_read_write spunvm /mnt/vendor/spunvm vfat || true

        # metadata is needed for FBE; keep it writable for AERA/vold.
        mount_read_write metadata /metadata f2fs ext4 || true

        # Verify the stock binaries/services used by the boot chain.  Missing
        # entries are logged, but the UI is not blocked on a single optional
        # framework service.
        for f in \
            /vendor/bin/qseecomd \
            /vendor/bin/hlosminkdaemon \
            /vendor/bin/spdaemon \
            /vendor/bin/sec_nvm \
            /vendor/bin/hw/android.hardware.security.secretkeeper-service-qti \
            /vendor/bin/hw/android.hardware.gatekeeper-rust-service-qti \
            /vendor/bin/hw/android.hardware.gatekeeper-service-spu-qti \
            /vendor/bin/hw/android.hardware.security.keymint-service-spu-qti \
            /vendor/bin/hw/android.hardware.security.onekeymint-service-qti \
            /vendor/bin/hw/android.hardware.weaver-service-spu-qti \
            /vendor/bin/hw/vendor.qti.hardware.spu-service \
            /vendor/bin/hw/vendor.qti.hardware.display.allocator-service \
            /vendor/lib64/libQSEEComAPI.so \
            /vendor/lib64/libspcom.so \
            /vendor/lib64/hw/libspuqtigatekeeper.so; do
            [ -e "$f" ] || log "missing $f"
        done

        log "real partitions mounted"
        setprop aera.stock.mounted true
        exit 0
    fi

    wait_count=$((wait_count + 1))
    sleep 1
done

log "stock partition mount failed after 180s"
setprop aera.stock.mount_failed true
exit 1
