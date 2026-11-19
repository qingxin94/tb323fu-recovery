#!/system/bin/sh
# v13: search firmware and vendor libraries across partitions.
# Runs early (on fs) and again after twrp.modules.loaded. Read-only mounts only.

PATH=/system/bin:/vendor/bin
export PATH

mkdir -p /system/lib64 /lib/firmware /mnt/aera_scan /mnt/vendor/persist 2>/dev/null

LOG=/tmp/aera-firmware-finder.log
echo "=== aera-firmware-finder start $(date) ===" >> "$LOG"

LIBS="librpmb.so librpmbStaticHelper.so libqtikeymaster4.so libQSEEComAPI.so libdiag.so libkeymasterprovision.so libkeymasterdeviceutils.so libkeymasterutils.so libkeymaster_messages.so libspukeymint.so libspukeymintutils.so libspukeymintdeviceutils.so vendor.qti.hardware.qseecom@1.0.so vendor.qti.hardware.qseecom-V1-ndk.so"
FW="novatek_ts_fw.bin aw22xxx_fw.bin haptic_ram.bin"

copy_lib() {
  src="$1"; name="$2"
  [ -f "$src" ] || return 0
  [ -f "/system/lib64/$name" ] && return 0
  cp -f "$src" "/system/lib64/$name" 2>/dev/null && \
    echo "COPY LIB $name <- $src" >> "$LOG"
}

copy_fw() {
  src="$1"; name="$2"
  [ -f "$src" ] || return 0
  [ -f "/lib/firmware/$name" ] && return 0
  cp -f "$src" "/lib/firmware/$name" 2>/dev/null && \
    echo "COPY FW $name <- $src" >> "$LOG"
}

scan_tree() {
  dir="$1"
  [ -d "$dir" ] || return 0
  for n in $LIBS; do
    for src in $(find "$dir" -type f -name "$n" 2>/dev/null | head -n 3); do
      copy_lib "$src" "$n"
    done
  done
  for n in $FW; do
    for src in $(find "$dir" -type f -name "$n" 2>/dev/null | head -n 3); do
      copy_fw "$src" "$n"
    done
  done
  for src in $(find "$dir" -type f -name 'thermal-engine*.conf' 2>/dev/null | head -n 5); do
    mkdir -p /system/etc 2>/dev/null
    cp -f "$src" "/system/etc/$(basename "$src")" 2>/dev/null && \
      echo "COPY THERMAL $(basename "$src") <- $src" >> "$LOG"
  done
}

# Already-visible trees.
for d in /vendor /odm /product /system /persist; do scan_tree "$d"; done

# Scan block partitions by-name, read-only. Skip obviously huge/unneeded ones.
for blk in /dev/block/by-name/*; do
  [ -e "$blk" ] || continue
  name=$(basename "$blk")
  case "$name" in
    vendor_a|vendor_b|vendor|odm_a|odm_b|odm|product_a|product_b|product|system_a|system_b|system|modem_a|modem_b|modem|persist|persist_a|persist_b) ;;
    *) continue ;;
  esac
  mp="/mnt/aera_scan/$name"
  mkdir -p "$mp" 2>/dev/null
  mounted=0
  for fs in ext4 f2fs vfat; do
    if mount -t "$fs" -o ro "$blk" "$mp" 2>/dev/null; then mounted=1; break; fi
  done
  if [ "$mounted" = 0 ]; then
    # Already mounted elsewhere? Try the conventional mount point.
    case "$name" in
      vendor*) [ -d /vendor ] && scan_tree /vendor ;;
      odm*) [ -d /odm ] && scan_tree /odm ;;
      product*) [ -d /product ] && scan_tree /product ;;
      system*) [ -d /system ] && scan_tree /system ;;
    esac
    continue
  fi
  echo "MOUNT $name -> $mp" >> "$LOG"
  scan_tree "$mp"
done

# firmware_mnt: qseecomd and TEE expect modem firmware under /vendor/firmware_mnt.
if [ ! -e /vendor/firmware_mnt/image ] && [ ! -e /vendor/firmware_mnt/ADSP* ]; then
  for n in modem_a modem_b modem; do
    blk="/dev/block/by-name/$n"
    [ -e "$blk" ] || continue
    mkdir -p /vendor/firmware_mnt 2>/dev/null
    if mount -t vfat -o ro,fmask=0000,dmask=0000 "$blk" /vendor/firmware_mnt 2>/dev/null; then
      echo "MOUNT firmware_mnt <- $n" >> "$LOG"
      break
    fi
    if mount -t ext4 -o ro "$blk" /vendor/firmware_mnt 2>/dev/null; then
      echo "MOUNT firmware_mnt(ext4) <- $n" >> "$LOG"
      break
    fi
  done
fi

# Some vendor services read /mnt/vendor/persist; bind the recovery /persist mount.
if [ -d /persist ] && [ ! -e /tmp/aera-persist-bound ]; then
  mount -o bind /persist /mnt/vendor/persist 2>/dev/null && {
    echo "BIND persist -> /mnt/vendor/persist" >> "$LOG"
    touch /tmp/aera-persist-bound 2>/dev/null
  }
fi

# Ensure qseecomd sees the copied libs even when the real vendor partition is mounted.
echo "=== aera-firmware-finder done $(date) ===" >> "$LOG"
exit 0
