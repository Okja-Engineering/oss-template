#!/usr/bin/env bash
# The suite runner must fail when a suite fails, when none ran, and when a
# suite git tracks did not run. A green runner hiding a red suite is worse
# than no runner.
set -u
export LC_ALL=C
TEST_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/assert.sh
. "$TEST_DIR/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=lib/fixture.sh
. "$TEST_DIR/lib/fixture.sh"

RUN_ALL="$TEST_DIR/run-all.sh"
FIXTURES="$TEST_DIR/fixtures/runner"
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# write_suite FILE NAME: a suite with one passing assertion.
write_suite() {
  printf '#!/usr/bin/env bash\nset -u\n. "%s/lib/assert.sh"\nassert_eq a a "%s"\nassert_done\n' \
    "$TEST_DIR" "$2" >"$1"
}

# --- a failing suite fails the runner ---------------------------------------
out=$(bash "$RUN_ALL" "$FIXTURES/failing" 2>&1)
status=$?
assert_status 1 "$status" "runner exits 1 when a suite fails"
assert_contains "$out" "FAIL" "runner marks the failing suite FAIL"
assert_contains "$out" "1 of 1 suites failed" "runner says how many suites failed"

# --- a passing suite passes the runner --------------------------------------
out=$(bash "$RUN_ALL" "$FIXTURES/passing" 2>&1)
status=$?
assert_status 0 "$status" "runner exits 0 when every suite passes"
assert_contains "$out" "PASS" "runner marks the passing suite PASS"
assert_contains "$out" "1 suites passed" "runner says how many suites passed"

# --- an empty directory is a failure, not a pass ----------------------------
mkdir "$SCRATCH/empty"
out=$(bash "$RUN_ALL" "$SCRATCH/empty" 2>&1)
status=$?
assert_status 1 "$status" "runner exits 1 when it finds no suites"
assert_contains "$out" "no test suites found" "runner says it found no suites"

# --- a missing directory is a failure ---------------------------------------
out=$(bash "$RUN_ALL" "$SCRATCH/no-such-dir" 2>&1)
status=$?
assert_status 1 "$status" "runner exits 1 when the directory does not exist"
assert_contains "$out" "not a directory" "runner says the directory does not exist"

# --- a suite with no assertions is a failure --------------------------------
mkdir "$SCRATCH/silent"
printf '#!/usr/bin/env bash\nset -u\n. "%s/lib/assert.sh"\nassert_done\n' \
  "$TEST_DIR" >"$SCRATCH/silent/test_no_assertions.sh"
out=$(bash "$RUN_ALL" "$SCRATCH/silent" 2>&1)
status=$?
assert_status 1 "$status" "runner exits 1 when a suite ran no assertions"
assert_contains "$out" "no assertions ran" "the suite says no assertions ran"

# --- a tracked suite missing from the tree is a failure ---------------------
# Discovery is a glob, and a glob reports whatever is in front of it: deleting
# a suite would read as a smaller pass. The expectation comes from git.
REPO="$SCRATCH/repo"
mkdir "$REPO"
git -C "$REPO" init -q -b main
write_suite "$REPO/test_one.sh" one
write_suite "$REPO/test_two.sh" two
git -C "$REPO" add -A
git -C "$REPO" commit -q -m 'test: add two suites'

out=$(bash "$RUN_ALL" "$REPO" 2>&1)
status=$?
assert_status 0 "$status" "two tracked suites, both present, pass"
assert_contains "$out" "2 suites passed" "and the runner counts both"

rm -f "$REPO/test_two.sh"
out=$(bash "$RUN_ALL" "$REPO" 2>&1)
status=$?
assert_status 1 "$status" "a suite git tracks that did not run fails the runner"
assert_contains "$out" "test_two.sh" "the refusal names the missing suite"
assert_not_contains "$out" "1 suites passed" "it does not report a smaller pass"

# A new suite git does not track yet still runs and does not trip the check.
write_suite "$REPO/test_two.sh" two
write_suite "$REPO/test_three.sh" three
out=$(bash "$RUN_ALL" "$REPO" 2>&1)
status=$?
assert_status 0 "$status" "an untracked new suite runs without tripping the check"
assert_contains "$out" "3 suites passed" "and is counted"

# Outside a work tree the runner says it could not cross-check.
mkdir "$SCRATCH/nogit"
write_suite "$SCRATCH/nogit/test_x.sh" x
out=$(cd "$SCRATCH/nogit" && bash "$RUN_ALL" "$SCRATCH/nogit" 2>&1)
assert_contains "$out" "not cross-checked" "outside a work tree it says the list was not checked"

# --- the runner, given no directory, runs its own ---------------------------
# run-all.sh hands the runner library the directory it sits in, so a copy of
# it beside other suites runs those suites and no others.
COPY="$SCRATCH/copy"
mkdir -p "$COPY/lib"
cp "$RUN_ALL" "$COPY/run-all.sh"
cp "$TEST_DIR/lib/runner.sh" "$TEST_DIR/lib/assert.sh" "$COPY/lib/" 2>/dev/null
write_suite "$COPY/test_own.sh" own
out=$(cd "$SCRATCH" && bash "$COPY/run-all.sh" 2>&1)
status=$?
assert_status 0 "$status" "run-all.sh with no argument passes on its own directory"
assert_contains "$out" "$COPY/test_own.sh" "and ran the suite beside it"
assert_contains "$out" "1 suites passed" "and only that suite"

# --- the real suite directory is cross-checked ------------------------------
gone=""
for t in $(git -C "$TEST_DIR" ls-files -- 'test_*.sh' 2>/dev/null); do
  case "$t" in */*) continue ;; esac
  [ -f "$TEST_DIR/$t" ] || gone="$gone $t"
done
assert_eq "" "$gone" "no suite git tracks beside this one is missing"

assert_done
