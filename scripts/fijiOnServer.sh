#!/bin/bash

# Run Fiji with an available graphical backend.
#
# SDG normally passes one generated caller macro. The legacy image/macro syntax
# remains supported for other FSDB callers. Runtime scripts never install
# dependencies or recursively change Fiji permissions; installation owns those
# tasks.

# fsdb-rev-date: 260828

set -o nounset
set -o pipefail

usage() {
	cat <<EOF
Usage:
  $(basename "$0") [--job-id ID] CALLER.IJM
  $(basename "$0") [--job-id ID] IMAGE... MACRO.IJM [PARAMETER...]...
  $(basename "$0") --cleanup-stale-stubs

Options:
  --job-id ID              Use a private temporary directory for one SDG job
  --cleanup-stale-stubs    Safely remove global /tmp/ImageJ-*stub files
EOF
}

job_id=""
cleanup_stubs=0
positional_arguments=()

while (( $# > 0 )); do
	case $1 in
		--job-id)
			[[ -n ${2:-} ]] || {
				printf 'ERROR: --job-id requires an ID\n' >&2
				exit 2
			}
			job_id=$2
			shift 2
			;;
		--cleanup-stale-stubs)
			cleanup_stubs=1
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			positional_arguments+=("$1")
			shift
			;;
	esac
done
set -- "${positional_arguments[@]}"

this_dir=$(dirname -- "$(realpath -- "$0")")
# shellcheck source=sdg-common.sh
source "$this_dir/sdg-common.sh"

sdg_load_fsdb "$this_dir" || exit 1
intro "$(basename "$0")"

cleanup_legacy_stubs() {
	local stub_file
	local lock_directory=${SDG_LOCK_DIR:-/tmp}

	sdg_require_commands flock find pgrep
	mkdir -p -- "$lock_directory"

	# Stub names are global, so cleanup must also be global and serialized.
	exec {stub_lock_fd}>>"$lock_directory/imagej-stubs.lock"
	flock "$stub_lock_fd"

	if sdg_any_fiji_running; then
		error "Refusing stale-stub cleanup while Fiji/ImageJ is active"
		return 1
	fi

	while IFS= read -r -d '' stub_file; do
		rm -f -- "$stub_file" || return 1
	done < <(find /tmp -maxdepth 1 -name 'ImageJ-*stub' -print0)
}

if (( cleanup_stubs != 0 )); then
	cleanup_legacy_stubs
	exit $?
fi

(( $# > 0 )) || fail "No Fiji macro or image was provided"

job_temporary_directory=""
if [[ -n $job_id ]]; then
	[[ $job_id =~ ^[A-Za-z0-9._-]+$ ]] || fail "Unsafe job ID: $job_id"

	job_temporary_directory="${SDG_RUNTIME_DIR:-/tmp/fsdb-sdg}/jobs/$job_id/tmp"
	mkdir -p -- "$job_temporary_directory"
	find "$job_temporary_directory" \
		-maxdepth 1 \
		-name 'ImageJ-*stub' \
		-delete

	# Fiji and Java now create their temporary files inside the job namespace.
	# Concurrent jobs therefore never delete one another's active stubs.
	export TMPDIR=$job_temporary_directory
	export TMP=$job_temporary_directory
	export TEMP=$job_temporary_directory
	export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Djava.io.tmpdir=$job_temporary_directory"
fi

# Existing policy: server operation uses a virtual display. Set force=0 only
# for explicitly interactive operation. force_xvfb overrides Weston selection.
force=1
force_xvfb=0

run_fiji_on_x11() {
	dbg "X11" | tee -a "$LOG"
	cd "$FIJIDIR" || return 1

	printf 'timeout %sm fiji %s -macro %s %s\n' \
		"$TIMEOUTMINUTES" "$IMG" "$MACRO" "$PARAM"
	timeout "${TIMEOUTMINUTES}m" \
		fiji "$IMG" -macro "$MACRO" "$PARAM" \
		2>>"$LOG"
}

run_fiji_on_xvfb() {
	dbg "Xvfb" | tee -a "$LOG"
	[[ -f $XVFB ]] || {
		error "Cannot find Xvfb wrapper: $XVFB"
		return 1
	}

	printf 'timeout time: %sm\n' "$TIMEOUTMINUTES" >>"$LOG"
	printf 'timeout %sm %s "fiji %s -macro %s %s"\n' \
		"$TIMEOUTMINUTES" "$XVFB" "$IMG" "$MACRO" "$PARAM" \
		>>"$LOG"
	timeout "${TIMEOUTMINUTES}m" \
		"$XVFB" "fiji $IMG -macro $MACRO $PARAM" \
		2>>"$LOG"
}

run_fiji_on_wayland() {
	dbg "Wayland - Weston" | tee -a "$LOG"
	command -v weston >/dev/null 2>&1 || {
		error "Weston is not installed; runtime scripts do not install dependencies"
		return 1
	}
	[[ -f $WESTON ]] || {
		error "Cannot find Weston wrapper: $WESTON"
		return 1
	}

	printf 'timeout time: %sm\n' "$TIMEOUTMINUTES" >>"$LOG"
	printf 'timeout %sm %s "fiji %s -macro %s %s"\n' \
		"$TIMEOUTMINUTES" "$WESTON" "$IMG" "$MACRO" "$PARAM" \
		>>"$LOG"
	timeout "${TIMEOUTMINUTES}m" \
		"$WESTON" "fiji $IMG -macro $MACRO $PARAM" \
		2>>"$LOG"
}

run_fiji_on_windows() {
	local fiji_executable="$FIJIDIR/ImageJ-win64.exe"

	dbg "Windows" | tee -a "$LOG"
	cd "$FIJIDIR" || return 1
	"$fiji_executable" "$IMG" -macro "$MACRO" "$PARAM" 2>>"$LOG"
}

headless_backend() {
	if (( force_xvfb != 0 )) && command -v Xvfb >/dev/null 2>&1; then
		printf 'xvfb\n'
	elif command -v weston >/dev/null 2>&1; then
		printf 'wayland\n'
	elif command -v Xvfb >/dev/null 2>&1; then
		printf 'xvfb\n'
	else
		printf 'none\n'
		return 1
	fi
}

remove_job_stubs() {
	[[ -n $job_temporary_directory ]] || return 0
	find "$job_temporary_directory" \
		-maxdepth 1 \
		-name 'ImageJ-*stub' \
		-delete
}

run_fiji() {
	local backend
	local run_status=0

	dbg2 "$(date)" | tee -a "$LOG"

	if [[ $(uname) != Linux ]]; then
		run_fiji_on_windows
		run_status=$?
	elif grep -qi microsoft /proc/version; then
		dbg "WSL" | tee -a "$LOG"
		run_fiji_on_x11
		run_status=$?
	elif (( force == 0 )); then
		run_fiji_on_x11
		run_status=$?
	else
		backend=$(headless_backend) || backend=none
		case $backend in
			wayland)
				run_fiji_on_wayland
				run_status=$?
				;;
			xvfb)
				run_fiji_on_xvfb
				run_status=$?
				;;
			*)
				error "No supported graphical backend is available"
				run_status=1
				;;
		esac
	fi

	remove_job_stubs
	if (( run_status == 124 )); then
		dbg "$0 TIMEOUT" >>"$LOG"
	else
		dbg "$0 DONE" >>"$LOG"
	fi
	dbg2 "$(date)\n"
	return "$run_status"
}

