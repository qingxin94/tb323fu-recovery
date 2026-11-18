# TB323FU AERA device tree — real-partition / on-demand build

This tree intentionally does **not** reuse the old boot-time module table.

## Boot chain

1. `aera-stock-mount.sh` mounts the real `vendor`, `vendor_dlkm`, `odm`,
   `system_dlkm`, `persist`, `spunvm` and `metadata` partitions.
2. `aera-base-modules` loads only `base.list` from the real partitions.
   `base.list` contains touch (`nvt_36xxx`) and the SPU/weaver transport
   (`spss_utils`, `spcom`) plus optional crypto helpers.
3. `aera-crypto.rc` services start after `aera.base.loaded=true`.
4. AERA's normal decrypt path reads `/data/system_de/0/spblob`; the legacy
   `/data/system/users/0/gatekeeper.password.key` is not expected on this
   Android 16 build. `aera-spblob-check.sh` logs this path read-only.

No Wi-Fi, audio or haptics module is loaded at boot.

## On-demand groups

```text
setprop sys.aera.wifi.load 1
setprop sys.aera.audio.load 1
setprop sys.aera.haptics.load 1
```

Each group is a small `.list` of top-level modules. `aera-load-group.sh`
resolves dependencies from the real `modules.dep` under `/vendor_dlkm` or
`/system_dlkm`, then calls `insmod` on the real path. Nothing is copied to
`/tmp` and no `.ko` lives in the ramdisk.

## Time

`/persist/time/ats_2` is an 8-byte little-endian millisecond offset.
`aera-clock.sh` combines it with `/sys/class/rtc/rtc0/since_epoch` and sets
`CLOCK_REALTIME`. AERA also calls its built-in
`TWFunc::Fixup_Time_On_Boot("/persist/time/")`, and the stock
`vendor.time_daemon` is defined for the network/modem time path.

## Key files

- `BoardConfig.mk` — empty AERA module tables; real-partition policy
- `recovery/root/init.recovery.qcom.rc` — boot order
- `recovery/root/system/bin/aera-stock-mount.sh`
- `recovery/root/system/bin/aera-load-group.sh`
- `recovery/root/system/etc/aera-modules/*.list`
- `recovery/root/vendor/etc/init/aera-crypto.rc`
- `recovery/root/system/etc/recovery.fstab`
- `recovery/root/system/etc/twrp.flags`
