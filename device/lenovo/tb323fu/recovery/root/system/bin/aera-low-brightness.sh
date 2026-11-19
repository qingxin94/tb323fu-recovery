#!/system/bin/sh
/system/bin/toybox sleep 20
echo 300 > /sys/class/backlight/panel0-backlight/brightness
