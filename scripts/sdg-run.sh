#!/bin/bash

# Execute jobs recorded in an immutable SDG plan.
#
# The runner is the only scheduling component. It limits concurrency, records
# results separately from the plan, consumes priority plans, and implements the
# drain/cancel controls exposed by sdg.sh.

set -o nounset
set -o pipefail

usage() {
	cat <<EOF
Usage: $(basename "$0") [--jobs N] [--lock-held] PLAN

Options:
  --jobs N       Maximum number of concurrent image/series jobs
  --lock-held    The caller already owns SDG_RUN_LOCK
EOF
}

die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

jobs_requested=""
lock_already_held=0
plan=""

while (( $# > 0 )); do
	case $1 in
		--jobs)
			[[ -n ${2:-} ]] || die "--jobs requires a positive integer"
			jobs_requested=$2
			shift 2
			;;
		--lock-held)
			lock_already_held=1
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		-*)
			die "unknown option: $1"
			;;
		*)
			[[ -z $plan ]] || die "only one plan may be executed"
			plan=$1
			shift
			;;
	esac
done

if [[ -z $plan ]]; then
	usage >&2
	exit 2
fi

this_dir=$(dirname -- "$(realpath -- "$0")")
# shellcheck source=sdg-common.sh
source "$this_dir/sdg-common.sh"

sdg_load_fsdb "$this_dir" || die "could not load FSDB"
intro "$(basename "$0")"

sdg_require_commands flock setsid
sdg_require_vars \
	MAKESECDATA FIJIONSERVER SDG_CONTROL_DIR SDG_LOCK_DIR \
	SDG_RUNTIME_DIR SDG_STATE_FILE SDG_RUN_LOCK SDG_JOBS
sdg_require_files MAKESECDATA FIJIONSERVER
sdg_plan_assert_header "$plan"

plan=$(realpath -- "$plan")
if [[ -z $jobs_requested ]]; then
	jobs_requested=$SDG_JOBS
fi
[[ $jobs_requested =~ ^[1-9][0-9]*$ ]] \
	|| fail "Invalid worker count: $jobs_requested"

mkdir -p -- \
	"$SDG_CONTROL_DIR/priority/incoming" \
	"$SDG_CONTROL_DIR/priority/accepted" \
	"$SDG_LOCK_DIR" \
	"$SDG_RUNTIME_DIR" \
	"$(dirname -- "$SDG_STATE_FILE")"

if (( lock_already_held == 0 )); then
	exec {run_lock_fd}>>"$SDG_RUN_LOCK"
	if ! flock -n "$run_lock_fd"; then
		msg "Another SDG run is active; nothing to do"
		exit 0
	fi
fi

plan_id=$(sdg_plan_id "$plan")
[[ -n $plan_id ]] || fail "Plan contains no plan_id: $plan"

total_jobs=$(awk -F '\t' '$1 == "JOB" { count++ } END { print count + 0 }' "$plan")
main_results="$plan.results.tsv"
touch "$main_results"
chmod 640 "$main_results"

# Parallel arrays make queue selection explicit without modifying plan files.
normal_job_ids=()
normal_plan_paths=()
priority_job_ids=()
priority_plan_paths=()
normal_index=0
priority_index=0

# Worker slots use the same array index for PID and job metadata.
worker_pids=()
worker_job_ids=()
worker_plan_paths=()
worker_started=()
active_workers=0
job_failed=0
control_mode=""

job_is_done() {
	local plan_path=$1
	local job_id=$2

	awk -F '\t' -v id="$job_id" '
		$1 == id && $2 == "DONE" { found = 1 }
		END { exit !found }
	' "$plan_path.results.tsv" 2>/dev/null
}

enqueue_plan() {
	local plan_path=$1
	local queue_type=$2
	local job_id

	sdg_plan_assert_header "$plan_path"
	while IFS= read -r job_id; do
		[[ -n $job_id ]] || continue
		job_is_done "$plan_path" "$job_id" && continue

		if [[ $queue_type == priority ]]; then
			priority_job_ids+=("$job_id")
			priority_plan_paths+=("$plan_path")
		else
			normal_job_ids+=("$job_id")
			normal_plan_paths+=("$plan_path")
		fi
	done < <(awk -F '\t' '$1 == "JOB" { print $2 }' "$plan_path")
}

