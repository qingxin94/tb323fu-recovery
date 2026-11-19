#!/system/bin/sh
# Read-only check of the Android 16 FBE protector location for user 0.
#
# TB323FU stores the user-0 protector in:
#   /data/system_de/0/spblob/
# It does NOT use /data/system/users/0/gatekeeper.password.key on this build.
# This script only logs; it never copies or modifies the protector.
#
set -u

LOG=/tmp/aera-spblob.log
: > "$LOG" 2>/dev/null || true
log() { echo "$*" >> "$LOG" 2>/dev/null || true; }

i=0
while [ ! -d /data/system_de/0/spblob ] && [ "$i" -lt 10 ]; do
    sleep 1
    i=$((i + 1))
done

if [ -d /data/system_de/0/spblob ]; then
    log "found /data/system_de/0/spblob"
    for f in /data/system_de/0/spblob/*; do
        [ -e "$f" ] || continue
        log "  $(basename "$f") $(wc -c < "$f" 2>/dev/null) bytes"
    done
    setprop aera.spblob.present true
else
    log "missing /data/system_de/0/spblob"
    setprop aera.spblob.present false
fi

if [ -e /data/system/users/0/gatekeeper.password.key ]; then
    log "unexpected legacy gatekeeper.password.key present"
else
    log "legacy gatekeeper.password.key absent (expected on this build)"
fi

exit 0
