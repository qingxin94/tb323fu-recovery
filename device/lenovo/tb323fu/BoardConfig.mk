#
# BoardConfig for Lenovo Legion Y700 2025 - codename: tb323fu
# SoC: Qualcomm SM8850 (Snapdragon 8 Elite Gen 5, platform: canoe)
# Kernel: 6.12.30-android16-5
# Screen: 横版平板, Novatek NT36523 + CSOT 3K DSC (物理分辨率待实测)
#

DEVICE_PATH := device/lenovo/tb323fu

# ─── Build tolerance ───
ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_NINJA_USES_ENV_VARS += RTIC_MPGEN
BUILD_BROKEN_PLUGIN_VALIDATION := soong-libaosprecovery_defaults soong-libguitwrp_defaults soong-libminuitwrp_defaults soong-vold_defaults

# ─── Architecture (Oryon CPU) ───
TARGET_ARCH             := arm64
TARGET_ARCH_VARIANT     := armv8-a
TARGET_CPU_ABI          := arm64-v8a
TARGET_CPU_ABI2         :=
TARGET_CPU_VARIANT      := generic
TARGET_CPU_VARIANT_RUNTIME := oryon

ENABLE_CPUSETS    := true
ENABLE_SCHEDBOOST := true

# ─── Platform (canoe = SM8845/SM8850) ───
PRODUCT_PLATFORM      := canoe
TARGET_BOOTLOADER_BOARD_NAME := canoe
TARGET_NO_BOOTLOADER  := true
TARGET_USES_UEFI      := true
TARGET_BOARD_PLATFORM := canoe
TARGET_BOARD_PLATFORM_GPU := qcom-adreno840
QCOM_BOARD_PLATFORMS  += canoe

# ─── Kernel ───
TARGET_KERNEL_ARCH        := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_KERNEL_IMAGE_NAME   := Image
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE     := 4096
TARGET_KERNEL_CLANG_COMPILE := true
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_MKBOOTIMG_ARGS      += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS      += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_RAMDISK_USE_LZ4     := true

# Kernel lives in vendor_boot — do NOT embed in recovery.img
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
BOARD_KERNEL_CMDLINE :=

# ─── Boot / partition sizes ───
BOARD_BOOT_HEADER_VERSION := 4
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296       # 96 MB
BOARD_INIT_BOOT_HEADER_VERSION := 4
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608  # 8 MB
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296  # 96 MB
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 134217728  # 128 MB
BOARD_DTBOIMG_PARTITION_SIZE := 75497472         # 72 MB

# NOTE: do NOT define BOARD_INCLUDE_DTB_IN_BOOTIMG at all (even =false).
# AERA build_make uses `ifdef BOARD_INCLUDE_DTB_IN_BOOTIMG` (core/Makefile ~line 1028):
# merely defining it makes INSTALLED_DTBIMAGE_TARGET := $(PRODUCT_OUT)/dtb.img,
# which then has no build rule → ninja "dtb.img missing". myron/canoe has no such line.

# ─── A/B ───
AB_OTA_UPDATER   := true
BOARD_RECOVERY_NEEDS_BOOTLOADER_CONTROL := true
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    init_boot \
    odm \
    product \
    system \
    system_dlkm \
    system_ext \
    vbmeta \
    vbmeta_system \
    vendor \
    vendor_boot \
    vendor_dlkm

BOARD_USES_RECOVERY_AS_BOOT := false

# ─── Dynamic partitions ───
BOARD_SUPER_PARTITION_SIZE := 16441663488
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 16437469184
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    system_dlkm \
    odm

# ─── Filesystem ───
BOARD_HAS_LARGE_FILESYSTEM := true
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
TARGET_COPY_OUT_VENDOR     := vendor
BOARD_USES_VENDOR_DLKMIMAGE := true
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_ODM := odm
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs

# ─── FBE / crypto ───
BOARD_USES_METADATA_PARTITION  := true
BOARD_USES_QCOM_FBE_DECRYPTION := true
AERA_INCLUDE_CRYPTO            := true
AERA_INCLUDE_CRYPTO_FBE        := true
AERA_INCLUDE_FBE_METADATA_DECRYPT := true
AERA_USE_FSCRYPT_POLICY := 2

# Anti-rollback
PLATFORM_VERSION             := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH      := 2099-12-31
VENDOR_SECURITY_PATCH        := $(PLATFORM_VERSION)
BOOT_SECURITY_PATCH          := $(PLATFORM_VERSION)

