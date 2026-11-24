#!/usr/bin/env bash
# The workspace's git hooks call its bin/check with their arguments:
# commit-msg with the message file, pre-commit in staged mode, and pre-push
# in range mode per pushed ref (new, updated) with HEAD's committed checks,
# skipping a deleted ref. Driven through real git in a fixture workspace with
# a bare remote.
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

# The checks committed at HEAD judge it: editing them in the working tree
# does not change its verdict.
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

# --- pre-push runs no code from a pushed ref -----------------------------------
# HEAD's committed checks judge every pushed ref's tree. pp LINE...: run the
# hook as git would, on these ref lines; sets OUT and ST to its own exit.
ZERO=0000000000000000000000000000000000000000
pp() {
  OUT=$(printf '%s\n' "$@" | (cd "$R" && .githooks/pre-push origin "$R-origin.git") 2>&1)
  ST=$?
}
T="$SCRATCH/theirs"
git clone -q "$R-origin.git" "$T"
printf '#!/bin/sh\necho ran >"%s/MARKER"\nexit 0\n' "$SCRATCH" >"$T/bin/check"
printf '#!/bin/sh\n# A check that passes everything\n# modes: tree staged range\nexit 0\n' \
  >"$T/bin/checks/content"
git -C "$T" add -A
git -C "$T" commit -q -m "feat: checks of their own"
git -C "$T" push -q origin HEAD:refs/heads/theirs-good
fixture_write "$T/judged.txt" "BAD"
git -C "$T" commit -q -am "feat: a bad tree under checks of their own"
git -C "$T" push -q origin HEAD:refs/heads/theirs-bad
git -C "$R" fetch -q origin
pp "refs/remotes/origin/theirs-bad $(sha origin/theirs-bad) refs/heads/review $ZERO"
assert_status 1 "$ST" "a fetched ref's bad tree is refused by HEAD's checks, not passed by its own"
pp "refs/remotes/origin/theirs-good $(sha origin/theirs-good) refs/heads/review $ZERO"
assert_status 0 "$ST" "a fetched ref with a good tree passes"
g push origin origin/theirs-good:refs/heads/review
assert_status 0 "$ST" "  and git pushes it"
assert_eq "absent" "$([ -e "$SCRATCH/MARKER" ] && echo present || echo absent)" \
  "pushing a fetched ref never runs its bin/check"

# A ref holding no bin/check of its own is judged like any other.
git -C "$R" checkout -q --orphan bare
git -C "$R" rm -q -rf --cached .
fixture_write "$R/judged.txt" "good"
git -C "$R" add judged.txt
git -C "$R" commit -q --no-verify -m "feat: a tree with no harness"
fixture_write "$R/judged.txt" "BAD"
git -C "$R" commit -q --no-verify -am "feat: a bad tree with no harness"
git -C "$R" checkout -q -f main
git -C "$R" clean -q -fd
pp "refs/heads/bare $(sha bare~1) refs/heads/bare $ZERO"
assert_status 0 "$ST" "a ref with no bin/check of its own and a good tree passes"
pp "refs/heads/bare $(sha bare) refs/heads/bare $ZERO"
assert_status 1 "$ST" "  and with a bad tree is refused"

# Refs sharing a commit, a branch and its tag: clean or not, both get one verdict.
git -C "$R" branch twin main
git -C "$R" tag -a -m "a tag" v1 main
g push origin twin v1
assert_status 0 "$ST" "a branch and a tag on one clean commit are both pushed"
assert_eq "2" "$(git -C "$R-origin.git" for-each-ref refs/heads/twin refs/tags/v1 | grep -c .)" \
  "  and the remote gets both"
git -C "$R" branch twin-bad worse
git -C "$R" tag -a -m "a tag" v2 worse
pp "refs/heads/twin-bad $(sha worse) refs/heads/twin-bad $ZERO" \
  "refs/tags/v2 $(sha v2) refs/tags/v2 $ZERO"
assert_status 1 "$ST" "a branch and a tag on one bad commit are refused, not 'cannot run'"
g push origin twin-bad v2
assert_eq "0" "$(git -C "$R-origin.git" for-each-ref refs/heads/twin-bad refs/tags/v2 | grep -c .)" \
  "  and the remote gets neither"
pp "refs/tags/blobtag $(sha blobtag) refs/tags/blobtag $ZERO"
assert_status 2 "$ST" "a ref on a non-commit is 'cannot judge', exit 2"

# --- pre-push judges each ref by its own range ---------------------------------
# Two refs at one commit, whose ranges differ: a ref's verdict is the one it
# gets when pushed alone. The remote's rel already holds a commit whose subject
# holds BAD; its main does not.
cp "$TEST_DIR/fixtures/checks/subjects" "$R/bin/checks/subjects"
plant "test: a check on the subjects a push adds"
g push --no-verify origin main
git -C "$R" checkout -q -b rel
git -C "$R" commit -q --allow-empty --no-verify -m "feat: BAD subject"
g push --no-verify origin rel
git -C "$R" checkout -q main
git -C "$R" merge -q --ff-only rel
git -C "$R" commit -q --allow-empty --no-verify -m "feat: after it"
git -C "$R" branch -q -f rel main
rel_old=$(git -C "$R-origin.git" rev-parse rel)
main_old=$(git -C "$R-origin.git" rev-parse main)
pp "refs/heads/rel $(sha main) refs/heads/rel $rel_old"
assert_status 0 "$ST" "rel alone adds no BAD subject and passes"
pp "refs/heads/main $(sha main) refs/heads/main $main_old"
assert_status 1 "$ST" "main alone adds the BAD subject and is refused"
pp "refs/heads/rel $(sha main) refs/heads/rel $rel_old" "refs/heads/main $(sha main) refs/heads/main $main_old"
assert_status 1 "$ST" "pushed together at one commit, main is still refused"
g push origin rel main
assert_eq "$main_old" "$(git -C "$R-origin.git" rev-parse main)" "  and the remote's main does not move"

# --- hooks run by hand --------------------------------------------------------
OUT=$(cd "$R" && .githooks/commit-msg 2>&1)
assert_status 2 "$?" "commit-msg with no FILE exits 2"
OUT=$(printf 'refs/heads/worse %s refs/heads/worse %s' "$(sha worse)" "$(sha main)" |
  (cd "$R" && .githooks/pre-push origin "$R-origin.git") 2>&1)
assert_status 1 "$?" "pre-push judges a last line that lacks its newline"

assert_done
