#!/usr/bin/env bash
# bin/check (C4) over fixture checks: modes, bases, --list, exit codes and
# LC_ALL=C, and that range mode judges the head commit, never the checkout.
set -u
export LC_ALL=C
TEST_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/assert.sh
. "$TEST_DIR/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=lib/fixture.sh
. "$TEST_DIR/lib/fixture.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
ZERO=0000000000000000000000000000000000000000

# repo NAME CHECK...: a fixture repository whose bin/checks holds only the
# fixture checks named.
repo() {
  local dir="$SCRATCH/$1" c
  shift
  fixture_repo "$dir"
  rm -rf "$dir/bin/checks"
  mkdir -p "$dir/bin/checks"
  for c in "$@"; do
    cp -p "$TEST_DIR/fixtures/checks/$c" "$dir/bin/checks/$c"
  done
  fixture_commit "$dir" "test: install fixture checks"
  git -C "$dir" push -q origin main
  printf '%s' "$dir"
}

# run DIR ARGS...: run DIR's bin/check from DIR; sets OUT and ST.
run() {
  local dir=$1
  shift
  OUT=$(cd "$dir" && bin/check "$@" 2>&1)
  ST=$?
}

# value NAME: what the env fixture check printed for NAME in $OUT.
value() { printf '%s\n' "$OUT" | sed -n "s/^ *$1=//p" | head -n 1; }

# --- exit codes and output ---------------------------------------------------
R=$(repo codes pass fail broken env)
run "$R" pass env
assert_status 0 "$ST" "all checks passing exits 0"
assert_contains "$OUT" "ok pass" "a passing check prints ok"
assert_contains "$OUT" "examined nothing" "with what it examined"
run "$R" pass fail
assert_status 1 "$ST" "a refusal exits 1"
assert_contains "$OUT" "FAIL fail" "a refusing check prints FAIL"
assert_contains "$OUT" "planted refusal" "with its reason"
run "$R" pass broken
assert_status 2 "$ST" "a check unable to run exits 2"
assert_contains "$OUT" "FAIL broken" "and is reported"
run "$R" fail broken
assert_status 2 "$ST" "unable to run outranks a refusal"
run "$R" no-such-check
assert_status 2 "$ST" "an unknown check exits 2"
assert_contains "$OUT" "unknown check" "and says so"
run "$R" --bogus
assert_status 2 "$ST" "an unknown option exits 2"
run "$R" --range
assert_status 2 "$ST" "--range without BASE and HEAD exits 2"
run "$R" --range "" no-such-rev
assert_status 2 "$ST" "--range with an unknown HEAD exits 2"
run "$R" commit-msg "$SCRATCH/no-such-file"
assert_status 2 "$ST" "commit-msg with a missing file exits 2"
mkdir "$SCRATCH/nogit"
cp -Rp "$R/bin" "$SCRATCH/nogit/bin"
run "$SCRATCH/nogit" pass
assert_status 2 "$ST" "outside a git repository exits 2"
assert_contains "$OUT" "not inside a git repository" "and says so"

# --- --list --------------------------------------------------------------------
run "$R" --list
assert_status 0 "$ST" "--list exits 0"
assert_contains "$OUT" "pass" "--list names each check"
assert_contains "$OUT" "A fixture check that refuses" "--list gives each description"

# --- modes and filtering -------------------------------------------------------
run "$R" pass fail env
assert_eq "tree" "$(value CHECK_MODE)" "no option is tree mode"
assert_eq "$(cd "$R" && pwd -P)" "$(cd "$(value PWD)" && pwd -P)" "checks run at the top of the work tree"
printf 'feat: x\n' >"$SCRATCH/msg"
run "$R" commit-msg "$SCRATCH/msg"
assert_status 0 "$ST" "commit-msg runs only checks with that mode"
assert_not_contains "$OUT" "planted refusal" "a check without the mode is not run"
assert_eq "commit-msg" "$(value CHECK_MODE)" "commit-msg mode is set"
assert_eq "$SCRATCH/msg" "$(value CHECK_MSG_FILE)" "the message file is passed"
OUT=$(cd "$R" && PR_TITLE='feat: x' bin/check pr 2>&1)
assert_eq "pr" "$(value CHECK_MODE)" "pr mode is set"
run "$R" env --report
assert_eq "report" "$(value CHECK_MODE)" "CHECK --report is report mode"
run "$R" fail --report
assert_status 2 "$ST" "naming a check outside the mode exits 2"
OUT=$(cd "$R" && LC_ALL=en_US.UTF-8 bin/check env 2>&1)
assert_eq "C" "$(value LC_ALL)" "checks run under LC_ALL=C"

# --- tree mode bases -----------------------------------------------------------
fixture_write "$R/ahead.txt" "ahead"
fixture_commit "$R" "test: one commit ahead of origin"
run "$R" env
assert_eq "$(git -C "$R" rev-parse origin/main)" "$(value CHECK_BASE)" "tree mode: base is the upstream"
assert_eq "$(git -C "$R" rev-parse HEAD)" "$(value CHECK_HEAD)" "tree mode: head is HEAD"
assert_eq "$(git -C "$R" rev-parse origin/main)" "$(value DOCS_BASE)" \
  "tree mode: docs base is the merge base with the upstream"
