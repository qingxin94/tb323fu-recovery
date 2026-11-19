#!/system/bin/sh
# Mount every mountable partition named by the stock/AERA TB323FU fstab.
# Image-only partitions (boot/init_boot/vendor_boot/dtbo/recovery/misc)
# are not filesystems and are never passed to mount(2).
#
# /system, /system_ext and /product are mounted at /mnt/aera/stock/* on
# purpose: mounting them over /system would hide the AERA recovery binary
# and this script from the running ramdisk. All service-critical partitions
# (vendor, odm, vendor_dlkm, system_dlkm, persist, metadata, firmware) are
# mounted at their stock mount points.

# v15: this script is a one-shot audit. It is started by the crypto.ready
# action; if it runs again it must not re-trigger the stock -> base -> v13 ->
# crypto chain through aera.stock.mounted.
if [ "$(getprop aera.audit.done)" = "1" ]; then
    exit 0
fi
setprop aera.audit.done 1

LOG=/tmp/aera-stock-mount.log
exec >>"$LOG" 2>&1
echo "=== aera-stock-mount $(date 2>/dev/null)"

SLOT=$(getprop ro.boot.slot_suffix)
if [ -z "$SLOT" ]; then
    for s in _a _b; do
        [ -b "/dev/block/mapper/vendor$s" ] && SLOT="$s" && break
    done
fi
[ -n "$SLOT" ] || SLOT=_a

mounted() {
    awk -v mp="$1" '$2 == mp { found = 1 } END { exit(found ? 0 : 1) }' /proc/mounts
}

fail() { echo "FAIL $*"; FAILED="$FAILED $*"; }

# Resolve a real block device. AERA publishes the actual mapper device for
# vendor/system/product; the rest fall back to the mapper/by-name nodes.
dm_name_of() {
    base="$1"
    for f in "/sys/class/block/$base/dm/name" "/sys/block/$base/dm/name" "/sys/devices/virtual/block/$base/dm/name"; do
        if [ -r "$f" ]; then cat "$f"; return 0; fi
    done
    for f in "/sys/class/block/$base/uevent" "/sys/block/$base/uevent"; do
        if [ -r "$f" ]; then sed -n 's/^DM_NAME=//p' "$f"; return 0; fi
    done
    return 1
}

partname_of() {
    base="$1"; parent="${base%%[0-9]*}"
    for f in "/sys/class/block/$base/uevent" "/sys/block/$base/uevent" "/sys/block/$parent/$base/uevent"; do
        if [ -r "$f" ]; then sed -n 's/^PARTNAME=//p' "$f"; return 0; fi
    done
    return 1
}

