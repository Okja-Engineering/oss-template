#!/usr/bin/env bash
# The workspace's `setup` check (AC8): it reads shared/answers.tsv,
# setup/answers.env and setup/questionnaire.md through the tree reader, and
# refuses a questionnaire other than `bin/ask questionnaire`'s output and a
# setup file bin/lib/answers.sh's validator rejects.
set -u
set -o pipefail
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

valid
fixture_remove "$R/shared/answers.tsv"
fixture_commit "$R" "test: no schema"
refused "a missing schema" "shared/answers.tsv is missing"
assert_not_contains "$OUT" "header" "  and nothing is judged against it"

# A schema that does not parse, named by its path in the tree on every bash.
valid
printf 'X\trun\tbogus\tno\t-\t-\t-\tX?\n' >>"$R/shared/answers.tsv"
fixture_commit "$R" "test: a schema with an unknown type"
refused "a schema that does not parse" "shared/answers.tsv:5: X: an unknown type bogus"
assert_not_contains "$OUT" "examined" "  and nothing past the schema is judged"

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

# setup/answers.env is what bin/ask setup works out from setup/given.env
# (decision 229).
valid
(cd "$R" && bin/ask setup OWNER=acme >/dev/null)
fixture_commit "$R" "test: an owner given"
run
assert_status 0 "$ST" "passes: setup/answers.env and setup/given.env as bin/ask setup writes them"
assert_contains "$OUT" "setup/given.env" "  and it says it examined setup/given.env"
valid
(cd "$R" && bin/ask setup TARGET_ROOT=/srv/targets >/dev/null)
fixture_replace "$R/setup/answers.env" "OWNER=Okja-Engineering" "OWNER=acme"
fixture_commit "$R" "test: an owner edited by hand"
refused "a setup/answers.env edited by hand, away from what was given" "run bin/ask setup"
valid
(cd "$R" && bin/ask setup OWNER=acme >/dev/null)
fixture_remove "$R/setup/given.env"
fixture_commit "$R" "test: given.env removed"
refused "a setup/answers.env whose setup/given.env is gone" "not what bin/ask setup writes"
valid
(cd "$R" && bin/ask setup OWNER=acme >/dev/null)
printf 'OWNER=ac\000me\n' >"$R/setup/given.env"
fixture_commit "$R" "test: a NUL in given.env"
refused "a setup/given.env holding a NUL" "setup/given.env: the file holds a NUL byte"
valid
printf 'OWNER\n' >"$R/setup/given.env"
fixture_commit "$R" "test: a bare field in given.env"
refused "a setup/given.env line that is not FIELD=value" "setup/given.env:1: not a FIELD=value line"
valid
printf 'OWNER=-acme\n' >"$R/setup/given.env"
fixture_commit "$R" "test: a bad value in given.env"
refused "a setup/given.env value its check refuses" "give OWNER again"
valid
(cd "$R" && bin/ask setup OWNER=acme >/dev/null)
fixture_commit "$R" "test: an owner given"
fixture_failing "$SCRATCH/stub$n" cmp '*/want *' 1 2
OUT=$(cd "$R" && PATH="$SCRATCH/stub$n:$PATH" bin/check setup 2>&1)
assert_status 2 "$?" "a comparison that cannot run is an error, not a pass or a refusal"
fixture_failing "$SCRATCH/qstub$n" cmp '*/expected */questionnaire' 1 2
OUT=$(cd "$R" && PATH="$SCRATCH/qstub$n:$PATH" bin/check setup 2>&1)
assert_status 2 "$?" "a comparison of the questionnaire that cannot run is an error, not a refusal"
assert_not_contains "$OUT" "not what bin/ask questionnaire writes" "  and names no refusal"
fixture_failing "$SCRATCH/gstub$n" cat '*/setup/given.env' 1 1
OUT=$(cd "$R" && PATH="$SCRATCH/gstub$n:$PATH" bin/check setup 2>&1)
assert_status 2 "$?" "a setup/given.env that cannot be read is an error, not one that is absent"
# The check cannot run, and says nothing it judged, when the tree reader
# fails on a file, when the questionnaire cannot be written, when it has no
# scratch directory, and on a commit that does not exist (the tests lens's
# F3).
cannot_run() { # TOOL PATTERN WHAT
  local stub="$SCRATCH/cstub$n-$4"
  fixture_failing "$stub" "$1" "$2" 1
  OUT=$(cd "$R" && PATH="$stub:$PATH" bin/checks/setup 2>&1)
  assert_status 2 "$?" "the check cannot run when it cannot $3"
  assert_not_contains "$OUT" "examined" "  and judges nothing"
}
cannot_run cat '*/shared/answers.tsv' "read shared/answers.tsv" 1
cannot_run cat '*/setup/questionnaire.md' "read setup/questionnaire.md" 2
cannot_run cat '*/setup/answers.env' "read setup/answers.env" 3
cannot_run awk '*BEGIN { print ENVIRON\["H"] }*' "write the questionnaire it compares" 4
cannot_run mktemp '-d' "make its scratch directory" 5
# A judge that cannot judge, a grep or awk lookup failing with a higher
# status than its "no", is a check that cannot run, never a refusal or a
# pass (decision 228): the schema's check, setup/answers.env's lines,
# setup/given.env's lines, and what setup works out from them.
cannot_judge() { # TOOL PATTERN NTH WHAT
  local stub="$SCRATCH/jstub$n-$4"
  fixture_failing "$stub" "$1" "$2" "$3" 2
  OUT=$(cd "$R" && PATH="$stub:$PATH" bin/checks/setup 2>&1)
  assert_status 2 "$?" "the check cannot run when it cannot judge $4"
  assert_not_contains "$OUT" "examined" "  and judges nothing"
}
cannot_judge awk '*function bad(why)*' 1 "the schema"
cannot_judge grep '-Eq -e ^((\[*' 1 "a value of setup/answers.env"
# Each line of setup/answers.env has its field name matched first, then
# setup/given.env's first line.
cannot_judge grep '-Eq -e ^(\[A-Z]\[A-Z0-9_]*' "$(($(wc -l <"$R/setup/answers.env") + 1))" "a line of setup/given.env"
cannot_judge awk '*!found && i > 1*' 1 "what was given, for setup/answers.env"
# setup/given.env's own judge: the scope of a field it gives, a lookup only
# it makes of a valid tree, and the sort of its lines (conformance N-I's n17
# and n18 of S2's fourth ship gate).
mkdir -p "$SCRATCH/scope$n"
printf '#!/bin/sh\n[ "$C" != scope ] || exit 2\nexec %s "$@"\n' "$(command -v awk)" >"$SCRATCH/scope$n/awk"
chmod +x "$SCRATCH/scope$n/awk"
OUT=$(cd "$R" && PATH="$SCRATCH/scope$n:$PATH" bin/checks/setup 2>&1)
assert_status 2 "$?" "the check cannot run when it cannot read the scope of a field setup/given.env gives"
assert_not_contains "$OUT" "is not a setup field" "  and names no refusal"
cannot_judge sort '' 1 "the order of setup/given.env"
OUT=$(cd "$R" && CHECK_MODE=range CHECK_HEAD=no-such-commit bin/checks/setup 2>&1)
assert_status 2 "$?" "the check cannot run on a commit that does not exist"
assert_not_contains "$OUT" "examined" "  and judges nothing"

