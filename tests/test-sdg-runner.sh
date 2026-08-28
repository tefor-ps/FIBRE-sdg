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
truncate -s 200 "$fixture/oversized.tif"
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
COMP='test-host'
minsize=0
maxsize=100
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
fail() { printf 'FAIL: %s\n' "\$*" >&2; exit 128; }
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
[[ $(head -1 "$plan") == $'SDG_PLAN\t2' ]]
[[ $(awk -F '\t' '$1 == "IMAGE" { print $3; exit }' "$plan") -eq 0 ]]

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

# Planning is host-independent: the oversized image remains in the plan and
# metadata is retained, but the runner defers its jobs before caller/Fiji work.
deferred_plan=$(bash "$repo/scripts/sdg-plan.sh" \
	--image "$fixture/oversized.tif" \
	--output "$fixture/var/deferred.plan.tsv" \
	| tail -1)

[[ $(awk -F '\t' '$1 == "IMAGE" { print $3; exit }' "$deferred_plan") -eq 200 ]]
[[ $(awk -F '\t' '$1 == "JOB" { count++ } END { print count + 0 }' \
	"$deferred_plan") -eq 2 ]]

before=$(sha256sum "$deferred_plan")
bash "$repo/scripts/sdg-run.sh" --jobs 2 "$deferred_plan"
after=$(sha256sum "$deferred_plan")
[[ $before == "$after" ]]

final_status=$(awk -F '\t' '$1 == "status" { print $2 }' \
	"$fixture/var/runtime/state.tsv")
deferred_count=$(awk -F '\t' '$2 == "DEFERRED" { count++ } END { print count + 0 }' \
	"$deferred_plan.results.tsv")
caller_count=$(find "$fixture/var/callers" -type f -name '*.caller.ijm' | wc -l)

[[ $final_status == deferred ]]
[[ $deferred_count -eq 2 ]]
[[ $caller_count -eq 2 ]]
grep -Fq 'above host maximum=100' "$deferred_plan.results.tsv"

printf 'PASS: host-independent planning and runner-side size deferral\n'

# Version 1 plans have no IMAGE record. They remain executable, with the runner
# obtaining the source size through stat before applying the host profile.
legacy_plan="$fixture/var/legacy-v1.plan.tsv"
awk -F '\t' 'BEGIN { OFS = "\t" }
	NR == 1 { print "SDG_PLAN", "1"; next }
	$1 != "IMAGE" { print }
' "$deferred_plan" > "$legacy_plan"

bash "$repo/scripts/sdg-run.sh" --jobs 2 "$legacy_plan"
legacy_deferred_count=$(awk -F '\t' '
	$2 == "DEFERRED" { count++ }
	END { print count + 0 }
' "$legacy_plan.results.tsv")

[[ $legacy_deferred_count -eq 2 ]]
grep -Fq 'size=200' "$legacy_plan.results.tsv"

printf 'PASS: version 1 plan size-policy compatibility\n'

# A version 2 plan must contain the recorded size. Missing structural data is
# fatal and must never be disguised as an ordinary host-capacity deferral.
malformed_plan="$fixture/var/malformed-v2.plan.tsv"
awk -F '\t' '$1 != "IMAGE" { print }' "$deferred_plan" > "$malformed_plan"

set +o errexit
bash "$repo/scripts/sdg-run.sh" --jobs 2 "$malformed_plan" \
	> "$fixture/malformed.stdout" \
	2> "$fixture/malformed.stderr"
malformed_status=$?
set -o errexit

[[ $malformed_status -ne 0 ]]
grep -Fq 'Cannot resolve planned image size for job' "$fixture/malformed.stderr"
[[ $(awk -F '\t' '$2 == "FAILED" { count++ } END { print count + 0 }' \
	"$malformed_plan.results.tsv") -eq 2 ]]
! grep -Fq $'\tDEFERRED\t' "$malformed_plan.results.tsv"
[[ $(awk -F '\t' '$1 == "status" { print $2 }' \
	"$fixture/var/runtime/state.tsv") == failed ]]

printf 'PASS: malformed version 2 plan fails instead of deferring\n'