resolve_source() {
    kind="$1"; name="$2"
    if [ "$kind" = logical ]; then
        p=$(getprop "aera.${name}.block_device")
        if [ -n "$p" ] && [ -b "$p" ]; then echo "$p"; return 0; fi
        for n in "${name}${SLOT}" "${name}_a" "${name}_b" "$name"; do
            for d in /dev/block/mapper /dev/block/by-name /dev/block/bootdevice/by-name; do
                [ -b "$d/$n" ] && { echo "$d/$n"; return 0; }
            done
        done
        # Mapper symlink missing: search device-mapper DM_NAME.
        for sys in /sys/class/block/dm-*; do
            dm=$(dm_name_of "$(basename "$sys")")
            case " $dm " in
                *" ${name}_a "*|*" ${name}_b "*|*" $name "*)
                    echo "/dev/block/$(basename "$sys")"; return 0;;
            esac
        done
        return 1
    fi
    for d in /dev/block/bootdevice/by-name /dev/block/by-name /dev/block/platform/soc/*/by-name /dev/block/mapper; do
        for n in "$name${SLOT}" "$name" "$name""_a" "$name""_b"; do
            [ -b "$d/$n" ] && { echo "$d/$n"; return 0; }
        done
    done
    # by-name symlink missing: search the kernel PARTNAME for this GPT entry.
    for sys in /sys/class/block/sd*; do
        pn=$(partname_of "$(basename "$sys")")
        for n in "$name${SLOT}" "$name" "$name""_a" "$name""_b"; do
            [ "$pn" = "$n" ] && { echo "/dev/block/$(basename "$sys")"; return 0; }
        done
    done
    # Physical partition may already be wrapped in device-mapper by AERA.
    for sys in /sys/class/block/dm-*; do
        dm=$(dm_name_of "$(basename "$sys")")
        case " $dm " in
            *" ${name}_a "*|*" ${name}_b "*|*" $name "*)
                echo "/dev/block/$(basename "$sys")"; return 0;;
        esac
    done
    return 1
}

# Wait up to 10 s for AERA to publish vendor's actual block device.
i=0
while [ $i -lt 20 ]; do
    p=$(getprop aera.vendor.block_device)
    [ -n "$p" ] && break
    i=$((i + 1)); sleep 0.5
done
echo "aera.vendor.block_device=${p:-<empty>} slot=${SLOT}"

# Wait for AERA to map all seven logical volumes from super. Without this,
# a fast mount would race the mapper and report vendor/system as absent.
i=0
while [ $i -lt 60 ]; do
    mapped=0
    for n in system system_ext product vendor vendor_dlkm system_dlkm odm; do
        prop=$(getprop "aera.${n}.block_device")
        if [ -n "$prop" ] && [ -b "$prop" ]; then mapped=$((mapped + 1)); continue; fi
        if [ -b "/dev/block/mapper/${n}${SLOT}" ] || [ -b "/dev/block/mapper/${n}_a" ] || [ -b "/dev/block/mapper/${n}_b" ]; then
            mapped=$((mapped + 1))
        fi
    done
    [ "$mapped" -eq 7 ] && break
    i=$((i + 1)); sleep 1
done
echo "super volumes mapped=${mapped:-0}/7 after ${i}s"

mount_entry() {
    ROWS_SEEN=$((ROWS_SEEN + 1))
    kind="$1"; name="$2"; mp="$3"; fs="$4"; opts="$5"; critical="${6:-0}"
    if mounted "$mp"; then echo "OK already $mp"; OK=$((OK + 1)); return 0; fi
    mkdir -p "$mp" 2>/dev/null || true
    if ! src=$(resolve_source "$kind" "$name"); then
        echo "ABSENT $name (no block device for $mp)"
        ABSENT="$ABSENT $name"
        if [ "$critical" = 1 ]; then
            fail "$name critical block device absent"
        else
            SKIPPED=$((SKIPPED + 1))
        fi
        return 1
    fi
    mount -t "$fs" -o "$opts" "$src" "$mp" 2>>"$LOG"
    if mounted "$mp"; then
        echo "OK $src -> $mp ($fs,$opts)"
        OK=$((OK + 1))
        return 0
    fi
    fail "$name $src -> $mp"
    return 1
}

# Raw partitions have no filesystem. They must still be checked so that a
# missing GPT entry is never silently treated as "mounted".
verify_raw() {
    ROWS_SEEN=$((ROWS_SEEN + 1))
    name="$1"
    if src=$(resolve_source physical "$name"); then
        echo "OK raw $name $src (image partition, not mounted)"
        RAW=$((RAW + 1))
    else
        echo "SKIP raw $name (no block device; image-only, does not affect decrypt)"
        ABSENT="$ABSENT $name"
        SKIPPED=$((SKIPPED + 1))
    fi
}

# /data is encrypted and has metadata encryption. A raw f2fs mount here
# would mount ciphertext, not the user's DE storage. AERA/keystore mounts it
# only after PIN decrypt; before that we verify the block device exists.
verify_userdata() {
    ROWS_SEEN=$((ROWS_SEEN + 1))
    if src=$(resolve_source physical userdata); then
        echo "OK deferred userdata $src (mount after PIN decrypt)"
        DEFERRED=$((DEFERRED + 1))
    else
        echo "ABSENT userdata"
        ABSENT="$ABSENT userdata"
        fail "userdata block device absent"
    fi
}

FAILED=""
ABSENT=""
OK=0
RAW=0
DEFERRED=0
SKIPPED=0
ROWS_SEEN=0
MOUNT_COUNT=0

# 1) Logical partitions on super. Keep AERA's /system ramdisk intact.
mount_entry logical system       /mnt/aera/stock/system      ext4 ro 0
mount_entry logical system_ext   /mnt/aera/stock/system_ext  ext4 ro 0
mount_entry logical product      /mnt/aera/stock/product     ext4 ro 0
mount_entry logical vendor       /vendor                    ext4 ro 1
mount_entry logical vendor_dlkm  /vendor_dlkm               ext4 ro 1
mount_entry logical system_dlkm  /system_dlkm               ext4 ro 0
mount_entry logical odm          /odm                       ext4 ro 1

# 2) Metadata, dataext, persist.
mount_entry physical metadata /metadata f2fs "noatime,nosuid,nodev,discard" 1
mount_entry physical dataext  /dataext  ext4 "ro,barrier=1,discard" 0
mount_entry physical persist  /persist  ext4 "noatime,nosuid,nodev,barrier=1" 1

# 3) Firmware and vendor sub-partitions, after /vendor is mounted.
mount_entry physical modem     /vendor/firmware_mnt vfat "ro,shortname=lower,uid=1000,gid=1000,dmask=227,fmask=337" 0
mount_entry physical dsp       /vendor/dsp        ext4 "ro,nosuid,nodev,barrier=1" 0
mount_entry physical bluetooth /vendor/bt_firmware vfat "ro,shortname=lower,uid=1002,gid=3002,dmask=227,fmask=337" 0
mount_entry physical soccp     /vendor/soccp_firmware vfat "ro,shortname=lower,uid=0,gid=1000,dmask=227,fmask=337" 0
mount_entry physical vm-bootsys /vendor/vm-system ext4 "ro,nosuid,nodev,barrier=1" 0

# 4) Vendor/mnt partitions.
mount_entry physical qmcs      /mnt/vendor/qmcs      vfat "noatime,nosuid,nodev" 0
mount_entry physical spunvm    /mnt/vendor/spunvm    vfat "noatime,nosuid,nodev" 0
mount_entry physical vm-persist /mnt/vendor/vm-persist ext4 "noatime,nosuid,nodev,barrier=1" 0

# 4b) Every remaining by-name / mapper block must be classified.  This is
# the anti-silent-omission pass: mount what is mountable, and log every raw
# or encrypted partition with a reason.  Unknown mountable partitions go to
# /mnt/aera-stock/parts/<name>; no partition is skipped without a log row.
EXTRA_OK=0
EXTRA_RAW=0
EXTRA_ENC=0
for src in /dev/block/by-name/* /dev/block/bootdevice/by-name/* /dev/block/mapper/*; do
    [ -b "$src" ] || continue
    name="$(basename "$src")"
    case "$name" in
        *_a|*_b) continue ;;
    esac
    case "$name" in
        system|system_ext|product|vendor|vendor_dlkm|system_dlkm|odm|metadata|dataext|persist|modem|dsp|bluetooth|soccp|vm-bootsys|qmcs|spunvm|vm-persist|userdata|misc|boot|init_boot|vendor_boot|dtbo|recovery)
            continue ;;
    esac
    grep -q " $src " /proc/mounts 2>/dev/null && continue
    case "$name" in
        boot|init_boot|vendor_boot|dtbo|recovery|misc|vbmeta|vbmeta_system|vbmeta_vendor|super|frp|devinfo|logfs|countrycode|oem)
            echo "RAW $name (image/raw partition, not mountable)"
            EXTRA_RAW=$((EXTRA_RAW + 1))
            continue ;;
        userdata|data)
            echo "ENC $name (encrypted, deferred until PIN)"
            EXTRA_ENC=$((EXTRA_ENC + 1))
            continue ;;
    esac
    dst="/mnt/aera-stock/parts/$name"
    mkdir -p "$dst" 2>/dev/null || true
    ok=0
    for fs in ext4 f2fs erofs vfat; do
        if mount -t "$fs" -o ro "$src" "$dst" 2>>"$LOG"; then
            echo "OK extra $src -> $dst ($fs)"
            EXTRA_OK=$((EXTRA_OK + 1))
            ok=1
            break
        fi
    done
    [ "$ok" = 1 ] || { echo "SKIP unclassified $name ($src)"; SKIPPED=$((SKIPPED + 1)); }
done

# 5) Compatibility aliases used by AERA/stock services.
mkdir -p /mnt/vendor/persist /firmware 2>/dev/null || true
mounted /persist && ! mounted /mnt/vendor/persist && mount -o bind /persist /mnt/vendor/persist 2>/dev/null
mounted /vendor/firmware_mnt && ! mounted /firmware && mount -o bind /vendor/firmware_mnt /firmware 2>/dev/null

# 6) Image-only partitions from the same fstab. They are block devices, not
#    filesystems; mount(2) would fail. Check every one explicitly.
verify_raw misc
verify_raw boot
verify_raw init_boot
verify_raw vendor_boot
verify_raw dtbo
verify_raw recovery

# 7) /data is encrypted. Never raw-mount it here; AERA/keystore mounts it
#    after the PIN decrypt. Verify only that the block device exists.
verify_userdata

# 8) spdaemon/sec_nvm directories.
for d in secnvm spudc iar_db; do
    mkdir -p "/persist/$d" 2>/dev/null || true
    chown system:system "/persist/$d" 2>/dev/null || true
    chmod 0770 "/persist/$d" 2>/dev/null || true
done

# 9) Load the exact stock TEE subset, in stock modules.load order.
/system/bin/aera-load-tee-modules.sh

# 10) Wait for the devices the services open.
for i in 1 2 3 4 5 6 7 8 9 10; do
    [ -e /dev/qseecom ] && [ -e /dev/spcom ] && [ -e /dev/spss_utils ] && break
    sleep 1
done
echo "devices: qseecom=$([ -e /dev/qseecom ] && echo yes || echo no) spcom=$([ -e /dev/spcom ] && echo yes || echo no) spss_utils=$([ -e /dev/spss_utils ] && echo yes || echo no)"

# AERA fstab has 25 rows: 7 logical + 4 physical filesystems + 6 raw +
# 8 firmware/vendor sub-partitions. /data is the one deferred row.
ROWS_TOTAL=25
# Every one of the 25 fstab rows must be accounted for above.  An optional
# row that is absent is logged as SKIP, not a hard failure: dataext, vm-*,
# soccp and raw image partitions do not gate PIN decryption.
echo "MOUNT_LEDGER rows_total=$ROWS_TOTAL rows_seen=$ROWS_SEEN mounted=$OK raw_checked=$RAW deferred=$DEFERRED skipped=$SKIPPED absent:$ABSENT"
if [ "$ROWS_SEEN" -ne "$ROWS_TOTAL" ]; then
    fail "fstab rows covered $ROWS_SEEN/$ROWS_TOTAL"
fi
# Mount is best-effort.  Never let one missing partition hold the UI or
# the PIN decrypt path: log every failure, then let crypto start anyway.
echo "MOUNT_FAILED:$FAILED"
setprop aera.stock.mount.fail "$FAILED"
setprop aera.stock.mount.absent "$ABSENT"
# v15: do not set aera.stock.mounted here. aera-stock-mount already owns that
# property; setting it from the audit re-triggers aera-base-modules ->
# aera-v13-modules -> aera-crypto-chain every audit cycle.
echo "=== mount stage done"
