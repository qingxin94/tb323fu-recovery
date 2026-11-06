#!/system/bin/sh
# Copyright (C) 2026 AERA Recovery Project contributors
# SPDX-License-Identifier: Apache-2.0

PATH=/system/bin:/sbin
export PATH

report() {
    echo "AERA Wi-Fi: $*" > /dev/kmsg
}

report "waiting for wlan0 after WPSS boot request"
attempt=0
while [ "$attempt" -lt 3000 ]; do
    if [ -e /sys/class/net/wlan0 ]; then
        # Macan's WLAN driver enters its idle shutdown roughly 250 ms after
        # publishing wlan0 when no client has claimed the interface.  Polling
        # once per second therefore starts supplicant after the radio has
        # already begun shutting down.  Claim it within the idle window.
        report "wlan0 appeared after ${attempt} fast polls; requesting supplicant"
        setprop wifi.driver.ready true
        sleep 0.1
        report "supplicant=$(getprop init.svc.wpa_supplicant), operstate=$(cat /sys/class/net/wlan0/operstate 2>/dev/null)"
        exit 0
    fi
    case "$attempt" in
        250|750|1500)
            report "still waiting after ${attempt} fast polls; interfaces: $(ls /sys/class/net)"
            ;;
    esac
    attempt=$((attempt + 1))
    sleep 0.02
done
report "timeout: wlan0 did not appear; interfaces: $(ls /sys/class/net)"
for node in /sys/class/remoteproc/remoteproc*; do
    [ -r "$node/name" ] || continue
    report "remoteproc $(cat "$node/name"): $(cat "$node/state" 2>/dev/null)"
done
exit 1
