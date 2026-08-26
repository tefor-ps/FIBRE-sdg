#!/bin/bash
<<'README'
This script installs the OS-specific version of Fiji used by the fsdb.

Output is controlled by the fsdb debug level:
  debug=0  almost silent; only errors/failures are shown
  debug=1  concise installation progress (default)
  debug>=2 verbose/development output, including underlying command output

A locally/environment-set `debug` takes precedence over the global fsdb
`DEBUGLEVEL` loaded by getVar. If neither is defined, level 1 is used.

If this script encounters Windows Subsystem for Linux (WSL), it installs the
Linux version of Fiji. Fiji is linked into /usr/local/bin/fiji after install.
README
# fsdb-rev-date: 260826

## ======
## BOOTSTRAP FUNCTIONS
## ======

bootstrap_fail() {
    local message="$*"
    printf '\033[31mError in %s: %s\033[0m\n' "$(basename "$0")" "$message" >&2
    printf '\033[31mExiting.\033[0m\n' >&2
    exit 128
}

sudoer() {
    # This installer writes to the fsdb installation and /usr/local/bin.
    if [[ $(id -u) -ne 0 ]]; then
        bootstrap_fail "This script needs to be run with root privileges."
    fi
}

find_and_source_getvar() {
    local dir candidate

    # Prefer the normal installed command/symlink if available.
    if command -v getVar >/dev/null 2>&1; then
        # shellcheck disable=SC1090
        source "$(command -v getVar)"
        return
    fi

    # During installation getVar may not yet be on PATH. Search upward from
    # this script, matching the historical behaviour without printing noise.
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
## VERBOSITY / EXECUTION HELPERS
## ======

set_debug_level() {
    # Local/environment debug overrides the global DEBUGLEVEL loaded by getVar.
    debug=${debug:-${DEBUGLEVEL:-1}}

    if ! [[ $debug =~ ^[0-9]+$ ]]; then
        warn "Invalid debug level '$debug'; using debug=1."
        debug=1
    fi

    export debug
}

status() {
    # Level 1: only significant progress messages.
    if (( debug >= 1 )); then
        intro "$*"
    fi
}

verbose() {
    # Level 2+: development details.
    if (( debug >= 2 )); then
        dbg2 "$*"
    fi
}

show_quiet_failure_log() {
    if [[ -s $SETUP_LOG ]]; then
        warn "The last 40 lines of the Fiji setup log follow:"
        tail -n 40 "$SETUP_LOG" >&2
        warn "Full setup output is available at: $SETUP_LOG"
    fi
}

run_step() {
    local description=$1
    shift
    local rc

    status "$description"

    if (( debug >= 2 )); then
        verbose "Executing: $(printf '%q ' "$@")"
        "$@"
        rc=$?
    else
        "$@" >>"$SETUP_LOG" 2>&1
        rc=$?
    fi

    if (( rc != 0 )); then
        (( debug >= 2 )) || show_quiet_failure_log
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

    verbose "Expected MD5: $expected"
    verbose "Actual MD5:   $actual"

    if [[ $actual != "$expected" ]]; then
        printf 'ERROR: Fiji MD5 checksum mismatch. Expected %s, got %s.\n' \
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

    # Preserve the historical ownership behaviour when invoked through sudo.
    # If SUDO_USER is unavailable (e.g. direct root invocation), retain root
    # ownership rather than constructing an invalid chown target.
    if [[ -n ${SUDO_USER:-} ]]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "$FIJIDIR" || return $?
    else
        verbose "SUDO_USER is not set; retaining current Fiji ownership."
    fi

    chmod -R 775 "$FIJIDIR"
}

## ======
## MAIN
## ======

sudoer

thisDir=$(dirname "$(realpath "$0")")
find_and_source_getvar
set_debug_level

verbose "setupFiji debug level: $debug"
verbose "setupFiji script: $thisDir/$(basename "$0")"

if [[ -f $FIJIDIR/fiji ]]; then
    fail "Fiji already exists at $FIJIDIR."
fi

# Determine the correct Fiji archive without emitting platform chatter at
# debug=0. At level 1 the selected platform is included in one concise line.
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

status "Installing Fiji for $OS_LABEL to $FIJIDIR"

# Create a working directory and keep it on failure so the quiet-mode log is
# available for diagnosis. It is removed only after a successful installation.
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
status "Fiji installation complete."
