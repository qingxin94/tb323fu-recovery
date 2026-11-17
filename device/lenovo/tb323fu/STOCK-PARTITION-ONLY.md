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
  - the AERA device VINTF root is kept as `system/etc/vintf/manifest.xml`
  - it is not bind-mounted over `/odm`: stock `/odm` has no `/etc/vintf`
    directory and is mounted read-only, so that bind could never succeed
- Added the fix3b SPU service chain
  - `vendor.secretkeeper`, `vendor.spdaemon`, `vendor.gatekeeper_spu`,
    `vendor.keymint-spu-qti` and `vendor.qti.hardware.spu.service` are
    defined against real `/vendor/bin/*` paths and started after
    `aera.stock.mounted`
  - `vendor.gatekeeper.is_security_level_spu=1`
  - `/persist` and `/mnt/vendor/spunvm` are mounted writable; `secnvm`,
    `spudc` and `iar_db` are created on real `/persist`
  - `crypto.ready=1` is set before `restart keystore2`
- Removed `nvt_36xxx.ko` from the startup module list
  - touch is loaded after `/vendor` and `/vendor_dlkm` are mounted
- Added `system/bin/aera-stock-mount.sh`
  - mounts the real `vendor`, `vendor_dlkm`, `odm`, optional `system_dlkm`
  - binds `/vendor/firmware` to `/lib/firmware`
  - mounts `modem_a` at `/vendor/firmware_mnt` when needed
  - binds `/persist` to `/mnt/vendor/persist`
  - verifies the required HAL/library/firmware paths before setting
    `aera.stock.mounted`
- Added `system/bin/aera-real-modules.sh` and `system/etc/aera-real-modules.list`
  - the 75 Wi-Fi/audio/haptics modules are `insmod`ed in place from the real
    `/vendor_dlkm/lib/modules` and `/system_dlkm/lib/modules`
  - no module is copied or staged into `/tmp`; `AERA_POST_DECRYPT_MODULES` is
    empty, so nothing waits for `/data` decryption
  - `rfkill.ko` and `libarc4.ko` are pulled from the real `system_dlkm`
    (mounted directly if the optional stock-mount pass did not mount it)
  - `cnss-daemon` is started before `qca_cld3_peach_v2.ko`
- Added `system/bin/aera-touch-load.sh`
  - searches the real module dirs and loads `nvt_36xxx.ko` only after mount
- Added service gating in `init.recovery.qcom.rc`
  - display allocator, crypto/weaver/keymint, boot HAL and thermal engine
    start only on `aera.stock.mounted=true`
  - no vendor service starts before the partitions are verified
  - `vendor.qti.vibrator` and `vendor.lenovo.vibrator_dual` start on
    `aera.modules.loaded=true`, after the real haptics modules are resident
  - stock vibrator device nodes and LED sysfs attributes are chmod'ed in
    `on boot`, exactly as the stock vendor rc does
- Wi-Fi and audio no longer depend on userdata decryption
  - `init.recovery.wifi.rc` starts `cnss-daemon`, writes the real
    `fs_ready`, waits for `wlan0`, then starts the real
    `/vendor/bin/hw/wpa_supplicant`
  - `init.recovery.audio.rc` starts `aera-audio-bootstrap` on
    `aera.modules.loaded=true`
  - `wpa_supplicant`/`wpa_cli` ramdisk copies produced by aera_build.mk are
    removed by `BOARD_RECOVERY_IMAGE_PREPARE`; the service uses the vendor
    binary and `wlan.cpp` finds `wpa_cli` under `/vendor/bin`
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
