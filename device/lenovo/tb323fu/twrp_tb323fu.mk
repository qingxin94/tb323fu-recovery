#
# AERA Recovery product definition for Lenovo TB323FU
#
# SPDX-License-Identifier: Apache-2.0
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, vendor/twrp/config/common.mk)
$(call inherit-product, device/lenovo/tb323fu/device.mk)

PRODUCT_DEVICE := tb323fu
PRODUCT_NAME := twrp_tb323fu
PRODUCT_BRAND := Lenovo
PRODUCT_MODEL := Lenovo Legion Tab 8.8 Gen5
PRODUCT_MANUFACTURER := Lenovo
PRODUCT_GMS_CLIENTID_BASE := android-lenovo

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="TB323FU-user 16 BQ2A.250831.001-BP2A.250605.031.A3 ZUXOS_2.0.12.088_260610_PRC release-keys"

BUILD_FINGERPRINT := Lenovo/TB323FU/TB323FU:16/BQ2A.250831.001-BP2A.250605.031.A3/ZUXOS_2.0.12.088_260610_PRC:user/release-keys

AERA_STATUS_ICONS_ALIGN := center
PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE := false