# Read through the tree reader.
valid
fixture_replace "$R/setup/answers.env" "OWNER=Okja-Engineering" "OWNER=-okja"
run --range "" HEAD
assert_status 0 "$ST" "range mode judges HEAD, not an uncommitted edit"
git -C "$R" add setup/answers.env
run --staged
assert_status 1 "$ST" "staged mode judges the index"

# setup/given.env's fields are judged: each a setup field of the schema, in
# the order bin/ask setup writes them; and a given.env that is missing, or
# not staged, is named with the step that helps (answers' NIT 3 of S2's
# third ship gate).
valid
printf 'BOGUS=1\n' >"$R/setup/given.env"
fixture_commit "$R" "test: an unknown field given"
refused "a setup/given.env holding an unknown field" "setup/given.env:1: BOGUS is not a setup field"
valid
printf 'NAME=widget\n' >"$R/setup/given.env"
fixture_commit "$R" "test: a run field given"
refused "a setup/given.env holding a run field" "setup/given.env:1: NAME is not a setup field"
valid
(cd "$R" && bin/ask setup OWNER=acme TARGET_ROOT=/srv/targets >/dev/null)
printf 'TARGET_ROOT=/srv/targets\nOWNER=acme\n' >"$R/setup/given.env"
fixture_commit "$R" "test: given.env out of order"
refused "a setup/given.env out of order" "setup/given.env is not in the order bin/ask setup writes"
valid
(cd "$R" && bin/ask setup OWNER=acme >/dev/null)
fixture_remove "$R/setup/given.env"
fixture_commit "$R" "test: given.env removed"
refused "a setup/answers.env whose setup/given.env is gone, routed" "setup/given.env is missing"
assert_contains "$OUT" "give each field again" "  naming the step that keeps the values"
valid
(cd "$R" && bin/ask setup OWNER=acme >/dev/null)
git -C "$R" add setup/answers.env
run --staged
assert_status 1 "$ST" "refused: a staged setup/answers.env whose setup/given.env is not staged"
assert_contains "$OUT" "setup/given.env is not staged" "  naming the step: stage it"

