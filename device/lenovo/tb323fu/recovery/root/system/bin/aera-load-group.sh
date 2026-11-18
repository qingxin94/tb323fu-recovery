#!/system/bin/sh
# Load one explicit kernel-module group from the real vendor_dlkm/system_dlkm.
#
# Usage: aera-load-group.sh base|wifi|audio|haptics
#
# Design:
#   - no module is copied to /tmp or into the recovery ramdisk
#   - the group manifest is a small list of top-level modules
#   - dependencies are read from the real modules.dep and loaded first
#   - every insmod uses the real path found under /vendor_dlkm or /system_dlkm
#   - a group is never started at boot unless init explicitly starts it
#
set -u

GROUP="${1:-}"
[ -n "$GROUP" ] || exit 1

PATH=/system/bin:/vendor/bin
export PATH

LIST="/system/etc/aera-modules/${GROUP}.list"
FALLBACK="/system/etc/aera-modules/${GROUP}.fallback"
LOG="/tmp/aera-modules-${GROUP}.log"
SEEN="/tmp/aera-modules-${GROUP}.seen"
: > "$LOG" 2>/dev/null || true
: > "$SEEN" 2>/dev/null || true

log() { echo "$*" >> "$LOG" 2>/dev/null || true; }

prop_for_group() {
    case "$1" in
        base) echo aera.base.loaded ;;
        wifi) echo aera.wifi.loaded ;;
        audio) echo aera.audio.loaded ;;
        haptics) echo aera.haptics.loaded ;;
        *) echo "" ;;
    esac
}

normalize() {
    echo "$1" | tr '-' '_' | sed 's/\.ko$//'
}

is_loaded() {
    name="$(normalize "$1")"
    grep -q "^${name} " /proc/modules 2>/dev/null
}

mark_seen() {
    name="$(normalize "$1")"
    grep -qx "$name" "$SEEN" 2>/dev/null || echo "$name" >> "$SEEN"
}

was_seen() {
    name="$(normalize "$1")"
    grep -qx "$name" "$SEEN" 2>/dev/null
}

# Find the actual file for a module name.  Search direct paths first, then
# one level of versioned subdirectories, then a bounded recursive search.
find_module_file() {
    wanted="$1"
    case "$wanted" in
        *.ko) ;;
        *) wanted="${wanted}.ko" ;;
    esac
    # Kernel module names use both '-' and '_' in the stock images.  Try both
    # spellings before giving up.
    alt="$(echo "$wanted" | tr '_' '-')"
    alt2="$(echo "$wanted" | tr '-' '_')"
    for base in /vendor_dlkm/lib/modules /system_dlkm/lib/modules /vendor/lib/modules /lib/modules; do
        [ -d "$base" ] || continue
        for candidate in "$wanted" "$alt" "$alt2"; do
            [ -f "$base/$candidate" ] && { echo "$base/$candidate"; return 0; }
            for sub in "$base"/*; do
                [ -d "$sub" ] || continue
                [ -f "$sub/$candidate" ] && { echo "$sub/$candidate"; return 0; }
            done
            found="$(find "$base" -maxdepth 4 -type f -name "$candidate" 2>/dev/null | head -n 1)"
            [ -n "$found" ] && { echo "$found"; return 0; }
        done
    done
    return 1
}

# Find modules.dep on the real partitions.  Return its directory so relative
# dependency paths can be resolved.
find_dep_file() {
    for base in /vendor_dlkm/lib/modules /system_dlkm/lib/modules; do
        [ -d "$base" ] || continue
        [ -f "$base/modules.dep" ] && { echo "$base/modules.dep"; return 0; }
        found="$(find "$base" -maxdepth 3 -type f -name modules.dep 2>/dev/null | head -n 1)"
        [ -n "$found" ] && { echo "$found"; return 0; }
    done
    return 1
}

DEP_FILE="$(find_dep_file || true)"
DEP_DIR=""
[ -n "${DEP_FILE:-}" ] && DEP_DIR="$(dirname "$DEP_FILE")"

# Print dependency basenames for a module, from modules.dep.
# Pure shell: no awk dependency in recovery.
deps_of() {
    want="$(normalize "$1")"
    [ -n "${DEP_FILE:-}" ] && [ -f "$DEP_FILE" ] || return 0
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        path="${line%%:*}"
        base="${path##*/}"
        base="${base%.ko}"
        base="$(normalize "$base")"
        [ "$base" = "$want" ] || continue
        deps="${line#*:}"
        for dep in $deps; do
            [ -n "$dep" ] || continue
            depbase="${dep##*/}"
            depbase="${dep%.ko}"
            [ -n "$depbase" ] && echo "$depbase"
        done
    done < "$DEP_FILE" 2>/dev/null
}

load_one() {
    mod="$1"
    name="$(normalize "$mod")"
    is_loaded "$name" && { log "already loaded: $name"; return 0; }
    was_seen "$name" && { log "seen already: $name"; return 0; }
    mark_seen "$name"

    # Load dependencies first.  They are looked up by basename, so versioned
    # module directories and cross-partition dependencies both work.
    for dep in $(deps_of "$name"); do
        load_one "$dep"
    done

    file="$(find_module_file "$mod" || true)"
    if [ -z "${file:-}" ]; then
        log "missing real module: $name"
        return 1
    fi

    log "insmod $file"
    insmod "$file" 2>>"$LOG"
    rc=$?
    if [ "$rc" -eq 0 ] || is_loaded "$name"; then
        log "loaded: $name"
        return 0
    fi
    log "insmod failed ($rc): $name"
    return 1
}

load_list() {
    list="$1"
    [ -f "$list" ] || return 0
    while read -r line; do
        case "$line" in
            ''|'#'*) continue ;;
        esac
        load_one "$line"
    done < "$list"
}

if [ ! -f "$LIST" ]; then
    log "missing group list: $LIST"
    prop="$(prop_for_group "$GROUP")"
    [ -n "$prop" ] && setprop "$prop" true
    exit 1
fi

log "group=$GROUP dep_file=${DEP_FILE:-none}"
load_list "$LIST"

# If modules.dep is unavailable, use the explicit fallback order.  This is
# only a safety net for partitions that omit modules.dep; it is not used on
# the stock TB323FU images.
if [ -z "${DEP_FILE:-}" ] && [ -f "$FALLBACK" ]; then
    log "modules.dep unavailable; using fallback order"
    load_list "$FALLBACK"
fi

prop="$(prop_for_group "$GROUP")"
[ -n "$prop" ] && setprop "$prop" true
log "group $GROUP finished"
exit 0