# ─── AVB ───
BOARD_AVB_ENABLE := true
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 0
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 0

# ─── Recovery / UI ───
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_QCOM_RTC_FIX := true
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/fstab.qcom
AERA_INCLUDE_FASTBOOTD := true
AERA_SKIP_ADDITIONAL_FSTAB := true
AERA_UI_ADAPTIVE_RESOLUTION := true
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
RECOVERY_SDCARD_ON_DATA := true

# Screen: 横版平板 (landscape) — 物理分辨率待实测, 先按 landscape_hdpi
AERA_THEME := landscape_hdpi
AERA_FRAMERATE := 144
TARGET_SCREEN_WIDTH  := 2560
TARGET_SCREEN_HEIGHT := 1600
AERA_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
AERA_DEFAULT_BRIGHTNESS := 2048
AERA_MAX_BRIGHTNESS := 4094
AERA_NO_SCREEN_BLANK := true
AERA_SCREEN_BLANK_ON_BOOT := true
AERA_STATUS_ICONS_ALIGN := center

# ─── Storage tools ───
TARGET_USES_MKE2FS := true
AERA_ENABLE_FS_COMPRESSION := true
AERA_INCLUDE_FUSE_EXFAT := true
AERA_INCLUDE_FUSE_NTFS := true
AERA_INCLUDE_NTFS_3G := false
AERA_NO_EXFAT_FUSE := true

# ─── Tools ───
AERA_INCLUDE_7ZA := true
AERA_INCLUDE_LIBRESETPROP := true
AERA_INCLUDE_LPDUMP := true
AERA_INCLUDE_LPTOOLS := true
AERA_INCLUDE_REPACKTOOLS := true
AERA_INCLUDE_RESETPROP := true
AERA_USE_TOOLBOX := true
AERA_ENABLE_ALL_PARTITION_TOOLS := true
AERA_USE_DMCTL := true
AERA_DEFAULT_TIMEZONE := Asia/Shanghai

