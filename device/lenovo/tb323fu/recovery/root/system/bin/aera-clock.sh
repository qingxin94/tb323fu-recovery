#!/system/bin/sh
# Set the recovery system clock from the real persist time offset.
#
# This matches the Skyward/QCOM layout:
#   /persist/time/ats_2        8-byte little-endian milliseconds
#   /sys/class/rtc/rtc0/since_epoch  RTC seconds
#   real time = rtc_seconds + ats_2 / 1000
#
# AERA's TWFunc::Fixup_Time_On_Boot("/persist/time/") does the same thing
# through settimeofday when the persist partition is processed.  This script is
# an explicit fallback/verification for the device tree and never depends on
# /data being decrypted.
#
set -u

LOG=/tmp/aera-clock.log
ATS=/persist/time/ats_2
RTC=/sys/class/rtc/rtc0/since_epoch
: > "$LOG" 2>/dev/null || true

log() { echo "$*" >> "$LOG" 2>/dev/null || true; }

i=0
while [ ! -f "$ATS" ] && [ "$i" -lt 10 ]; do
    sleep 1
    i=$((i + 1))
done

if [ ! -f "$ATS" ]; then
    log "missing $ATS"
    exit 1
fi
if [ ! -f "$RTC" ]; then
    log "missing $RTC"
    exit 1
fi

# Read 8 bytes as little-endian uint64 without relying on od's endianness.
set -- $(od -An -tx1 -v "$ATS" 2>/dev/null)
if [ "$#" -lt 8 ]; then
    log "short ats_2 file"
    exit 1
fi
b1=$1; b2=$2; b3=$3; b4=$4; b5=$5; b6=$6; b7=$7; b8=$8
offset=$((0x$b1 + (0x$b2 << 8) + (0x$b3 << 16) + (0x$b4 << 24) + \
          (0x$b5 << 32) + (0x$b6 << 40) + (0x$b7 << 48) + (0x$b8 << 56)))

rtc_s="$(cat "$RTC" 2>/dev/null | tr -d '[:space:]')"
case "$rtc_s" in
    ''|*[!0-9]*) log "bad rtc value: $rtc_s"; exit 1 ;;
esac

epoch_s=$((rtc_s + offset / 1000))
log "rtc=$rtc_s ats2_ms=$offset epoch=$epoch_s"

# Toybox date accepts -s.  Try @epoch first, then an explicit UTC string.
if date -u -s "@$epoch_s" >>"$LOG" 2>&1; then
    setprop aera.clock.set true
    log "clock set from ats_2"
    exit 0
fi
date_string="$(date -u -d "@$epoch_s" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
if [ -n "$date_string" ] && date -u -s "$date_string" >>"$LOG" 2>&1; then
    setprop aera.clock.set true
    log "clock set from formatted epoch"
    exit 0
fi

log "could not set clock; AERA Fixup_Time may already have done it"
exit 1
