#
# AERA Recovery device configuration for Lenovo Legion Tab 8.8" Gen 5
# Model: TB323FU (Lenovo Legion Y700 Gen 5, Qualcomm Canoe / SM8850)
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/lenovo/tb323fu

# Keep the build tolerant while porting; remove once the tree is fully clean.
ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := oryon
TARGET_USES_64_BIT_BINDER := true

# Platform
TARGET_BOARD_PLATFORM := sm8850
TARGET_BOARD_PLATFORM_GPU := qcom-adreno840
QCOM_BOARD_PLATFORMS += sm8850

TARGET_BOOTLOADER_BOARD_NAME := TB323FU
TARGET_NO_BOOTLOADER := true

# Kernel
# The firmware package ships two closely related 6.12.30 builds:
#   boot.img        -> 6.12.30-android16-5-g1750f757fabe-ab13938768-4k
#   vmlinux         -> 6.12.30-android16-5-maybe-dirty-4k
# The vendor_dlkm modules carry __versions CRCs.  With CONFIG_MODVERSIONS=y,
# same_magic() skips the release/localversion prefix and compares only
# " SMP preempt mod_unload modversions aarch64"; symbol CRCs then enforce ABI.
# So the stock boot kernel can load these modules; no kernel replacement is
# required.  prebuilt/kernel is only an optional reference/boot experiment,
# and recovery itself is kernel-less like stock.  Never patch vermagic or
# bundle vendor .ko files.
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_RAMDISK_USE_LZ4 := true

# Recovery image geometry (GPT, LUN4)
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
# Stock boot.img is 96 MiB and holds the kernel (ramdisk_size = 0).
# Recovery mode loads that kernel; recovery.img itself has kernel_size = 0.
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_DTBOIMG_PARTITION_SIZE := 75497472

# Recovery is a ramdisk-only image, exactly like stock: kernel_size = 0.
# The bootloader boots it with the kernel from the boot partition (g1750).
# That kernel accepts the maybe-dirty vendor modules through __versions CRC
# matching, so recovery must not try to carry or replace the boot kernel.
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true

# A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS := \
    boot \
    init_boot \
    vendor_boot \
    dtbo \
    recovery \
    odm \
    product \
    system \
    system_ext \
    system_dlkm \
    vbmeta \
    vbmeta_system \
    vendor \
    vendor_dlkm \
    dataext

# Verified boot
BOARD_AVB_ENABLE := true
# 不生成 chained vbmeta_system：本构建只产出 recovery.img，设备上沿用
# stock vbmeta_system。缺少 key 时保留下面这行会让 Soong fsgen 报
# "No key found for chained avb partition vbmeta_system"。
# BOARD_AVB_VBMETA_SYSTEM := system system_ext product system_dlkm

# Dynamic partitions (super = 20,480 MiB, LP group qti_dynamic_partitions)
BOARD_SUPER_PARTITION_SIZE := 21474836480
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 21470642176
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    odm \
    system_dlkm

BOARD_PARTITION_LIST := $(call to-upper, $(BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST))
$(foreach p, $(BOARD_PARTITION_LIST), $(eval BOARD_$(p)IMAGE_FILE_SYSTEM_TYPE := ext4))
$(foreach p, $(BOARD_PARTITION_LIST), $(eval TARGET_COPY_OUT_$(p) := $(call to-lower, $(p))))
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4

# File systems
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Crypto / FBE
BOARD_USES_METADATA_PARTITION := true
BOARD_USES_QCOM_FBE_DECRYPTION := true
AERA_INCLUDE_CRYPTO := true
AERA_INCLUDE_CRYPTO_FBE := true
AERA_INCLUDE_FBE_METADATA_DECRYPT := true
AERA_USE_FSCRYPT_POLICY := 2

# Recovery
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab
AERA_INCLUDE_FASTBOOTD := true
AERA_USE_DMCTL := 1
AERA_SKIP_ADDITIONAL_FSTAB := true
AERA_UI_ADAPTIVE_RESOLUTION := true

