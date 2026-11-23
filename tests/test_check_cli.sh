#!/usr/bin/env bash
# The workspace's bin/check sources the product's dispatcher over the
# workspace's own bin/checks/ and takes each of C4's argument forms (AC5).
set -u
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$TEST_DIR/../foundation/tests/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=fixtures/workspace.sh
. "$TEST_DIR/fixtures/workspace.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
R="$SCRATCH/ws"
ws_fixture "$R" env pass fail docs
# A product check sits in foundation/: the workspace must never run it.
mkdir -p "$R/foundation/bin/checks"
cp -p "$TEST_DIR/fixtures/checks/fail" "$R/foundation/bin/checks/decoy"
fixture_write "$R/second.txt" "second"
fixture_commit "$R" "test: a second commit"

run() { OUT=$(cd "$R" && bin/check "$@" 2>&1); ST=$?; }
value() { printf '%s\n' "$OUT" | sed -n "s/^ *$1=//p" | head -n 1; }

# --list
run --list
assert_status 0 "$ST" "--list exits 0"
assert_contains "$OUT" "A fixture check that prints" "--list describes the workspace's checks"
assert_not_contains "$OUT" "decoy" "--list shows no product check"

# [CHECK...]
run
assert_status 1 "$ST" "no argument runs every workspace check in tree mode"
assert_contains "$OUT" "FAIL fail" "including the refusing one"
assert_not_contains "$OUT" "decoy" "and no product check"
run pass env
assert_status 0 "$ST" "named checks run alone"
assert_eq "tree" "$(value CHECK_MODE)" "in tree mode"
OUT=$(cd "$R" && CDPATH=.:/nonexistent bin/check pass 2>&1)
assert_status 0 "$?" "bin/check run by a relative path under CDPATH runs"

# --range BASE HEAD [CHECK...]
run --range HEAD~1 HEAD env
assert_status 0 "$ST" "--range BASE HEAD CHECK runs"
assert_eq "range" "$(value CHECK_MODE)" "in range mode"
assert_eq "$(git -C "$R" rev-parse HEAD~1)" "$(value CHECK_BASE)" "with BASE passed on"
assert_eq "$(git -C "$R" rev-parse HEAD)" "$(value CHECK_HEAD)" "and HEAD passed on"

# --staged
run --staged env
assert_status 0 "$ST" "--staged runs"
assert_eq "staged" "$(value CHECK_MODE)" "in staged mode"

# commit-msg FILE
printf 'feat: x\n' >"$SCRATCH/msg"
run commit-msg "$SCRATCH/msg"
assert_status 0 "$ST" "commit-msg FILE runs"
assert_eq "commit-msg" "$(value CHECK_MODE)" "in commit-msg mode"
assert_eq "$SCRATCH/msg" "$(value CHECK_MSG_FILE)" "with the file passed on"

# pr
OUT=$(cd "$R" && PR_TITLE='feat: a title' bin/check pr 2>&1)
assert_eq "pr" "$(value CHECK_MODE)" "pr runs in pr mode"
assert_eq "feat: a title" "$(value PR_TITLE)" "with PR_TITLE passed through"

# docs --report
run docs --report
assert_status 0 "$ST" "docs --report runs"
assert_contains "$OUT" "docs ran in report mode" "in report mode"

# An empty bin/checks/ has nothing to refuse; a missing one cannot run.
rm -f "$R"/bin/checks/*
run
assert_status 0 "$ST" "a workspace with an empty bin/checks/ passes"
assert_contains "$OUT" "no checks run" "and says so"
rm -rf "$R/bin/checks"
run
assert_status 2 "$ST" "a workspace with no bin/checks/ exits 2"

assert_done
