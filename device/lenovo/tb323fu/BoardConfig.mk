#
# AERA Recovery device tree - Lenovo Legion Y700 (TB323FU)
# Platform: SM8850 / canoe / Android 16 / kernel 6.12.30-4k
# All partition geometry is measured from the stock TB323_ZUXOS_2.0.12.088 package.
#
DEVICE_PATH := device/lenovo/tb323fu

# Build tolerance (minimal manifest)
ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_NINJA_USES_ENV_VARS += RTIC_MPGEN
BUILD_BROKEN_PLUGIN_VALIDATION := soong-libaosprecovery_defaults soong-libguitwrp_defaults soong-libminuitwrp_defaults soong-vold_defaults

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := oryon
TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := kryo
TARGET_USES_64_BIT_BINDER := true
TARGET_SUPPORTS_64_BIT_APPS := true

# Power
ENABLE_CPUSETS := true
ENABLE_SCHEDBOOST := true

# Bootloader / platform
PRODUCT_PLATFORM := canoe
TARGET_BOOTLOADER_BOARD_NAME := canoe
TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true
TARGET_BOARD_PLATFORM := sm8850
TARGET_BOARD_PLATFORM_GPU := qcom-adreno840
QCOM_BOARD_PLATFORMS += sm8850

# Kernel (stock boot.img Image: 6.12.30-android16-5-g1750f757fabe-ab13938768-4k)
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_RAMDISK_USE_LZ4 := true
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
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
    vbmeta_system \
    vbmeta_vendor

# Partition sizes (measured from GPT / package super chunks)
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
BOARD_DTBOIMG_PARTITION_SIZE := 75497472
BOARD_INIT_BOOTIMAGE_PARTITION_SIZE := 8388608
BOARD_FLASH_BLOCK_SIZE := 131072

# Dynamic partitions: super = 20 GiB (LP block device size 0x500000000)
BOARD_SUPER_PARTITION_SIZE := 21474836480
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 21470642176
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    odm \
    system_dlkm
BOARD_PARTITION_LIST := $(call to-upper, $(BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST))
# All logical partitions in this retail package are ext4 (verified 0xef53 superblock)
$(foreach p, $(BOARD_PARTITION_LIST), $(eval BOARD_$(p)IMAGE_FILE_SYSTEM_TYPE := ext4))
$(foreach p, $(BOARD_PARTITION_LIST), $(eval TARGET_COPY_OUT_$(p) := $(call to-lower, $(p))))
BOARD_BUILD_VENDOR_DLKM_IMAGE := true
BOARD_BUILD_SYSTEM_DLKM_IMAGE := true

# Filesystems
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Crypto
BOARD_USES_METADATA_PARTITION := true
BOARD_USES_QCOM_FBE_DECRYPTION := true
AERA_INCLUDE_CRYPTO := true
AERA_INCLUDE_CRYPTO_FBE := true
AERA_INCLUDE_FBE_METADATA_DECRYPT := true
AERA_USE_FSCRYPT_POLICY := 2

# Recovery
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab
AERA_INCLUDE_FASTBOOTD := true
AERA_SKIP_ADDITIONAL_FSTAB := true
AERA_UI_ADAPTIVE_RESOLUTION := true

# Tools
AERA_INCLUDE_LIBRESETPROP := true
AERA_INCLUDE_LPDUMP := true
AERA_INCLUDE_LPTOOLS := true
AERA_INCLUDE_REPACKTOOLS := true
AERA_INCLUDE_RESETPROP := true

# Debug
TARGET_USES_LOGD := true
AERA_INCLUDE_LOGCAT := true
TARGET_RECOVERY_DEVICE_MODULES += debuggerd
TARGET_RECOVERY_DEVICE_MODULES += strace
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/debuggerd
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/strace

# Display: 8.8" 3040x1904 165Hz, panel0-backlight
AERA_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
AERA_DEFAULT_BRIGHTNESS := 2047
AERA_MAX_BRIGHTNESS := 4094
AERA_SCREEN_H := 2280
AERA_FRAMERATE := 165
AERA_NO_SCREEN_BLANK := true
AERA_SCREEN_BLANK_ON_BOOT := true
AERA_THEME := portrait_hdpi
TARGET_USES_VULKAN := true

# Filesystem / storage
RECOVERY_SDCARD_ON_DATA := true
TARGET_USES_MKE2FS := true
AERA_ENABLE_FS_COMPRESSION := true
AERA_INCLUDE_FUSE_EXFAT := true
AERA_INCLUDE_FUSE_NTFS := true
AERA_INCLUDE_NTFS_3G := true
AERA_NO_EXFAT_FUSE := true

# Version: never leak the retail patch level into the TEE HAL info
PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
AERA_DEVICE_VERSION := Lenovo_Legion_Y700

# Input haptics
AERA_SUPPORT_INPUT_AIDL_HAPTICS := true

