#
# Copyright (C) 2026 The AERA Recovery Project
#
# SPDX-License-Identifier: Apache-2.0
#
# Lenovo Legion Y700 5th Gen (TB323FU) / SM8850 "canoe"
# 所有数值均从原厂 TB323_ZUXOS_2.0.12.088 固件实测提取（GPT + rawprogram + super LP metadata）
#

DEVICE_PATH := device/lenovo/tb323fu

# 构建容错
ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_NINJA_USES_ENV_VARS += RTIC_MPGEN
BUILD_BROKEN_PLUGIN_VALIDATION := soong-libaosprecovery_defaults soong-libguitwrp_defaults soong-libminuitwrp_defaults soong-vold_defaults

# 架构
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := oryon

ENABLE_CPUSETS := true
ENABLE_SCHEDBOOST := true

# 平台（实测 vendor/build.prop：ro.board.platform=canoe / ro.product.board=baldur_prc_wifi）
PRODUCT_PLATFORM := canoe
TARGET_BOOTLOADER_BOARD_NAME := TB323FU
TARGET_NO_BOOTLOADER := true
TARGET_BOARD_PLATFORM := sm8850
TARGET_BOARD_PLATFORM_GPU := qcom-adreno840
QCOM_BOARD_PLATFORMS += sm8850

# 内核（原厂 boot.img：Linux 6.12.30-android16-5，KMI 6.12，GKI header v4）
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_RAMDISK_USE_LZ4 := true

TARGET_KERNEL_VERSION := 6.12
AERA_ROOT_MODULE_KERNELS := 6.12

# A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS := \
    boot \
    init_boot \
    recovery \
    vendor_boot \
    dtbo \
    vbmeta \
    vbmeta_system

# 分区大小（GPT LBA × 4096 字节，实测）
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296          # boot_a 24576 扇区 = 96 MiB
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296  # vendor_boot_a 24576 扇区
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600     # recovery_a 25600 扇区 = 100 MiB
BOARD_DTBOIMG_PARTITION_SIZE := 75497472            # dtbo_a 18432 扇区 = 72 MiB
BOARD_INIT_BOOTIMAGE_PARTITION_SIZE := 8388608      # init_boot_a 2048 扇区
BOARD_FLASH_BLOCK_SIZE := 131072

# 动态分区（GPT：super LBA 8968–5251847 = 20 GiB）
BOARD_SUPER_PARTITION_SIZE := 21474836480
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 21470642176   # super - 4 MiB 预留
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system \
    system_ext \
    product \
    vendor \
    odm

BOARD_PARTITION_LIST := $(call to-upper, $(BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST))
# 实测：super 内 system/system_ext/product/vendor/odm 全部为 ext4（非 erofs）
$(foreach p, $(BOARD_PARTITION_LIST), $(eval BOARD_$(p)IMAGE_FILE_SYSTEM_TYPE := ext4))
$(foreach p, $(BOARD_PARTITION_LIST), $(eval TARGET_COPY_OUT_$(p) := $(call to-lower, $(p))))

BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_USES_METADATA_PARTITION := true
BOARD_USES_QCOM_FBE_DECRYPTION := true

# AVB
BOARD_AVB_ENABLE := true
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true

# Recovery 基本
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab
TARGET_USES_LOGD := true

# AERA 特性
AERA_ENABLE_WLAN := true
AERA_ENABLE_MOBILE_DATA := 0
AERA_ENABLE_ROOT_MANAGER := 0
AERA_ENABLE_EFISP := 1
AERA_INCLUDE_CRYPTO := true
AERA_INCLUDE_CRYPTO_FBE := true
AERA_INCLUDE_FBE_METADATA_DECRYPT := true
AERA_USE_FSCRYPT_POLICY := 2
AERA_INCLUDE_FASTBOOTD := true
AERA_SKIP_ADDITIONAL_FSTAB := true

AERA_INCLUDE_LIBRESETPROP := true
AERA_INCLUDE_LPDUMP := true
AERA_INCLUDE_LPTOOLS := true
AERA_INCLUDE_REPACKTOOLS := true
AERA_INCLUDE_RESETPROP := true
AERA_INCLUDE_LOGCAT := true
AERA_INCLUDE_FUSE_EXFAT := true
AERA_INCLUDE_FUSE_NTFS := true
AERA_INCLUDE_NTFS_3G := true
AERA_NO_EXFAT_FUSE := true
AERA_EXCLUDE_APEX := true
AERA_USE_DMCTL := true
AERA_SUPPORT_INPUT_AIDL_HAPTICS := true
AERA_ENABLE_FS_COMPRESSION := true
AERA_THEME := portrait_hdpi
AERA_NO_SCREEN_BLANK := true
AERA_SCREEN_BLANK_ON_BOOT := true
AERA_SCREEN_H := 3040
AERA_FRAMERATE := 165