git -C "$R" branch -q --unset-upstream
run "$R" env
assert_eq "$(git -C "$R" rev-parse HEAD)" "$(value DOCS_BASE)" "tree mode without an upstream: docs base is HEAD"

# --- range mode: merge-base selection ------------------------------------------
R=$(repo range env)
A=$(git -C "$R" rev-parse HEAD)
git -C "$R" checkout -q -b feature
fixture_write "$R/f1.txt" "f1"
fixture_commit "$R" "test: f1"
fixture_write "$R/f2.txt" "f2"
fixture_commit "$R" "test: f2"
F2=$(git -C "$R" rev-parse HEAD)
F1=$(git -C "$R" rev-parse HEAD~1)
git -C "$R" checkout -q main
fixture_write "$R/m1.txt" "m1"
fixture_commit "$R" "test: main moves on"
M1=$(git -C "$R" rev-parse HEAD)
run "$R" --range main feature env
assert_eq "range" "$(value CHECK_MODE)" "--range is range mode"
assert_eq "$M1" "$(value CHECK_BASE)" "range: base is BASE"
assert_eq "$F2" "$(value CHECK_HEAD)" "range: head is HEAD, checked out or not"
assert_eq "$A" "$(value DOCS_BASE)" "range: docs base is the merge base, not BASE's tip"

# --- range mode: empty and all-zero BASE ---------------------------------------
# origin/main is at A; feature's F1 and F2 are on no remote ref.
for base in "" "$ZERO"; do
  run "$R" --range "$base" feature env
  assert_eq "" "$(value CHECK_BASE)" "BASE '$base' is passed on as empty"
  assert_eq "$A" "$(value DOCS_BASE)" "BASE '$base' with a remote ref: docs base is the parent of the oldest unpushed commit ($F1)"
done
git -C "$R" remote remove origin
run "$R" --range "$ZERO" feature env
assert_eq "" "$(value DOCS_BASE)" "all-zero BASE with no remote ref: the oldest is a root, so no docs base"

# --- AC22: a first push where origin/main equals HEAD --------------------------
R=$(repo first env)
git -C "$R" remote set-head origin main
run "$R" --range "$ZERO" HEAD env
assert_eq "$(git -C "$R" rev-parse HEAD)" "$(value DOCS_BASE)" \
  "with no CHECK_REF, commits on origin/main are not checked (docs base HEAD)"
OUT=$(cd "$R" && CHECK_REF=main bin/check --range "$ZERO" HEAD env 2>&1)
assert_eq "main" "$(value CHECK_REF)" "CHECK_REF is passed on"
assert_eq "" "$(value DOCS_BASE)" "CHECK_REF=main: the root is checked, so no docs base"
OUT=$(cd "$R" && CHECK_REF=refs/heads/main bin/check --range "" HEAD env 2>&1)
assert_eq "" "$(value DOCS_BASE)" "CHECK_REF as a full ref name works the same"

# --- AC22: a commit on an unborn branch ----------------------------------------
U="$SCRATCH/unborn"
git init -q -b main "$U"
mkdir -p "$U/bin/checks"
cp -Rp "$FIXTURE_FOUNDATION/bin/check" "$FIXTURE_FOUNDATION/bin/lib" "$U/bin/" 2>/dev/null
cp -p "$TEST_DIR/fixtures/checks/env" "$TEST_DIR/fixtures/checks/pass" "$U/bin/checks/"
git -C "$U" add -A
run "$U" --staged env pass
assert_status 0 "$ST" "staged mode on an unborn branch runs"
assert_eq "staged" "$(value CHECK_MODE)" "--staged is staged mode"
assert_eq "" "$(value CHECK_HEAD)" "unborn: no head"
assert_eq "" "$(value DOCS_BASE)" "unborn: no docs base"
run "$U" env
assert_status 0 "$ST" "tree mode on an unborn branch runs"

# --- an uncommitted edit is ignored in range mode ------------------------------
R=$(repo judged content)
fixture_write "$R/judged.txt" "good"
fixture_commit "$R" "test: a good file"
fixture_write "$R/judged.txt" "BAD"
run "$R" --range HEAD~1 HEAD content
assert_status 0 "$ST" "range mode judges HEAD's objects, ignoring the uncommitted edit"
run "$R" content
assert_status 1 "$ST" "tree mode judges the working tree and sees it"
run "$R" --staged content
assert_status 0 "$ST" "staged mode does not see an unstaged edit"
git -C "$R" add judged.txt
run "$R" --staged content
assert_status 1 "$ST" "staged mode sees it once staged"
git -C "$R" commit -q -m "test: a bad file"
git -C "$R" branch -q bad
git -C "$R" reset -q --hard HEAD~1
run "$R" --range main bad content
assert_status 1 "$ST" "range mode judges a ref that is not checked out"

assert_done
