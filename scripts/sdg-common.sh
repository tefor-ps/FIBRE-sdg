#!/bin/bash

# Common bootstrap helpers for fsdb-sdg shell scripts.
#
# This file must be sourced. It deliberately contains no Fiji-specific setup:
# getVar.sh remains the authoritative FSDB configuration loader, while Fiji's
# bundled Java is configured only by the scripts that actually need it.

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	printf 'ERROR: %s must be sourced, not executed.\n' "$(basename "$0")" >&2
	exit 1
fi

sdg_bootstrap_error() {
	printf 'ERROR: fsdb-sdg bootstrap: %s\n' "$*" >&2
}

sdg_find_getvar() {
	local start_dir=$1
	local candidate=""
	local search_dir=""
	local resolved=""
	local known=""
	local -a candidates=()
	local -a unique=()
	local -a names=(getVar getVar.sh)
	local name
	local level

	if [[ -n ${SDG_GETVAR:-} ]]; then
		if [[ ! -f $SDG_GETVAR ]]; then
			sdg_bootstrap_error \
				"SDG_GETVAR does not name a file: $SDG_GETVAR"
			return 1
		fi
		realpath -- "$SDG_GETVAR"
		return 0
	fi

	for name in "${names[@]}"; do
		candidate=$(command -v "$name" 2>/dev/null || true)
		if [[ -f $candidate ]]; then
			candidates+=("$candidate")
		fi
	done

	search_dir=$(realpath -m -- "$start_dir")
	for level in 1 2 3 4 5; do
		for candidate in \
			"$search_dir/fsdb-core/scripts/core/getVar.sh" \
			"$search_dir/scripts/core/getVar.sh" \
			"$search_dir/core/getVar.sh"; do
			if [[ -f $candidate ]]; then
				candidates+=("$candidate")
			fi
		done

		if [[ $search_dir == / ]]; then
			break
		fi
		search_dir=$(dirname -- "$search_dir")
	done

	for candidate in "${candidates[@]}"; do
		resolved=$(realpath -- "$candidate") || continue
		known=0
		for name in "${unique[@]}"; do
			if [[ $name == "$resolved" ]]; then
				known=1
				break
			fi
		done
		if (( known == 0 )); then
			unique+=("$resolved")
		fi
	done

	case ${#unique[@]} in
		0)
			sdg_bootstrap_error "cannot find getVar.sh from $start_dir"
			return 1
			;;
		1)
			printf '%s\n' "${unique[0]}"
			;;
		*)
			sdg_bootstrap_error "found multiple getVar.sh candidates:"
			printf '  %s\n' "${unique[@]}" >&2
			return 1
			;;
	esac
}

sdg_load_fsdb() {
	local script_dir=$1
	local getvar_path=""
	local function_name=""
	local getvar_status=0
	local nounset_was_enabled=0
	local -a required_functions=(
		intro msg warn error fail dbg dbg2 dbg3 getLevel
	)

	getvar_path=$(sdg_find_getvar "$script_dir") || return 1

	# getVar is expected to be sourced and is authoritative for both the compiled
	# FSDB configuration and the fun_colMsg messaging API. The existing getVar
	# implementation probes variables before assigning defaults, so it is not
	# compatible with `set -u`. Temporarily suspend nounset without changing the
	# option state observed by the calling script after this function returns.
	if [[ $- == *u* ]]; then
		nounset_was_enabled=1
	fi
	set +o nounset

	# shellcheck source=/dev/null
	if source "$getvar_path"; then
		getvar_status=0
	else
		getvar_status=$?
	fi

	if (( nounset_was_enabled != 0 )); then
		set -o nounset
	else
		set +o nounset
	fi

	if (( getvar_status != 0 )); then
		sdg_bootstrap_error "could not source $getvar_path"
		return 1
	fi

	for function_name in "${required_functions[@]}"; do
		if ! declare -F "$function_name" >/dev/null; then
			sdg_bootstrap_error \
				"getVar did not provide required function: $function_name"
			return 1
		fi
	done

	SDG_GETVAR=$getvar_path
	export SDG_GETVAR
}

