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

# Firmware files: touch, GPU, WiFi, audio
# Copy from vendor/firmware to system/etc/firmware (like Xiaomi dada)
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/novatek_ts_fw.bin:recovery/root/vendor/firmware/novatek_ts_fw.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/novatek_ts_mp.bin:recovery/root/vendor/firmware/novatek_ts_mp.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/novatek_ts_fw.bin:recovery/root/system/etc/firmware/novatek_ts_fw.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/novatek_ts_mp.bin:recovery/root/system/etc/firmware/novatek_ts_mp.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/gen80000_zap.mbn:recovery/root/vendor/firmware/gen80000_zap.mbn \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/gen80000_gmu.bin:recovery/root/vendor/firmware/gen80000_gmu.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/gen80000_aqe.fw:recovery/root/vendor/firmware/gen80000_aqe.fw \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/gen80000_sqe.fw:recovery/root/vendor/firmware/gen80000_sqe.fw \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/gen80000_zap.mbn:recovery/root/system/etc/firmware/gen80000_zap.mbn \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/gen80000_gmu.bin:recovery/root/system/etc/firmware/gen80000_gmu.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/gen80000_aqe.fw:recovery/root/system/etc/firmware/gen80000_aqe.fw \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/gen80000_sqe.fw:recovery/root/system/etc/firmware/gen80000_sqe.fw \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/aw882xx_acf.bin:recovery/root/vendor/firmware/aw882xx_acf.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/aw882xx_acf.bin:recovery/root/system/etc/firmware/aw882xx_acf.bin
