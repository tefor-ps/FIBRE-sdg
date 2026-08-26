#!/bin/bash
<<'README'
This script installs the OS-specific version of Fiji used by the fsdb.

Verbosity is controlled by the standard fsdb debug mechanism provided by
getVar.sh / fun_colMsg.sh:
  debug=0  almost silent; errors only
  debug=1  concise installation progress
  debug>=2 verbose/development output, including subprocess output

The local variable `debug`, when set, overrides the global `DEBUGLEVEL` exactly
as defined by fun_colMsg.sh. This script deliberately does not implement a
second message-filtering layer.

If this script encounters Windows Subsystem for Linux (WSL), it installs the
Linux version of Fiji. Fiji is linked into /usr/local/bin/fiji after install.
README
# fsdb-rev-date: 260826

## ======
## BOOTSTRAP
## ======

# Needed only until getVar has been sourced. Afterwards use the standard fsdb
# functions from fun_colMsg.sh (fail, warn, dbg, dbg2, ...).
bootstrap_fail() {
    printf 'ERROR: %s: %s\n' "$(basename "$0")" "$*" >&2
    exit 128
}

find_and_source_getvar() {
    local dir candidate

    # Normal installed FSDB: getVar is linked into PATH.
    if command -v getVar >/dev/null 2>&1; then
        # shellcheck disable=SC1090
        source "$(command -v getVar)"
        return
    fi

    # During installation the symlink may not yet be usable. First try the
    # deterministic manifest-era location relative to fsdb-sdg/install.
    candidate="$(realpath -m "$thisDir/../../fsdb-core/scripts/core/getVar.sh")"
    if [[ -f $candidate ]]; then
        # shellcheck disable=SC1090
        source "$candidate"
        return
    fi

    # Compatibility fallback for older/non-standard layouts.
    dir=$thisDir
    for _ in 1 2 3 4; do
        candidate=$(find "$dir" -name getVar.sh -type f -print -quit 2>/dev/null)
        if [[ -n $candidate && -f $candidate ]]; then
            # shellcheck disable=SC1090
            source "$candidate"
            return
        fi
        dir=$(dirname "$dir")
    done

    bootstrap_fail "Can't find getVar.sh"
}

## ======
## EXECUTION HELPERS
## ======

show_quiet_failure_log() {
    if [[ -s ${SETUP_LOG:-} ]]; then
        warn "The last 40 lines of the Fiji setup log follow:"
        tail -n 40 "$SETUP_LOG" >&2
        warn "Full setup output is available at: $SETUP_LOG"
    fi
}

run_step() {
    local description=$1
    shift
    local rc level

    # fun_colMsg performs the message filtering:
    #   dbg  -> debug >= 1
    #   dbg2 -> debug >= 2
    dbg "$description"
    dbg2 "Executing: $(printf '%q ' "$@")"

    level=$(getLevel)
    if (( level >= 2 )); then
        "$@"
        rc=$?
    else
        "$@" >>"$SETUP_LOG" 2>&1
        rc=$?
    fi

    if (( rc != 0 )); then
        if (( level < 2 )); then
            show_quiet_failure_log
        fi
        fail "$description failed (exit code $rc)."
    fi
}

## ======
## INSTALLATION STEPS
## ======

download_fiji() {
    wget -O "$FIJI" "https://downloads.imagej.net/fiji/latest/$FIJI" || return $?
    wget -O "$MD5" "https://downloads.imagej.net/fiji/latest/$MD5"
}

verify_fiji_download() {
    local actual expected

    actual=$(md5sum "$FIJI" | awk '{print $1}') || return $?
    expected=$(awk '{print $1}' "$MD5") || return $?

    dbg2 "Expected MD5: $expected"
    dbg2 "Actual MD5:   $actual"

    if [[ $actual != "$expected" ]]; then
        printf 'Fiji MD5 checksum mismatch. Expected %s, got %s.\n' \
            "$expected" "$actual" >&2
        return 1
    fi
}

install_fiji_archive() {
    mkdir -p "$FIJIDIR" || return $?
    unzip -o "$FIJI" || return $?
    rsync -Sau Fiji/ "$FIJIDIR"
}

update_fiji() {
    cd "$FIJIDIR" || return $?
    bash fiji --update update
}

integrate_fiji() {
    # Make the launcher resolve symlinks correctly when called from PATH.
    sed -i 's@dir=$(dirname "$0")@dir=$(dirname $(realpath "$0"))@' \
        "$FIJIDIR/fiji" || return $?

    ln -sf "$FIJIDIR/fiji" /usr/local/bin/fiji || return $?

    # Preserve historical ownership when invoked through sudo. When run as
    # root directly there is no invoking user, so retain current ownership.
    if [[ -n ${SUDO_USER:-} ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "$FIJIDIR" || return $?
    else
        dbg2 "SUDO_USER is not set; retaining current Fiji ownership."
    fi

    chmod -R 775 "$FIJIDIR"
}

## ======
## MAIN
## ======

thisDir=$(dirname "$(realpath "$0")")
intro $(basename $0)

# getVar also performs the standard FSDB root/sudo checks and sources
# fun_colMsg.sh. From this point onward, use its messaging/debug API.
find_and_source_getvar

dbg2 "setupFiji effective debug level: $(getLevel)"
dbg2 "setupFiji script: $thisDir/$(basename "$0")"

if [[ -f $FIJIDIR/fiji ]]; then
    fail "Fiji already exists at $FIJIDIR."
fi

case ${OSTYPE:-} in
    linux-gnu*)
        if uname -r | grep -qi microsoft; then
            OS_LABEL="WSL/Linux"
        else
            OS_LABEL="Linux"
        fi
        FIJI=fiji-latest-linux64-jdk.zip
        ;;
    darwin*)
        OS_LABEL="macOS"
        FIJI=fiji-latest-macos64-jdk.zip
        ;;
    cygwin*)
        OS_LABEL="Cygwin/Windows"
        FIJI=fiji-latest-win64-jdk.zip
        ;;
    msys*)
        OS_LABEL="MSYS/Windows"
        FIJI=fiji-latest-win64-jdk.zip
        ;;
    freebsd*)
        OS_LABEL="FreeBSD"
        FIJI=fiji-latest-linux64-jdk.zip
        ;;
    *)
        fail "Unknown operating system: OSTYPE='${OSTYPE:-unset}', uname='$(uname -a)'"
        ;;
esac
MD5=${FIJI}.md5

dbg "Installing Fiji for $OS_LABEL to $FIJIDIR"
dbg2 "Fiji archive: $FIJI"

# Keep the directory/log after failure for diagnosis; remove it on success.
TMPDIR="$ADMINDIR/tmp-$(basename "$0" .sh)"
mkdir -p "$TMPDIR" || fail "Could not create temporary directory: $TMPDIR"
SETUP_LOG="$TMPDIR/setupFiji.log"
: >"$SETUP_LOG" || fail "Could not create setup log: $SETUP_LOG"
cd "$TMPDIR" || fail "Could not enter temporary directory: $TMPDIR"

run_step "Downloading Fiji..." download_fiji
run_step "Verifying Fiji download..." verify_fiji_download
run_step "Installing Fiji files..." install_fiji_archive
run_step "Updating Fiji..." update_fiji
run_step "Integrating Fiji with the system..." integrate_fiji

rm -rf "$TMPDIR"
dbg "Fiji installation complete."
