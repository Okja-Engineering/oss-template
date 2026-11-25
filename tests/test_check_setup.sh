#!/usr/bin/env bash
# The workspace's `setup` check (AC8): it reads shared/answers.tsv,
# setup/answers.env and setup/questionnaire.md through the tree reader, and
# refuses a questionnaire other than `bin/ask questionnaire`'s output and a
# setup file bin/lib/answers.sh's validator rejects.
set -u
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$TEST_DIR/../foundation/tests/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=fixtures/workspace.sh
. "$TEST_DIR/fixtures/workspace.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
n=0

run() { OUT=$(cd "$R" && bin/check "$@" setup 2>&1); ST=$?; }
refused() { # DESCRIPTION NEEDLE
  run
  assert_status 1 "$ST" "refused: $1"
  assert_contains "$OUT" "$2" "  and the refusal says: $2"
}
# valid: the workspace's schema, its setup file and questionnaire as
# bin/ask writes them, committed.
valid() {
  n=$((n + 1))
  R="$SCRATCH/ws$n"
  ws_fixture "$R"
  ws_real_check "$R" setup
  cp -p "$WS_ROOT/bin/ask" "$R/bin/ask"
  mkdir -p "$R/shared"
  cp -p "$WS_ROOT/shared/answers.tsv" "$R/shared/answers.tsv"
  (cd "$R" && bin/ask setup >/dev/null && bin/ask questionnaire >/dev/null) || return 1
  fixture_commit "$R" "test: setup as bin/ask writes it"
}

valid
run
assert_status 0 "$ST" "passes: the setup file and questionnaire bin/ask writes"
assert_contains "$OUT" "examined" "and it says what it examined"

# A stale questionnaire: the schema changed and it was not regenerated.
valid
fixture_replace "$R/shared/answers.tsv" "Which GitHub account" "Which account on GitHub"
fixture_commit "$R" "test: a question reworded"
refused "a stale questionnaire" "setup/questionnaire.md"
valid
fixture_append "$R/setup/questionnaire.md" "A line added by hand."
fixture_commit "$R" "test: a hand edit"
refused "a questionnaire edited by hand" "bin/ask questionnaire"
valid
fixture_remove "$R/setup/questionnaire.md"
fixture_commit "$R" "test: no questionnaire"
refused "a missing questionnaire" "setup/questionnaire.md"

# A setup file the validator rejects.
valid
fixture_replace "$R/setup/answers.env" "OWNER=Okja-Engineering" "OWNER=-okja"
fixture_commit "$R" "test: a bad value"
refused "a value the validator rejects" "setup/answers.env:1: OWNER"
valid
fixture_replace "$R/setup/answers.env" "TARGET_ROOT=~/Development/Okja-Engineering" "TARGET_ROOT=~okja/targets"
fixture_commit "$R" "test: a ~user path"
refused "a TARGET_ROOT the validator rejects" "TARGET_ROOT"
valid
fixture_append "$R/setup/answers.env" "NAME=widget"
fixture_commit "$R" "test: a run field"
refused "a run field in the setup file" "NAME"
valid
fixture_remove "$R/setup/answers.env"
fixture_commit "$R" "test: no setup file"
refused "a missing setup file" "setup/answers.env"

# Read through the tree reader.
valid
fixture_replace "$R/setup/answers.env" "OWNER=Okja-Engineering" "OWNER=-okja"
run --range "" HEAD
assert_status 0 "$ST" "range mode judges HEAD, not an uncommitted edit"
git -C "$R" add setup/answers.env
run --staged
assert_status 1 "$ST" "staged mode judges the index"

assert_done
