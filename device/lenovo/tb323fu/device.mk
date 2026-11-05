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

# Firmware files: copy to both vendor/firmware and system/etc/firmware
# (nvt_36xxx.ko may look in either path)
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/novatek_ts_fw.bin:recovery/root/system/etc/firmware/novatek_ts_fw.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/novatek_ts_mp.bin:recovery/root/system/etc/firmware/novatek_ts_mp.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/gen80000_zap.mbn:recovery/root/system/etc/firmware/gen80000_zap.mbn \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/gen80000_gmu.bin:recovery/root/system/etc/firmware/gen80000_gmu.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/gen80000_aqe.fw:recovery/root/system/etc/firmware/gen80000_aqe.fw \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/gen80000_sqe.fw:recovery/root/system/etc/firmware/gen80000_sqe.fw
