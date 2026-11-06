#
# Copyright (C) 2026 The AERA Recovery Project
#
# SPDX-License-Identifier: Apache-2.0
#
# Lenovo Legion Y700 5th Gen (TB323FU)
#
# 注意：recovery/root/** 会被 AERA 构建自动打进 ramdisk，
# 绝对不要在这里写源路径指向 recovery/root 的 PRODUCT_COPY_FILES，
# 否则 soong 在 build/soong/fsgen/ 下解析成 ../../recovery/root/...
# 会直接报 "is outside of the source root" 并中断构建。
#

LOCAL_PATH := device/lenovo/tb323fu

# API level（Android 16）
BOARD_SHIPPING_API_LEVEL := 36
PRODUCT_SHIPPING_API_LEVEL := 36
PRODUCT_TARGET_VNDK_VERSION := 36

# 动态分区
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# AERA 工具
PRODUCT_PACKAGES += \
    aera-audio-bridge \
    aera-audio-service \
    aera-browser-jail \
    lpflash \
    lpmake \
    lpunpack

# Adreno GPU 后端（本机 ro.hardware.egl=adreno / vulkan=adreno）
PRODUCT_VENDOR_PROPERTIES += \
    ro.hardware.egl=adreno \
    ro.hardware.vulkan=adreno

# OTA 签名证书
PRODUCT_EXTRA_RECOVERY_KEYS += \
    $(LOCAL_PATH)/security/local_OTA \
    $(LOCAL_PATH)/security/special_OTA

# Soong namespace
PRODUCT_SOONG_NAMESPACES += $(LOCAL_PATH)

# AERA 设备参数
$(call inherit-product, $(LOCAL_PATH)/aera_tb323fu.mk)