sdg_require_vars() {
	local name
	local -a missing=()

	for name in "$@"; do
		if [[ -z ${!name:-} ]]; then
			missing+=("$name")
		fi
	done

	if (( ${#missing[@]} > 0 )); then
		fail "Missing required FSDB variables: ${missing[*]}"
	fi
}

sdg_require_files() {
	local name
	local path
	local -a missing=()

	for name in "$@"; do
		path=${!name:-}
		if [[ -z $path || ! -f $path ]]; then
			missing+=("$name=${path:-<unset>}")
		fi
	done

	if (( ${#missing[@]} > 0 )); then
		fail "Missing required FSDB files: ${missing[*]}"
	fi
}

sdg_require_commands() {
	local name
	local -a missing=()

	for name in "$@"; do
		command -v "$name" >/dev/null 2>&1 || missing+=("$name")
	done

	if (( ${#missing[@]} > 0 )); then
		fail "Missing required commands: ${missing[*]}"
	fi
}

sdg_validate_field() {
	local field_name=$1
	local value=$2

	if [[ $value == *$'\t'* || $value == *$'\n'* || $value == *$'\r'* ]]; then
		fail "$field_name contains a tab or newline; it cannot be represented in an SDG plan"
	fi
}

sdg_plan_assert_header() {
	local record
	local version

	[[ -f $1 ]] || fail "Plan does not exist: $1"
	IFS=$'\t' read -r record version < "$1"
	[[ $record == SDG_PLAN && ( $version == 1 || $version == 2 ) ]] \
		|| fail "Unsupported or malformed SDG plan: $1"
}

sdg_plan_version() {
	local record
	local version

	IFS=$'\t' read -r record version < "$1"
	[[ $record == SDG_PLAN ]] || return 1
	printf '%s\n' "$version"
}

sdg_plan_job_image() {
	local plan=$1
	local job_id=$2

	awk -F '\t' -v id="$job_id" '
		$1 == "JOB" && $2 == id { print $3; exit }
	' "$plan"
}

sdg_plan_image_size() {
	local plan=$1
	local image=$2
	local version
	local planned_size

	version=$(sdg_plan_version "$plan") || return 1
	if [[ $version == 2 ]]; then
		planned_size=$(awk -F '\t' -v image="$image" '
			$1 == "IMAGE" && $2 == image { print $3; exit }
		' "$plan")
		[[ $planned_size =~ ^[0-9]+$ ]] || return 1
		printf '%s\n' "$planned_size"
	else
		# Version 1 did not record input sizes. Retain compatibility with old
		# paused plans by inspecting their source file at execution time.
		stat -c%s -- "$image"
	fi
}

sdg_job_id() {
	# NUL separators prevent ambiguous concatenations such as ab+c and a+bc.
	printf '%s\0%s\0%s' "$1" "$2" "$3" | sha256sum | cut -c 1-20
}

sdg_plan_id() {
	awk -F '\t' '
		$1 == "META" && $2 == "plan_id" { print $3; exit }
	' "$1"
}

sdg_read_state_value() {
	local state_file=$1
	local key=$2

	awk -F '\t' -v key="$key" '
		$1 == key { print substr($0, length($1) + 2); exit }
	' "$state_file" 2>/dev/null
}

sdg_ij_escape() {
	local value=$1

	value=${value//\\/\\\\}
	value=${value//\"/\\\"}
	value=${value//$'\n'/\\n}
	value=${value//$'\r'/}
	printf '%s' "$value"
}

sdg_config_names() {
	# CONFIG is the source, human-readable module config. Its first
	# whitespace-delimited field is the variable name compiled by getVar.
	awk -v suffix="$1" '
		$1 !~ /^#/ && $1 ~ (suffix "$") { print $1 }
	' "$CONFIG"
}

sdg_any_fiji_running() {
	pgrep -f \
		'(^|/)(ImageJ[^/]*|fiji)([[:space:]]|$)|net\.imagej\.Main|ij\.ImageJ' \
		>/dev/null 2>&1
}
