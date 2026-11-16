# TB323FU AERA 功能覆盖表

这份表只记录当前设备树里“有什么、缺什么、为什么缺”，不把别的机型或别的
recovery 的实现当成已完成。所有 vendor `.ko` 仍然只写模块名，运行时从设备真实的
`/vendor_dlkm`、`/system_dlkm` 加载；`recovery/root` 下没有任何 `.ko`。

## 已落地 / 部分落地

| 功能 | 状态 | 当前实现 / 缺口 |
| --- | --- | --- |
| 显示 / GPU | 用户态闭包已补齐，未真机验证 | `msm_drm.ko`、`msm_kgsl.ko`、Adreno 840 固件、EGL/GLES、gralloc/mapper、display allocator；补入 `libadreno_utils.so`、`vendor.qti.hardware.hexlp-V2-ndk.so` 及缺失的 graphics HIDL 依赖 |
| 面板 | 配置已按真机参数修正 | 物理 3040×1904；`AERA_SCREEN_H := 2280`、`AERA_THEME := portrait_hdpi`、`AERA_FRAMERATE := 60`，对应 AERA 的 1440×3040 逻辑画布 |
| 触摸 | 已配置，未真机验证 | `panel_event_notifier.ko` + `nvt_36xxx.ko`，Novatek 固件/校准已放入 recovery 用户态目录 |
| 分区 / 存储 | 已配置 | fstab 含 `vendor_dlkm`、`system_dlkm`、`dataext`、`persist`、`boot`、`init_boot`、`vendor_boot`、`dtbo`、`recovery` 等；SD/USB 在 `twrp.flags` |
| ADB / MTP / sideload | AERA 默认能力，未单独真机验证 | USB 控制器和 `sys.usb.configfs` 已配置；MTP/sideload 由 AERA 产品层提供 |
| fastbootd | HAL 已补，未真机验证 | 已提取 `android.hardware.boot-service.qti`、`libboot_control_qti.so` 及依赖，服务在 `twrp.modules.loaded=true` 后启动；VINTF manifest 已存在 |
| 解密 / FBE | 部分 | `AERA_INCLUDE_CRYPTO/FBE/METADATA` 已开；gatekeeper/onekeymint/qseecomd 服务已改为模块加载后启动；vendor 没有 `prepdecrypt.sh`/`prepdecrypt.rc`，AERA 的 prepdecrypt 分支不会被触发 |
| Wi-Fi | 配置已就绪，未真机验证 | `AERA_POST_DECRYPT_MODULES` 已列 Wi-Fi 链；`init.recovery.wifi.rc` 负责 `fs_ready` 和 WLAN 开关；WLAN 固件在 modem 分区，vendor 镜像里没有可直接提取的 `peach_v2` 固件 |
| 振动 | 部分 | `qcom-hv-haptics.ko`、`haptic.ko`、`qbt_handler.ko` 已列启动；Lenovo 双振动器 HAL 尚未提取 |
| 时间显示 | 已配置 | `AERA_DEFAULT_TIMEZONE := CST-8`；`TARGET_RECOVERY_QCOM_RTC_FIX := true`，时钟由内核 RTC 提供，不复制任何模块 |
| 电池 / 充电 | 部分 | AERA 从 `/sys/class/power_supply` / SOCCP 读取；`qti_battery_charger.ko`、`qti_battery_debug.ko`、`qcom_q6v5.ko`、`qcom_q6v5_pas.ko`、`frpc-adsprpc.ko` 只写名字，全部从真实 `vendor_dlkm` 加载 |
| EFISP | 已启用配置 | `AERA_ENABLE_EFISP := 1`；efisp 分区存在，实际备份/恢复未真机验证 |
| 音频 | 源码已落盘，未真机验证 | vendor_dlkm 有 44 个音频模块，stock vendor 有 15 个运行件和 8 个配置；已写 `audio/aera_audio_host.c`（只注册 AGM/PAL）、`audio/aera_audio_bridge.cpp`（AERA `aera-browser-audio-v1` 协议）、`recovery/root/system/bin/aera-audio-bootstrap`（只读挂载 stock vendor/dsp/modem 并启动服务）。模块仍只从真实 `/vendor_dlkm` 加载，`recovery/root` 无 `.ko`。尚未上机验证 ADSP/PAL 初始化与扬声器出声 |

## 明确未实现

| 功能 | 状态 | 原因 |
| --- | --- | --- |
| 指纹 | 未启用 | `AERA_SUPPORT_FINGERPRINT` 未开；当前 recovery 目录没有指纹 HAL/service |
| 传感器 | 未包含 | recovery 不需要完整 sensor HAL；没有把手机传感器栈塞进来 |
| 蓝牙 | 未包含 | 没有 BT HAL/协议栈；当前只保留 Wi-Fi 所需的模块链 |
| HDMI/DP、摄像头、NFC | 未包含 | 不属于 recovery 核心功能，也未做设备适配 |

## 参考树的使用边界

`UGY1412/android_device_lenovo_TB323FU-aera` 是 Android 17、已做过真机验证的
参考树。只用它核对设备事实（例如 `AERA_SCREEN_H := 2280` 对应 1440×3040 逻辑
画布、`AERA_DYNAMIC_FULL_SIZE` 应等于 `BOARD_QTI_DYNAMIC_PARTITIONS_SIZE`）、
以及确认哪些功能需要额外的 stock 运行件；没有复制它的音频实现、init 服务顺序、
模块预置方式或 A17 TEE 替换文件。

当前树仍是 **Android 16 / AERA 16.0** 基线，不能直接套用 Android 17 的 TEE
替换结论。

## 2026-11-16 本轮静态复核修复

本轮只做静态核查，没有完整编译或刷机。已修掉以下会直接造成构建/启动失败的问题：

- `vendor/bin` 下 stock HAL/守护进程原本是 0644，init 无法执行；已统一为 0755，`extract_stock_blobs.sh` 也补了权限处理。
- `AERA_USE_DMSETUP` 与 `AERA_USE_DMCTL` 同时启用会触发 AERA 构建报错；已移除 DMSETUP。`AERA_USE_DMCTL` 从 `true` 改为 `1`，否则 `aera_build.mk` 的 `ifeq (...,1)` 不会启用 DMCTL。
- 设备有独立 `recovery_a/b` 分区，却继承了 `virtual_ab_ota/compression.mk` 并导出 `AERA_VIRTUAL_AB_DEVICE`；已移除，避免被当作 virtual A/B，也避免 `twrp.cpp` 删除 `boot-service.qti.xml`。
- 补入 stock vendor 的 `libvmmem.so`（gralloc/snapalloc）、`libqcbor.so`（gatekeeper/QSEEComAPI）、`libxml2.so`（drmfs）。
- `aera-graphics-allocator` 改为在 `twrp.modules.loaded=true`、`msm_kgsl/msm_drm` 已加载后再启动。
- `twrp.flags` 的 `/dataext` 补 `slotselect`，避免 A/B 槽位挂错。
- 移除没有对应实现的 health/fastboot VINTF 声明；`boot-service.qti.xml` 保留，和 `vendor.boot-qti` 对应。
- 音频 bootstrap 改为先启动 ADSP remoteproc，再启动 `pd-mapper`，避免服务定位器在 DSP 未上电时启动。

剩余未验证项见 `AUDIT_REPORT.md`，尤其是完整构建、`TARGET_PREBUILT_KERNEL` 是否真的不进 recovery.img、音频 AGM/PAL ABI、`agmplay` 的 card/device/FIFO 行为，以及 fstab/twrp.flags 的实际解析。
