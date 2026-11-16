#!/bin/bash
#
# Pack a v4 boot image for TB323FU.
#
#   kernel-only (replaces the boot partition kernel, stock layout):
#     tools/pack_boot.sh prebuilt/kernel - boot_vmlinux.img
#
#   AERA recovery ramdisk + matching kernel (for `fastboot boot`):
#     tools/pack_boot.sh prebuilt/kernel /tmp/aera_recovery/ramdisk aera_recovery_boot.img
#
# Run after `source build/envsetup.sh` so mkbootimg is on PATH.
#
set -eu

KERNEL="${1:?usage: pack_boot.sh <kernel> <ramdisk|-> <out> [cmdline]}"
RAMDISK="${2:?usage: pack_boot.sh <kernel> <ramdisk|-> <out> [cmdline]}"
OUT="${3:?usage: pack_boot.sh <kernel> <ramdisk|-> <out> [cmdline]}"
CMDLINE="${4:-}"

if ! command -v mkbootimg >/dev/null 2>&1; then
    echo "mkbootimg not found; run: source build/envsetup.sh" >&2
    exit 1
fi
if [ ! -s "$KERNEL" ]; then
    echo "kernel not found: $KERNEL" >&2
    exit 1
fi

args=(--header_version 4 --pagesize 4096 --kernel "$KERNEL")
if [ -n "$CMDLINE" ]; then
    args+=(--cmdline "$CMDLINE")
fi
if [ "$RAMDISK" != "-" ]; then
    if [ ! -s "$RAMDISK" ]; then
        echo "ramdisk not found: $RAMDISK" >&2
        exit 1
    fi
    args+=(--ramdisk "$RAMDISK")
fi

mkbootimg "${args[@]}" -o "$OUT"
echo "wrote $OUT ($(stat -c %s "$OUT") bytes)"
