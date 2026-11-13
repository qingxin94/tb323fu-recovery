add_lunch_combo twrp_tb323fu-eng
add_lunch_combo twrp_tb323fu-userdebug
add_lunch_combo twrp_tb323fu-user

# Guarded per AERA bring-up guidance: only this device's tree may export these.
if [ -n "$AERA_BUILD_DEVICE" ] && [ "$AERA_BUILD_DEVICE" = "tb323fu" ]; then
    export AERA_VIRTUAL_AB_DEVICE=1
    export AERA_USE_DMCTL=1
    export AERA_ENABLE_WLAN=1
    export AERA_MOBILE_DATA_FLAG_SCOPE=0
fi