# ─── Vendor modules (Novatek NT36523 touch + battery + full dependency chain) ───
# ─── Vendor modules (从原厂 vendor ramdisk 提取, 共 309 个 ko) ───
AERA_LOAD_VENDOR_MODULES := "adsp_sleepmon.ko altmode-glink.ko arm_smmu.ko arm_smmu_pmu.ko bam_dma.ko bcl_pmic5.ko bcl_soc.ko boot_stats.ko bwmon.ko cambistmclkcc-canoe.ko camcc-alor.ko camcc-canoe.ko cdsprm.ko cfg80211.ko charger-ulog-glink.ko clk-dummy.ko clk-qcom.ko clk-rpmh.ko clk-scmi.ko cmd-db.ko coresight-csr.ko coresight-cti.ko coresight-dummy.ko coresight-funnel.ko coresight-qmi.ko coresight-remote-etm.ko coresight-replicator.ko coresight-stm.ko coresight-tgu.ko coresight-tmc-sec.ko coresight-tmc.ko coresight-tpda.ko coresight-tpdm.ko coresight-trace-noc.ko coresight-uetm.ko coresight.ko cpu_hotplug.ko cpu_mpam.ko cpucp_fast.ko cpucp_log.ko cpuss_telemetry.ko cqhci.ko crm-v2.ko dcc_v2.ko dcvs_fp.ko ddr_cdev.ko debug-regulator.ko debug_symbol.ko debugcc-alor.ko debugcc-canoe.ko deferred-free-helper.ko dispcc-canoe.ko dmesg_dumper.ko drm_display_helper.ko dwc3-msm.ko eom_driver.ko er.ko eud.ko evacc-canoe.ko extend_reclaim.ko f_fs_ipc_log.ko freq_cdev.ko fsa4480_i2c.ko fsa4480_sub_i2c.ko gcc-alor.ko gcc-canoe.ko gdsc-regulator.ko gh_arm_drv.ko gh_ctrl.ko gh_dbl.ko gh_irq_lend.ko gh_mem_notifier.ko gh_msgq.ko gh_panic_notifier.ko gh_rm_booster.ko gh_rm_drv.ko gh_rm_heap_manager.ko gh_tlmm_vm_mem_access.ko gh_vcpu_mgr.ko gic_intr_routing.ko glink_pkt.ko glink_probe.ko governor_gpubw_mon.ko governor_msm_adreno_ro.ko governor_msm_adreno_tz.ko gpucc-canoe.ko gunyah_trace.ko haptic.ko hdcp_qseecom_dlkm.ko heap_mem_ext_v01.ko hq_ptn3222_repeater.ko hqsysfs.ko hung_task_enh.ko hvc_gunyah.ko hwmon.ko i2c-msm-geni.ko i2c-qcom-geni.ko i3c-master-msm-geni.ko icc-bcm-voter.ko icc-clk.ko icc-debug.ko icc-rpmh.ko iommu-logger.ko ipclite.ko leds-aw22xxx.ko leds-qcom-flash.ko leds-qcom-lpg.ko leds-qpnp-vibrator-ldo.ko ledtrig-pattern.ko lenovo_kallsyms.ko llcc-qcom.ko llcc_heuristics.ko lmh_stats.ko lt9611uxc.ko mac80211.ko mdt_loader.ko mem-hooks.ko mem-offline.ko mem-prot.ko mem_buf.ko mem_buf_dev.ko mem_buf_msgq.ko mem_object.ko memlat.ko memory_dump_v2.ko mhi.ko mhi_dev_satellite.ko mhi_dev_uci.ko microdump_collector.ko minidump.ko mpam.ko mpam_msc.ko mpam_msc_slc.ko msm-mmrm.ko msm_dma_iommu_mapping.ko msm_drm.ko msm_ext_display.ko msm_geni_serial.ko msm_gpi.ko msm_hfi_core.ko msm_hw_fence.ko msm_memshare.ko msm_performance.ko msm_qmp.ko msm_sharedmem.ko msm_show_epoch.ko msm_show_resume_irq.ko msm_sysstats.ko nb7vpq904m.ko nvmem_qcom-spmi-sdam.ko nvmem_qfprom.ko nvt_36xxx.ko panel_event_notifier.ko pci-msm-drv.ko pci_phy_access.ko pcie-pdc.ko pdr_interface.ko phy-generic.ko phy-msm-m31-eusb2.ko phy-msm-ssusb-qmp.ko phy-qcom-emu.ko phy-qcom-eusb2-repeater.ko phy-qcom-m31-eusb2.ko phy-qcom-qmp-combo.ko phy-qcom-ufs-qmp-v4-canoe.ko phy-qcom-ufs-qrbtc-sdm845.ko phy-qcom-ufs.ko pinctrl-alor.ko pinctrl-canoe.ko pinctrl-chora.ko pinctrl-msm.ko pinctrl-spmi-gpio.ko pinctrl-spmi-mpp.ko platform_mpam.ko pm8941-pwrkey.ko pmic-glink-debug.ko pmic-pon-log.ko proxy-consumer.ko qcom-amoled-regulator.ko qcom-dcvs.ko qcom-dload-mode.ko qcom-hv-haptics.ko qcom-i2c-pmic.ko qcom-ipcc.ko qcom-pdc.ko qcom-pmic-ecid.ko qcom-pmu-lib.ko qcom-pon.ko qcom-reboot-reason.ko qcom-rng.ko qcom-scm.ko qcom-spmi-adc5-gen3.ko qcom-spmi-pmic.ko qcom-spmi-temp-alarm.ko qcom-vadc-common.ko qcom_aoss.ko qcom_cache_allocation.ko qcom_cpu_vendor_hooks.ko qcom_cpucp.ko qcom_cpuss_sleep_stats_v4.ko qcom_dma_heaps.ko qcom_dynamic_ramoops.ko qcom_edac.ko qcom_fdcvs.ko qcom_glink.ko qcom_glink_smem.ko qcom_glink_spss.ko qcom_hwspinlock.ko qcom_ice.ko qcom_iommu_debug.ko qcom_iommu_util.ko qcom_ipc_logging.ko qcom_llcc_pmu.ko qcom_logbuf_boot_log.ko qcom_logbuf_vendor_hooks.ko qcom_lpm.ko qcom_lpm_monitor.ko qcom_pd_mapper.ko qcom_pdr_msg.ko qcom_pil_info.ko qcom_q6v5.ko qcom_q6v5_pas.ko qcom_ramdump.ko qcom_rpmh.ko qcom_scmi_client.ko qcom_scmi_vendor.ko qcom_sdei.ko qcom_smd.ko qcom_soc_wdt.ko qcom_spss.ko qcom_stats.ko qcom_sysmon.ko qcom_tsens.ko qcom_tzmem.ko qcom_va_minidump.ko qcom_voltage_adj.ko qcom_wdt_core.ko qmi_helpers.ko qnoc-alor.ko qnoc-canoe.ko qti-ocp-notifier.ko qti-regmap-debugfs.ko qti_amoled_ecm.ko qti_battery_charger.ko qti_battery_debug.ko qti_btl.ko qti_cpufreq_cdev.ko qti_pmic_glink.ko qti_power_telemetry.ko qti_ptd_share.ko qti_qmi_cdev.ko qti_qmi_sensor_v2.ko qti_thermal_vendor_hooks.ko qti_userspace_cdev.ko rdbg.ko reboot-m��e.ko repeater-qti-pmic-eusb2.ko repeater.ko rpmh-regulator.ko rproc_qcom_common.ko rtc-pm8xxx.ko sche�-walt.ko sdhci-msm.ko secure_buffer.ko sg.ko si_core_module.ko slc_mpam.ko slc_perfmon.ko slim-qcom-ngd-ctrl.ko slimbus.ko smcinvoke_dlkm.ko smem.ko smmu_proxy_dlkm.ko smp2p.ko smp2p_sleepstate.ko snd-usb-audio-qmi.ko socinfo.ko spi-geni-qcom.ko spi-msm-geni.ko spmi-pmic-arb-debug.ko spmi-pmic-arb.ko spmi-pmic-err-debug.ko sps_drv.ko stm_console.ko stm_core.ko stm_ftrace.ko stm_heartbeat.ko stm_p_ost.ko stub-regulator.ko sync_fence.ko synx-driver.ko sys_pm_vx.ko sysmon_subsystem_stats.ko tcsrcc-canoe.ko thermal_config.ko thermal_pause.ko tmecom-intf_dlkm.ko tz_log_dlkm.ko ucsi_qti_glink.ko ufs-qcom.ko ufshcd-crypto-qti.ko usb_f_ccid.ko usb_f_cdev.ko usb_f_gsi.ko usb_f_qdss.ko usb_f_rndis.ko videocc-canoe.ko zram.ko zsmalloc.ko"
AERA_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
AERA_LOAD_PREBUILT_MODULES_AT_FIRST := true

