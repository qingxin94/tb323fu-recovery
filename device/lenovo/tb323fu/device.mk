#
# Copyright (C) 2026 AERA Recovery
# device.mk for Lenovo Legion Y700 (tb323fu)
#

# USB config
PRODUCT_PROPERTY_OVERRIDES += \
    ro.recovery.usb.vid=22B8 \
    ro.recovery.usb.adb.pid=2E81 \
    ro.recovery.usb.fastboot.pid=2E80 \

# Device identity (from boot_a.img fingerprint: Lenovo/TB323FU/TB323FU:16/BQ2A.250831.001...)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.device=tb323fu \
    ro.product.name=tb323fu \
    ro.product.model=TB323FU \
    ro.product.brand=Lenovo \
    ro.product.manufacturer=Motorola Mobility \
    ro.build.product=tb323fu \

# Modules are auto-loaded by AERA framework from modules/ directory
# (see AERA_LOAD_VENDOR_MODULES in BoardConfig.mk)

# 跳过prebuilt page size检查（magiskboot 4096 vs 16384）
PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE := false
