#!/usr/bin/env bash
# The workspace's runner (decision 233) runs the suites of the workspace's
# tests/ directory, and no others, through the product's runner library, at
# most RUN_ALL_JOBS at a time, and fails when one of them fails. Its output is
# a serial run's: each suite's whole, in the suites' order.
# shellcheck disable=SC2016 # the generated suites' lines expand when they run, not here
set -u
set -o pipefail
export LC_ALL=C
# The suite's verdict is its own: no caller's RUN_ALL_JOBS reaches a run
# that does not set its own, so the default is what is under test (the
# tests lens's N1 of S2's third ship gate).
unset RUN_ALL_JOBS
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
ROOT=$(cd "$TEST_DIR/.." && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$ROOT/foundation/tests/lib/assert.sh"

SCRATCH=$(mktemp -d)
SCRATCH=$(CDPATH='' cd -P -- "$SCRATCH" && pwd -P)
trap 'chmod -R u+rwx "$SCRATCH" 2>/dev/null; rm -rf "$SCRATCH"' EXIT

# write_suite FILE NAME: a suite with one passing assertion. The runner
# gives a suite no arguments, so it finds the assertion library through
# ASSERT_LIB, never through a path pasted into its source.
export ASSERT_LIB="$ROOT/foundation/tests/lib/assert.sh"
write_suite() {
  printf '%s\n' '#!/usr/bin/env bash' 'set -u' '. "$ASSERT_LIB"' "assert_eq a a '$2'" 'assert_done' >"$1"
}
# suite FILE LINE...: a suite of these lines, after the assertion library.
suite() {
  local f=$1
  shift
  printf '%s\n' '#!/usr/bin/env bash' 'set -u' '. "$ASSERT_LIB"' "$@" >"$f"
}
# block OUT SUITE: the lines the runner printed for SUITE, from its === line
# through its PASS or FAIL line.
block() {
  printf '%s\n' "$1" | awk -v s="$2" '
    $0 == "=== " s { on = 1 }
    on { print }
    on && ($0 == "PASS " s || $0 == "FAIL " s) { exit }'
}
# wait_for FILE [TENTHS]: until FILE exists, for TENTHS of a second at most,
# a minute by default; exit 1 when it never does. A case that orders
# suites run side by side does it by such a handshake, each wait bounded
# and failing loudly, never by a sleep.
wait_for() {
  local i=0
  while [ ! -e "$1" ]; do
    [ "$i" -lt "${2:-600}" ] || return 1
    sleep 0.1
    i=$((i + 1))
  done
}
export -f wait_for

# A copy of the workspace layout: tests/run-all.sh beside the product library.
W="$SCRATCH/ws"
mkdir -p "$W/tests" "$W/foundation/tests/lib"
cp "$TEST_DIR/run-all.sh" "$W/tests/run-all.sh" 2>/dev/null
cp "$ROOT/foundation/tests/lib/runner.sh" "$ROOT/foundation/tests/lib/assert.sh" \
  "$W/foundation/tests/lib/" 2>/dev/null
cp "$ROOT/foundation/tests/run-all.sh" "$W/foundation/tests/run-all.sh" 2>/dev/null
write_suite "$W/tests/test_workspace.sh" workspace
write_suite "$W/foundation/tests/test_product.sh" product
RUN_ALL="$W/tests/run-all.sh"

out=$(cd "$SCRATCH" && bash "$RUN_ALL" 2>&1)
status=$?
assert_status 0 "$status" "tests/run-all.sh with no argument passes on tests/"
assert_contains "$out" "$W/tests/test_workspace.sh" "it ran the workspace suite"
assert_not_contains "$out" "test_product.sh" "it did not run a product suite"
assert_contains "$out" "1 suites passed" "it counted one suite"

out=$(bash "$TEST_DIR/run-all.sh" "$ROOT/foundation/tests/fixtures/runner/failing" 2>&1)
status=$?
assert_status 1 "$status" "tests/run-all.sh fails on the failing fixture"
mkdir -p "$SCRATCH/empty"
out=$(bash "$RUN_ALL" "$SCRATCH/empty" 2>&1)
assert_status 1 "$?" "a directory holding no suite fails the run"
assert_contains "$out" "no test suites found" "  and the run says so"
out=$(bash "$RUN_ALL" "$SCRATCH/no-such-dir" 2>&1)
assert_status 1 "$?" "a directory that does not exist fails the run"
assert_contains "$out" "not a directory" "  and the run says so"

# --- a failing suite among passing ones ----------------------------------------------------
D="$SCRATCH/mixed"
mkdir -p "$D"
write_suite "$D/test_a.sh" a
suite "$D/test_b.sh" 'echo "b, before"' 'assert_eq x y "b fails"' 'echo "b, after"' 'assert_done'
write_suite "$D/test_c.sh" c
mkdir -p "$SCRATCH/tmp"
out=$(RUN_ALL_JOBS=3 TMPDIR="$SCRATCH/tmp" bash "$RUN_ALL" "$D" 2>&1)
assert_status 1 "$?" "a failing suite among passing ones fails the run"
assert_eq "" "$(ls -A "$SCRATCH/tmp")" "  leaving no private directory"
assert_eq "=== $D/test_b.sh
b, before
not ok 1 - b fails
#   expected: x
#   actual:   y
b, after
# 1 assertions, 1 failed
FAIL $D/test_b.sh" "$(block "$out" "$D/test_b.sh")" "  its output printed whole, then FAIL"
assert_contains "$out" "PASS $D/test_a.sh" "  the suite before it passes"
assert_contains "$out" "PASS $D/test_c.sh" "  and the one after"
assert_contains "$out" "run-all: 1 of 3 suites failed: $D/test_b.sh" "  and the run names it"

# --- the suites' order, though they finish out of order -----------------------------------
# Run side by side, b ends first: by a handshake, test_b starts its work
# only once test_a has started, and test_a ends only once test_b has; a
# wait that times out fails its suite, saying so.
D="$SCRATCH/order"
mkdir -p "$D"
export ORDER_LOG="$SCRATCH/order.log"
suite "$D/test_a.sh" ': >"$ORDER_LOG.a"' \
  'wait_for "$ORDER_LOG.b" || assert_fail "a waited a minute for b to end"' \
  'echo a >>"$ORDER_LOG"' 'assert_eq a a "a ends after b"' 'assert_done'
suite "$D/test_b.sh" 'wait_for "$ORDER_LOG.a" || assert_fail "b waited a minute for a to start"' \
  'echo b >>"$ORDER_LOG"' ': >"$ORDER_LOG.b"' 'assert_eq b b "b ends first"' 'assert_done'
out=$(RUN_ALL_JOBS=2 bash "$RUN_ALL" "$D" 2>&1)
assert_status 0 "$?" "suites that finish out of order pass"
assert_eq "b
a" "$(cat "$ORDER_LOG" 2>/dev/null)" "  b finished before a"
assert_eq "=== $D/test_a.sh
=== $D/test_b.sh" "$(printf '%s\n' "$out" | grep '^=== ')" "  and the output keeps the suites' order"
assert_eq "=== $D/test_a.sh
ok 1 - a ends after b
# 1 assertions, 0 failed
PASS $D/test_a.sh" "$(block "$out" "$D/test_a.sh")" "  each suite's output whole, under its own name"

# --- each suite runs once, whatever mkdir(1) does in a race --------------------------------
# Two callers racing to make one directory need not see one of them refused
# by mkdir(1): Ubuntu 26.04's, uutils coreutils 0.10, lets both succeed most
# times. A mkdir that never refuses stands in for that race.
D="$SCRATCH/once"
mkdir -p "$D" "$SCRATCH/lax"
export ONCE_LOG="$SCRATCH/once.log"
for s in a b c; do
  suite "$D/test_$s.sh" "echo $s >>\"\$ONCE_LOG\"" 'assert_eq x x "ran"' 'assert_done'
done
printf '#!/bin/sh\nexec %s -p "$@"\n' "$(command -v mkdir)" >"$SCRATCH/lax/mkdir"
chmod +x "$SCRATCH/lax/mkdir"
out=$(PATH="$SCRATCH/lax:$PATH" RUN_ALL_JOBS=3 bash "$RUN_ALL" "$D" 2>&1)
assert_status 0 "$?" "suites side by side, under a mkdir that never refuses, pass"
assert_eq "a
b
c" "$(sort "$ONCE_LOG" 2>/dev/null)" "  each run once"

# --- a suite that ends without its plan, or cannot be started -----------------------------
D="$SCRATCH/noplan"
mkdir -p "$D"
suite "$D/test_exits.sh" 'echo "partial"' 'exit 0'
suite "$D/test_killed.sh" 'assert_eq a a "one"' 'kill -KILL $$'
write_suite "$D/test_fine.sh" fine
suite "$D/test_status.sh" "trap 'exit 3' EXIT" 'assert_eq a a "passes, then exits 3"' 'assert_done'
# The plan is a whole line that counts no failure (the tests lens's N5 and
# N10): one that counts a failure, or sits after other text, is no plan.
suite "$D/test_onefailed.sh" "echo '# 1 assertions, 1 failed'" 'exit 0'
suite "$D/test_midline.sh" "echo 'x # 1 assertions, 0 failed'" 'exit 0'
out=$(RUN_ALL_JOBS=2 bash "$RUN_ALL" "$D" 2>&1)
assert_status 1 "$?" "a suite that exits 0 without its plan fails the run"
assert_contains "$out" "partial
FAIL $D/test_exits.sh" "  marked FAIL after what it printed"
assert_contains "$out" "FAIL $D/test_killed.sh" "  and a suite killed before its plan is marked FAIL"
assert_contains "$out" "# 1 assertions, 0 failed
FAIL $D/test_status.sh" "  and one exiting 3 after a passing plan is marked FAIL"
assert_contains "$out" "FAIL $D/test_onefailed.sh" "  and one exiting 0 after a plan counting a failure"
assert_contains "$out" "FAIL $D/test_midline.sh" "  and one exiting 0 after a plan that is not a whole line"
assert_contains "$out" "run-all: 5 of 6 suites failed" "  and the run counts the five"
# A run that cannot make its private directory fails, running no suite (the
# tests lens's N4).
D="$SCRATCH/nomktemp"
mkdir -p "$D" "$SCRATCH/mktstub"
export RAN="$SCRATCH/nomktemp.ran"
suite "$D/test_runs.sh" ': >"$RAN"' 'assert_done'
printf '#!/bin/sh\nexit 1\n' >"$SCRATCH/mktstub/mktemp"
chmod +x "$SCRATCH/mktstub/mktemp"
out=$(PATH="$SCRATCH/mktstub:$PATH" bash "$RUN_ALL" "$D" 2>&1)
assert_status 1 "$?" "a run that cannot make its private directory fails"
assert_contains "$out" "cannot make a private directory" "  and says so"
assert_eq "no" "$([ -e "$RAN" ] && echo yes || echo no)" "  running no suite"
if [ "$(id -u)" != 0 ]; then
  D="$SCRATCH/unreadable"
  mkdir -p "$D"
  write_suite "$D/test_locked.sh" locked
  chmod 000 "$D/test_locked.sh"
  out=$(RUN_ALL_JOBS=2 bash "$RUN_ALL" "$D" 2>&1)
  assert_status 1 "$?" "a suite that cannot be started fails the run"
  assert_contains "$out" "FAIL $D/test_locked.sh" "  marked FAIL"
fi

# --- RUN_ALL_JOBS=1 is a serial run --------------------------------------------------------
# Each suite logs its start and end; one at a time, they never overlap.
D="$SCRATCH/serial"
mkdir -p "$D"
export SERIAL_LOG="$SCRATCH/serial.log"
for s in a b c; do
  suite "$D/test_$s.sh" "echo start $s >>\"\$SERIAL_LOG\"" 'sleep 0.2' "echo end $s >>\"\$SERIAL_LOG\"" \
    "echo 'to stderr, $s' >&2" "assert_eq $s $s '$s'" 'assert_done'
done
out=$(RUN_ALL_JOBS=1 bash "$RUN_ALL" "$D" 2>&1)
assert_status 0 "$?" "RUN_ALL_JOBS=1 runs the suites"
assert_eq "start a
end a
start b
end b
start c
end c" "$(cat "$SERIAL_LOG")" "  one at a time"
serial=$(bash "$W/foundation/tests/run-all.sh" "$D" 2>&1)
assert_eq "$serial" "$out" "  printing what the product's serial runner prints"
out=$(RUN_ALL_JOBS=3 bash "$RUN_ALL" "$D" 2>&1)
assert_eq "$serial" "$out" "three at a time print the same"
# Unset, the CPU count, or sysctl's when getconf has none, or else 2.
mkdir -p "$SCRATCH/stub"
printf '#!/bin/sh\nexit 1\n' >"$SCRATCH/stub/getconf"
printf '#!/bin/sh\necho 1\n' >"$SCRATCH/stub/sysctl"
chmod +x "$SCRATCH/stub/getconf" "$SCRATCH/stub/sysctl"
rm -f "$SERIAL_LOG"
out=$(PATH="$SCRATCH/stub:$PATH" bash "$RUN_ALL" "$D" 2>&1)
assert_eq "start a
end a
start b
end b
start c
end c" "$(cat "$SERIAL_LOG")" "with getconf failing, sysctl's count, 1, is a serial run"
# Two at a time: test_a and test_b run side by side, each seeing the other
# start; then, for two seconds, each sees test_c not start; neither ends
# before both have looked.
D="$SCRATCH/two"
mkdir -p "$D"
export TWO="$SCRATCH/two-"
for s in a b; do
  o=$([ "$s" = a ] && echo b || echo a)
  suite "$D/test_$s.sh" ": >\"\${TWO}$s\"" "wait_for \"\${TWO}$o\" || assert_fail '$s waited a minute for $o'" \
    "assert_eq yes \"\$([ -e \"\${TWO}$o\" ] && echo yes)\" '$s runs beside $o'" \
    'wait_for "${TWO}c" 20' \
    "assert_eq no \"\$([ -e \"\${TWO}c\" ] && echo yes || echo no)\" 'c does not start beside a and b'" \
    ": >\"\${TWO}$s.looked\"" "wait_for \"\${TWO}$o.looked\" || assert_fail '$s waited a minute for $o to look'" \
    'assert_done'
done
suite "$D/test_c.sh" ': >"${TWO}c"' 'assert_eq c c "c runs"' 'assert_done'
printf '#!/bin/sh\necho undefined\n' >"$SCRATCH/stub/getconf"
printf '#!/bin/sh\nexit 1\n' >"$SCRATCH/stub/sysctl"
out=$(PATH="$SCRATCH/stub:$PATH" bash "$RUN_ALL" "$D" 2>&1)
assert_status 0 "$?" "with no count from getconf, undefined, nor sysctl, two run at a time"
# A count with leading zeros is that count: 01 is a serial run.
rm -f "$SERIAL_LOG"
D="$SCRATCH/serial"
out=$(RUN_ALL_JOBS=01 bash "$RUN_ALL" "$D" 2>&1)
assert_status 0 "$?" "RUN_ALL_JOBS=01 runs the suites"
assert_eq "start a
end a
start b
end b
start c
end c" "$(cat "$SERIAL_LOG")" "  one at a time"
for bad in 0 00 x -1 ''; do
  out=$(RUN_ALL_JOBS=$bad bash "$RUN_ALL" "$SCRATCH/serial" 2>&1)
  assert_status 1 "$?" "RUN_ALL_JOBS='$bad' is refused"
  assert_contains "$out" "RUN_ALL_JOBS must be a whole number above 0" "  and the refusal says so"
done

# --- an interrupt ends the suites and removes the private directory ------------------------
D="$SCRATCH/slow"
mkdir -p "$D"
export SLOW_PID="$SCRATCH/slow.pid"
suite "$D/test_slow.sh" 'echo $$ >"$SLOW_PID.x" && mv "$SLOW_PID.x" "$SLOW_PID"' 'sleep 30' \
  ': >"$SLOW_PID.finished"' 'assert_done'
# Each ends the run with 128 and its number (the tests lens's N6 and N10).
for sig in HUP INT TERM; do
  rm -f "$SLOW_PID" "$SLOW_PID.finished"
  set -m
  TMPDIR="$SCRATCH/tmp" bash "$RUN_ALL" "$D" >/dev/null 2>&1 &
  pid=$!
  set +m
  wait_for "$SLOW_PID" || assert_fail "the slow suite did not start within a minute"
  kill -s "$sig" "$pid"
  wait "$pid"
  st=$?
  assert_eq "$((128 + $(kill -l "$sig")))" "$st" "SIG$sig ends the run with 128 and its number"
  spid=$(cat "$SLOW_PID" 2>/dev/null)
  assert_eq "ended" "$(if [ -n "$spid" ] && kill -0 "$spid" 2>/dev/null; then echo running; else echo ended; fi)" \
    "  the running suite ended"
  assert_eq "no" "$([ -e "$SLOW_PID.finished" ] && echo yes || echo no)" "  ended by the run, not finished"
  assert_eq "" "$(ls -A "$SCRATCH/tmp")" "  and the private directory removed"
done

assert_done
