#!/bin/bash
<<'README'
This script installs the latest Bio-Formats command-line tools (bftools) used
by the fsdb.

Verbosity is controlled by the standard fsdb debug mechanism provided by
getVar.sh / fun_colMsg.sh:
  debug=0  almost silent; errors only
  debug=1  concise installation progress
  debug>=2 verbose/development output, including subprocess output

The local variable `debug`, when set, overrides the global `DEBUGLEVEL` exactly
as defined by fun_colMsg.sh. This script deliberately does not implement a
second message-filtering layer.

Bio-Formats is Java-based. FSDB deliberately does not require a system-wide JDK
for this purpose: this installer uses the Java runtime bundled with Fiji. Fiji
must therefore already be installed. The bftools launcher is configured to
resolve Fiji's current bundled Java at runtime, without modifying the global
PATH.

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
    local candidate dir

    # Normal installed FSDB: getVar is linked into PATH.
    if command -v getVar >/dev/null 2>&1; then
        # shellcheck disable=SC1090
        source "$(command -v getVar)"
        return
    fi

    # Historical location: fsdb-core/install/setupBioFormatsTools.sh
    candidate="$(realpath -m "$thisDir/../scripts/core/getVar.sh")"
    if [[ -f $candidate ]]; then
        # shellcheck disable=SC1090
        source "$candidate"
        return
    fi

    # Intended location: fsdb-sdg/install/setupBioFormatsTools.sh
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
        warn "The last 40 lines of the Bio-Formats setup log follow:"
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
## BIO-FORMATS INSTALLATION
## ======

download_bftools() {
    # This is the current upstream 'latest Bio-Formats' endpoint. curl follows
    # the redirect to the concrete release artifact.
    curl --fail --location --retry 3 --retry-delay 2 \
        --output "$BFTOOLS_ZIP" "$BFTOOLS_URL"
}

verify_bftools_archive() {
    # Besides detecting a damaged archive, this also catches an HTML error page
    # returned with HTTP 200, replacing the old MIME-type/HTML parsing hack.
    unzip -tq "$BFTOOLS_ZIP" >/dev/null
}

install_bftools_archive() {
    local extracted="$TMPDIR/extracted"

    rm -rf "$extracted"
    mkdir -p "$extracted" || return $?
    unzip -q -o "$BFTOOLS_ZIP" -d "$extracted" || return $?

    if [[ ! -d $extracted/bftools || ! -f $extracted/bftools/bf.sh ]]; then
        printf 'Downloaded archive does not contain the expected bftools directory.\n' >&2
        return 1
    fi

    # bftools is third-party installed state, not user configuration. Replace
    # the previous bundle completely so obsolete files from older releases do
    # not survive an update.
    rm -rf "$BFTOOLS_DIR" || return $?
    mv "$extracted/bftools" "$BFTOOLS_DIR" || return $?
    chmod -R a+rX "$BFTOOLS_DIR"
}

find_fiji_java() {
    local java_bin

    if [[ ! -d ${FIJIDIR:-}/java ]]; then
        printf 'Fiji Java directory not found: %s/java\n' "${FIJIDIR:-<unset>}" >&2
        return 1
    fi

    java_bin=$(find "$FIJIDIR/java" -type f -path '*/bin/java' -perm -u+x \
        -print -quit 2>/dev/null)

    if [[ -z $java_bin || ! -x $java_bin ]]; then
        printf 'No executable Java runtime found below: %s/java\n' "$FIJIDIR" >&2
        return 1
    fi

    FIJI_JAVA=$java_bin
    dbg2 "Fiji Java: $FIJI_JAVA"
}

