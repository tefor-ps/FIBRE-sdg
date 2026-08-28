#!/bin/bash

set -o pipefail

usage() {
	cat <<USAGE
Usage: $(basename "$0") IMAGE

Generate the configured secondary data for one raw image.

IMAGE must be an existing regular file. Database-wide planning, series
selection, file-size scheduling, and queue iteration belong to sdg-plan.sh and
sdg-run.sh; this script processes one selected input only.
USAGE
}

bootstrap_error() {
	printf 'ERROR: %s: %s\n' "$(basename "$0")" "$*" >&2
	exit 1
}

cleanup_lock() {
	if [[ ${lock_owned:-0} -eq 1 && -n ${lock:-} ]]; then
		if rm -f -- "$lock"; then
			dbg2 "Removed lock: $lock"
		else
			warn "Could not remove lock: $lock"
		fi
		lock_owned=0
	fi
}

create_lock() {
	local lock_details=""

	if ! (
		set -o noclobber
		printf 'pid=%s\nstarted=%s\nimage=%s\n' \
			"$$" "$(date --iso-8601=seconds)" "$img" > "$lock"
	) 2>/dev/null; then
		if [[ -r $lock ]]; then
			lock_details=$(tr '\n' ' ' < "$lock")
		fi
		warn "Image is locked; skipping: $img${lock_details:+ ($lock_details)}"
		exit 75
	fi

	lock_owned=1
	trap cleanup_lock EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
	trap 'exit 129' HUP
	dbg2 "Created lock: $lock"
}

read_channel_count() {
	local metadata_file=$1
	local count=""

	count=$(awk '/SizeC/ { value=$NF } END { print value }' "$metadata_file")
	if [[ ! $count =~ ^[1-9][0-9]*$ ]]; then
		fail "Could not determine a valid channel count from $metadata_file"
	fi

	printf '%s\n' "$count"
}

collect_expected_outputs() {
	local line
	local output
	local prefix
	local suffix
	local channel

	expected_outputs=()

	while IFS= read -r line; do
		# makeCaller writes saving operations as:
		# runMacro("...save*.ijm", "EXPECTED_OUTPUT");
		if [[ $line =~ runMacro\(\"[^\"]*[Ss]ave[^\"]*\"[[:space:]]*,[[:space:]]*\"([^\"]+)\"\)\; ]]; then
			output=${BASH_REMATCH[1]}

			# The current saveNrrd macro inserts -C<channel> immediately before
			# the first dot when it splits a multi-channel image. Preserve that
			# naming contract until the macro itself is refactored.
			if [[ $output == *.nrrd && $ch_num -gt 1 ]]; then
				prefix=${output%%.*}
				suffix=${output#"$prefix"}
				for (( channel=1; channel<=ch_num; channel++ )); do
					expected_outputs+=("${prefix}-C${channel}${suffix}")
				done
			else
				expected_outputs+=("$output")
			fi
		fi
	done < "$CALLER"

	if (( ${#expected_outputs[@]} == 0 )); then
		fail "The generated caller contains no recognizable output operations: $CALLER"
	fi
}

find_missing_outputs() {
	local output

	missing_outputs=()
	for output in "${expected_outputs[@]}"; do
		if [[ -f $output ]]; then
			dbg2 "Output exists: $output"
		else
			dbg "Output missing: $output"
			missing_outputs+=("$output")
		fi
	done
}

if (( $# != 1 )); then
	usage >&2
	exit 2
fi

case $1 in
	-h|--help)
		usage
		exit 0
		;;
esac

if [[ ! -f $1 ]]; then
	bootstrap_error "input is not a regular file: $1"
fi

img=$(realpath -- "$1") || bootstrap_error "cannot resolve input path: $1"
img_dir=$(dirname -- "$img")
filename=$(basename -- "$img")

if [[ $filename == *.* && $filename != .* ]]; then
	bn=${filename%.*}
else
	bn=$filename
fi

lock="$img_dir/$bn.lock"
lock_owned=0

this_dir=$(dirname -- "$(realpath -- "$0")")
common="$this_dir/lib/sdg-common.sh"
[[ -f $common ]] || bootstrap_error "cannot find common helper: $common"

# shellcheck source=lib/sdg-common.sh
source "$common"
sdg_load_fsdb "$this_dir" || bootstrap_error "could not load the FSDB environment"

intro "$(basename "$0")"
sdg_require_vars SECDATA_EXT MAKEMETA MAKECALLER CALLER FIJIONSERVER FIXPERMISSIONS
sdg_require_files MAKEMETA MAKECALLER FIJIONSERVER FIXPERMISSIONS

out_dir="$img_dir/${bn}${SECDATA_EXT}"
mkdir -p -- "$out_dir" || fail "Could not create output directory: $out_dir"

dbg "Image: $img"
dbg2 "Output directory: $out_dir"
dbg2 "getVar: $SDG_GETVAR"

create_lock

# Keep every processing step under the same effective account. At present,
# getVar itself still requires root, but nested sudo calls are unnecessary and
# make a later transition to a dedicated FSDB account harder.
metadata_output=$(bash "$MAKEMETA" "$img") \
	|| fail "Metadata extraction failed for $img"
meta=$(printf '%s\n' "$metadata_output" | tail -n 1)
[[ -f $meta ]] || fail "Metadata output was not created: ${meta:-<empty>}"

ch_num=$(read_channel_count "$meta") \
	|| fail "Could not read the image channel count"
dbg2 "Channels: $ch_num"

# CALLER is intentionally shared: sdg-run.sh will enforce sequential execution.
bash "$MAKECALLER" "$img" || fail "Caller generation failed for $img"
[[ -f $CALLER ]] || fail "Caller was not created: $CALLER"

declare -a expected_outputs=()
declare -a missing_outputs=()
collect_expected_outputs
find_missing_outputs

if (( ${#missing_outputs[@]} == 0 )); then
	msg "All configured secondary data already exist for $filename"
else
	msg "Generating ${#missing_outputs[@]} missing output(s) for $filename"
	bash "$FIJIONSERVER" "$CALLER" \
		|| fail "Fiji processing failed for $img"

	find_missing_outputs
	if (( ${#missing_outputs[@]} > 0 )); then
		printf 'Missing after Fiji processing:\n' >&2
		printf '  %s\n' "${missing_outputs[@]}" >&2
		fail "Fiji completed without producing every expected output"
	fi
fi

bash "$FIXPERMISSIONS" -d "$out_dir" \
	|| fail "Could not repair permissions for $out_dir"

msg "Secondary-data generation completed for $filename"
