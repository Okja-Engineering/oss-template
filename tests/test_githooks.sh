#!/usr/bin/env bash
# The workspace's git hooks call its bin/check with their arguments:
# commit-msg with the message file, pre-commit in staged mode, and pre-push
# in range mode per pushed ref (new, updated), skipping a deleted one. Driven
# through real git in a fixture workspace with a bare remote.
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

# The pushed ref's own checks judge it: editing the checks in the working
# tree does not change its verdict.
printf '#!/usr/bin/env bash\n# A check edited to pass\n# modes: tree staged range\nexit 0\n' \
  >"$R/bin/checks/content"
g push origin worse
assert_eq "1" "$([ "$ST" -ne 0 ] && echo 1 || echo 0)" "an uncommitted edit to bin/checks/ does not pass a bad ref"
assert_eq "" "$(git -C "$R-origin.git" for-each-ref refs/heads/worse)" "  and the remote does not get it"
git -C "$R" checkout -q -- bin/checks/content

# --- pre-push: a deleted ref ---------------------------------------------------
g push origin :feature
assert_status 0 "$ST" "deleting a remote ref passes"
assert_not_contains "$OUT" "CHECK_MODE=" "and bin/check does not run for it"
assert_eq "" "$(git -C "$R-origin.git" for-each-ref refs/heads/feature)" "the remote ref is gone"

# --- pre-push: a force-push over a remote commit this clone never fetched -----
O="$SCRATCH/other"
git clone -q "$R-origin.git" "$O"
git -C "$O" commit -q --allow-empty -m "feat: another clone's commit"
git -C "$O" push -q origin main
git -C "$R" commit -q --allow-empty --no-verify -m "feat: this clone's commit"
g push --force origin main
assert_status 0 "$ST" "a force-push over an unfetched remote commit is judged, not refused"
assert_eq "" "$(value CHECK_BASE)" "  as a new ref"
assert_eq "$(sha main)" "$(git -C "$R-origin.git" rev-parse main)" "  and the remote gets it"

# --- pre-push: refs that are not branches ------------------------------------
git -C "$R" notes add -m "a note" HEAD
g push origin refs/notes/commits
assert_status 0 "$ST" "a notes ref is not judged as a branch"
assert_contains "$OUT" "notes ref" "  and says so"
git -C "$R" tag blobtag "$(sha HEAD:judged.txt)"
g push origin blobtag
assert_eq "1" "$([ "$ST" -ne 0 ] && echo 1 || echo 0)" "a ref on something other than a commit is refused"
assert_eq "" "$(git -C "$R-origin.git" for-each-ref refs/tags/blobtag)" "  and the remote does not get it"
assert_contains "$OUT" "not a commit" "  and says so"

# --- hooks run by hand --------------------------------------------------------
OUT=$(cd "$R" && .githooks/commit-msg 2>&1)
assert_status 2 "$?" "commit-msg with no FILE exits 2"
OUT=$(printf 'refs/heads/worse %s refs/heads/worse %s' "$(sha worse)" "$(sha main)" |
  (cd "$R" && .githooks/pre-push origin "$R-origin.git") 2>&1)
assert_status 1 "$?" "pre-push judges a last line that lacks its newline"

assert_done
