#!/bin/bash

# Execute one image/series job from an immutable SDG plan.
#
# The scheduler may run several copies of this script. A per-job flock prevents
# accidental duplicate execution, while the caller and runtime directory are
# unique to the job ID.

set -o nounset
set -o pipefail

usage() {
	cat <<EOF
Usage: $(basename "$0") --plan FILE --job JOB_ID
EOF
}

die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

plan=""
job_id=""

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

sdg_require_commands flock
sdg_require_vars \
	MAKECALLER FIJIONSERVER FIXPERMISSIONS SDG_LOCK_DIR SDG_RUNTIME_DIR
sdg_require_files MAKECALLER FIJIONSERVER FIXPERMISSIONS
sdg_plan_assert_header "$plan"

job_record=$(awk -F '\t' -v id="$job_id" '
	$1 == "JOB" && $2 == id { print; exit }
' "$plan")
[[ -n $job_record ]] || fail "Job is absent from plan: $job_id"

IFS=$'\t' read -r \
	record_type parsed_job_id image series series_count channel_count group \
	caller_path output_directory output_basename \
	<<<"$job_record"

[[ $record_type == JOB && $parsed_job_id == "$job_id" ]] \
	|| fail "Malformed JOB record for: $job_id"
[[ -f $image ]] || fail "Input image is missing: $image"

mapfile -t expected_outputs < <(
	awk -F '\t' -v id="$job_id" '
		$1 == "OUTPUT" && $2 == id {
			print substr($0, length($1) + length($2) + 3)
		}
	' "$plan"
)
(( ${#expected_outputs[@]} > 0 )) || fail "Job has no expected outputs: $job_id"

job_runtime_directory="$SDG_RUNTIME_DIR/jobs/$job_id"
mkdir -p -- \
	"$SDG_LOCK_DIR/jobs" \
	"$job_runtime_directory" \
	"$output_directory"

exec {job_lock_fd}>>"$SDG_LOCK_DIR/jobs/$job_id.lock"
if ! flock -n "$job_lock_fd"; then
	warn "Job is already active: $job_id"
	exit 75
fi

{
	printf 'pid=%s\n' "$$"
	printf 'plan=%s\n' "$plan"
	printf 'image=%s\n' "$image"
	printf 'series=%s\n' "$series"
} >"$job_runtime_directory/owner"

child_pid=""
interrupted=0

forward_signal() {
	local signal_name=$1

	interrupted=1
	if [[ -n $child_pid ]]; then
		kill -s "$signal_name" "$child_pid" 2>/dev/null || true
	fi
}

cleanup_owner_record() {
	rm -f -- "$job_runtime_directory/owner"
}

trap 'forward_signal TERM' TERM
trap 'forward_signal INT' INT
trap cleanup_owner_record EXIT

outputs_are_complete() {
	local output_path
	local complete=0

	for output_path in "${expected_outputs[@]}"; do
		if [[ ! -f $output_path ]]; then
			printf '  %s\n' "$output_path" >&2
			complete=1
		fi
	done
	return "$complete"
}

if ! outputs_are_complete >/dev/null 2>&1; then
	bash "$MAKECALLER" \
		--plan "$plan" \
		--job "$job_id" \
		--output "$caller_path" \
		|| fail "Caller rendering failed: $job_id"

	msg "Running $job_id: $(basename -- "$image"), series $series/$series_count"
	bash "$FIJIONSERVER" --job-id "$job_id" "$caller_path" &
	child_pid=$!
	wait "$child_pid"
	fiji_status=$?
	child_pid=""

	(( interrupted == 0 )) || exit 130
	(( fiji_status == 0 )) || fail "Fiji failed with status $fiji_status: $job_id"

	if ! outputs_are_complete; then
		error "Missing planned outputs for job $job_id"
		fail "Output verification failed: $job_id"
	fi
fi

# Permission policy remains centralized in fsdb-core. This runtime step repairs
# only the completed output directory and never invokes sudo itself.
bash "$FIXPERMISSIONS" -d "$output_directory" \
	|| fail "Permission repair failed: $output_directory"

msg "Completed SDG job: $job_id"