accept_new_priority_plans() {
	local incoming_plan
	local accepted_plan
	local plan_name

	shopt -s nullglob
	for incoming_plan in "$SDG_CONTROL_DIR"/priority/incoming/*.plan.tsv; do
		plan_name=$(basename -- "$incoming_plan")
		accepted_plan="$SDG_CONTROL_DIR/priority/accepted/$plan_name"

		if [[ -e $accepted_plan ]]; then
			accepted_plan="$SDG_CONTROL_DIR/priority/accepted/${plan_name%.plan.tsv}.$$.plan.tsv"
		fi

		mv -- "$incoming_plan" "$accepted_plan" || continue
		touch "$accepted_plan.results.tsv"
		enqueue_plan "$accepted_plan" priority
		msg "Accepted priority plan: $accepted_plan"
	done
	shopt -u nullglob
}

load_retained_priority_plans() {
	local accepted_plan

	# Accepted plans remain here across pause/cancel. DONE records prevent
	# completed priority jobs from being queued again on resume.
	shopt -s nullglob
	for accepted_plan in "$SDG_CONTROL_DIR"/priority/accepted/*.plan.tsv; do
		enqueue_plan "$accepted_plan" priority
	done
	shopt -u nullglob
}

active_job_list() {
	local slot
	local list=""

	for slot in "${!worker_pids[@]}"; do
		[[ -n ${worker_pids[$slot]:-} ]] || continue
		list+="${list:+,}${worker_job_ids[$slot]}"
	done
	printf '%s' "$list"
}

write_state() {
	local status=$1
	local completed_jobs
	local temporary_state

	temporary_state=$(mktemp "$(dirname -- "$SDG_STATE_FILE")/.state.XXXXXX")
	completed_jobs=$(awk -F '\t' '
		$2 == "DONE" { done[$1] = 1 }
		END { print length(done) }
	' "$main_results")

	{
		printf 'status\t%s\n' "$status"
		printf 'plan\t%s\n' "$plan"
		printf 'plan_id\t%s\n' "$plan_id"
		printf 'runner_pid\t%s\n' "$$"
		printf 'jobs\t%s\n' "$jobs_requested"
		printf 'completed\t%s\n' "$completed_jobs"
		printf 'total\t%s\n' "$total_jobs"
		printf 'active\t%s\n' "$active_workers"
		printf 'active_jobs\t%s\n' "$(active_job_list)"
		printf 'updated_utc\t%s\n' "$(date -u +%FT%TZ)"
	} >"$temporary_state"

	chmod 640 "$temporary_state"
	mv -- "$temporary_state" "$SDG_STATE_FILE"
}

record_result() {
	local plan_path=$1
	local job_id=$2
	local status=$3
	local started_utc=$4
	local exit_status=$5

	printf '%s\t%s\t%s\t%s\t%s\n' \
		"$job_id" \
		"$status" \
		"$started_utc" \
		"$(date -u +%FT%TZ)" \
		"$exit_status" \
		>>"$plan_path.results.tsv"
}

find_free_worker_slot() {
	local slot

	for (( slot = 0; slot < jobs_requested; slot++ )); do
		if [[ -z ${worker_pids[$slot]:-} ]]; then
			printf '%s\n' "$slot"
			return 0
		fi
	done
	return 1
}

launch_job() {
	local plan_path=$1
	local job_id=$2
	local slot

	slot=$(find_free_worker_slot) || return 1
	worker_plan_paths[$slot]=$plan_path
	worker_job_ids[$slot]=$job_id
	worker_started[$slot]=$(date -u +%FT%TZ)

	# Each job gets a new process group. cancel-current can therefore terminate
	# Fiji and its descendants without using SIGKILL or affecting the runner.
	setsid bash "$MAKESECDATA" --plan "$plan_path" --job "$job_id" &
	worker_pids[$slot]=$!
	(( active_workers += 1 ))

	msg "Started job $job_id in worker $((slot + 1))/$jobs_requested"
}

reap_finished_workers() {
	local slot
	local pid
	local exit_status

	for slot in "${!worker_pids[@]}"; do
		pid=${worker_pids[$slot]:-}
		[[ -n $pid ]] || continue

		if kill -0 "$pid" 2>/dev/null; then
			continue
		fi

		wait "$pid"
		exit_status=$?

		if [[ $control_mode == cancel ]]; then
			msg "Canceled job remains pending: ${worker_job_ids[$slot]}"
		elif (( exit_status == 0 )); then
			record_result \
				"${worker_plan_paths[$slot]}" \
				"${worker_job_ids[$slot]}" \
				DONE \
				"${worker_started[$slot]}" \
				0
		else
			record_result \
				"${worker_plan_paths[$slot]}" \
				"${worker_job_ids[$slot]}" \
				FAILED \
				"${worker_started[$slot]}" \
				"$exit_status"
			warn "Job failed: ${worker_job_ids[$slot]}"
			job_failed=1
		fi

		worker_pids[$slot]=""
		worker_job_ids[$slot]=""
		worker_plan_paths[$slot]=""
		worker_started[$slot]=""
		(( active_workers -= 1 ))
	done
}

request_pause_from_signal() {
	touch "$SDG_CONTROL_DIR/paused"
	control_mode=pause
}

trap request_pause_from_signal TERM INT HUP

load_retained_priority_plans
enqueue_plan "$plan" normal
rm -f -- \
	"$SDG_CONTROL_DIR/stop.request" \
	"$SDG_CONTROL_DIR/cancel.request"

if [[ -e $SDG_CONTROL_DIR/paused ]]; then
	write_state paused
	msg "SDG is paused; plan retained"
	exit 0
fi

# Legacy ImageJ stubs are global. They are removed once, under a dedicated
# lock, before workers are launched. Per-job cleanup happens in fijiOnServer.sh.
bash "$FIJIONSERVER" --cleanup-stale-stubs \
	|| fail "Could not safely clean stale ImageJ stubs"

write_state running

while :; do
	accept_new_priority_plans

	if [[ -e $SDG_CONTROL_DIR/cancel.request && -z $control_mode ]]; then
		control_mode=cancel
		touch "$SDG_CONTROL_DIR/paused"

		for slot in "${!worker_pids[@]}"; do
			pid=${worker_pids[$slot]:-}
			[[ -n $pid ]] || continue
			kill -TERM -- "-$pid" 2>/dev/null || true
		done
	elif [[ -e $SDG_CONTROL_DIR/stop.request && -z $control_mode ]]; then
		control_mode=stop
	elif [[ -e $SDG_CONTROL_DIR/paused && -z $control_mode ]]; then
		control_mode=pause
	fi

	if [[ -z $control_mode ]]; then
		while (( active_workers < jobs_requested )); do
			if (( priority_index < ${#priority_job_ids[@]} )); then
				launch_job \
					"${priority_plan_paths[$priority_index]}" \
					"${priority_job_ids[$priority_index]}"
				(( priority_index += 1 ))
			elif (( normal_index < ${#normal_job_ids[@]} )); then
				launch_job \
					"${normal_plan_paths[$normal_index]}" \
					"${normal_job_ids[$normal_index]}"
				(( normal_index += 1 ))
			else
				break
			fi
		done
	fi

	reap_finished_workers
	if [[ -n $control_mode ]]; then
		write_state "draining-$control_mode"
	else
		write_state running
	fi

	if [[ -n $control_mode && $active_workers -eq 0 ]]; then
		break
	fi

	if [[ -z $control_mode &&
		$active_workers -eq 0 &&
		$normal_index -ge ${#normal_job_ids[@]} &&
		$priority_index -ge ${#priority_job_ids[@]} ]]; then
		# Close the small race in which a priority plan arrives as the final
		# ordinary job exits.
		accept_new_priority_plans
		if (( priority_index >= ${#priority_job_ids[@]} )); then
			break
		fi
	fi

	sleep 1
done

case $control_mode in
	pause)
		write_state paused
		msg "Paused after active jobs finished"
		;;
	cancel)
		rm -f -- "$SDG_CONTROL_DIR/cancel.request"
		write_state paused
		msg "Canceled gracefully; plan remains available for resume"
		;;
	stop)
		rm -f -- \
			"$SDG_CONTROL_DIR/stop.request" \
			"$SDG_CONTROL_DIR/paused"
		write_state stopped
		msg "Stopped; remaining jobs were discarded"
		;;
	*)
		if (( job_failed != 0 )); then
			write_state failed
		else
			write_state completed
			msg "Plan completed: $plan"
		fi
		;;
esac

(( job_failed == 0 ))