sdg_require_vars FIJIDIR TIMEOUTMINUTES XVFB WESTON LOG
[[ -d $FIJIDIR ]] || fail "Cannot find Fiji directory: $FIJIDIR"

# Bio-Formats and Fiji wrappers call java from PATH. The helper appends Fiji's
# bundled Java only as a fallback, preserving any earlier system Java choice.
fiji_java_helper="$this_dir/configureFijiJava.sh"
[[ -f $fiji_java_helper ]] \
	|| fail "Cannot find Fiji Java helper: $fiji_java_helper"
# shellcheck source=configureFijiJava.sh
source "$fiji_java_helper" \
	|| fail "Could not load Fiji Java helper: $fiji_java_helper"
configureFijiJava \
	|| fail "Could not configure Fiji's bundled Java runtime"

dbg "LOG: $LOG"
dbg2 "call: $0 $*" | tee -a "$LOG"
dbg2 "FIJI_JAVA: $FIJI_JAVA"

overall_status=0

# The normal SDG path is intentionally simple: one generated caller contains
# the import and all operations for exactly one image/series job.
if (( $# == 1 )) && [[ -f $1 && $1 == *.ijm ]]; then
	IMG=""
	MACRO=$1
	PARAM=""
	run_fiji || overall_status=$?
else
	input_arguments=("$@")
	images=()
	macros=()
	macro_parameters=()
	unrecognized=()
	argument_index=0

	# Legacy syntax treats existing non-IJM files as images. Non-file tokens
	# immediately following a macro are collected as that macro's parameters.
	while (( argument_index < ${#input_arguments[@]} )); do
		argument=${input_arguments[$argument_index]}
		if [[ -f $argument && $argument == *.ijm ]]; then
			macros+=("$argument")
			(( argument_index += 1 ))
			parameters=()

			while (( argument_index < ${#input_arguments[@]} )) &&
				[[ ! -f ${input_arguments[$argument_index]} ]]; do
				parameters+=("${input_arguments[$argument_index]}")
				(( argument_index += 1 ))
			done
			macro_parameters+=("${parameters[*]}")
		elif [[ -f $argument ]]; then
			images+=("$argument")
			(( argument_index += 1 ))
		else
			unrecognized+=("$argument")
			(( argument_index += 1 ))
		fi
	done

	if (( ${#unrecognized[@]} > 0 )); then
		fail "Unrecognized call elements: ${unrecognized[*]}"
	fi
	(( ${#images[@]} > 0 )) || fail "No input images were recognized"
	(( ${#macros[@]} > 0 )) || fail "No Fiji macros were recognized"

	for IMG in "${images[@]}"; do
		file_size=$(stat -c%s -- "$IMG")
		if (( file_size > maxsize )); then
			error "$IMG is too large for this host" | tee -a "$LOG"
			printf '%s\n' "$IMG" | tee -a "$LOGDIR/$D.tooBig.txt"
			continue
		fi
		if (( force == 0 && file_size < minsize )); then
			error "$IMG is too small for this host" | tee -a "$LOG"
			printf '%s\n' "$IMG" | tee -a "$LOGDIR/$D.tooSmall.txt"
			continue
		fi

		for macro_index in "${!macros[@]}"; do
			MACRO=${macros[$macro_index]}
			PARAM=${macro_parameters[$macro_index]// /,}

			printf 'macro: %s\n' "$MACRO" | tee -a "$LOG"
			printf 'param: %s\n' "$PARAM" | tee -a "$LOG"
			printf 'image: %s\n' "$IMG" | tee -a "$LOG"
			printf 'filesize: %s\n' "$file_size" | tee -a "$LOG"
			whoami >>"$LOG"

			run_fiji
			macro_status=$?
			if (( macro_status != 0 && overall_status == 0 )); then
				overall_status=$macro_status
			fi
		done
	done
fi

date >>"$LOG"
exit "$overall_status"
