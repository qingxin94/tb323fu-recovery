#
# AERA Recovery product configuration for Lenovo TB323FU
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/lenovo/tb323fu

BOARD_SHIPPING_API_LEVEL := 36
PRODUCT_SHIPPING_API_LEVEL := 36
PRODUCT_TARGET_VNDK_VERSION := 36

PRODUCT_USE_DYNAMIC_PARTITIONS := true

# AERA recovery packages.  Audio is built from device-local sources; stock
# libraries and kernel modules are consumed from the real partitions at
# runtime, never bundled into the ramdisk.
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

PRODUCT_SOONG_NAMESPACES += $(LOCAL_PATH)

$(call inherit-product, $(LOCAL_PATH)/aera_tb323fu.mk)
