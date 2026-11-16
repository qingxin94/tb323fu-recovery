#!/bin/bash
#
# Extract the minimal vendor blobs needed by AERA from the stock TB323FU
# firmware images. Nothing here is a kernel module: vendor .ko files always
# stay on the device's /vendor_dlkm and are loaded from there at runtime.
#
# Usage:
#   tools/extract_stock_blobs.sh [vendor.img] [device-tree-root]
#
set -u

VENDOR_IMG="${1:-/home/user/Doubao/chats/38454134509658626/aera-src/work/lp_full/vendor_a.img}"
OUT="${2:-$(cd "$(dirname "$0")/.." && pwd)}"

if [ ! -f "$VENDOR_IMG" ]; then
    echo "vendor image not found: $VENDOR_IMG" >&2
    exit 1
fi
if ! command -v debugfs >/dev/null 2>&1; then
    echo "debugfs (e2fsprogs) is required" >&2
    exit 1
fi

dump_one() {
    local src="$1" dst="$2"
    local target="$OUT/recovery/root/$dst"
    mkdir -p "$(dirname "$target")"
    rm -f "$target"
    if debugfs -R "dump $src $target" "$VENDOR_IMG" >/dev/null 2>&1 && [ -s "$target" ]; then
        # debugfs does not preserve the stock executable bit on all hosts.
        # HAL binaries and daemons must remain executable inside the ramdisk.
        case "$dst" in
            vendor/bin/*) chmod 0755 "$target" ;;
        esac
        printf '  %-58s -> %s\n' "$src" "$dst"
    else
        rm -f "$target"
        printf '  %-58s    (missing, skipped)\n' "$src"
    fi
}

echo "Extracting AERA vendor blobs"
echo "  source: $VENDOR_IMG"
echo "  output: $OUT/recovery/root"

# Adreno 840 / KGSL userspace
dump_one /lib64/egl/libEGL_adreno.so              vendor/lib64/egl/libEGL_adreno.so
dump_one /lib64/egl/libGLESv1_CM_adreno.so        vendor/lib64/egl/libGLESv1_CM_adreno.so
dump_one /lib64/egl/libGLESv2_adreno.so           vendor/lib64/egl/libGLESv2_adreno.so
dump_one /lib64/egl/eglSubDriverAndroid.so        vendor/lib64/egl/eglSubDriverAndroid.so
dump_one /lib64/egl/libq3dtools_adreno.so         vendor/lib64/egl/libq3dtools_adreno.so
dump_one /lib64/egl/libq3dtools_esx.so            vendor/lib64/egl/libq3dtools_esx.so
dump_one /lib64/libllvm-qgl.so                    vendor/lib64/libllvm-qgl.so
dump_one /lib64/libllvm-glnext.so                 vendor/lib64/libllvm-glnext.so
dump_one /lib64/libadreno_utils.so                vendor/lib64/libadreno_utils.so
dump_one /lib64/vendor.qti.hardware.hexlp-V2-ndk.so vendor/lib64/vendor.qti.hardware.hexlp-V2-ndk.so
dump_one /lib64/libgsl.so                         vendor/lib64/libgsl.so
dump_one /lib64/libgralloccore.so                 vendor/lib64/libgralloccore.so
dump_one /lib64/libgralloc.qti.so                 vendor/lib64/libgralloc.qti.so
dump_one /lib64/libgralloctypes.so                vendor/lib64/libgralloctypes.so
dump_one /lib64/libgrallocutils.so                vendor/lib64/libgrallocutils.so
dump_one /lib64/libmapperutils.so                 vendor/lib64/libmapperutils.so
dump_one /lib64/libdmabufheap.so                  vendor/lib64/libdmabufheap.so
dump_one /lib64/android.hardware.graphics.allocator@4.0.so   vendor/lib64/android.hardware.graphics.allocator@4.0.so
dump_one /lib64/android.hardware.graphics.allocator-V2-ndk.so vendor/lib64/android.hardware.graphics.allocator-V2-ndk.so
dump_one /lib64/android.hardware.graphics.mapper@4.0.so      vendor/lib64/android.hardware.graphics.mapper@4.0.so
dump_one /lib64/android.hardware.common-V2-ndk.so            vendor/lib64/android.hardware.common-V2-ndk.so
dump_one /lib64/android.hardware.graphics.common-V6-ndk.so   vendor/lib64/android.hardware.graphics.common-V6-ndk.so
dump_one /lib64/android.hardware.graphics.common@1.0.so      vendor/lib64/android.hardware.graphics.common@1.0.so
dump_one /lib64/android.hardware.graphics.common@1.1.so      vendor/lib64/android.hardware.graphics.common@1.1.so
dump_one /lib64/android.hardware.graphics.common@1.2.so      vendor/lib64/android.hardware.graphics.common@1.2.so
dump_one /lib64/android.hardware.graphics.common-V5-ndk.so   vendor/lib64/android.hardware.graphics.common-V5-ndk.so
dump_one /lib64/vendor.qti.hardware.display.config-V7-ndk.so vendor/lib64/vendor.qti.hardware.display.config-V7-ndk.so
dump_one /lib64/vendor.qti.hardware.display.mapper@4.0.so    vendor/lib64/vendor.qti.hardware.display.mapper@4.0.so
dump_one /lib64/vendor.qti.hardware.display.snapalloc-impl.so vendor/lib64/vendor.qti.hardware.display.snapalloc-impl.so
dump_one /lib64/libminkdescriptor.so                vendor/lib64/libminkdescriptor.so
dump_one /lib64/libjsoncpp.so                      vendor/lib64/libjsoncpp.so
dump_one /lib64/libutilscallstack.so               vendor/lib64/libutilscallstack.so
dump_one /lib64/vendor.qti.hardware.display.mapper@3.0.so vendor/lib64/vendor.qti.hardware.display.mapper@3.0.so
dump_one /lib64/vendor.qti.hardware.display.mapperextensions@1.0.so vendor/lib64/vendor.qti.hardware.display.mapperextensions@1.0.so
dump_one /lib64/vendor.qti.hardware.display.mapperextensions@1.1.so vendor/lib64/vendor.qti.hardware.display.mapperextensions@1.1.so
dump_one /lib64/vendor.qti.hardware.display.mapperextensions@1.2.so vendor/lib64/vendor.qti.hardware.display.mapperextensions@1.2.so
dump_one /lib64/vendor.qti.hardware.display.mapperextensions@1.3.so vendor/lib64/vendor.qti.hardware.display.mapperextensions@1.3.so
dump_one /lib64/android.hardware.graphics.mapper@2.0.so vendor/lib64/android.hardware.graphics.mapper@2.0.so
dump_one /lib64/android.hardware.graphics.mapper@3.0.so vendor/lib64/android.hardware.graphics.mapper@3.0.so
dump_one /lib64/libvmmem.so                         vendor/lib64/libvmmem.so
dump_one /lib64/libqcbor.so                         vendor/lib64/libqcbor.so
dump_one /lib64/libxml2.so                          vendor/lib64/libxml2.so
dump_one /lib64/vendor.qti.hardware.display.mapper@2.0.so vendor/lib64/vendor.qti.hardware.display.mapper@2.0.so
dump_one /lib64/android.hardware.graphics.mapper@2.1.so vendor/lib64/android.hardware.graphics.mapper@2.1.so
dump_one /lib64/hw/android.hardware.graphics.mapper@4.0-impl-qti-display.so vendor/lib64/hw/android.hardware.graphics.mapper@4.0-impl-qti-display.so
dump_one /lib64/hw/mapper.qti.so                  vendor/lib64/hw/mapper.qti.so
dump_one /lib64/hw/gralloc.default.so             vendor/lib64/hw/gralloc.default.so

# GPU / touch firmware
dump_one /firmware/gen80000_aqe.fw                vendor/firmware/gen80000_aqe.fw
dump_one /firmware/gen80000_gmu.bin               vendor/firmware/gen80000_gmu.bin
dump_one /firmware/gen80000_sqe.fw                vendor/firmware/gen80000_sqe.fw
dump_one /firmware/gen80000_zap.mbn               vendor/firmware/gen80000_zap.mbn
dump_one /firmware/novatek_ts_fw.bin              vendor/firmware/novatek_ts_fw.bin
dump_one /firmware/novatek_ts_mp.bin              vendor/firmware/novatek_ts_mp.bin

# Panel calibration for baldur_nt36523_csot_3k_dsc_vid
dump_one /etc/display/panel_baldur_nt36523_csot_3k_dsc_vid_C3D_cali_p3.txt   vendor/etc/display/panel_baldur_nt36523_csot_3k_dsc_vid_C3D_cali_p3.txt
dump_one /etc/display/panel_baldur_nt36523_csot_3k_dsc_vid_C3D_cali_srgb.txt vendor/etc/display/panel_baldur_nt36523_csot_3k_dsc_vid_C3D_cali_srgb.txt
dump_one /etc/display/qdcm_calib_data_nt36523_3k_fhd_plus_165Hz_DPHY_video_panel.json vendor/etc/display/qdcm_calib_data_nt36523_3k_fhd_plus_165Hz_DPHY_video_panel.json

# Display allocation format metadata
dump_one /etc/display/formats.json                 vendor/etc/display/formats.json
dump_one /etc/display/display_alignments.json      vendor/etc/display/display_alignments.json
dump_one /etc/display/gralloc_alignments.json      vendor/etc/display/gralloc_alignments.json

# Display / gatekeeper / keymint HALs
dump_one /bin/hw/vendor.qti.hardware.display.allocator-service       vendor/bin/hw/vendor.qti.hardware.display.allocator-service
dump_one /bin/hw/android.hardware.gatekeeper-rust-service-qti        vendor/bin/hw/android.hardware.gatekeeper-rust-service-qti
dump_one /bin/hw/android.hardware.security.onekeymint-service-qti    vendor/bin/hw/android.hardware.security.onekeymint-service-qti
dump_one /bin/qseecomd                             vendor/bin/qseecomd
dump_one /bin/ssgqmigd                             vendor/bin/ssgqmigd
dump_one /bin/ssgqmigd64                           vendor/bin/ssgqmigd64

# Fastbootd AIDL bootcontrol HAL (AERA_USE_AIDL_BOOT_CONTROL)
dump_one /bin/hw/android.hardware.boot-service.qti vendor/bin/hw/android.hardware.boot-service.qti
for lib in android.hardware.boot-V1-ndk.so android.hardware.boot@1.0.so \
           android.hardware.boot@1.1.so libboot_control_qti.so libion.so \
           librecovery_updater.so; do
    dump_one "/lib64/$lib" "vendor/lib64/$lib"
done

# Crypto / keymaster closure
for lib in libQSEEComAPI.so libdiag.so libgpt.so libdrmfs.so libdrmtime.so \
           libssd.so libseclog.so libtime_genoff.so libxml.so libgatekeeper.so \
           libkeymasterdeviceutils.so libkeymasterutils.so libGPTEE_vendor.so \
           libGPMTEEC_vendor.so libGPQeSE.so libtaautoload.so; do
    dump_one "/lib64/$lib" "vendor/lib64/$lib"
done
dump_one /lib64/hw/libqtigatekeeper.so             vendor/lib64/hw/libqtigatekeeper.so

# Wi-Fi configuration (module loading itself happens after decryption)
dump_one /etc/wifi/wpa_supplicant.conf              vendor/etc/wifi/wpa_supplicant.conf
dump_one /etc/wifi/wpa_supplicant_overlay.conf      vendor/etc/wifi/wpa_supplicant_overlay.conf
dump_one /etc/wifi/p2p_supplicant_overlay.conf      vendor/etc/wifi/p2p_supplicant_overlay.conf
dump_one /etc/wifi/vendor_cmd.xml                   vendor/etc/wifi/vendor_cmd.xml
dump_one /etc/wifi/sar-vendor-cmd.xml               vendor/etc/wifi/sar-vendor-cmd.xml
dump_one /etc/wifi/peach_v2/WCNSS_qcom_cfg.ini      vendor/etc/wifi/peach_v2/WCNSS_qcom_cfg.ini
dump_one /firmware/wlan/qca_cld/peach_v2/WCNSS_qcom_cfg.ini vendor/firmware/wlan/qca_cld/peach_v2/WCNSS_qcom_cfg.ini
dump_one /firmware/wlan/qca_cld/peach_v2/wlan_mac.bin      vendor/firmware/wlan/qca_cld/peach_v2/wlan_mac.bin

# Vendor uevent rules (kgsl, display, touch permissions)
dump_one /etc/ueventd.rc                            vendor/etc/ueventd.rc

echo "Done. Review sizes with: du -sh $OUT/recovery/root/vendor"
