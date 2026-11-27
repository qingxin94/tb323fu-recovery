#!/system/bin/sh
# Ensure the vendor binder context manager is the stock A16 vendor-domain
# binary.  The stock AGM/PAL libraries write VNDR parcels; recovery's
# system-domain vndservicemanager answers with SYST parcels, which produces
# BAD_TYPE and then "not declared in VINTF".
# The recovery vndservicemanager is no longer started on init; this script
# starts the stock /vendor/bin/vndservicemanager after /vendor is mounted.
set -u
PATH=/system/bin:/vendor/bin
export PATH
LOG=/tmp/aera-vnd.log
exec >>"$LOG" 2>&1
echo "=== aera-vnd-switch $(date 2>/dev/null)"

if [ "$(getprop aera.vnd.ready)" = "1" ]; then
    echo "already vendor-domain"
    exit 0
fi

if [ ! -x /vendor/bin/vndservicemanager ]; then
    echo "missing stock /vendor/bin/vndservicemanager"
    start vndservicemanager
    exit 1
fi

if [ "$(getprop init.svc.aera-vndservicemanager)" != "running" ]; then
    start aera-vndservicemanager
fi

i=0
while [ "$(getprop init.svc.aera-vndservicemanager)" != "running" ] && [ "$i" -lt 50 ]; do
    i=$((i + 1))
    sleep 0.1
done

if [ "$(getprop init.svc.aera-vndservicemanager)" != "running" ]; then
    echo "stock vendor vndservicemanager failed; restoring recovery one"
    start vndservicemanager
    exit 1
fi

setprop aera.vnd.ready 1
echo "vendor-domain vndservicemanager ready"
