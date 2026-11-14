#!/system/bin/sh
# Probe PAL stream types without rebuilding: run several tunnel candidates and
# report which one gets past tinyalsa pcm_plug_open.
# Usage: sh /system/bin/aera-pal-probe.sh [/tmp/aera-tone.raw]
TONE="${1:-/tmp/aera-tone.raw}"
[ -f "$TONE" ] || TONE=/tmp/tone.raw
FIFO=/tmp/aera-pal-probe.fifo
OUT=/tmp/aera-pal-probe.out
BIN=/system/bin/aera-palplayer
[ -x "$BIN" ] || { echo "missing $BIN"; exit 1; }
[ -f "$TONE" ] || { echo "missing $TONE (need raw S16LE 48k stereo)"; exit 1; }
export LD_LIBRARY_PATH=/AERA/audio/abi:/AERA/audio/lib64:/vendor/lib64:/system/lib64
: > "$OUT"
for stream_type in 13 12 11 0 16 21 24 1; do
  echo "===== stream-type $stream_type =====" >> "$OUT"
  rm -f "$FIFO"
  mkfifo "$FIFO" 2>/dev/null
  ( cat "$TONE" > "$FIFO" 2>/dev/null ) &
  writer=$!
  timeout 6 "$BIN" --fifo "$FIFO" --stream-type "$stream_type" \
      >> "$OUT" 2>&1
  rc=$?
  echo "rc=$rc" >> "$OUT"
  kill "$writer" 2>/dev/null
  wait "$writer" 2>/dev/null
  rm -f "$FIFO"
done
cat "$OUT"
