#
# Copyright (C) 2025 The AERA Recovery Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Configure base.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# Configure core_64_bit_only.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)

# Configure virtual_ab compression.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression.mk)

# Configure emulated_storage.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# Configure twrp common.mk
$(call inherit-product, vendor/twrp/config/common.mk)

# Inherit from TB323FU device
$(call inherit-product, device/lenovo/tb323fu/device.mk)

PRODUCT_DEVICE := tb323fu
PRODUCT_NAME := twrp_tb323fu
PRODUCT_BRAND := Lenovo
PRODUCT_MODEL := Lenovo Legion Y700 5th Gen
PRODUCT_MANUFACTURER := LENOVO

# ===== 真机指纹（从本机 boot.img 的 ramdisk/prop.default 原样读出，不是编的）=====
# ro.build.fingerprint / ro.system.build.fingerprint / ro.product.build.fingerprint 三者一致：
#   Lenovo/TB323FU/TB323FU:16/BQ2A.250831.001-BP2A.250605.031.A3/10.026.260205C:user/release-keys
# 对应固件 ZUX OS 2.0.10.026（boot.img 所在版本）
BUILD_FINGERPRINT := Lenovo/TB323FU/TB323FU:16/BQ2A.250831.001-BP2A.250605.031.A3/10.026.260205C:user/release-keys
PRIVATE_BUILD_DESC := TB323FU-user 16 BQ2A.250831.001-BP2A.250605.031.A3 26 release-keys

# 若按 firmware.7z 里的 2.0.12.088 出包（vendor/odm build.prop 的 incremental=88），把上面两行换成：
# BUILD_FINGERPRINT := Lenovo/TB323FU/TB323FU:16/BQ2A.250831.001-BP2A.250605.031.A3/88:user/release-keys
# PRIVATE_BUILD_DESC := TB323FU-user 16 BQ2A.250831.001-BP2A.250605.031.A3 88 release-keys

# 平台/机型属性（配合 system.prop，缺一项 AERA 的机型判定会落到 unknown）
# 注意：这里不要再写 PLATFORM_VERSION / PLATFORM_SECURITY_PATCH 的真实值。
# 官方 AERA canoe 树用 BoardConfig 固定的 99.87.36 / 2099-12-31，
# 真实值透传会让 keymint TA 收到越界的 os_version / os_patchlevel。
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_DEVICE=TB323FU \
    PRODUCT_MODEL="Lenovo Legion Y700 5th Gen" \
    PRODUCT_BRAND=Lenovo \
    PRODUCT_MANUFACTURER=LENOVO \
    TARGET_BUILD_TYPE=user \
    BUILD_ID=BQ2A.250831.001-BP2A.250605.031.A3 \
    BUILD_DISPLAY_ID=TB323FU_CN_OPEN_USER_Q00020.0_A16_ZUXOS_2.0.10.026_ST_260205 \
    PRODUCT_LOCALE=zh-Hans-CN \
    BUILD_FINGERPRINT=$(BUILD_FINGERPRINT)

# Theme
AERA_STATUS_ICONS_ALIGN := center

# magiskboot 预编译 4K 对齐，Android16 要求 16K，跳过该检查
PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE := false