# 屏幕：8.8" 3040×1904 165Hz

# 设备标识
AERA_DEVICE_VERSION := Y700_5th_Gen
AERA_MAINTAINER := TB323FU
AERA_TARGET_DEVICES := TB323FU

# 其他
TARGET_USES_MKE2FS := true
TARGET_USES_VULKAN := true
TARGET_RECOVERY_QCOM_RTC_FIX := true

# ===== 内核模块加载（AERA kernel_module_loader 会按名单去 /vendor_dlkm/lib/modules 递归找）=====
# 开机即加载：显示 / 触摸 / 触感 / 充电
AERA_LOAD_VENDOR_MODULES := "panel_event_notifier.ko spi-msm-geni.ko i3c-master-msm-geni.ko \
nvt_36xxx.ko msm_drm.ko msm_kgsl.ko \
qmi_helpers.ko qcom_glink.ko qcom_glink_smem.ko qcom_smd.ko qcom_pdr_msg.ko \
pdr_interface.ko rproc_qcom_common.ko qti_pmic_glink.ko hqsysfs.ko \
qti_battery_charger.ko qti_battery_debug.ko qcom-hv-haptics.ko \
swr_dlkm.ko swr_haptics_dlkm.ko leds-qpnp-vibrator-ldo.ko haptic.ko"
# ↑ 第一阶段（解密前）加载，顺序依据各 .ko 的 modinfo depends=（实测，非猜）：
#   panel_event_notifier 无依赖，却是 nvt_36xxx / msm_drm / qti_battery_charger 的公共依赖 → 必须第 1 个
#   nvt_36xxx(modinfo: depends=panel_event_notifier) → msm_drm(modinfo: depends=...,nvt_36xxx,...)
#   即触摸必须早于 DRM；而 SPI 控制器 spi-msm-geni 要早于 SPI 从设备 nvt_36xxx
#   电池/振动链：qti_pmic_glink → qti_battery_charger → qcom-hv-haptics / swr_haptics_dlkm

# FBE 解密之后再加载：WiFi / 蓝牙（本机 wcn7750，qca_cld3_wcn7750.ko 20MB，绝不进 ramdisk）
AERA_POST_DECRYPT_MODULES := "rfkill.ko qmi_helpers.ko smem-mailbox.ko wlan_firmware_service.ko \
cnss_prealloc.ko qcom_ramdump.ko qcom_pdr_msg.ko qcom_smd.ko qcom_glink.ko qcom_glink_smem.ko \
rproc_qcom_common.ko pdr_interface.ko mhi.ko pci-msm-drv.ko pcie-pdc.ko \
cnss_plat_ipc_qmi_svc.ko cnss_utils.ko cnss_nl.ko cnss2.ko icnss2.ko \
repeater.ko redriver.ko lenovo_kallsyms.ko qti_pmic_glink.ko ucsi_qti_glink.ko \
dwc3-msm.ko usb_f_gsi.ko rmnet_mem.ko qcom_va_minidump.ko gsim.ko ipam.ko \
cfg80211.ko qca_cld3_wcn7750.ko \
btfmcodec.ko btpower.ko bt_fm_swr.ko lpass_bt_swr_dlkm.ko machine_dlkm.ko"
# ↑ 顺序不是随手排的：按 /vendor_dlkm/lib/modules/modules.dep 的依赖图做拓扑排序得出
#   rfkill 必须第一个（它在 system_dlkm 里，不在 vendor_dlkm），否则 cfg80211/qca_cld3 会 insmod 失败
#   qca_cld3_wcn7750 必须最后，它依赖上面 30 多个

# 触感/输入
AERA_SUPPORT_INPUT_FF_HAPTICS := true
AERA_SUPPORT_INPUT_AIDL_HAPTICS := true
AERA_INPUT_BLACKLIST := "hbtp_vm:qcom-hv-haptics"

# 设备特有值（来自同平台参考树，需实机核对）
AERA_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
AERA_DEFAULT_BRIGHTNESS := 2048
AERA_MAX_BRIGHTNESS := 4094
AERA_DEFAULT_TIMEZONE := Asia/Shanghai
