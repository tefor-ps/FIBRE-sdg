#!/bin/bash

# Discover source images and describe the required work in an immutable plan.
#
# A plan records decisions; it does not run Fiji. This separation ensures that
# a pause/resume cycle executes the same inputs, series, macros, arguments, and
# expected outputs even if the live configuration changes in the meantime.

set -o errexit
set -o nounset
set -o pipefail

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Input selection:
  --image FILE      Add one source image; may be repeated
  --directory DIR   Recursively scan a directory; may be repeated
  --match TEXT      Require TEXT in the absolute image path

Plan options:
  --output FILE     Write the plan to FILE
  --priority        Mark the plan as priority work
  -h, --help        Show this help

With no --image or --directory, SDG_INPUT_ROOTS are scanned.
EOF
}

die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

images=()
directories=()
path_match=""
output_plan=""
priority=0

while (( $# > 0 )); do
	case $1 in
		--image)
			[[ -n ${2:-} ]] || die "--image requires a file"
			images+=("$2")
			shift 2
			;;
		--directory)
			[[ -n ${2:-} ]] || die "--directory requires a directory"
			directories+=("$2")
			shift 2
			;;
		--match)
			[[ -n ${2:-} ]] || die "--match requires text"
			path_match=$2
			shift 2
			;;
		--output)
			[[ -n ${2:-} ]] || die "--output requires a file"
			output_plan=$2
			shift 2
			;;
		--priority)
			priority=1
			shift
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

this_dir=$(dirname -- "$(realpath -- "$0")")
# shellcheck source=sdg-common.sh
source "$this_dir/sdg-common.sh"

sdg_load_fsdb "$this_dir" || die "could not load FSDB"
intro "$(basename "$0")"

sdg_require_commands awk find realpath sha256sum sort
sdg_require_vars \
	SECDATA_EXT MAKEMETA MAKECALLER STACKEXTENSION \
	SDG_PLAN_DIR SDG_CALLER_DIR SDG_GROUPS
sdg_require_files MAKEMETA MAKECALLER

mkdir -p -- "$SDG_PLAN_DIR" "$SDG_CALLER_DIR"

plan_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
if [[ -z $output_plan ]]; then
	output_plan="$SDG_PLAN_DIR/$plan_id.plan.tsv"
fi
output_plan=$(realpath -m -- "$output_plan")
mkdir -p -- "$(dirname -- "$output_plan")"
[[ ! -e $output_plan ]] \
	|| fail "Refusing to overwrite immutable plan: $output_plan"

temporary_plan=$(mktemp "$(dirname -- "$output_plan")/.sdg-plan.XXXXXX")
temporary_job=""
cleanup_temporary_files() {
	rm -f -- "$temporary_plan" "${temporary_job:-}"
}
trap cleanup_temporary_files EXIT

{
	printf 'SDG_PLAN\t1\n'
	printf 'META\tplan_id\t%s\n' "$plan_id"
	printf 'META\tcreated_utc\t%s\n' "$(date -u +%FT%TZ)"
	printf 'META\thost\t%s\n' "$(hostname)"
	printf 'META\tpriority\t%s\n' "$priority"
	printf 'META\tconfig\t%s\n' "$CONFIG"
} >"$temporary_plan"

candidate_images=()
declare -A image_seen=()

