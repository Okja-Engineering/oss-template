#!/usr/bin/env bash
# `agents`: CLAUDE.md is exactly @AGENTS.md and AGENTS.md is at most 80 lines
# (TAC10, AC1), judged through the tree reader.
set -u
export LC_ALL=C
TEST_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/assert.sh
. "$TEST_DIR/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=lib/fixture.sh
. "$TEST_DIR/lib/fixture.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
n=0

# fresh: a new fixture repository in $R.
fresh() {
  n=$((n + 1))
  R="$SCRATCH/repo$n"
  fixture_repo "$R"
}
check() { OUT=$(cd "$R" && bin/check "$@" agents 2>&1); ST=$?; }
lines() { awk -v n="$1" 'BEGIN { for (i = 1; i <= n; i++) print "line " i }'; }

fresh
check
assert_status 0 "$ST" "the fixture passes"
assert_contains "$OUT" "AGENTS.md" "and says what it examined"

# --- CLAUDE.md ---------------------------------------------------------------
fixture_append "$R/CLAUDE.md" "Also read the docs."
check
assert_status 1 "$ST" "CLAUDE.md with extra content is refused"
assert_contains "$OUT" "CLAUDE.md" "the refusal names CLAUDE.md"

fresh
fixture_write "$R/CLAUDE.md" "@README.md"
check
assert_status 1 "$ST" "CLAUDE.md importing another file is refused"

fresh
printf '@AGENTS.md' >"$R/CLAUDE.md"
check
assert_status 0 "$ST" "CLAUDE.md without a final newline passes"

fresh
fixture_remove "$R/CLAUDE.md"
check
assert_status 1 "$ST" "a missing CLAUDE.md is refused"

# --- AGENTS.md ---------------------------------------------------------------
fresh
lines 80 >"$R/AGENTS.md"
check
assert_status 0 "$ST" "an 80-line AGENTS.md passes"
fixture_append "$R/AGENTS.md" "line 81"
check
assert_status 1 "$ST" "an 81-line AGENTS.md is refused"
assert_contains "$OUT" "81" "the refusal gives the count"
printf 'last line without a newline' >>"$R/AGENTS.md"
check
assert_status 1 "$ST" "a final line without a newline still counts"

fresh
fixture_remove "$R/AGENTS.md"
check
assert_status 1 "$ST" "a missing AGENTS.md is refused"

# --- judged through the tree reader ------------------------------------------
fresh
lines 81 >"$R/AGENTS.md"
check --range HEAD~0 HEAD
assert_status 0 "$ST" "range mode ignores an uncommitted 81-line AGENTS.md"
git -C "$R" add AGENTS.md
check --staged
assert_status 1 "$ST" "staged mode sees it once staged"

assert_done