configure_bftools_java() {
    local java_wrapper_dir="$BFTOOLS_DIR/.fsdb-java"
    local java_wrapper="$java_wrapper_dir/java"
    local bf_launcher="$BFTOOLS_DIR/bf.sh"
    local marker='# FSDB_FIJI_JAVA_PATH'

    find_fiji_java || return $?

    mkdir -p "$java_wrapper_dir" || return $?

    # Resolve Fiji's bundled Java dynamically at runtime. This survives Fiji
    # updates that replace the versioned JDK directory without requiring a
    # system-wide Java installation or a global PATH modification.
    cat >"$java_wrapper" <<EOF_WRAPPER
#!/bin/bash
# FSDB wrapper: use the Java runtime bundled with Fiji.
FIJIDIR=$(printf '%q' "$FIJIDIR")
java_bin=\$(find "\$FIJIDIR/java" -type f -path '*/bin/java' -perm -u+x -print -quit 2>/dev/null)
if [[ -z \$java_bin || ! -x \$java_bin ]]; then
    printf 'ERROR: Fiji Java runtime not found below %s/java\\n' "\$FIJIDIR" >&2
    exit 127
fi
exec "\$java_bin" "\$@"
EOF_WRAPPER
    chmod 755 "$java_wrapper" || return $?

    [[ -f $bf_launcher ]] || return 1

    # All Bio-Formats Unix tools ultimately execute bf.sh, which invokes the
    # command `java`. Prepending our private wrapper directory to PATH here is
    # sufficient for every bftools command and leaves the system PATH intact.
    if ! grep -Fq "$marker" "$bf_launcher"; then
        awk -v marker="$marker" '
            NR == 2 {
                print marker
                print "export PATH=\"$(dirname \"$0\")/.fsdb-java:$PATH\""
            }
            { print }
        ' "$bf_launcher" >"$bf_launcher.fsdb-new" || return $?
        mv "$bf_launcher.fsdb-new" "$bf_launcher" || return $?
        chmod 755 "$bf_launcher" || return $?
    fi
}

verify_bftools_installation() {
    [[ -x $BFTOOLS_DIR/showinf ]] || {
        printf 'Expected Bio-Formats launcher not found: %s/showinf\n' "$BFTOOLS_DIR" >&2
        return 1
    }

    # This is also an end-to-end test that the launcher can find Fiji's Java.
    "$BFTOOLS_DIR/showinf" -version
}

## ======
## MAIN
## ======

thisDir=$(dirname "$(realpath "$0")")

# getVar performs the standard FSDB root/sudo checks and sources
# fun_colMsg.sh. From this point onward, use its messaging/debug API.
find_and_source_getvar

intro $(basename $0)

dbg2 "setupBioFormatsTools effective debug level: $(getLevel)"
dbg2 "setupBioFormatsTools script: $thisDir/$(basename "$0")"

if [[ -z ${SCRIPTSDIR:-} || -z ${ADMINDIR:-} || -z ${FIJIDIR:-} ]]; then
    fail "Required FSDB variables SCRIPTSDIR, ADMINDIR and FIJIDIR are not available."
fi

if [[ ! -x $FIJIDIR/fiji && ! -f $FIJIDIR/fiji ]]; then
    fail "Fiji must be installed before Bio-Formats tools. Expected launcher: $FIJIDIR/fiji"
fi

BFTOOLS_DIR="$SCRIPTSDIR/bftools"
BFTOOLS_URL="https://downloads.openmicroscopy.org/latest/bio-formats/artifacts/bftools.zip"

# Keep the directory/log after failure for diagnosis; remove it on success.
TMPDIR="$ADMINDIR/tmp-$(basename "$0" .sh)"
mkdir -p "$TMPDIR" || fail "Could not create temporary directory: $TMPDIR"
SETUP_LOG="$TMPDIR/setupBioFormatsTools.log"
: >"$SETUP_LOG" || fail "Could not create setup log: $SETUP_LOG"
BFTOOLS_ZIP="$TMPDIR/bftools.zip"

dbg "Installing Bio-Formats command-line tools into $BFTOOLS_DIR"
dbg2 "Bio-Formats download: $BFTOOLS_URL"

run_step "Downloading Bio-Formats tools..." download_bftools
run_step "Verifying Bio-Formats archive..." verify_bftools_archive
run_step "Installing Bio-Formats tools..." install_bftools_archive
run_step "Configuring Bio-Formats to use Fiji Java..." configure_bftools_java
run_step "Verifying Bio-Formats installation..." verify_bftools_installation

rm -rf "$TMPDIR"
dbg "Bio-Formats command-line tools installation complete."
