#
# Copyright (C) 2026 AERA Recovery
# aera_tb323fu.mk - product config for Lenovo Legion Y700 (tb323fu)
#

# ─── Product inheritance chain (aligned with myron/canoe proven template) ───
# base.mk pulls in base_vendor.mk which supplies the recovery variant modules
# (init_second_stage.recovery, adbd.recovery, linker.recovery, ...). Without it
# $(TARGET_ROOT_OUT) is never created and ramdisk assembly fails with
# "rsync: link_stat .../root failed: No such file or directory".
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# Inherit AERA Recovery common config
$(call inherit-product, vendor/twrp/config/common.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit device makefile
$(call inherit-product, device/lenovo/tb323fu/device.mk)

# Product identity
PRODUCT_NAME := twrp_tb323fu
PRODUCT_DEVICE := tb323fu
PRODUCT_BRAND := Lenovo
PRODUCT_MODEL := TB323FU
PRODUCT_MANUFACTURER := Motorola Mobility

# Overrides (real fingerprint extracted from boot_a.img)
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_DEVICE=tb323fu \
    PRODUCT_NAME=tb323fu \
    PRIVATE_BUILD_DESC="tb323fu-user 16 BQ2A.250831.001-BP2A.250605.031.A3 10.026.260205C release-keys"

BUILD_FINGERPRINT := Lenovo/TB323FU/TB323FU:16/BQ2A.250831.001-BP2A.250605.031.A3/10.026.260205C:user/release-keys

# ─── AERA device config (aligned with myron/canoe proven template) ───
# Kernel and recovery behavior
AERA_FORCE_PREBUILT_KERNEL := 1
AERA_AB_DEVICE_WITH_RECOVERY_PARTITION := 1
AERA_NO_RELOAD_AFTER_DECRYPTION := 1
AERA_NO_TREBLE_COMPATIBILITY_CHECK := 1
AERA_USE_LZ4_COMPRESSION := 1
AERA_ENABLE_WLAN := 1
AERA_ENABLE_FRP_WIPE := 1
AERA_USE_AIDL_BOOT_CONTROL := 1

# Partition / format handling
AERA_DYNAMIC_FULL_SIZE := 16441663488
AERA_DISPLAY_FORMAT_FILESYSTEMS_DEBUG_INFO := 1
AERA_ENABLE_ALL_PARTITION_TOOLS := 1
AERA_USE_DMCTL := 1
AERA_FORCE_DATA_FORMAT_F2FS := 1
AERA_FORCE_CASEFOLDING := 1
AERA_UNBIND_SDCARD_F2FS := 1
AERA_BIND_MOUNT_SDCARD_ON_FORMAT := 1
AERA_UNMOUNT_SDCARDS_BEFORE_REBOOT := 1
AERA_WIPE_METADATA_AFTER_DATAFORMAT := 1
AERA_WORKAROUND_BACKUP_BUG := 1

# UI metrics for 横版平板 (landscape) — 物理分辨率待实测
AERA_MAINTAINER := qingxin94
AERA_SCREEN_H := 1600
AERA_STATUS_H := 80
AERA_STATUS_INDENT_LEFT := 40
AERA_STATUS_INDENT_RIGHT := 40
AERA_HIDE_NOTCH := 1
AERA_CLOCK_POS := 1
AERA_OPTIONS_LIST_NUM := 6

# Misc
AERA_ALLOW_POPULATED_MEDIA_WITHOUT_POLICY := 1
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.aera.allow_nonempty_media=$(AERA_ALLOW_POPULATED_MEDIA_WITHOUT_POLICY)

# 默认中文
PRODUCT_PROPERTY_OVERRIDES += ro.product.locale=zh-CN
