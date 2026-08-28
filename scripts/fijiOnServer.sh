#!/bin/bash

# Run Fiji on a machine without a graphical desktop.
#
# Fiji's legacy macro language and a number of ImageJ plugins still instantiate
# AWT components. Consequently, Fiji's native --headless mode is not a safe
# default for FSDB. This wrapper starts a private Xvfb display for each job and
# runs Fiji on that display. Native headless and an existing X11 display remain
# available as explicit, opt-in backends for testing and interactive use.

# fsdb-rev-date: 260828

set -o pipefail

usage() {
	cat <<EOF
Usage:
  $(basename "$0") [OPTIONS] CALLER.IJM
  $(basename "$0") [OPTIONS] IMAGE... MACRO.IJM [PARAMETER...]
  $(basename "$0") --cleanup-stale-stubs

Options:
  --job-id ID              Isolate temporary files for one SDG job
  --backend BACKEND        xvfb (default), native-headless, or x11
  --cleanup-stale-stubs    Safely remove global /tmp/ImageJ-*stub files
  -h, --help               Show this help text

The backend can also be selected with SDG_FIJI_BACKEND. Native headless is
never selected automatically because some FSDB macros and plugins require AWT.
EOF
}

job_id=""
backend_override=""
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
		--backend)
			[[ -n ${2:-} ]] || {
				printf 'ERROR: --backend requires a value\n' >&2
				exit 2
			}
			backend_override=$2
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
		--)
			shift
			positional_arguments+=("$@")
			break
			;;
		-*)
			printf 'ERROR: Unknown option: %s\n' "$1" >&2
			exit 2
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
	local stub_lock_fd

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
	find "$job_temporary_directory" -maxdepth 1 -name 'ImageJ-*stub' -delete

	# Concurrent jobs must not share Java or ImageJ temporary files.
	export TMPDIR=$job_temporary_directory
	export TMP=$job_temporary_directory
	export TEMP=$job_temporary_directory
	export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Djava.io.tmpdir=$job_temporary_directory"
fi

remove_job_stubs() {
	[[ -n $job_temporary_directory ]] || return 0
	find "$job_temporary_directory" -maxdepth 1 -name 'ImageJ-*stub' -delete
}

log_command() {
	local argument

	{
		printf 'Fiji command:'
		for argument in "$@"; do
			printf ' %q' "$argument"
		done
		printf '\n'
	} >>"$LOG"
}

run_with_timeout() {
	local -a command=("$@")

	log_command "${command[@]}"
	timeout --signal=TERM --kill-after=30s "${TIMEOUTMINUTES}m" \
		"${command[@]}" 2>>"$LOG"
}

# The display lock is held for the complete Fiji invocation, not merely during
# allocation, so parallel SDG workers cannot select the same display number.
xvfb_pid=""
xvfb_display=""
xvfb_lock_fd=""
xvfb_log=""

release_xvfb_display() {
	if [[ -n $xvfb_pid ]] && kill -0 "$xvfb_pid" 2>/dev/null; then
		kill "$xvfb_pid" 2>/dev/null || true
		wait "$xvfb_pid" 2>/dev/null || true
	fi
	xvfb_pid=""

	if [[ -n $xvfb_lock_fd ]]; then
		flock -u "$xvfb_lock_fd" 2>/dev/null || true
		exec {xvfb_lock_fd}>&-
	fi
	xvfb_lock_fd=""
	xvfb_display=""
}

display_is_in_use() {
	local display_number=$1

	[[ -e /tmp/.X11-unix/X${display_number} || \
		-e /tmp/.X${display_number}-lock ]]
}

reserve_xvfb_display() {
	local display_number
	local candidate_fd
	local display_min=${SDG_XVFB_DISPLAY_MIN:-99}
	local display_max=${SDG_XVFB_DISPLAY_MAX:-599}
	local lock_directory=${SDG_LOCK_DIR:-/tmp/fsdb-sdg-locks}/xvfb

	[[ $display_min =~ ^[0-9]+$ ]] \
		|| fail "Invalid SDG_XVFB_DISPLAY_MIN: $display_min"
	[[ $display_max =~ ^[0-9]+$ ]] \
		|| fail "Invalid SDG_XVFB_DISPLAY_MAX: $display_max"
	(( display_min <= display_max )) \
		|| fail "Xvfb display range is empty: $display_min-$display_max"

	mkdir -p -- "$lock_directory"
	for (( display_number = display_min; display_number <= display_max; display_number++ )); do
		exec {candidate_fd}>>"$lock_directory/display-$display_number.lock" \
			|| continue

		if flock -n "$candidate_fd" && ! display_is_in_use "$display_number"; then
			xvfb_lock_fd=$candidate_fd
			xvfb_display=$display_number
			return 0
		fi

		flock -u "$candidate_fd" 2>/dev/null || true
		exec {candidate_fd}>&-
	done

	error "No free Xvfb display in range $display_min-$display_max"
	return 1
}

wait_for_xvfb() {
	local attempts=${SDG_XVFB_STARTUP_ATTEMPTS:-100}
	local attempt

	[[ $attempts =~ ^[1-9][0-9]*$ ]] \
		|| fail "Invalid SDG_XVFB_STARTUP_ATTEMPTS: $attempts"

	for (( attempt = 1; attempt <= attempts; attempt++ )); do
		if ! kill -0 "$xvfb_pid" 2>/dev/null; then
			wait "$xvfb_pid" 2>/dev/null || true
			error "Xvfb exited before display :$xvfb_display became ready; see $xvfb_log"
			return 1
		fi

		# Prefer an actual X protocol probe when x11-utils is installed. The
		# socket check remains sufficient on minimal servers without xdpyinfo.
		if command -v xdpyinfo >/dev/null 2>&1; then
			if DISPLAY=":$xvfb_display" xdpyinfo >/dev/null 2>&1; then
				return 0
			fi
		elif [[ -S /tmp/.X11-unix/X${xvfb_display} ]]; then
			return 0
		fi
		sleep 0.1
	done

	error "Xvfb did not create display :$xvfb_display; see $xvfb_log"
	return 1
}

