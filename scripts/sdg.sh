#!/bin/bash

# Operator entry point for secondary-data generation.
#
# This script deliberately contains no image-processing logic. It coordinates
# the planner and runner, exposes operational controls, and acquires the run
# lock before discovery so overlapping cron invocations cannot create duplicate
# plans.

set -o nounset
set -o pipefail

usage() {
	cat <<EOF
Usage: $(basename "$0") COMMAND [OPTIONS]

Commands:
  plan [planner options]        Create a plan without executing it
  run [--jobs N] [options]     Discover, plan, and execute configured inputs
  process [--jobs N] IMAGE     Plan and execute one image
  execute [--jobs N] PLAN      Execute an existing plan
  pause                         Drain active jobs and retain unfinished work
  resume [--jobs N]            Continue the retained plan
  stop                          Drain active jobs and discard unfinished work
  cancel-current               Gracefully terminate active jobs, then pause
  priority IMAGE               Queue one image ahead of ordinary work
  status                        Print machine-readable runner state
EOF
}

die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

if (( $# == 0 )); then
	usage >&2
	exit 2
fi

if [[ $1 == -h || $1 == --help ]]; then
	usage
	exit 0
fi

command_name=$1
shift

this_dir=$(dirname -- "$(realpath -- "$0")")
# shellcheck source=sdg-common.sh
source "$this_dir/sdg-common.sh"

sdg_load_fsdb "$this_dir" || die "could not load FSDB"
intro "$(basename "$0")"

sdg_require_commands flock
sdg_require_vars \
	SDGPLAN SDGRUN SDG_PLAN_DIR SDG_CONTROL_DIR SDG_LOCK_DIR \
	SDG_STATE_FILE SDG_RUN_LOCK SDG_JOBS
sdg_require_files SDGPLAN SDGRUN

mkdir -p -- \
	"$SDG_PLAN_DIR" \
	"$SDG_CONTROL_DIR/priority/incoming" \
	"$SDG_LOCK_DIR" \
	"$(dirname -- "$SDG_STATE_FILE")"

# Results populated by parse_jobs().
jobs_requested=$SDG_JOBS
remaining_args=()

parse_jobs() {
	jobs_requested=$SDG_JOBS
	remaining_args=()

	while (( $# > 0 )); do
		case $1 in
			--jobs)
				[[ -n ${2:-} ]] || fail "--jobs requires a positive integer"
				jobs_requested=$2
				shift 2
				;;
			*)
				remaining_args+=("$1")
				shift
				;;
		esac
	done

	[[ $jobs_requested =~ ^[1-9][0-9]*$ ]] \
		|| fail "Invalid worker count: $jobs_requested"
}

runner_is_active() {
	local lock_fd

	exec {lock_fd}>>"$SDG_RUN_LOCK"
	if flock -n "$lock_fd"; then
		flock -u "$lock_fd"
		exec {lock_fd}>&-
		return 1
	fi

	exec {lock_fd}>&-
	return 0
}

new_plan_path() {
	printf '%s/%s-%s.plan.tsv\n' \
		"$SDG_PLAN_DIR" \
		"$(date -u +%Y%m%dT%H%M%SZ)" \
		"$$"
}

plan_and_run() {
	local plan_path
	local run_fd
	local planner_status

	# The same descriptor remains open while planner and runner execute. The
	# runner receives --lock-held so it does not try to lock itself out.
	exec {run_fd}>>"$SDG_RUN_LOCK"
	if ! flock -n "$run_fd"; then
		msg "Another SDG run is active; cron overlap skipped"
		return 0
	fi

	if [[ -e $SDG_CONTROL_DIR/paused ]]; then
		msg "SDG is paused; no new plan was created"
		return 0
	fi

	plan_path=$(new_plan_path)
	bash "$SDGPLAN" --output "$plan_path" "${remaining_args[@]}"
	planner_status=$?
	if (( planner_status != 0 )); then
		return "$planner_status"
	fi

	bash "$SDGRUN" --lock-held --jobs "$jobs_requested" "$plan_path"
}

mark_inactive_plan_stopped() {
	local temporary_state

	temporary_state=$(mktemp "$(dirname -- "$SDG_STATE_FILE")/.state.XXXXXX")
	awk -F '\t' '
		$1 == "status" { print "status\tstopped"; next }
		{ print }
	' "$SDG_STATE_FILE" >"$temporary_state"
	mv -- "$temporary_state" "$SDG_STATE_FILE"
}

case $command_name in
	plan)
		exec bash "$SDGPLAN" "$@"
		;;

	run)
		parse_jobs "$@"
		plan_and_run
		;;

	process)
		parse_jobs "$@"
		(( ${#remaining_args[@]} == 1 )) || fail "process requires one IMAGE"
		remaining_args=(--image "${remaining_args[0]}")
		plan_and_run
		;;

	execute)
		parse_jobs "$@"
		(( ${#remaining_args[@]} == 1 )) || fail "execute requires one PLAN"
		exec bash "$SDGRUN" --jobs "$jobs_requested" "${remaining_args[0]}"
		;;

	pause)
		touch "$SDG_CONTROL_DIR/paused"
		if runner_is_active; then
			msg "Pause requested; active jobs will finish"
		else
			msg "SDG paused"
		fi
		;;

	resume)
		parse_jobs "$@"
		(( ${#remaining_args[@]} == 0 )) || fail "resume accepts only --jobs N"

		state_status=$(sdg_read_state_value "$SDG_STATE_FILE" status)
		state_plan=$(sdg_read_state_value "$SDG_STATE_FILE" plan)

		# A global pause can exist without a retained plan. In that case resume
		# merely enables future cron runs.
		if [[ $state_status != paused && -e $SDG_CONTROL_DIR/paused ]]; then
			rm -f -- \
				"$SDG_CONTROL_DIR/paused" \
				"$SDG_CONTROL_DIR/cancel.request"
			msg "Scheduling enabled; there was no paused plan"
			exit 0
		fi

		[[ $state_status == paused && -f $state_plan ]] \
			|| fail "No paused plan is available"

		rm -f -- \
			"$SDG_CONTROL_DIR/paused" \
			"$SDG_CONTROL_DIR/cancel.request"
		exec bash "$SDGRUN" --jobs "$jobs_requested" "$state_plan"
		;;

	stop)
		if runner_is_active; then
			touch "$SDG_CONTROL_DIR/stop.request"
			msg "Stop requested; active jobs will finish"
		else
			state_status=$(sdg_read_state_value "$SDG_STATE_FILE" status)
			rm -f -- \
				"$SDG_CONTROL_DIR/paused" \
				"$SDG_CONTROL_DIR/stop.request"

			if [[ $state_status == paused ||
				$state_status == running ||
				$state_status == draining-* ]]; then
				mark_inactive_plan_stopped
				msg "Inactive plan marked stopped"
			else
				msg "No active or paused plan"
			fi
		fi
		;;

	cancel-current)
		if runner_is_active; then
			touch \
				"$SDG_CONTROL_DIR/paused" \
				"$SDG_CONTROL_DIR/cancel.request"
			msg "Graceful cancellation requested"
		else
			warn "No active jobs"
		fi
		;;

	priority)
		(( $# == 1 )) || fail "priority requires one IMAGE"

		priority_plan="$SDG_CONTROL_DIR/priority/incoming/$(date -u +%Y%m%dT%H%M%SZ)-$$.plan.tsv"
		bash "$SDGPLAN" --priority --image "$1" --output "$priority_plan" \
			|| exit $?

		exec {priority_fd}>>"$SDG_RUN_LOCK"
		if ! flock -n "$priority_fd"; then
			msg "Priority plan queued"
		elif [[ -e $SDG_CONTROL_DIR/paused ]]; then
			msg "Priority plan queued until resume"
		else
			plan_name=$(basename -- "$priority_plan")
			mv -- "$priority_plan" "$SDG_PLAN_DIR/$plan_name"
			exec bash "$SDGRUN" \
				--lock-held \
				--jobs "$SDG_JOBS" \
				"$SDG_PLAN_DIR/$plan_name"
		fi
		;;

	status)
		if [[ -f $SDG_STATE_FILE ]]; then
			cat "$SDG_STATE_FILE"
		else
			printf 'status\tidle\n'
		fi

		if [[ -e $SDG_CONTROL_DIR/paused ]]; then
			printf 'global_pause\tyes\n'
		else
			printf 'global_pause\tno\n'
		fi
		;;

	*)
		usage >&2
		fail "Unknown command: $command_name"
		;;
esac