# Tools
AERA_INCLUDE_LIBRESETPROP := true
AERA_INCLUDE_LPDUMP := true
AERA_INCLUDE_LPTOOLS := true
AERA_INCLUDE_REPACKTOOLS := true
AERA_INCLUDE_RESETPROP := true

# Root Manager supports the device's 6.12 GKI kernel
AERA_ROOT_MODULE_KERNELS := 6.12

# Debug
TARGET_USES_LOGD := true
AERA_INCLUDE_LOGCAT := true
TARGET_RECOVERY_DEVICE_MODULES += debuggerd
TARGET_RECOVERY_DEVICE_MODULES += strace
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/debuggerd
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/strace

# Display: 8.8" 3040x1904, NT36523 + CSOT, 165 Hz capable
AERA_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
AERA_DEFAULT_BRIGHTNESS := 2000
AERA_MAX_BRIGHTNESS := 4095
AERA_FRAMERATE := 60
AERA_NO_SCREEN_BLANK := true
AERA_SCREEN_BLANK_ON_BOOT := true
AERA_THEME := portrait_hdpi

# Filesystem features
RECOVERY_SDCARD_ON_DATA := true
TARGET_USES_MKE2FS := true
AERA_ENABLE_FS_COMPRESSION := true
AERA_INCLUDE_FUSE_EXFAT := true
AERA_INCLUDE_FUSE_NTFS := true
AERA_INCLUDE_NTFS_3G := true
AERA_NO_EXFAT_FUSE := true

# Version
PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
AERA_DEVICE_VERSION := Lenovo_Legion_Tab_Gen5_TB323FU

# Haptics
AERA_SUPPORT_INPUT_AIDL_HAPTICS := true

# Other AERA settings
TARGET_RECOVERY_QCOM_RTC_FIX := true
AERA_EXCLUDE_APEX := true
AERA_EXCLUDE_DEFAULT_USB_INIT := true
AERA_DEFAULT_LANGUAGE := zh_CN
AERA_EXTRA_LANGUAGES := true

# ---------------------------------------------------------------------------
# Vendor modules: names only. AERA mounts the real /vendor and /vendor_dlkm
# partitions and loads the .ko files that are already on the device. Nothing
# here is copied into the recovery ramdisk.
#
# Startup chain (SPU/weaver -> touch/display/USB/haptics/battery/crypto):
# ---------------------------------------------------------------------------
AERA_LOAD_VENDOR_MODULES := "\
    qcom_smd.ko \
    qcom_glink.ko \
    qcom_glink_smem.ko \
    rproc_qcom_common.ko \
    qcom_aoss.ko \
    qcom-scm.ko \
    mem_buf_dev.ko \
    mdt_loader.ko \
    qcom_pil_info.ko \
    qcom_ramdump.ko \
    socinfo.ko \
    pinctrl-msm.ko \
    qti-regmap-debugfs.ko \
    qcom_ipc_logging.ko \
    qcom_q6v5.ko \
    qcom_q6v5_pas.ko \
    qmi_helpers.ko \
    qcom_sysmon.ko \
    frpc-adsprpc.ko \
    qcom_glink_spss.ko \
    qcom_spss.ko \
    spss_utils.ko \
    spcom.ko \
    panel_event_notifier.ko \
    drm_display_helper.ko \
    msm_drm.ko \
    msm_kgsl.ko \
    dwc3-msm.ko \
    phy-msm-ssusb-qmp.ko \
    phy-qcom-qmp-combo.ko \
    phy-msm-m31-eusb2.ko \
    phy-qcom-eusb2-repeater.ko \
    phy-qcom-m31-eusb2.ko \
    phy-generic.ko \
    repeater.ko \
    redriver.ko \
    nb7vpq904m.ko \
    qcom-hv-haptics.ko \
    haptic.ko \
    qbt_handler.ko \
    qti_battery_charger.ko \
    qti_battery_debug.ko \
    qce50_dlkm.ko \
    qcrypto-msm_dlkm.ko \
    qrng_dlkm.ko \
    smcinvoke_dlkm.ko \
    tz_log_dlkm.ko \
    tmecom-intf_dlkm.ko"

