#!/system/bin/sh
# Wait for the real Peach WLAN driver to publish wlan0.  The module chain is
# loaded from /vendor_dlkm and /system_dlkm by aera-real-modules.sh; nothing is
# copied into the recovery ramdisk.
#
# This used to be an unbounded "until" loop, which left the WiFi service in
# "running" forever when the driver never appeared and gave the UI no error.
# Bound it, publish wifi.driver.ready on success, and publish an explicit
# failure property otherwise.

PATH=/system/bin:/vendor/bin
export PATH

LOG=/tmp/aera-wlan-ready.log
: > "$LOG" 2>/dev/null || true

i=0
while [ "$i" -lt 60 ]; do
    if [ -e /sys/class/net/wlan0 ]; then
        echo "wlan0 present after ${i}s" >> "$LOG" 2>/dev/null || true
        ifconfig wlan0 up 2>/dev/null || true
        setprop wifi.driver.ready true
        exit 0
    fi
    sleep 1
    i=$((i + 1))
done

echo "wlan0 did not appear within 60s" >> "$LOG" 2>/dev/null || true
setprop aera.wifi.driver.failed true
exit 1
