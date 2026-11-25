#!/usr/bin/env bash
# bin/ask (AC7): `setup` rewrites setup/answers.env and `questionnaire`
# writes setup/questionnaire.md, both from the schema, on a fixture
# workspace with its own schema. Each refusal writes nothing.
# shellcheck disable=SC2016,SC2088 # values hold a literal ~, $ and backticks
set -u
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$TEST_DIR/../foundation/tests/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=fixtures/workspace.sh
. "$TEST_DIR/fixtures/workspace.sh"

SCRATCH=$(mktemp -d)
trap 'chmod -R u+rwx "$SCRATCH" 2>/dev/null; rm -rf "$SCRATCH"' EXIT
n=0
T='	'

row() { # the cells, joined by tabs
  local IFS="$T"
  printf '%s\n' "$*"
}
# fresh: a fixture workspace holding bin/ask and a schema of its own.
fresh() {
  n=$((n + 1))
  R="$SCRATCH/ws$n"
  ws_fixture "$R"
  cp -p "$WS_ROOT/bin/ask" "$R/bin/ask"
  mkdir -p "$R/shared"
  {
    row field scope type render selects pattern default question
    row NAME run name no - - - 'What is the repository called?'
    row OWNER setup owner no - - Okja-Engineering 'Which GitHub account owns the repositories?'
    row TARGET_ROOT setup path no - - '~/Development/{{OWNER}}' 'Which directory holds the targets?'
    row HOLDER setup text yes - - '{{OWNER}}' 'Who holds the copyright?'
    row DESCRIPTION run description yes - - - 'One line about the repository?'
    row VISIBILITY run select no - 'public|private' public 'Public or private?'
  } >"$R/shared/answers.tsv"
  fixture_commit "$R" "test: a fixture schema"
}
ask() { OUT=$(cd "$R" && bin/ask "$@" 2>&1); ST=$?; }
setup_file() { cat "$R/setup/answers.env" 2>/dev/null; }
state() { cksum <"$R/setup/answers.env" 2>/dev/null || echo absent; }
# refused DESCRIPTION NEEDLE ARGS...: bin/ask refuses and writes nothing.
refused() {
  local what=$1 needle=$2 before
  shift 2
  before=$(state)
  ask "$@"
  assert_status 1 "$ST" "refused: $what"
  assert_contains "$OUT" "$needle" "  and the refusal says: $needle"
  assert_eq "$before" "$(state)" "  and setup/answers.env is unchanged"
}

# --- usage -----------------------------------------------------------------------
fresh
ask
assert_status 2 "$ST" "no subcommand is a usage error"
assert_contains "$OUT" "usage" "  and prints the usage"
ask bogus
assert_status 2 "$ST" "an unknown subcommand is a usage error"

# --- setup -----------------------------------------------------------------------
fresh
ask setup
assert_status 0 "$ST" "setup with no values writes the defaults"
assert_eq "HOLDER=Okja-Engineering
OWNER=Okja-Engineering
TARGET_ROOT=~/Development/Okja-Engineering" "$(setup_file)" \
  "  sorted, each default's {{FIELD}} given that field's value"
assert_eq "" "$(tr -d -c '\r' <"$R/setup/answers.env")" "  with LF endings"

fresh
ask setup OWNER=acme
assert_status 0 "$ST" "setup OWNER=acme"
assert_eq "HOLDER=acme
OWNER=acme
TARGET_ROOT=~/Development/acme" "$(setup_file)" "  fills the other defaults from the new OWNER"
ask setup TARGET_ROOT=/srv/targets
assert_status 0 "$ST" "a second setup"
assert_eq "HOLDER=acme
OWNER=acme
TARGET_ROOT=/srv/targets" "$(setup_file)" "  rewrites the one field and keeps the rest"

fresh
VALUE='Bé & back\slash = equals $HOME'
ask setup "HOLDER=$VALUE"
assert_status 0 "$ST" "setup with non-ASCII, &, \\, = and \$ in a value"
assert_eq "HOLDER=$VALUE" "$(grep '^HOLDER=' "$R/setup/answers.env")" "  kept as written"
fresh
ask setup 'HOLDER=$(touch made-by-value) `touch made-by-backticks`'
assert_status 0 "$ST" "setup with \$(touch x) in a value"
assert_eq "" "$(find "$SCRATCH" -name 'made-by-*')" "  creates nothing"

fresh
ask setup
refused "a run field given to setup" "NAME" setup NAME=widget
refused "an unknown field" "BOGUS" setup BOGUS=1
refused "a value its type refuses" "OWNER" setup OWNER=-acme
refused "an argument that is not FIELD=value" "OWNER" setup OWNER
refused "a field given twice" "OWNER" setup OWNER=a OWNER=b
refused "an email address in free text" "email" setup 'HOLDER=a.person@example.org'
refused "a rule word in free text" "never" setup 'HOLDER=It never ends'
refused "a TARGET_ROOT holding a .. component" ".." setup 'TARGET_ROOT=/srv/../etc'
fixture_append "$R/setup/answers.env" 'STALE=1'
refused "a setup file holding a field the schema does not list" "STALE" setup OWNER=acme

# --- questionnaire -----------------------------------------------------------------
fresh
ask questionnaire
assert_status 0 "$ST" "questionnaire"
Q=$(cat "$R/setup/questionnaire.md" 2>/dev/null)
assert_contains "$Q" '1. Which GitHub account owns the repositories? (`OWNER`, owner; default `Okja-Engineering`)' \
  "  numbers each setup question with its field, type and default"
assert_contains "$Q" '2. Which directory holds the targets? (`TARGET_ROOT`, path; default `~/Development/{{OWNER}}`)' \
  "  the second"
assert_contains "$Q" '3. Who holds the copyright? (`HOLDER`, text; default `{{OWNER}}`)' "  the third"
assert_not_contains "$Q" "NAME" "  and keeps a run field out"
assert_not_contains "$Q" "DESCRIPTION" "  every run field"
assert_eq "3" "$(printf '%s\n' "$Q" | grep -c '^[0-9][0-9]*\. ')" "  one flat list, every question at once"
first=$(cksum <"$R/setup/questionnaire.md")
ask questionnaire
assert_eq "$first" "$(cksum <"$R/setup/questionnaire.md")" "  and a second run writes the same bytes"
ask questionnaire extra
assert_status 2 "$ST" "questionnaire takes no argument"

assert_done
