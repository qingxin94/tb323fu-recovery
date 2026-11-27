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
#   - the audio group starts automatically after aera-stock-mount.sh sets
#     aera.stock.mounted=true; sys.aera.audio.load=1 remains a manual fallback
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
        v13) echo aera.v13.loaded ;;
        *) echo "" ;;
    esac
}

normalize() {
    local n="${1##*/}"
    n="${n%.ko}"
    case "$n" in
        *-*) n="$(echo "$n" | tr '-' '_')" ;;
    esac
    echo "$n"
}

is_loaded() {
    local n
    n="$(normalize "$1")"
    grep -q "^${n} " /proc/modules 2>/dev/null
}

mark_seen() {
    local n
    n="$(normalize "$1")"
    grep -qx "$n" "$SEEN" 2>/dev/null || echo "$n" >> "$SEEN"
}

was_seen() {
    local n
    n="$(normalize "$1")"
    grep -qx "$n" "$SEEN" 2>/dev/null
}

# Find the actual file for a module name.  Search direct paths first, then
# one level of versioned subdirectories, then a bounded recursive search.
find_module_file() {
    local wanted alt alt2 base candidate sub found
    wanted="${1##*/}"
    case "$wanted" in
        *.ko) ;;
        *) wanted="${wanted}.ko" ;;
    esac
    # Kernel module names use both '-' and '_' in the stock images.  Try both
    # spellings before giving up.
    alt="$(echo "$wanted" | tr '_' '-')"
    alt2="$(echo "$wanted" | tr '-' '_')"
    for base in /vendor_dlkm/lib/modules /system_dlkm/lib/modules /vendor/lib/modules /system/lib/modules /lib/modules; do
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
    local base found
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
    local want line deps dep depbase
    want="$(normalize "$1")"
    [ -n "${DEP_FILE:-}" ] && [ -f "$DEP_FILE" ] || return 0
    # One fixed-string grep beats scanning all 400+ modules.dep lines in
    # shell for every dependency.  The stock file has one line per module.
    line="$(grep -F "/${want}.ko:" "$DEP_FILE" 2>/dev/null | head -n 1 || true)"
    [ -n "$line" ] || return 0
    deps="${line#*:}"
    for dep in $deps; do
        [ -n "$dep" ] || continue
        depbase="${dep##*/}"
        depbase="${depbase%.ko}"
        [ -n "$depbase" ] && echo "$depbase"
    done
}

# Dependency stack guard.  Some stock modules.dep entries contain a self
# dependency (for example q6_pdr_dlkm -> q6_pdr_dlkm).  Without a stack guard,
# load_one() recurses forever, aera.audio.loaded is never set, and the audio
# bootstrap is never started.
LOADING=""

is_loading() {
    case " ${LOADING} " in
        *" $1 "*) return 0 ;;
    esac
    return 1
}

pop_loading() {
    local pname new item
    pname="$1"
    new=""
    for item in $LOADING; do
        [ "$item" = "$pname" ] || new="${new} ${item}"
    done
    LOADING="${new# }"
}

load_one() {
    local mod name file rc dep
    mod="$1"
    name="$(normalize "$mod")"
    is_loaded "$name" && { log "already loaded: $name"; return 0; }
    if is_loading "$name"; then
        log "dependency cycle: $name already on stack; skip recursive load"
        return 0
    fi
    # Do not return success just because this module was seen earlier:
    # a previous dependency attempt may have failed, and the old short-circuit
    # silently skipped qca_cld3_peach_v2 after marking it seen.
    was_seen "$name" && log "retrying seen: $name"
    mark_seen "$name"

    # Load dependencies first.  They are looked up by basename, so versioned
    # module directories and cross-partition dependencies both work.
    LOADING="${LOADING} ${name}"
    for dep in $(deps_of "$name"); do
        load_one "$dep"
    done
    pop_loading "$name"
    # A dependency may have loaded the module already; avoid a duplicate
    # insmod "File exists" storm in the log.
    is_loaded "$name" && { log "loaded by dependency: $name"; return 0; }

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
    local list line
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