# WiFi/BT modules loaded after FBE decrypt (per official pattern)
AERA_POST_DECRYPT_MODULES := "smem-mailbox.ko cnss_prealloc.ko cnss_utils.ko cnss_plat_ipc_qmi_svc.ko cnss_nl.ko qmi_helpers.ko qcom_pdr_msg.ko pdr_interface.ko rproc_qcom_common.ko spi_cnss_proto.ko rfkill.ko cfg80211.ko gsim.ko wlan_firmware_service.ko cnss2.ko icnss2.ko qca_cld3_wcn7750.ko rmnet_mem.ko rmnet_ctl.ko rmnet_core.ko rmnet_wlan.ko ipam.ko btfmcodec.ko btpower.ko bt_fm_swr.ko lpass_bt_swr_dlkm.ko machine_dlkm.ko"

# Input blacklist (exclude unwanted input devices)
AERA_INPUT_BLACKLIST := "hbtp_vm:qcom-hv-haptics"

# Support haptics feedback
AERA_SUPPORT_INPUT_FF_HAPTICS := true
AERA_SUPPORT_INPUT_AIDL_HAPTICS := true
AERA_LOAD_VENDOR_BOOT_MODULES := true
AERA_NO_LEGACY_PROPS := true

# Battery (AERA defaults to /sys/class/power_supply/battery; align with myron — no custom vars)
AERA_BATTERY_SYSFS_WAIT_SECONDS := 5

# USB
AERA_EXCLUDE_DEFAULT_USB_INIT := true
TARGET_RECOVERY_USB_VENDOR_ID := 0x22b8
TARGET_RECOVERY_USB_PRODUCT_ID_ADB := 0x2e81
TARGET_RECOVERY_USB_PRODUCT_ID_FASTBOOT := 0x2e80

# ─── Misc ───
TARGET_USES_LOGD := true
AERA_INCLUDE_LOGCAT := true
AERA_EXCLUDE_APEX := true
AERA_HAS_EDL_MODE := false
AERA_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
AERA_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone45/temp"
AERA_EXTRA_LANGUAGES := true
AERA_DEFAULT_LANGUAGE := zh-CN
AERA_DEVICE_VERSION := LENOVO_Y700_TB323FU
AERA_INCLUDE_OMAPI := true
HAVE_SELINUX := true
RECOVERY_GRAPHICS_USE_LINELENGTH := true
