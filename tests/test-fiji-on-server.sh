#!/bin/bash

# Regression test for the server-side Fiji display wrapper. It uses a fake
# Xvfb server that creates a real Unix socket and a fake Fiji executable, so no
# graphical packages or Fiji installation are required.

set -o errexit
set -o nounset
set -o pipefail

repo=$(realpath -- "$(dirname -- "$0")/..")
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT

current_test="initialization"
report_failure() {
	local status=$?
	local line=${BASH_LINENO[0]:-unknown}

	printf 'FAIL: %s (line %s, status %s)\n' \
		"$current_test" "$line" "$status" >&2
	exit "$status"
}
trap report_failure ERR

mkdir -p \
	"$fixture/bin" \
	"$fixture/Fiji installation/java/runtime/bin" \
	"$fixture/runtime" \
	"$fixture/locks" \
	/tmp/.X11-unix

caller_one="$fixture/caller one.ijm"
caller_two="$fixture/caller two.ijm"
legacy_macro="$fixture/legacy macro.ijm"
legacy_image="$fixture/legacy image.tif"
touch "$caller_one" "$caller_two" "$legacy_macro" "$legacy_image"

cat >"$fixture/bin/Xvfb" <<'EOF'
#!/bin/bash
display=${1#:}
marker="/tmp/.X11-unix/X$display"
cleanup() {
	rm -f -- "$marker"
}
trap 'cleanup; exit 0' TERM INT
trap cleanup EXIT
touch "$marker"
while true; do
	sleep 1
done
EOF

cat >"$fixture/bin/xdpyinfo" <<'EOF'
#!/bin/bash
display=${DISPLAY#:}
[[ -e /tmp/.X11-unix/X$display ]]
EOF

cat >"$fixture/Fiji installation/fiji" <<'EOF'
#!/bin/bash
{
	flock 9
	printf 'DISPLAY=<%s>' "${DISPLAY:-unset}"
	for argument in "$@"; do
		printf '|<%s>' "$argument"
	done
	printf '\n'
} 9>>"$FIJI_TEST_LOCK" >>"$FIJI_TEST_OUTPUT"
sleep 0.3
EOF

cat >"$fixture/Fiji installation/java/runtime/bin/java" <<'EOF'
#!/bin/bash
exit 0
EOF

chmod +x \
	"$fixture/bin/Xvfb" \
	"$fixture/bin/xdpyinfo" \
	"$fixture/Fiji installation/fiji" \
	"$fixture/Fiji installation/java/runtime/bin/java"

cat >"$fixture/getVar.sh" <<EOF
FIJIDIR='$fixture/Fiji installation'
TIMEOUTMINUTES=1
LOG='$fixture/fiji-wrapper.log'
LOGDIR='$fixture'
D='test'
SDG_LOCK_DIR='$fixture/locks'
SDG_RUNTIME_DIR='$fixture/runtime'
SDG_FIJI_BACKEND='xvfb'
SDG_XVFB_DISPLAY_MIN=590
SDG_XVFB_DISPLAY_MAX=599
SDG_XVFB_STARTUP_ATTEMPTS=50
intro() { :; }
msg() { printf 'MSG: %s\n' "\$*"; }
warn() { printf 'WARN: %s\n' "\$*" >&2; }
error() { printf 'ERROR: %s\n' "\$*" >&2; }
fail() { printf 'FAIL: %s\n' "\$*" >&2; exit 128; }
dbg() { :; }
dbg2() { :; }
dbg3() { :; }
getLevel() { printf '0\n'; }
EOF

export SDG_GETVAR="$fixture/getVar.sh"
export FIJI_TEST_OUTPUT="$fixture/fiji-calls.txt"
export FIJI_TEST_LOCK="$fixture/fiji-calls.lock"
export PATH="$fixture/bin:$PATH"
# Native-headless must not accidentally depend on the developer's graphical
# login. Xvfb will set its own DISPLAY for virtual-display tests.
unset DISPLAY

current_test="two concurrent jobs receive distinct Xvfb displays"
printf 'TEST: %s\n' "$current_test"
bash "$repo/scripts/fijiOnServer.sh" --job-id one "$caller_one" &
first_pid=$!
bash "$repo/scripts/fijiOnServer.sh" --job-id two "$caller_two" &
second_pid=$!
wait "$first_pid"
wait "$second_pid"

mapfile -t xvfb_calls < <(grep '^DISPLAY=<:59[0-9]>' "$FIJI_TEST_OUTPUT")
[[ ${#xvfb_calls[@]} -eq 2 ]]
display_count=$(sed -n 's/^DISPLAY=<\(:[0-9][0-9]*\)>.*/\1/p' \
	"$FIJI_TEST_OUTPUT" | sort -u | wc -l)
[[ $display_count -eq 2 ]]
grep -Fq "|<-macro>|<$caller_one>" "$FIJI_TEST_OUTPUT"
grep -Fq "|<-macro>|<$caller_two>" "$FIJI_TEST_OUTPUT"
for display in $(sed -n 's/^DISPLAY=<:\([0-9][0-9]*\)>.*/\1/p' \
	"$FIJI_TEST_OUTPUT"); do
	[[ ! -e /tmp/.X11-unix/X$display ]]
done
printf 'PASS: %s\n' "$current_test"

current_test="native-headless is explicit and supplies --headless"
printf 'TEST: %s\n' "$current_test"
bash "$repo/scripts/fijiOnServer.sh" \
	--backend native-headless \
	--job-id native \
	"$caller_one" \
	2>"$fixture/native-headless.stderr"
grep -Fq "DISPLAY=<unset>|<--headless>|<-macro>|<$caller_one>" \
	"$FIJI_TEST_OUTPUT"
grep -Fq "Using Fiji native headless mode" \
	"$fixture/native-headless.stderr"
printf 'PASS: %s\n' "$current_test"

# ImageJ macros receive exactly one getArgument() value. Verify that the
# legacy multi-parameter call is compiled into one comma-bridged argument,
# rather than being split into several process arguments.
current_test="legacy parameters form one comma-bridged macro argument"
printf 'TEST: %s\n' "$current_test"
bash "$repo/scripts/fijiOnServer.sh" \
	--job-id legacy \
	"$legacy_image" \
	"$legacy_macro" \
	first second third
grep -Eq \
	"^DISPLAY=<:59[0-9]>\|<$legacy_image>\|<-macro>\|<$legacy_macro>\|<first,second,third>$" \
	"$FIJI_TEST_OUTPUT"
printf 'PASS: %s\n' "$current_test"

current_test="removed Weston backend is rejected"
printf 'TEST: %s\n' "$current_test"
if bash "$repo/scripts/fijiOnServer.sh" \
	--backend weston \
	--job-id invalid \
	"$caller_one" \
	>"$fixture/weston.stdout" \
	2>"$fixture/weston.stderr"; then
	printf 'Expected the removed Weston backend to be rejected\n' >&2
	exit 1
fi
grep -Fq "Unsupported Fiji backend: weston" "$fixture/weston.stderr"
printf 'PASS: %s\n' "$current_test"

printf 'PASS: all fijiOnServer regression tests\n'
