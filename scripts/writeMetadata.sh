#!/bin/bash

# Extract Bio-Formats and ExifTool metadata beside one source image.
#
# Dependencies are provisioned by the installer. This runtime script reports a
# missing prerequisite instead of installing packages with sudo.

# fsdb-rev-date: 260828

set -o pipefail

usage() {
	printf 'Usage: %s IMAGE\n' "$(basename "$0")"
}

if (( $# != 1 )); then
	usage >&2
	exit 2
fi

this_dir=$(dirname -- "$(realpath -- "$0")")
# shellcheck source=sdg-common.sh
source "$this_dir/sdg-common.sh"

sdg_load_fsdb "$this_dir" || exit 1
intro "$(basename "$0")"

sdg_require_vars SECDATA_EXT SCRIPTSDIR
sdg_require_commands exiftool

image=$(realpath -- "$1") || fail "Cannot resolve input image: $1"
[[ -f $image ]] || fail "Input image does not exist: $image"

image_directory=$(dirname -- "$image")
filename=$(basename -- "$image")
if [[ $filename == *.* && $filename != .* ]]; then
	basename_without_extension=${filename%.*}
else
	basename_without_extension=$filename
fi

output_directory="$image_directory/${basename_without_extension}${SECDATA_EXT}"
metadata_file="$output_directory/$basename_without_extension.meta.txt"
mkdir -p -- "$output_directory"

showinf="$SCRIPTSDIR/bftools/showinf"
[[ -x $showinf ]] || fail \
	"Missing executable Bio-Formats showinf: $showinf. Run ${BFT_SETUP:-the SDG Bio-Formats setup}."

# Bio-Formats' command-line wrapper invokes java from PATH. Append Fiji's
# bundled Java as a fallback without overriding an existing system Java.
fiji_java_helper="$this_dir/configureFijiJava.sh"
[[ -f $fiji_java_helper ]] \
	|| fail "Cannot find Fiji Java helper: $fiji_java_helper"
# shellcheck source=configureFijiJava.sh
source "$fiji_java_helper" \
	|| fail "Could not load Fiji Java helper: $fiji_java_helper"
configureFijiJava \
	|| fail "Could not configure Fiji's bundled Java runtime"

# Increase the Bio-Formats wrapper's default heap from 512 MiB to 2 GiB.
export BF_MAX_MEM=2g

{
	printf '\n------------------------\n'
	printf 'Bio-Formats metadata for %s\n' "$filename"
	printf '%s\n' '------------------------'
} >"$metadata_file"

if ! bash "$showinf" -nopix "$image" \
	| grep -v 'Parsing block' \
	>>"$metadata_file"; then
	error "Bio-Formats metadata extraction failed: $image"
	exit 1
fi

{
	printf '\n------------------------\n'
	printf 'ExifTool metadata for %s\n' "$filename"
	printf '%s\n' '------------------------'
} >>"$metadata_file"

exiftool_status=0
exiftool "$image" >>"$metadata_file" 2>&1 || exiftool_status=$?

if (( exiftool_status != 0 )); then
	{
		printf '\nExifTool note: extraction returned status %s.\n' "$exiftool_status"
		printf '%s\n' \
			'Partial filesystem metadata above was retained; processing continues.'
	} >>"$metadata_file"

	warn "ExifTool could not fully interpret $image (status $exiftool_status); partial metadata retained"
fi

# The planner consumes the final stdout line as the metadata path.
printf '%s\n' "$metadata_file"
