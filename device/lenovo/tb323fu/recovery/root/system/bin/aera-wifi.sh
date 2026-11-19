#!/system/bin/sh
# On-demand WiFi chain for TB323FU recovery.
# Trigger: setprop sys.aera.wifi.load 1

LOG=/tmp/aera-wifi.log
exec >>"$LOG" 2>&1
echo "=== aera-wifi $(date 2>/dev/null)"

mkdir -p /tmp/recovery/sockets /tmp/recovery/wifi 2>/dev/null || true
chmod 0777 /tmp/recovery /tmp/recovery/sockets 2>/dev/null || true

/system/bin/aera-load-wifi-modules.sh

# Stock WCN7750 station stack.
start vendor.cnss-daemon
start vendor.wifi_hal_legacy
start wpa_supplicant
start wifi_qos_daemon

for i in $(seq 1 15); do
    [ "$(getprop init.svc.vendor.wifi_hal_legacy)" = "running" ] && break
    sleep 1
done

echo "wifi: hal=$(getprop init.svc.vendor.wifi_hal_legacy) supplicant=$(getprop init.svc.wpa_supplicant) cnss=$(getprop init.svc.vendor.cnss-daemon)"
setprop aera.wifi.loaded true
echo "=== wifi done"