# Misc
TARGET_RECOVERY_QCOM_RTC_FIX := true
AERA_EXCLUDE_APEX := true
AERA_EXCLUDE_DEFAULT_USB_INIT := true
AERA_DEFAULT_LANGUAGE := "zh_CN"
AERA_EXTRA_LANGUAGES := true
AERA_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
AERA_USE_TOOLBOX := true
AERA_ENABLE_WLAN := true
AERA_ENABLE_MOBILE_DATA := 0
AERA_ENABLE_ROOT_MANAGER := 0
AERA_ENABLE_EFISP := 1
AERA_INCLUDE_OMAPI := true
AERA_ENABLE_FRP_WIPE := 1
AERA_ENABLE_ABL_PRESERVATION := 1
AERA_AB_DEVICE_WITH_RECOVERY_PARTITION := 1
AERA_WORKAROUND_BACKUP_BUG := 1
AERA_USE_AIDL_BOOT_CONTROL := 1
AERA_FORCE_DATA_FORMAT_F2FS := 1
AERA_USE_LZ4_COMPRESSION := 1
AERA_DYNAMIC_FULL_SIZE := 21474836480
AERA_NO_RELOAD_AFTER_DECRYPTION := 1
AERA_FORCE_PREBUILT_KERNEL := 1
AERA_NO_TREBLE_COMPATIBILITY_CHECK := 1
# No fingerprint hardware on this tablet
AERA_SUPPORT_FINGERPRINT := 0

# ---- Module loading (dependency order from stock modules.dep) ----
# Stage 1 (before decryption): display / touch / haptics / charger
AERA_LOAD_VENDOR_MODULES := "panel_event_notifier.ko spi-msm-geni.ko i3c-master-msm-geni.ko nvt_36xxx.ko msm_kgsl.ko qmi_helpers.ko qcom_glink.ko qcom_glink_smem.ko qcom_smd.ko qcom_pdr_msg.ko pdr_interface.ko rproc_qcom_common.ko qti_pmic_glink.ko qcom-hv-haptics.ko swr_dlkm.ko swr_haptics_dlkm.ko aw882xx_dlkm.ko leds-qpnp-vibrator-ldo.ko haptic.ko adsp_loader_dlkm.ko spcom.ko spss_utils.ko stm_st54se_gpio.ko nxp-nci.ko"
AERA_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true

# Stage 2 (after FBE decryption): WiFi/BT (wcn7750)
AERA_POST_DECRYPT_MODULES := "rfkill.ko smem-mailbox.ko wlan_firmware_service.ko cnss_prealloc.ko qcom_ramdump.ko qcom_smd.ko qcom_glink.ko qcom_glink_smem.ko rproc_qcom_common.ko pdr_interface.ko mhi.ko pci-msm-drv.ko pcie-pdc.ko cnss_plat_ipc_qmi_svc.ko cnss_utils.ko cnss_nl.ko cnss2.ko icnss2.ko repeater.ko redriver.ko rmnet_mem.ko gsim.ko ipam.ko cfg80211.ko qca_cld3_wcn7750.ko btfmcodec.ko btpower.ko bt_fm_swr.ko lpass_bt_swr_dlkm.ko machine_dlkm.ko"

# Stage the installed ROM runtime (vendor/odm/system) in RAM and use it,
# instead of shipping a hand-picked copy of the vendor blobs in ramdisk.
AERA_COPY_RUNTIME_TO_RAM := 1
# The shipped canoe reference (oneplus_infiniti R1.0) and both community
# recoveries that boot on TB323FU (TWRP-16.0, OrangeFox R12.0) use a fully
# expanded ramdisk: no aera-runtime.tar.xz, no early-init unpack step.
AERA_USE_EXTREME_COMPRESSION := 0
AERA_DEFAULT_KEYMASTER_VERSION := 4.x   # 设备为 AIDL KeyMint V4；不设会触发 aera_build.mk:648 的 $(error)
AERA_FORCE_KEYMASTER_VER := true
AERA_INPUT_BLACKLIST := "hbtp_vm"   # 触摸控制器驱动名，避免误判为输入设备
AERA_USE_UPDATED_MAGISKBOOT := 0   # 默认 prebuilt magiskboot 4K 对齐；_updated 为 16K 对齐，本机 4K 页内核不可用
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_INCLUDE_CRYPTO := true

AERA_VIRTUAL_AB_DEVICE := 1      # aera_build.mk 判等 "1"；原厂 ro.virtual_ab.enabled=true
AERA_USE_DMCTL := 1              # 映射到 OF_USE_DMCTL，判等 1；dynamic partitions / super
AERA_DRM_FIXED_REFRESH_RATE := 165  # 3040x1904 165Hz panel
AERA_SUPPORT_INPUT_AIDL_HAPTICS_FQNAME := "vendor.lenovo.hardware.vibrator_dual"

# Verified Boot
BOARD_AVB_ENABLE := true
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true
