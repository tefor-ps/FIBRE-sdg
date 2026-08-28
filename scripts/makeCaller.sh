#!/bin/bash

# Render one job from an SDG plan as a self-contained Fiji caller macro.
#
# This script performs no planning. It translates the ordered STEP records for
# one job and writes the caller atomically, which allows multiple jobs to render
# callers concurrently without sharing caller.ijm.

set -o errexit
set -o nounset
set -o pipefail

usage() {
	cat <<EOF
Usage: $(basename "$0") --plan FILE --job JOB_ID [--output CALLER.IJM]
EOF
}

die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

plan=""
job_id=""
output=""

while (( $# > 0 )); do
	case $1 in
		--plan)
			[[ -n ${2:-} ]] || die "--plan requires a file"
			plan=$2
			shift 2
			;;
		--job)
			[[ -n ${2:-} ]] || die "--job requires an ID"
			job_id=$2
			shift 2
			;;
		--output)
			[[ -n ${2:-} ]] || die "--output requires a file"
			output=$2
			shift 2
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			die "unknown option: $1"
			;;
	esac
done

if [[ -z $plan || -z $job_id ]]; then
	usage >&2
	exit 2
fi

this_dir=$(dirname -- "$(realpath -- "$0")")
# shellcheck source=sdg-common.sh
source "$this_dir/sdg-common.sh"

sdg_load_fsdb "$this_dir" || die "could not load FSDB"
intro "$(basename "$0")"
sdg_plan_assert_header "$plan"

job_record=$(awk -F '\t' -v id="$job_id" '
	$1 == "JOB" && $2 == id { print; exit }
' "$plan")
[[ -n $job_record ]] || fail "Job is absent from plan: $job_id"

IFS=$'\t' read -r \
	record_type parsed_job_id image series series_count channel_count group \
	planned_caller output_directory output_basename \
	<<<"$job_record"

[[ $record_type == JOB && $parsed_job_id == "$job_id" ]] \
	|| fail "Malformed JOB record for: $job_id"

if [[ -z $output ]]; then
	output=$planned_caller
fi

mkdir -p -- "$(dirname -- "$output")"
temporary_caller=$(mktemp "$(dirname -- "$output")/.caller.XXXXXX")
trap 'rm -f -- "$temporary_caller"' EXIT

{
	printf '// Generated from %s\n' "$(sdg_ij_escape "$plan")"
	printf '// Job %s; group %s; series %s/%s; channels %s\n\n' \
		"$job_id" "$group" "$series" "$series_count" "$channel_count"

	printf 'run("Close All");\n'
	printf 'print("\\\\Clear");\n'
	printf 'run("Bio-Formats Windowless Importer", '
	printf '"open=[%s] autoscale color_mode=Default ' "$(sdg_ij_escape "$image")"
	printf 'rois_import=[ROI manager] view=Hyperstack '
	printf 'stack_order=XYCZT series_%s");\n' "$series"
	printf 'IID=getImageID();\n'

	if (( series_count > 1 )); then
		printf 'rename("%s");\n' "$(sdg_ij_escape "$output_basename")"
	fi

	while IFS=$'\t' read -r \
		step_record step_job_id sequence operation macro_path argument extra; do
		[[ $step_record == STEP && $step_job_id == "$job_id" ]] || continue
		[[ -z ${extra:-} ]] || fail "Malformed STEP record: $sequence"

		macro_path=$(sdg_ij_escape "$macro_path")
		argument=$(sdg_ij_escape "$argument")
		printf '\n// STEP %s %s\n' "$sequence" "$operation"

		case $operation in
			APPLY | DIRECT)
				printf 'selectImage(IID);\n'
				printf 'runMacro("%s", "%s");\n' "$macro_path" "$argument"
				printf 'IID=getImageID();\n'
				;;
			DERIVE)
				printf 'selectImage(IID);\n'
				printf 'runMacro("%s", "%s");\n' "$macro_path" "$argument"
				;;
			ANNOTATE | SAVE)
				printf 'runMacro("%s", "%s");\n' "$macro_path" "$argument"
				;;
			*)
				fail "Unsupported plan operation: $operation"
				;;
		esac
	done <"$plan"

	printf '\nprint("Done: %s");\n' "$job_id"
	printf 'run("Quit");\n'
} >"$temporary_caller"

chmod 640 "$temporary_caller"
mv -- "$temporary_caller" "$output"
trap - EXIT

msg "Rendered caller: $output"
printf '%s\n' "$output"
