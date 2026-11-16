#
# AERA Recovery product configuration for Lenovo TB323FU
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/lenovo/tb323fu

# Shipping API
BOARD_SHIPPING_API_LEVEL := 36
PRODUCT_SHIPPING_API_LEVEL := 36
PRODUCT_TARGET_VNDK_VERSION := 36

# Dynamic partitions
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# AERA recovery packages
# Audio: recovery-side AGM/PAL host and AERA browser PCM bridge.  The source
# is device-local under audio/; stock libraries/modules are loaded from the
# installed partitions at runtime, never copied into the ramdisk.
PRODUCT_PACKAGES += \
    aera-audio-bridge \
    aera-audio-service \
    aera-browser-jail \
    lpflash \
    lpmake \
    lpunpack

# Adreno 840 graphics backend
PRODUCT_VENDOR_PROPERTIES += \
    ro.hardware.egl=adreno

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += $(LOCAL_PATH)

# AERA settings
$(call inherit-product, $(LOCAL_PATH)/aera_tb323fu.mk)
