#
# Copyright (C) 2026 AERA Recovery
# device.mk for Lenovo Legion Y700 (tb323fu)
#

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

# Firmware files live ONLY at recovery/root/vendor/firmware/ -> ramdisk /vendor/firmware/
# DO NOT add PRODUCT_COPY_FILES whose source is $(DEVICE_PATH)/recovery/root/...:
#   soong resolves it as ../../recovery/root/... relative to build/soong/fsgen/
#   -> "is outside of the source root" -> soong bootstrap fails before compiling.
# AERA packs recovery/root/** into the recovery ramdisk automatically, so no copy rule is needed.
# For a second search path (/system/etc/firmware), place real files under
# recovery/root/system/etc/firmware/ instead of using a copy rule.
