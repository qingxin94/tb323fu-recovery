#
# AERA Recovery device configuration for Lenovo Legion Y700 Gen 5
# Model: TB323FU (SM8850 / Canoe)
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/lenovo/tb323fu

# Keep build tolerant while the device tree is being brought up.
ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := oryon
TARGET_USES_64_BIT_BINDER := true

# Platform
TARGET_BOARD_PLATFORM := sm8850
TARGET_BOARD_PLATFORM_GPU := qcom-adreno840
QCOM_BOARD_PLATFORMS += sm8850

TARGET_BOOTLOADER_BOARD_NAME := TB323FU
TARGET_NO_BOOTLOADER := true

# Kernel
# The stock boot image supplies the kernel for recovery mode.  This recovery
# image is ramdisk-only (kernel_size = 0), exactly like stock.  Do not bundle
# vendor .ko files: they are loaded from the real vendor_dlkm/system_dlkm.
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_RAMDISK_USE_LZ4 := true

# Recovery image geometry (GPT, LUN4)
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_DTBOIMG_PARTITION_SIZE := 75497472

# Recovery is kernel-less; boot partition supplies the kernel.
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true

# A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS := \
    boot \
    init_boot \
    vendor_boot \
    dtbo \
    recovery \
    odm \
    product \
    system \
    system_ext \
    system_dlkm \
    vbmeta \
    vbmeta_system \
    vendor \
    vendor_dlkm \
    dataext

# Verified boot
BOARD_AVB_ENABLE := true

# Dynamic partitions (super = 20,480 MiB, LP group qti_dynamic_partitions)
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
$(foreach p, $(BOARD_PARTITION_LIST), $(eval BOARD_$(p)IMAGE_FILE_SYSTEM_TYPE := ext4))
$(foreach p, $(BOARD_PARTITION_LIST), $(eval TARGET_COPY_OUT_$(p) := $(call to-lower, $(p))))
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4

# File systems
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Crypto / FBE
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
AERA_USE_DMCTL := 1
AERA_SKIP_ADDITIONAL_FSTAB := true
AERA_UI_ADAPTIVE_RESOLUTION := true

# Tools
AERA_INCLUDE_LIBRESETPROP := true
AERA_INCLUDE_LPDUMP := true
AERA_INCLUDE_LPTOOLS := true
AERA_INCLUDE_REPACKTOOLS := true
AERA_INCLUDE_RESETPROP := true

# Root manager supports the device's 6.12 GKI kernel
AERA_ROOT_MODULE_KERNELS := 6.12

# Debug
TARGET_USES_LOGD := true
AERA_INCLUDE_LOGCAT := true
TARGET_RECOVERY_DEVICE_MODULES += debuggerd
TARGET_RECOVERY_DEVICE_MODULES += strace
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/debuggerd
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/strace

# Display: 8.8" 3040x1904, NT36523 + CSOT, 165 Hz capable
AERA_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
AERA_DEFAULT_BRIGHTNESS := 2000
AERA_MAX_BRIGHTNESS := 4095
AERA_FRAMERATE := 60
AERA_NO_SCREEN_BLANK := true
AERA_SCREEN_BLANK_ON_BOOT := true
AERA_THEME := portrait_hdpi

# Filesystem features
RECOVERY_SDCARD_ON_DATA := true
TARGET_USES_MKE2FS := true
AERA_ENABLE_FS_COMPRESSION := true
AERA_INCLUDE_FUSE_EXFAT := true
AERA_INCLUDE_FUSE_NTFS := true
AERA_INCLUDE_NTFS_3G := true
AERA_NO_EXFAT_FUSE := true

# Version
PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
AERA_DEVICE_VERSION := Lenovo_Legion_Tab_Gen5_TB323FU

# Haptics
AERA_SUPPORT_INPUT_AIDL_HAPTICS := true

# Other AERA settings
TARGET_RECOVERY_QCOM_RTC_FIX := true
AERA_EXCLUDE_APEX := true
AERA_EXCLUDE_DEFAULT_USB_INIT := true
AERA_DEFAULT_LANGUAGE := zh_CN
AERA_EXTRA_LANGUAGES := true

# ---------------------------------------------------------------------------
# Module policy: boot loads nothing automatically.
#
# AERA's own TW_LOAD_VENDOR_MODULES / TW_POST_DECRYPT_MODULES paths must stay
# empty.  The device tree mounts the real partitions and then loads small,
# explicit groups from /vendor_dlkm and /system_dlkm:
#
#   base     -> touch + SPU/weaver prerequisites (boot, small)
#   wifi     -> cfg80211 + qca_cld3_peach_v2 (on demand only)
#   audio    -> audio module group (on demand only)
#   haptics  -> haptics module group (on demand only)
#
# The group loader resolves module dependencies from the real modules.dep
# before calling insmod.  Nothing is copied to /tmp and no .ko is placed in
# the recovery ramdisk.
# ---------------------------------------------------------------------------
AERA_LOAD_VENDOR_MODULES := ""
AERA_POST_DECRYPT_MODULES := ""
AERA_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
AERA_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
AERA_USE_TOOLBOX := true
AERA_INPUT_BLACKLIST := "hbtp_vm"

# AERA's WLAN integration can install ramdisk copies of wpa_supplicant and
# its client libraries when AERA_ENABLE_WLAN=1.  This tree uses the real
# /vendor binary and libraries.  Remove any generated ramdisk copies before
# the image is packed; this never touches the real partitions.
BOARD_RECOVERY_IMAGE_PREPARE += if [ -n "$(TARGET_RECOVERY_ROOT_OUT)" ] && [ -d "$(TARGET_RECOVERY_ROOT_OUT)/system/bin" ]; then rm -f "$(TARGET_RECOVERY_ROOT_OUT)/system/bin/wpa_supplicant" "$(TARGET_RECOVERY_ROOT_OUT)/system/bin/wpa_cli" "$(TARGET_RECOVERY_ROOT_OUT)/system/lib64/libkeystore-engine-wifi-hidl.so" "$(TARGET_RECOVERY_ROOT_OUT)/system/lib64/android.hardware.wifi.common-V2-ndk.so" "$(TARGET_RECOVERY_ROOT_OUT)/system/lib64/android.hardware.wifi.supplicant-V4-ndk.so"; fi

# eSE / OMAPI
AERA_INCLUDE_OMAPI := false