# Wi-Fi stack: staged from the real system_dlkm/vendor_dlkm after userdata
# decryption, then the radio is brought up only when the user toggles WLAN
# (see init.recovery.wifi.rc). Keep this list in dependency order.
AERA_POST_DECRYPT_MODULES := "\
    rfkill.ko \
    libarc4.ko \
    cfg80211.ko \
    mac80211.ko \
    wlan_firmware_service.ko \
    cnss_plat_ipc_qmi_svc.ko \
    cnss_prealloc.ko \
    smem-mailbox.ko \
    cnss_utils.ko \
    qcom_ramdump.ko \
    pcie-pdc.ko \
    pci-msm-drv.ko \
    mhi.ko \
    cnss2.ko \
    cnss_nl.ko \
    lenovo_kallsyms.ko \
    qcom_pdr_msg.ko \
    pdr_interface.ko \
    qti_pmic_glink.ko \
    ucsi_qti_glink.ko \
    usb_f_gsi.ko \
    rmnet_mem.ko \
    qcom_va_minidump.ko \
    gsim.ko \
    ipam.ko \
    qca_cld3_peach_v2.ko \
    q6_pdr_dlkm.ko \
    q6_notifier_dlkm.ko \
    snd_event_dlkm.ko \
    gpr_dlkm.ko \
    spf_core_dlkm.ko \
    adsp_loader_dlkm.ko \
    adsp_sleepmon.ko \
    q6_dlkm.ko \
    spk_id_dlkm.ko \
    audpkt_ion_dlkm.ko \
    audio_pkt_dlkm.ko \
    audio_prm_dlkm.ko \
    pinctrl_lpi_dlkm.ko \
    hqsysfs.ko \
    aw882xx_dlkm.ko \
    swr_dlkm.ko \
    wcd_core_dlkm.ko \
    swr_ctrl_dlkm.ko \
    lpass_bt_swr_dlkm.ko \
    lpass_cdc_dlkm.ko \
    lpass_cdc_rx_macro_dlkm.ko \
    lpass_cdc_tx_macro_dlkm.ko \
    lpass_cdc_va_macro_dlkm.ko \
    lpass_cdc_wsa2_macro_dlkm.ko \
    lpass_cdc_wsa_macro_dlkm.ko \
    wcd9xxx_dlkm.ko \
    fsa4480_i2c.ko \
    fsa4480_sub_i2c.ko \
    sdca_registers_dlkm.ko \
    mbhc_dlkm.ko \
    wcd9378_dlkm.ko \
    wcd9378_slave_dlkm.ko \
    wcd939x_slave_dlkm.ko \
    wcd939x_dlkm.ko \
    wcd938x_dlkm.ko \
    wcd938x_slave_dlkm.ko \
    wsa883x_dlkm.ko \
    wsa884x_dlkm.ko \
    wsa885x_i2c_dlkm.ko \
    simple_amp_dlkm.ko \
    swr_dmic_dlkm.ko \
    swr_haptics_dlkm.ko \
    machine_dlkm.ko \
    btpower.ko \
    btfmcodec.ko \
    bt_fm_swr.ko \
    slimbus.ko \
    btfm_slim_codec.ko \
    snd-usb-audio-qmi.ko"

# The audio block above is names only.  AERA stages them from the real
# /vendor_dlkm after userdata decryption; aera-audio-bootstrap then starts the
# stock AGM/PAL user-space services.  Do not copy any .ko into recovery/root.

AERA_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
AERA_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
AERA_USE_TOOLBOX := true
AERA_INPUT_BLACKLIST := "hbtp_vm"

# eSE / OMAPI (device has ST54L). Keep OMAPI off in the first build because
# the vendor image does not expose the secure-element HAL/lib closure; turn it
# on after adding those blobs.
AERA_INCLUDE_OMAPI := false
