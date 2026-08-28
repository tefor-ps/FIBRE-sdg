#!/bin/bash

# End-to-end regression test using fake metadata, Fiji, and permissions tools.
# It exercises the real planner, caller renderer, per-job executor, and runner.

set -o errexit
set -o nounset
set -o pipefail

repo=$(realpath -- "$(dirname -- "$0")/..")
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT

mkdir -p "$fixture/macros" "$fixture/var"
touch "$fixture/input.tif"
for name in mip savepng; do
	touch "$fixture/macros/$name.ijm"
done

cat >"$fixture/sdg.config" <<EOF
GLOBAL_PPTOG 0
GLOBAL_IMTOG 0
GLOBAL_EXTOG 0
GLOBAL_IPTOG 0
GLOBAL_SDTOG 1
MIP_SDTOG 1
GLOBAL_IATOG 0
EOF

cat >"$fixture/metadata.sh" <<'EOF'
#!/bin/bash
out="$1.meta.txt"
printf '%s\n' \
	'Series count = 2' \
	'Series #0' \
	'SizeC = 2' \
	'Series #1' \
	'SizeC = 1' \
	>"$out"
printf '%s\n' "$out"
EOF

cat >"$fixture/fiji.sh" <<'EOF'
#!/bin/bash
if [[ ${1:-} == --cleanup-stale-stubs ]]; then
	exit 0
fi
shift 2
caller=$1
while IFS= read -r output; do
	mkdir -p -- "$(dirname -- "$output")"
	: >"$output"
done < <(
	sed -n 's@^runMacro("[^"]*savepng\.ijm", "\([^"]*\.png\)");$@\1@p' "$caller"
)
EOF

cat >"$fixture/fix-permissions.sh" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$fixture/metadata.sh" "$fixture/fiji.sh" "$fixture/fix-permissions.sh"

cat >"$fixture/getVar.sh" <<EOF
CONFIG='$fixture/sdg.config'
SECDATA_EXT='-secData'
STACKEXTENSION='tif'
SDG_INPUT_ROOTS='$fixture'
SDG_GROUPS='DEFAULT'
SDG_GROUP_DEFAULT_MATCH='ALL'
SDG_GROUP_DEFAULT_SERIES='all'
SDG_PLAN_DIR='$fixture/var/plans'
SDG_CALLER_DIR='$fixture/var/callers'
SDG_CONTROL_DIR='$fixture/var/control'
SDG_LOCK_DIR='$fixture/var/locks'
SDG_RUNTIME_DIR='$fixture/var/runtime'
SDG_STATE_FILE='$fixture/var/runtime/state.tsv'
SDG_RUN_LOCK='$fixture/var/locks/run.lock'
SDG_JOBS=2
MAKEMETA='$fixture/metadata.sh'
MAKECALLER='$repo/scripts/makeCaller.sh'
MAKESECDATA='$repo/scripts/makeSecData.sh'
FIJIONSERVER='$fixture/fiji.sh'
FIXPERMISSIONS='$fixture/fix-permissions.sh'
SDGPLAN='$repo/scripts/sdg-plan.sh'
SDGRUN='$repo/scripts/sdg-run.sh'
GLOBAL_PPTOG=0
GLOBAL_IMTOG=0
GLOBAL_EXTOG=0
GLOBAL_IPTOG=0
GLOBAL_SDTOG=1
MIP_SDTOG=1
GLOBAL_IATOG=0
MIP_MAC='$fixture/macros/mip.ijm'
MIP_SUFF='.mip'
MIP_FT='.png'
SAVEPNG_MAC='$fixture/macros/savepng.ijm'
intro() { :; }
msg() { printf 'MSG: %s\n' "\$*" >&2; }
warn() { printf 'WARN: %s\n' "\$*" >&2; }
error() { printf 'ERROR: %s\n' "\$*" >&2; }
fail() { printf 'FAIL: %s\n' "\$*" >&2; return 1; }
dbg() { :; }
dbg2() { :; }
dbg3() { :; }
getLevel() { :; }
EOF

export SDG_GETVAR="$fixture/getVar.sh"
plan=$(bash "$repo/scripts/sdg-plan.sh" \
	--image "$fixture/input.tif" \
	--output "$fixture/var/two-series.plan.tsv" \
	| tail -1)

job_count=$(awk -F '\t' '$1 == "JOB" { count++ } END { print count + 0 }' "$plan")
[[ $job_count -eq 2 ]]

before=$(sha256sum "$plan")
bash "$repo/scripts/sdg-run.sh" --jobs 2 "$plan"
after=$(sha256sum "$plan")
[[ $before == "$after" ]]

final_status=$(awk -F '\t' '$1 == "status" { print $2 }' \
	"$fixture/var/runtime/state.tsv")
output_count=$(find "$fixture" -type f -name '*.png' | wc -l)
caller_count=$(find "$fixture/var/callers" -type f -name '*.caller.ijm' | wc -l)

[[ $final_status == completed ]]
[[ $output_count -eq 2 ]]
[[ $caller_count -eq 2 ]]

printf 'PASS: two-series plan, unique callers, two-worker execution, and immutable plan\n'
