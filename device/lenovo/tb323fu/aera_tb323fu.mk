#
# AERA Recovery R1.0 product configuration for the Lenovo Legion Y700 Gen 5 (TB323FU)
#
# Mirrors the structure of the official AERA device trees (aera_<device>.mk):
# AERA_* product-level behaviour switches, inherited from device.mk.
#
AERA_MAINTAINER := 自恋也是种美 @DeepSeek V4.1 Flash 1017

# Display: 8.8" panel is 3040x1904 native; recovery UI is portrait 1904x3040.
# AERA_SCREEN_H is NOT the physical panel height. AERA UI converts it to its
# 1440-wide logical canvas with logical_height = AERA_SCREEN_H * 4 / 3
# (aeraui/include/aeraui/runner.hpp, DisplayMetrics::FromThemeMetrics), i.e.
# AERA_SCREEN_H is expressed in the stock theme's 1080-wide reference space.
# The AERA scenes are laid out for a 1440x3168 canvas. Batch3-R1 deliberately
# uses 2280 instead of 3168 * 1080 / 1440 = 2376: this yields the 1440x3040
# logical canvas whose height equals the physical panel height, so
# DisplayTransform::Adaptive picks scale = 1000/1000 and the UI is composited
# 1:1 (zero resampling). The 232 px side bands are filled with the page
# background by the Batch2 engine patch. True full-width 1904x3040 rendering
# (R2) still requires a horizontal reflow of the scene layouts; see
# research/native-resolution-plan.md.
AERA_SCREEN_H := 2280
AERA_STATUS_H := 114
AERA_STATUS_ICONS_ALIGN := center
AERA_OPTIONS_LIST_NUM := 6
AERA_USE_GREEN_LED := 0

AERA_ENABLE_ALL_PARTITION_TOOLS := 1
AERA_WORKAROUND_BACKUP_BUG := 1
AERA_USE_AIDL_BOOT_CONTROL := 1
AERA_FORCE_DATA_FORMAT_F2FS := 1
AERA_UNBIND_SDCARD_F2FS := 1
AERA_WIPE_METADATA_AFTER_DATAFORMAT := 1
# BOARD_QTI_DYNAMIC_PARTITIONS_SIZE (21470642176) from BoardConfig.mk.
AERA_DYNAMIC_FULL_SIZE := 21470642176
AERA_DISPLAY_FORMAT_FILESYSTEMS_DEBUG_INFO := 1
AERA_NO_RELOAD_AFTER_DECRYPTION := 1
AERA_NO_TREBLE_COMPATIBILITY_CHECK := 1
AERA_AB_DEVICE_WITH_RECOVERY_PARTITION := 1
AERA_USE_LZ4_COMPRESSION := 1
# Recovery-side WLAN: stock WCN786x (peach v2) driver modules are staged under
# recovery/root/AERA/modules/wlan (extracted from the stock vendor_dlkm) and loaded
# on demand by recovery/root/system/bin/aera-wlan-up.sh.
AERA_ENABLE_WLAN := 1
#

# Feature switches (AERA R1.0): Root Manager (KSU/SukiSU assets), EFISP, ABL preservation
# 与验证树原值一致：开启 Root Manager，root-providers 资产已随包（5.37 MB），
# 镜像压缩后仍在 104857600 以内；不做任何功能裁剪。
AERA_ENABLE_ROOT_MANAGER := 1
AERA_ROOT_MODULE_KERNELS := 6.12
AERA_ENABLE_EFISP := 1
AERA_ENABLE_ABL_PRESERVATION := 1

# Build branch label for the recovery banner (the source tree has no .git metadata,
# so bootable/recovery/aera_build.mk falls back to this instead of "broken repo").
AERA_CURRENT_BRANCH := aera-16.0
