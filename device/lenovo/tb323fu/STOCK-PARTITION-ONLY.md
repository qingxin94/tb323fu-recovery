# TB323FU device tree — stock partition only

Rule: the recovery ramdisk contains only AERA recovery's own files. Every
stock `.ko`, HAL binary, shared library, config, firmware and VINTF fragment
is mounted from the real device partitions and used in place.

## Changed from the previous tree

- Removed the whole `recovery/root/vendor` stock overlay:
  - all `/vendor/bin`, `/vendor/lib64`, `/vendor/etc`, `/vendor/firmware`
  - GPU/EGL, display, boot, gatekeeper, keymint, weaver, QSEECom, WiFi configs
- Removed `recovery/root/system/etc/firmware/novatek_ts_*.bin`
  - touch firmware now comes from the real `/vendor/firmware`
- Removed stock ODM VINTF fragments and `ueventd.rc`
  - the AERA device VINTF root is kept as `system/etc/vintf/device-manifest.xml`
  - it is bind-mounted over the real `/odm/etc/vintf/manifest.xml` after `/odm` mounts
- Removed `nvt_36xxx.ko` from the startup module list
  - touch is loaded after `/vendor` and `/vendor_dlkm` are mounted
- Added `system/bin/aera-stock-mount.sh`
  - mounts the real `vendor`, `vendor_dlkm`, `odm`, optional `system_dlkm`
  - binds `/vendor/firmware` to `/lib/firmware`
  - mounts `modem_a` at `/vendor/firmware_mnt` when needed
  - binds `/persist` to `/mnt/vendor/persist`
  - verifies the required HAL/library/firmware paths before setting
    `aera.stock.mounted`
- Added `system/bin/aera-touch-load.sh`
  - searches the real module dirs and loads `nvt_36xxx.ko` only after mount
- Added service gating in `init.recovery.qcom.rc`
  - display allocator, crypto/weaver/keymint, boot HAL and thermal engine
    start only on `aera.stock.mounted=true`
  - no vendor service starts before the partitions are verified
- Moved `aera-crypto.rc` from `/vendor/etc/init` to `/system/etc/init`
  - it is AERA service configuration, not a stock vendor file

## Still intentionally in ramdisk

Only files required for the recovery process itself:

- `system/bin/recovery`, `system/bin/adbd`, linker, libc/libc++/libbase/
  libutils/libcutils and AERA's own `libminuitwrp`/UI libraries
- AERA's own init rc files and shell scripts
- framework VINTF root manifests
- `libandroidicu.so`, `libvndksupport.so` (required by the recovery runtime)
- `system/bin/keystore2` and its framework ABI libraries (crypto path)

No stock kernel module, HAL binary, vendor shared library, vendor config,
vendor firmware or VINTF fragment is stored here.

## Boot order

1. `init` starts, sets the kernel firmware path to `/vendor/firmware`
2. AERA mounts the real vendor/vendor_dlkm while loading startup modules
3. `twrp.modules.loaded=true` starts `aera-stock-mount`
4. `aera-stock-mount` mounts and verifies the real partitions
5. `aera.stock.mounted=true` starts display allocator, touch loader,
   crypto/weaver/keymint and thermal engine
6. No service is started if the mount verification fails; it sets
   `aera.stock.mount_failed=true` and leaves a log in
   `/tmp/aera-stock-mount.log`

## Build

This is a device-tree change. It must be rebuilt with the AERA manifest
(`aera-16.0`) and not patched into an existing recovery image.
