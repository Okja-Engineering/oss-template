#!/usr/bin/env bash
# The workspace's git hooks call its bin/check with their arguments:
# commit-msg with the message file, pre-commit in staged mode, and pre-push
# in range mode per pushed ref (new, updated), skipping a deleted one. Driven
# through real git in a fixture workspace with a bare remote.
set -u
export LC_ALL=C
TEST_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$TEST_DIR/../foundation/tests/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=fixtures/workspace.sh
. "$TEST_DIR/fixtures/workspace.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
R="$SCRATCH/ws"
ws_fixture "$R" env message content
(cd "$R" && bin/setup >/dev/null)

g() { OUT=$(cd "$R" && git "$@" 2>&1); ST=$?; }
# value NAME [N]: the Nth value the env fixture check printed for NAME.
value() { printf '%s\n' "$OUT" | sed -n "s/^ *$1=//p" | sed -n "${2:-1}p"; }
sha() { git -C "$R" rev-parse "$1"; }
# plant MESSAGE: commit everything, bypassing the hooks, to set up a case.
plant() { git -C "$R" add -A && git -C "$R" commit -q --no-verify -m "$1"; }

# --- commit-msg and pre-commit -----------------------------------------------
fixture_write "$R/judged.txt" "good again"
git -C "$R" add judged.txt
g commit -m "feat: a good change"
assert_status 0 "$ST" "a good commit passes both hooks"
assert_contains "$OUT" "CHECK_MODE=staged" "pre-commit runs bin/check --staged"
assert_contains "$OUT" "CHECK_MODE=commit-msg" "commit-msg runs bin/check commit-msg"
assert_contains "$(value CHECK_MSG_FILE 2)" "COMMIT_EDITMSG" "with git's message file as FILE"

before=$(sha HEAD)
g commit --allow-empty -m "BAD message"
assert_eq "1" "$([ "$ST" -ne 0 ] && echo 1 || echo 0)" "commit-msg refuses what bin/check refuses"
assert_eq "$before" "$(sha HEAD)" "and no commit is made"

fixture_write "$R/judged.txt" "BAD"
git -C "$R" add judged.txt
g commit -m "feat: a bad change"
assert_eq "1" "$([ "$ST" -ne 0 ] && echo 1 || echo 0)" "pre-commit refuses a bad staged tree"
assert_eq "$before" "$(sha HEAD)" "and no commit is made"
git -C "$R" reset -q --hard HEAD

# --- pre-push: an updated ref --------------------------------------------------
old=$(sha origin/main)
fixture_write "$R/judged.txt" "BAD"
g push origin main
assert_status 0 "$ST" "pushing an updated ref passes, an uncommitted edit ignored"
assert_eq "range" "$(value CHECK_MODE)" "pre-push runs bin/check --range"
assert_eq "$old" "$(value CHECK_BASE)" "an updated ref's base is the remote's old SHA"
assert_eq "$(sha main)" "$(value CHECK_HEAD)" "its head is the pushed SHA"
assert_eq "main" "$(value CHECK_REF)" "and CHECK_REF is the pushed branch"
git -C "$R" checkout -q -- judged.txt

# --- pre-push: a new ref -------------------------------------------------------
git -C "$R" checkout -q -b feature
fixture_write "$R/new.txt" "new"
plant "feat: on a new branch"
git -C "$R" checkout -q main
g push origin feature
assert_status 0 "$ST" "pushing a new ref passes"
assert_eq "" "$(value CHECK_BASE)" "a new ref has an empty base"
assert_eq "$(sha feature)" "$(value CHECK_HEAD)" "its head is the pushed SHA, though not checked out"
assert_eq "feature" "$(value CHECK_REF)" "CHECK_REF is the new branch"
assert_eq "$(sha main)" "$(value DOCS_BASE)" "its docs base is the parent of its first unpushed commit"

git -C "$R" checkout -q -b worse
fixture_write "$R/judged.txt" "BAD"
plant "feat: a bad tree on a new branch"
git -C "$R" checkout -q main
g push origin worse
assert_eq "1" "$([ "$ST" -ne 0 ] && echo 1 || echo 0)" "a pushed ref's bad tree is refused"
assert_eq "" "$(git -C "$R-origin.git" for-each-ref refs/heads/worse)" "and the remote does not get it"

# --- pre-push: a deleted ref ---------------------------------------------------
g push origin :feature
assert_status 0 "$ST" "deleting a remote ref passes"
assert_not_contains "$OUT" "CHECK_MODE=" "and bin/check does not run for it"
assert_eq "" "$(git -C "$R-origin.git" for-each-ref refs/heads/feature)" "the remote ref is gone"

assert_done