# In staged mode each route ends in the index the check judges: the step
# that mends the file, then staging what it writes (answers' R4 of S2's
# fourth ship gate). In tree mode the step alone.
staged_route() { # DESCRIPTION NEEDLE
  git -C "$R" add -A
  run --staged
  assert_status 1 "$ST" "refused, staged: $1"
  assert_contains "$OUT" "$2" "  and the route stages what it writes: $2"
  run
  assert_status 1 "$ST" "refused, in the tree: $1"
  assert_not_contains "$OUT" "then stage" "  and the route is the step alone"
}
valid
printf 'BOGUS=1\n' >"$R/setup/given.env"
staged_route "a setup/given.env holding an unknown field" \
  "run bin/ask setup, which drops it, then stage setup/given.env and setup/answers.env"
valid
(cd "$R" && bin/ask setup OWNER=acme TARGET_ROOT=/srv/targets >/dev/null)
printf 'TARGET_ROOT=/srv/targets\nOWNER=acme\n' >"$R/setup/given.env"
staged_route "a setup/given.env out of order" \
  "run bin/ask setup, which sorts it, then stage setup/given.env and setup/answers.env"
valid
fixture_append "$R/setup/questionnaire.md" "A line added by hand."
staged_route "a questionnaire edited by hand" \
  "run bin/ask questionnaire, then stage setup/questionnaire.md"
valid
fixture_remove "$R/setup/questionnaire.md"
staged_route "a missing questionnaire" \
  "run bin/ask questionnaire to write it, then stage setup/questionnaire.md"
valid
fixture_remove "$R/setup/answers.env"
staged_route "a missing setup file" \
  "run bin/ask setup to write it, then stage setup/given.env and setup/answers.env"
valid
(cd "$R" && bin/ask setup TARGET_ROOT=/srv/targets >/dev/null)
fixture_replace "$R/setup/answers.env" "OWNER=Okja-Engineering" "OWNER=acme"
staged_route "a setup/answers.env edited by hand" \
  "run bin/ask setup, then stage setup/given.env and setup/answers.env"
valid
(cd "$R" && bin/ask setup OWNER=acme >/dev/null)
fixture_remove "$R/setup/given.env"
staged_route "a setup/answers.env whose setup/given.env is gone" \
  "give each field again with bin/ask setup FIELD=value..., then stage setup/given.env and setup/answers.env"

assert_done