add_candidate_image() {
	local candidate=$1
	local extension
	local configured_extension
	local extension_supported=0

	candidate=$(realpath -- "$candidate" 2>/dev/null) || return 0
	[[ -f $candidate ]] || return 0
	[[ -z $path_match || $candidate == *"$path_match"* ]] || return 0

	extension=${candidate##*.}
	for configured_extension in $STACKEXTENSION; do
		if [[ ${extension,,} == ${configured_extension,,} ]]; then
			extension_supported=1
			break
		fi
	done
	(( extension_supported != 0 )) || return 0

	if [[ -z ${image_seen[$candidate]+known} ]]; then
		image_seen[$candidate]=1
		candidate_images+=("$candidate")
	fi
}

for image in "${images[@]}"; do
	add_candidate_image "$image"
done

if (( ${#images[@]} == 0 && ${#directories[@]} == 0 )); then
	read -r -a directories <<<"${SDG_INPUT_ROOTS:-}"
fi

for directory in "${directories[@]}"; do
	if [[ ! -d $directory ]]; then
		warn "Missing input root: $directory"
		continue
	fi

	while IFS= read -r -d '' image; do
		add_candidate_image "$image"
	done < <(find "$directory" -type f -print0)
done

if (( ${#candidate_images[@]} > 0 )); then
	mapfile -t candidate_images < <(
		printf '%s\n' "${candidate_images[@]}" | sort -u
	)
fi

configured_macro() {
	local variable_name=$1
	local macro_path=${!variable_name:-}

	[[ -n $macro_path && -f $macro_path ]] \
		|| fail "Configured macro missing: $variable_name=${macro_path:-<unset>}"
	printf '%s' "$macro_path"
}

# append_step and append_output operate on the job currently being assembled.
append_step() {
	local operation=$1
	local macro_path=$2
	local argument=$3

	(( ++step_sequence ))
	sdg_validate_field "step macro" "$macro_path"
	sdg_validate_field "step argument" "$argument"
	printf 'STEP\t%s\t%04d\t%s\t%s\t%s\n' \
		"$job_id" "$step_sequence" "$operation" "$macro_path" "$argument" \
		>>"$temporary_job"
}

append_output() {
	local output_path=$1

	sdg_validate_field "output" "$output_path"
	printf 'OUTPUT\t%s\t%s\n' "$job_id" "$output_path" >>"$temporary_job"
	(( ++output_count ))
}

output_is_missing() {
	local output_path=$1
	local channel_count=$2
	local base_path
	local extension
	local channel

	# The NRRD macro writes one file per channel. The plan records and verifies
	# those concrete files rather than the unsuffixed macro argument.
	if [[ $output_path == *.nrrd && $channel_count -gt 1 ]]; then
		base_path=${output_path%.*}
		extension=.${output_path##*.}
		for (( channel = 1; channel <= channel_count; channel++ )); do
			[[ -f $base_path-C$channel$extension ]] || return 0
		done
		return 1
	fi

	[[ ! -f $output_path ]]
}

append_output_set() {
	local output_path=$1
	local channel_count=$2
	local base_path
	local extension
	local channel

	if [[ $output_path == *.nrrd && $channel_count -gt 1 ]]; then
		base_path=${output_path%.*}
		extension=.${output_path##*.}
		for (( channel = 1; channel <= channel_count; channel++ )); do
			append_output "$base_path-C$channel$extension"
		done
	else
		append_output "$output_path"
	fi
}

group_for_image() {
	local image_path=$1
	local filename
	local group
	local match_variable
	local group_match

	filename=$(basename -- "$image_path")
	for group in $SDG_GROUPS; do
		[[ $group =~ ^[A-Z][A-Z0-9_]*$ ]] \
			|| fail "Invalid SDG group name: $group"

		match_variable=SDG_GROUP_${group}_MATCH
		group_match=${!match_variable:-}
		if [[ $group_match == ALL ||
			( -n $group_match && $filename == *"$group_match"* ) ]]; then
			printf '%s' "$group"
			return 0
		fi
	done

	printf 'DEFAULT'
}

selected_series() {
	local series_count=$1
	local specification=$2
	local item
	local range_start
	local range_end
	local series

	if [[ $specification == all ]]; then
		seq 1 "$series_count"
		return 0
	fi

	for item in ${specification//,/ }; do
		if [[ $item =~ ^([0-9]+)-([0-9]+)$ ]]; then
			range_start=${BASH_REMATCH[1]}
			range_end=${BASH_REMATCH[2]}
			for (( series = range_start; series <= range_end; series++ )); do
				if (( series >= 1 && series <= series_count )); then
					printf '%s\n' "$series"
				fi
			done
		elif [[ $item =~ ^[0-9]+$ ]] &&
			(( item >= 1 && item <= series_count )); then
			printf '%s\n' "$item"
		fi
	done | sort -nu
}

channel_count_for_series() {
	local metadata_path=$1
	local series=$2
	local fallback=$3
	local channel_count

	channel_count=$(awk -v target="$((series - 1))" '
		/^Series #[0-9]+/ {
			series_number = $2
			gsub(/^#/, "", series_number)
			inside_target = (series_number == target)
			next
		}
		inside_target && /SizeC/ { print $NF; exit }
	' "$metadata_path")

	if [[ $channel_count =~ ^[1-9][0-9]*$ ]]; then
		printf '%s' "$channel_count"
	else
		printf '%s' "$fallback"
	fi
}

append_preprocessing_steps() {
	local toggle_name
	local task_name
	local macro_path
	local suffix_variable

	preprocessing_suffix=$current_suffix
	for toggle_name in $(sdg_config_names _PPTOG); do
		[[ $toggle_name != GLOBAL_* ]] || continue
		[[ ${GLOBAL_PPTOG:-0} == 1 ]] || continue
		[[ ${!toggle_name:-0} == 1 ]] || continue

		task_name=${toggle_name%_PPTOG}
		macro_path=$(configured_macro "${task_name}_MAC")
		suffix_variable=${task_name}_PPSUFF
		preprocessing_suffix+=${!suffix_variable:-}
		append_step APPLY "$macro_path" "$preprocessing_suffix"
	done
	current_suffix=$preprocessing_suffix
}

append_manipulation_step() {
	local toggle_name
	local task_name
	local last_macro=""
	local last_suffix=""
	local accumulated_suffix=$current_suffix
	local suffix_variable
	local task_suffix

	[[ ${GLOBAL_IMTOG:-0} == 1 ]] || return 0

	# The legacy caller retained only the final manipulation result. Preserve
	# that behavior explicitly while moving the decision into the plan.
	for toggle_name in $(sdg_config_names _IMTOG); do
		[[ $toggle_name != GLOBAL_* ]] || continue
		[[ ${!toggle_name:-0} == 1 ]] || continue

		task_name=${toggle_name%_IMTOG}
		last_macro=$(configured_macro "${task_name}_MAC")
		suffix_variable=${task_name}_PPSUFF
		task_suffix=${!suffix_variable:-}

		if [[ $task_suffix == -* ]]; then
			accumulated_suffix=$preprocessing_suffix$task_suffix
		else
			accumulated_suffix+=$task_suffix
		fi
		last_suffix=$accumulated_suffix
	done

	if [[ -n $last_macro ]]; then
		append_step APPLY "$last_macro" "$last_suffix"
		current_suffix=$last_suffix
	fi
}

append_direct_exports() {
	local toggle_name
	local task_name
	local macro_path
	local suffix_variable
	local filetype_variable
	local output_path

	[[ ${GLOBAL_EXTOG:-0} == 1 ]] || return 0

	for toggle_name in $(sdg_config_names _EXTOG); do
		[[ $toggle_name != GLOBAL_* ]] || continue
		[[ ${!toggle_name:-0} == 1 ]] || continue

		task_name=${toggle_name%_EXTOG}
		macro_path=$(configured_macro "${task_name}_MAC")
		suffix_variable=${task_name}_SUFF
		filetype_variable=${task_name}_FT
		output_path="$output_directory/${output_basename}${current_suffix}${!suffix_variable:-}${!filetype_variable:-}"

		if output_is_missing "$output_path" "$channel_count"; then
			append_step DIRECT "$macro_path" "$output_path"
			append_output_set "$output_path" "$channel_count"
		fi
	done
}

save_macro_for_filetype() {
	case $1 in
		.png)
			configured_macro SAVEPNG_MAC
			;;
		.tif | .tiff)
			configured_macro SAVETIF_MAC
			;;
		.nrrd)
			configured_macro SAVENRRD_MAC
			;;
		*)
			fail "No save macro is configured for file type: $1"
			;;
	esac
}

append_derived_outputs() {
	local processing_toggles=()
	local processing_toggle
	local processing_task
	local processing_macro
	local processing_argument
	local processing_suffix_variable
	local variant_suffix

	local derived_toggle
	local derived_task
	local derived_macro
	local derived_suffix_variable
	local derived_filetype_variable
	local derived_suffix
	local filetype

	local annotation_toggle
	local annotation_task
	local annotation_suffix_variable
	local annotation_suffix
	local annotation_index
	local output_path
	local save_macro
	local -a annotation_macros
	local -a annotation_arguments

	if [[ ${GLOBAL_IPTOG:-0} == 1 ]]; then
		for processing_toggle in $(sdg_config_names _IPTOG); do
			[[ $processing_toggle != GLOBAL_* ]] || continue
			[[ ${!processing_toggle:-0} == 1 ]] || continue
			processing_toggles+=("$processing_toggle")
		done
	fi

	# An empty element represents the unprocessed source variant.
	(( ${#processing_toggles[@]} > 0 )) || processing_toggles+=("")

	for processing_toggle in "${processing_toggles[@]}"; do
		variant_suffix=$current_suffix
		processing_macro=""
		processing_argument=""

		if [[ -n $processing_toggle ]]; then
			processing_task=${processing_toggle%_IPTOG}
			processing_macro=$(configured_macro "${processing_task}_MAC")
			processing_suffix_variable=${processing_task}_IPSUFF
			processing_argument=${!processing_suffix_variable:-}
			variant_suffix+=$processing_argument
		fi

		for derived_toggle in $(sdg_config_names _SDTOG); do
			[[ $derived_toggle != GLOBAL_* ]] || continue
			[[ ${GLOBAL_SDTOG:-0} == 1 ]] || continue
			[[ ${!derived_toggle:-0} == 1 ]] || continue

			derived_task=${derived_toggle%_SDTOG}
			derived_macro=$(configured_macro "${derived_task}_MAC")
			derived_suffix_variable=${derived_task}_SUFF
			derived_filetype_variable=${derived_task}_FT
			derived_suffix=${!derived_suffix_variable:-}
			filetype=${!derived_filetype_variable:-}

			annotation_suffix=""
			annotation_macros=()
			annotation_arguments=()

			if [[ ${GLOBAL_IATOG:-0} == 1 ]]; then
				for annotation_toggle in $(sdg_config_names _IATOG); do
					[[ $annotation_toggle != GLOBAL_* ]] || continue
					[[ ${!annotation_toggle:-0} == 1 ]] || continue

					annotation_task=${annotation_toggle%_IATOG}
					annotation_macros+=(
						"$(configured_macro "${annotation_task}_MAC")"
					)
					annotation_suffix_variable=${annotation_task}_IASUFF
					annotation_suffix+=${!annotation_suffix_variable:-}
					annotation_arguments+=(
						"$variant_suffix$annotation_suffix$derived_suffix$filetype"
					)
				done
			fi

			output_path="$output_directory/${output_basename}${variant_suffix}${annotation_suffix}${derived_suffix}${filetype}"
			output_is_missing "$output_path" "$channel_count" || continue

			# Apply image processing once per variant, immediately before its first
			# required derived-data operation.
			if [[ -n $processing_macro ]]; then
				append_step APPLY "$processing_macro" "$processing_argument"
				processing_macro=""
			fi

			append_step DERIVE \
				"$derived_macro" \
				"$variant_suffix$derived_suffix$filetype"

			for annotation_index in "${!annotation_macros[@]}"; do
				append_step ANNOTATE \
					"${annotation_macros[$annotation_index]}" \
					"${annotation_arguments[$annotation_index]}"
			done

			save_macro=$(save_macro_for_filetype "$filetype")
			append_step SAVE "$save_macro" "$output_path"
			append_output_set "$output_path" "$channel_count"
		done
	done
}

job_count=0
skipped_for_size=0

for image in "${candidate_images[@]}"; do
	file_size=$(stat -c%s -- "$image")
	echo "$(basename $image): $file_size"
	if [[ ${minsize:-0} =~ ^[0-9]+$ && $file_size -lt ${minsize:-0} ]] ||
		[[ ${maxsize:-0} =~ ^[0-9]+$ &&
			${maxsize:-0} -gt 0 &&
			$file_size -gt ${maxsize:-0} ]]; then
		warn "Skipping size-incompatible image: $image"
		(( ++skipped_for_size ))
		continue
	fi

	metadata_output=$(bash "$MAKEMETA" "$image") \
		|| fail "Metadata extraction failed: $image"
	metadata_path=$(printf '%s\n' "$metadata_output" | tail -1)
	[[ -f $metadata_path ]] || fail "Metadata file missing for: $image"

	series_count=$(awk '/Series count/ { value = $NF } END { print value }' "$metadata_path")
	global_channel_count=$(awk '/SizeC/ { value = $NF } END { print value }' "$metadata_path")
	[[ $series_count =~ ^[1-9][0-9]*$ ]] || series_count=1
	[[ $global_channel_count =~ ^[1-9][0-9]*$ ]] || global_channel_count=1

	group=$(group_for_image "$image")
	series_variable=SDG_GROUP_${group}_SERIES
	series_specification=${!series_variable:-all}

	while IFS= read -r series; do
		[[ -n $series ]] || continue

		channel_count=$(channel_count_for_series \
			"$metadata_path" "$series" "$global_channel_count")

		filename=$(basename -- "$image")
		if [[ $filename == *.* && $filename != .* ]]; then
			basename_without_extension=${filename%.*}
		else
			basename_without_extension=$filename
		fi

		output_basename=$basename_without_extension
		if (( series_count > 1 )); then
			printf -v series_suffix '.Series%02d' "$series"
			output_basename+=$series_suffix
		fi

		output_directory="$(dirname -- "$image")/${basename_without_extension}${SECDATA_EXT}"
		job_id=$(sdg_job_id "$image" "$series" "$group")
		caller_path="$SDG_CALLER_DIR/$plan_id/$job_id.caller.ijm"

		temporary_job=$(mktemp)
		step_sequence=0
		output_count=0
		current_suffix=""
		preprocessing_suffix=""

		append_preprocessing_steps
		append_manipulation_step
		append_direct_exports
		append_derived_outputs

		if (( output_count > 0 )); then
			mkdir -p -- "$(dirname -- "$caller_path")"
			for plan_field in \
				"$job_id" "$image" "$group" "$caller_path" \
				"$output_directory" "$output_basename"; do
				sdg_validate_field "job field" "$plan_field"
			done

			printf 'JOB\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
				"$job_id" \
				"$image" \
				"$series" \
				"$series_count" \
				"$channel_count" \
				"$group" \
				"$caller_path" \
				"$output_directory" \
				"$output_basename" \
				>>"$temporary_plan"
			cat "$temporary_job" >>"$temporary_plan"
			(( ++job_count ))
		fi

		rm -f -- "$temporary_job"
		temporary_job=""
	done < <(selected_series "$series_count" "$series_specification")
done

{
	printf 'META\tjob_count\t%s\n' "$job_count"
	printf 'META\tskipped_size\t%s\n' "$skipped_for_size"
} >>"$temporary_plan"

chmod 640 "$temporary_plan"
mv -- "$temporary_plan" "$output_plan"
trap - EXIT

msg "Wrote SDG plan with $job_count job(s): $output_plan"
printf '%s\n' "$output_plan"
