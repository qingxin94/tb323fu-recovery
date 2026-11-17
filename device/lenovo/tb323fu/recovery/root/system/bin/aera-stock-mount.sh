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

# Persist and spunvm must be writable: spdaemon/sec_nvm create secnvm/spudc/
# iar_db under /persist, and spu_weaver opens NVM state on spunvm.  A read-only
# mount makes the SPU services start but fail on their first write, which is
# exactly the "service is running but GetConfig fails" symptom.
mount_rw() {
    part="$1"; mp="$2"; shift 2
    mkdir -p "$mp" 2>/dev/null
    if mounted "$mp"; then
        # /persist is bind-mounted at /mnt/vendor/persist for spdaemon.  Drop
        # that bind first, otherwise a read-only /persist cannot be remounted.
        if [ "$mp" = "/persist" ] && mounted /mnt/vendor/persist; then
            umount /mnt/vendor/persist 2>>"$LOG" || true
        fi
        if grep -q " $mp ro," /proc/mounts; then
            umount "$mp" 2>>"$LOG" || true
        else
            log "already mounted rw $mp"
            return 0
        fi
    fi
    for src in /dev/block/mapper/$part                /dev/block/by-name/${part}_a /dev/block/by-name/$part                /dev/block/bootdevice/by-name/${part}_a /dev/block/bootdevice/by-name/$part; do
        [ -e "$src" ] || continue
        for fs in "$@"; do
            if mount -t "$fs" "$src" "$mp" 2>>"$LOG"; then
                log "mounted rw $src -> $mp ($fs)"
                return 0
            fi
        done
    done
    log "FAILED rw mount $part -> $mp"
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
            mkdir -p /lib/firmware
            mount -o bind /vendor/firmware /lib/firmware 2>>"$LOG" || true
            log "bind /vendor/firmware -> /lib/firmware"
        fi
        # AERA audio bootstrap and audio service definitions use this path.
        # Use a symlink to the already-mounted real /vendor, not a bind that
        # would need a pre-existing target directory.
        if [ ! -e /mnt/aera-stock/vendor ] && [ -d /vendor ]; then
            mkdir -p /mnt/aera-stock
            ln -s /vendor /mnt/aera-stock/vendor 2>>"$LOG" || true
        fi
        # qseecomd/KeyMint read the modem firmware image from this mount.
        if [ ! -e /vendor/firmware_mnt/image ]; then
            mkdir -p /vendor/firmware_mnt
            for src in /dev/block/by-name/modem_a /dev/block/by-name/modem                        /dev/block/bootdevice/by-name/modem_a /dev/block/bootdevice/by-name/modem; do
                [ -e "$src" ] || continue
                mount -t vfat -o ro "$src" /vendor/firmware_mnt 2>>"$LOG" && break
                mount -t ext4 -o ro "$src" /vendor/firmware_mnt 2>>"$LOG" && break
            done
        fi
        # The QCA driver reads bdwlan/amss images from firmware_mnt.  Do not
        # block display/touch if modem is slow, but leave an explicit trace.
        if [ -d /vendor/firmware_mnt/image ]; then
            log "modem firmware visible at /vendor/firmware_mnt/image"
        else
            log "WARN: /vendor/firmware_mnt/image missing; WiFi firmware may be unavailable"
        fi
        # Persist and SPU NVM are required by gatekeeper/weaver/sec_nvm.
        # Mount the real partitions writable; never bind a stale empty
        # directory.  spdaemon/sec_nvm create secnvm/spudc/iar_db here.
        if ! mounted /persist; then
            mount_rw persist /persist ext4 f2fs || true
        fi
        if mounted /persist; then
            # Only create a missing state directory.  If stock already
            # provisioned it, leave its owner/mode and contents untouched.
            for d in secnvm spudc iar_db; do
                if [ ! -d "/persist/$d" ]; then
                    mkdir -p "/persist/$d" 2>>"$LOG" || true
                    chown system:system "/persist/$d" 2>>"$LOG" || true
                    chmod 0770 "/persist/$d" 2>>"$LOG" || true
                    log "created /persist/$d"
                fi
            done
        fi
        if ! mounted /mnt/vendor/spunvm; then
            mkdir -p /mnt/vendor/spunvm
            mount_rw spunvm /mnt/vendor/spunvm vfat || true
        fi
        if mounted /persist && ! mounted /mnt/vendor/persist; then
            mkdir -p /mnt/vendor/persist
            mount -o bind /persist /mnt/vendor/persist 2>>"$LOG" || true
        fi
        # AERA's device VINTF manifest lives in the recovery system ramdisk
        # (/system/etc/vintf/manifest.xml).  Do not create /odm/etc/vintf:
        # stock /odm is read-only and has no vintf directory, so binding
        # there can never work.
        # Verify the exact stock binaries/libraries that display, touch and
        # crypto use.  If any one is missing we do not set aera.stock.mounted,
        # so init never starts a service against a path that does not exist.
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
            /vendor/bin/hw/vendor.qti.hardware.vibrator.service \
            /vendor/bin/hw/vendor.lenovo.hardware.vibrator_dual-service \
            /vendor/bin/hw/wpa_supplicant \
            /vendor/bin/cnss-daemon \
            /vendor/lib64/egl/libEGL_adreno.so \
            /vendor/lib64/libQSEEComAPI.so \
            /vendor/lib64/libspcom.so \
            /vendor/lib64/libspukeymint.so \
            /vendor/lib64/libspukeymintdeviceutils.so \
            /vendor/lib64/libspukeymintutils.so \
            /vendor/lib64/libspuprovisionids.so \
            /vendor/lib64/hw/libspuqtigatekeeper.so \
            /vendor/lib64/vendor.qti.hardware.spu-V2-ndk.so \
            /vendor/lib64/android.hardware.vibrator-V2-ndk.so \
            /vendor/lib64/vendor.qti.hardware.vibrator.impl.so \
            /vendor/lib64/vendor.qti.hardware.vibratorCL.impl.so \
            /vendor/lib64/vendor.qti.hardware.vibratorOL.impl.so \
            /vendor/lib64/vendor.qti.hardware.vibratorSel.impl.so \
            /vendor/lib64/libqtivibratoreffect.so \
            /vendor/lib64/libaacvibrator.so \
            /vendor/lib64/vendor.lenovo.hardware.vibrator_dual-V1-ndk.so \
            /vendor/lib64/libsoc_helper.so \
            /vendor/lib64/android.hardware.wifi.common-V2-ndk.so \
            /vendor/lib64/android.hardware.wifi.supplicant-V4-ndk.so \
            /vendor/lib64/vendor.qti.hardware.wifi.supplicant-V1-ndk.so \
            /vendor/etc/wifi/wpa_supplicant.conf \
            /odm/etc/aac_richtap_r.config \
            /odm/etc/aac_richtap_l.config \
            /vendor/firmware/haptic_rtp.bin \
            /vendor/firmware/haptic_ram.bin \
            /vendor/firmware/novatek_ts_fw.bin \
            /system/etc/vintf/manifest.xml; do
            [ -e "$f" ] || { log "missing $f"; ok=0; }
        done
        # The manifest must actually declare the SPU/KeyMint/Weaver HALs;
        # existence alone is not enough if the wrong manifest was installed.
        for h in \
            android.hardware.weaver \
            android.hardware.security.keymint \
            android.hardware.security.secretkeeper \
            android.hardware.vibrator \
            android.hardware.wifi.supplicant \
            vendor.qti.hardware.wifi.supplicant \
            vendor.lenovo.hardware.vibrator_dual \
            vendor.qti.hardware.spu; do
            grep -q "$h" /system/etc/vintf/manifest.xml 2>>"$LOG" || {
                log "manifest missing $h"
                ok=0
            }
        done
        # Modules may come from vendor_dlkm or the real vendor_boot ramdisk.
        if [ ! -d /vendor_dlkm/lib/modules ] && [ ! -d /lib/modules ]; then
            log "missing module directory"
            ok=0
        fi
        if [ "$ok" = 1 ]; then
            # Touch is started once by init from the aera.stock.mounted trigger;
            # do not insmod nvt_36xxx twice here.
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