start_xvfb() {
	local screen=${SDG_XVFB_SCREEN:-1920x1080x24}

	reserve_xvfb_display || return 1
	xvfb_log=${job_temporary_directory:-${SDG_RUNTIME_DIR:-/tmp/fsdb-sdg}}/xvfb-${xvfb_display}.log
	mkdir -p -- "$(dirname -- "$xvfb_log")"

	Xvfb ":$xvfb_display" -screen 0 "$screen" -nolisten tcp -ac \
		>"$xvfb_log" 2>&1 &
	xvfb_pid=$!

	if ! wait_for_xvfb; then
		release_xvfb_display
		return 1
	fi

	export DISPLAY=":$xvfb_display"
	dbg "Xvfb display: $DISPLAY"
}

run_fiji_on_xvfb() {
	local status=0
	local -a fiji_command=("$FIJI_EXECUTABLE" "$@")

	sdg_require_commands Xvfb flock timeout
	start_xvfb || return 1
	run_with_timeout "${fiji_command[@]}" || status=$?
	release_xvfb_display
	return "$status"
}

run_fiji_native_headless() {
	local -a fiji_command=("$FIJI_EXECUTABLE" --headless "$@")

	warn "Using Fiji native headless mode; legacy AWT-dependent macros may fail"
	sdg_require_commands timeout
	run_with_timeout "${fiji_command[@]}"
}

run_fiji_on_x11() {
	local -a fiji_command=("$FIJI_EXECUTABLE" "$@")

	[[ -n ${DISPLAY:-} ]] || {
		error "The x11 backend requires DISPLAY to be set"
		return 1
	}
	sdg_require_commands timeout
	run_with_timeout "${fiji_command[@]}"
}

run_fiji_on_windows() {
	local fiji_executable="$FIJIDIR/ImageJ-win64.exe"

	[[ -x $fiji_executable ]] \
		|| fail "Cannot execute Fiji: $fiji_executable"
	"$fiji_executable" "$@" 2>>"$LOG"
}

run_fiji() {
	local selected_backend=${backend_override:-${SDG_FIJI_BACKEND:-xvfb}}
	local run_status=0

	dbg2 "$(date)"
	if [[ $(uname) != Linux ]]; then
		run_fiji_on_windows "$@" || run_status=$?
	else
		case $selected_backend in
			xvfb)
				run_fiji_on_xvfb "$@" || run_status=$?
				;;
			native-headless)
				run_fiji_native_headless "$@" || run_status=$?
				;;
			x11)
				run_fiji_on_x11 "$@" || run_status=$?
				;;
			*)
				error "Unsupported Fiji backend: $selected_backend"
				run_status=2
				;;
		esac
	fi

	remove_job_stubs
	if (( run_status == 124 || run_status == 137 )); then
		warn "Fiji timed out after $TIMEOUTMINUTES minute(s)"
	elif (( run_status != 0 )); then
		error "Fiji exited with status $run_status"
	else
		dbg "Fiji completed"
	fi
	dbg2 "$(date)"
	return "$run_status"
}

sdg_require_vars FIJIDIR TIMEOUTMINUTES LOG
[[ -d $FIJIDIR ]] || fail "Cannot find Fiji directory: $FIJIDIR"

FIJI_EXECUTABLE="$FIJIDIR/fiji"
[[ -x $FIJI_EXECUTABLE ]] || fail "Cannot execute Fiji: $FIJI_EXECUTABLE"

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
dbg2 "call: $0 $*"
dbg2 "FIJI_JAVA: $FIJI_JAVA"

# Ensure an interrupted wrapper cannot leave its private X server running.
trap 'release_xvfb_display; remove_job_stubs' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

overall_status=0

# The normal SDG path is intentionally simple: one generated caller contains
# the import and all operations for exactly one image/series job.
if (( $# == 1 )) && [[ -f $1 && $1 == *.ijm ]]; then
	run_fiji -macro "$1" || overall_status=$?
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

	for image in "${images[@]}"; do
		file_size=$(stat -c%s -- "$image")
		if [[ ${maxsize:-0} =~ ^[0-9]+$ ]] &&
			(( maxsize > 0 && file_size > maxsize )); then
			warn "$image is too large for this host"
			printf '%s\n' "$image" >>"$LOGDIR/$D.tooBig.txt"
			continue
		fi

		for macro_index in "${!macros[@]}"; do
			macro=${macros[$macro_index]}
			# ImageJ's macro interpreter exposes only one getArgument() string.
			# Preserve the established FSDB bridge: compile every logical
			# parameter into one comma-delimited payload, then pass that payload
			# as one quoted command-array element. The macro converts commas back
			# to its internal separator before parsing individual values.
			parameter=${macro_parameters[$macro_index]// /,}
			fiji_arguments=("$image" -macro "$macro")
			[[ -z $parameter ]] || fiji_arguments+=("$parameter")

			printf 'macro: %s\n' "$macro" >>"$LOG"
			printf 'parameter: %s\n' "$parameter" >>"$LOG"
			printf 'image: %s\n' "$image" >>"$LOG"
			printf 'filesize: %s\n' "$file_size" >>"$LOG"

			run_fiji "${fiji_arguments[@]}"
			macro_status=$?
			if (( macro_status != 0 && overall_status == 0 )); then
				overall_status=$macro_status
			fi
		done
	done
fi

date >>"$LOG"
exit "$overall_status"
