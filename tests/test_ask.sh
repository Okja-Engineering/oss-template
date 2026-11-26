#!/usr/bin/env bash
# bin/ask (AC7, AC9): `setup` rewrites setup/answers.env and `questionnaire`
# writes setup/questionnaire.md, both from the schema; `run` writes a run's
# answers file, `confirm` its confirmed.md, and `--redo --remove` first
# discards the target through the shared discard. On a fixture workspace
# with its own schema; each refusal writes nothing and removes nothing.
# shellcheck disable=SC2016,SC2088 # values hold a literal ~, $ and backticks
set -u
set -o pipefail
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
rep() { # COUNT TEXT: TEXT repeated COUNT times
  local i=0 s=""
  while [ "$i" -lt "$1" ]; do
    s="$s$2"
    i=$((i + 1))
  done
  printf '%s' "$s"
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
    row TITLE run text no - - - 'What is its title?'
    row SUMMARY run text no - '[A-Z].*' 'About {{TITLE}}' 'What is it about?'
  } >"$R/shared/answers.tsv"
  fixture_commit "$R" "test: a fixture schema"
}
ask() { OUT=$(cd "$R" && bin/ask "$@" 2>&1); ST=$?; }
setup_file() { cat "$R/setup/answers.env" 2>/dev/null; }
gone() { if [ -e "$1" ] || [ -L "$1" ]; then echo present; else echo gone; fi; }
state() { cksum 2>/dev/null <"$R/setup/answers.env" || echo absent; }
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

# Setup keeps only what the operator gave, in setup/given.env, and works
# each other field's default out again from it (decision 229).
fresh
ask setup OWNER=acme
assert_eq "OWNER=acme" "$(cat "$R/setup/given.env" 2>/dev/null)" "  setup records what was given in setup/given.env"
ask setup OWNER=other
assert_status 0 "$ST" "a second setup giving OWNER again"
assert_eq "HOLDER=other
OWNER=other
TARGET_ROOT=~/Development/other" "$(setup_file)" "  moves each default worked out from OWNER with it"
ask setup HOLDER=Someone
assert_eq "HOLDER=Someone
OWNER=other" "$(cat "$R/setup/given.env" 2>/dev/null)" "  and setup/given.env keeps every field given"
fresh
ask setup HOLDER=Someone
ask setup OWNER=acme
assert_eq "HOLDER=Someone
OWNER=acme" "$(cat "$R/setup/given.env" 2>/dev/null)" "  sorted, a field given after one it sorts before"
fresh
ask setup
assert_eq "gone" "$(gone "$R/setup/given.env")" "setup given nothing writes no setup/given.env"
printf 'OWNER=acme\n' >"$R/setup/given.env"
ask setup
assert_eq "OWNER=acme" "$(grep '^OWNER=' "$R/setup/answers.env")" "  and keeps a given.env's value when given nothing"

# A given value its check now refuses is not written back (T6's k11).
fresh
ask setup
printf 'HOLDER=a\001b\nOWNER=acme\n' >"$R/setup/given.env"
refused "a given setup value that fails its check" "setup/answers.env is not written" setup OWNER=other
assert_contains "$OUT" "HOLDER" "  and the refusal names the given field"
assert_contains "$OUT" "give HOLDER again" "  and says to give it again"
# The one reader refuses a file holding a NUL before any value is kept.
printf 'OWNER=ac\000me\n' >"$R/setup/given.env"
refused "a setup/given.env holding a NUL" "setup/given.env: the file holds a NUL byte" setup
printf 'OWNER\n' >"$R/setup/given.env"
refused "a setup/given.env line that is not FIELD=value" "not a FIELD=value line" setup

fresh
ask setup
refused "a run field given to setup" "NAME is a run field, not a setup field" setup NAME=widget
refused "an unknown field" "BOGUS: an unknown field" setup BOGUS=1
refused "a value its type refuses" "OWNER: a GitHub login is" setup OWNER=-acme
refused "an argument that is not FIELD=value" "not FIELD=value: OWNER" setup OWNER
refused "a field given twice" "OWNER is given twice" setup OWNER=a OWNER=b
refused "an email address in free text" "free text holds no email address" setup 'HOLDER=a.person@example.org'
refused "a rule word in free text" "free text holds no rule word" setup 'HOLDER=It never ends'
refused "a TARGET_ROOT holding a .. component" "a path holds no empty, . or .. component" setup 'TARGET_ROOT=/srv/../etc'
refused "a TARGET_ROOT holding a . component" "a path holds no empty, . or .. component" setup 'TARGET_ROOT=/srv/./targets'
refused "a TARGET_ROOT ending in /" "a path holds no empty, . or .. component" setup 'TARGET_ROOT=/srv/targets/'
fixture_append "$R/setup/answers.env" 'STALE=1'
ask setup OWNER=acme
assert_status 0 "$ST" "setup beside a setup/answers.env holding a field the schema does not list"
assert_not_contains "$(setup_file)" "STALE" "  writes it from what was given, without that field"
printf 'OWNER=acme\nSTALE=1\n' >"$R/setup/given.env"
ask setup
assert_status 0 "$ST" "setup beside a setup/given.env holding a field the schema does not list"
assert_contains "$OUT" "setup/given.env holds STALE, which is no longer a setup field; it is dropped" "  drops it, with a note"
assert_eq "OWNER=acme" "$(cat "$R/setup/given.env")" "  from setup/given.env too"

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

# --- run -----------------------------------------------------------------------------
# ready: a fresh workspace whose setup sends targets to a TARGET_ROOT in
# SCRATCH, which exists.
ready() {
  fresh
  ROOT="$SCRATCH/targets$n"
  mkdir -p "$ROOT"
  ask setup "TARGET_ROOT=$ROOT"
  OUTD="$R/stages/01-ask/output/widget"
  ANS="$OUTD/answers.env"
}
# run_state: the run's answers file, confirmed.md and setup.override.env,
# and its 02 and 03 outputs, so a refused redo is seen to leave them all.
run_state() {
  local f
  for f in "$ANS" "$OUTD/confirmed.md" "$OUTD/setup.override.env"; do
    if [ -e "$f" ]; then cksum <"$f"; fi
  done
  (cd "$R/stages" 2>/dev/null && find 02-render/output/widget 03-verify/output/widget 2>/dev/null | LC_ALL=C sort)
  [ -e "$ANS" ] || echo absent
}
# rrefused DESCRIPTION NEEDLE ARGS...: bin/ask refuses, and writes no answers
# file and no setup file.
rrefused() {
  local what=$1 needle=$2 before setup_before
  shift 2
  before=$(run_state)
  setup_before=$(state)
  ask "$@"
  assert_status 1 "$ST" "refused: $what"
  assert_contains "$OUT" "$needle" "  and the refusal says: $needle"
  assert_eq "$before" "$(run_state)" "  and the run's files are as they were"
  assert_eq "$setup_before" "$(state)" "  and setup/answers.env is as it was"
}

# A schema that does not parse is refused by each command that reads it,
# before it writes anything (T2's rest in the tests lens).
ready
printf 'BROKEN\tsetup\tno-such-type\tno\t-\t-\t-\tQ?\n' >>"$R/shared/answers.tsv"
rrefused "setup under a schema that does not parse" "shared/answers.tsv does not parse:" setup OWNER=acme
rrefused "questionnaire under a schema that does not parse" "shared/answers.tsv does not parse:" questionnaire
assert_eq "gone" "$(gone "$R/setup/questionnaire.md")" "  and writes no questionnaire"
rrefused "run under a schema that does not parse" "shared/answers.tsv does not parse:" \
  run widget 'TITLE=A' 'DESCRIPTION=B'

# T6's survivors: a schema with no TARGET_ROOT, a default its check refuses,
# a render.md naming no target, and a stale setup.override.env.
ready
grep -v '^TARGET_ROOT' "$R/shared/answers.tsv" >"$SCRATCH/schema$n" && mv "$SCRATCH/schema$n" "$R/shared/answers.tsv"
ask run widget 'TITLE=A' 'DESCRIPTION=B'
assert_status 1 "$ST" "refused: a run under a schema with no TARGET_ROOT"
assert_contains "$OUT" "shared/answers.tsv has no TARGET_ROOT" "  and the refusal says so"
assert_eq "gone" "$(gone "$ANS")" "  and writes no answers file"
ready
awk -F '\t' -v OFS='\t' '$1 == "TITLE" { $7 = "you must" } { print }' "$R/shared/answers.tsv" >"$SCRATCH/schema$n" &&
  mv "$SCRATCH/schema$n" "$R/shared/answers.tsv"
ask run widget 'DESCRIPTION=B'
assert_status 1 "$ST" "refused: a run field's default that its check refuses"
assert_contains "$OUT" "the answers are not written" "  and the refusal says so"
assert_contains "$OUT" "TITLE" "  naming the field"
assert_eq "gone" "$(gone "$ANS")" "  and writes no answers file"
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
mkdir -p "$R/stages/02-render/output/widget"
printf '%s\n' '# Render of widget' '' 'fingerprint: x' >"$R/stages/02-render/output/widget/render.md"
ask run widget --redo 'TITLE=C'
assert_status 1 "$ST" "refused: a redo whose render.md names no target"
assert_contains "$OUT" "render.md names no target" "  and the refusal says so"
assert_eq "TITLE=A" "$(grep '^TITLE=' "$ANS")" "  and the answers are as they were"
# Its route is the step that works, removing render.md by hand, not moving
# away a target it does not name (render's NIT 1 of S2's fourth ship gate);
# followed, the redo goes on.
assert_contains "$OUT" "the operator may remove render.md by hand" "  naming the step that works"
assert_not_contains "$OUT" "move that target away" "  and no step that does not"
rm "$R/stages/02-render/output/widget/render.md"
ask run widget --redo 'TITLE=C'
assert_status 0 "$ST" "  and, render.md removed by hand, the redo goes on"
ready
mkdir -p "$OUTD"
printf 'OWNER=stale\n' >"$OUTD/setup.override.env"
ask run widget 'TITLE=A' 'DESCRIPTION=B'
assert_status 0 "$ST" "a run with no override, beside a stale setup.override.env"
assert_eq "gone" "$(gone "$OUTD/setup.override.env")" "  removes it"
assert_eq "OWNER=Okja-Engineering" "$(grep '^OWNER=' "$ANS")" "  and records the setup value"


ready
ask run widget 'TITLE=A title' 'DESCRIPTION=One line'
assert_status 0 "$ST" "run writes the answers file"
assert_eq "DESCRIPTION=One line
HOLDER=Okja-Engineering
NAME=widget
OWNER=Okja-Engineering
SUMMARY=About A title
TARGET=$ROOT/widget
TARGET_ROOT=$ROOT
TITLE=A title
VISIBILITY=public" "$(cat "$ANS" 2>/dev/null)" \
  "  setup fields, run fields with their defaults and TARGET, sorted"
assert_eq "" "$(tr -d -c '\r' <"$ANS")" "  with LF endings"

fresh
mkdir -p "$SCRATCH/home$n/targets"
ask setup 'TARGET_ROOT=~/targets'
OUT=$(cd "$R" && HOME="$SCRATCH/home$n" bin/ask run widget 'TITLE=A title' 'DESCRIPTION=One line' 2>&1)
assert_status 0 "$?" "run with a TARGET_ROOT under ~"
assert_eq "TARGET=$SCRATCH/home$n/targets/widget" \
  "$(grep '^TARGET=' "$R/stages/01-ask/output/widget/answers.env")" "  writes TARGET with ~ expanded"
assert_eq "TARGET_ROOT=~/targets" \
  "$(grep '^TARGET_ROOT=' "$R/stages/01-ask/output/widget/answers.env")" "  and keeps TARGET_ROOT as written"
# run writes no TARGET it would itself refuse: the path type judges a
# TARGET_ROOT's expansion, so a HOME whose bytes the value rule refuses is
# refused before any TARGET is worked out (answers A2 of S2's second ship
# gate; decision 227).
for home in "$SCRATCH/home$n/new
line" "$(printf '%s/home\302\205' "$SCRATCH")" "$(printf '%s/bad\377' "$SCRATCH")" "$SCRATCH/{{OWNER}}"; do
  rm -rf "$R/stages/01-ask/output/widget"
  OUT=$(cd "$R" && HOME=$home bin/ask run widget 'TITLE=A title' 'DESCRIPTION=One line' 2>&1)
  assert_status 1 "$?" "refused: run under a HOME the value rule refuses: $(printf '%s' "$home" | od -An -c | tr -s ' ' | tail -c 24)"
  assert_contains "$OUT" "TARGET_ROOT, its ~ expanded from HOME:" "  and the refusal says so"
  assert_eq "absent" "$([ -e "$R/stages/01-ask/output/widget/answers.env" ] && echo present || echo absent)" \
    "  and writes no answers file"
done

ready
before=$(state)
ask run widget 'TITLE=A title' 'DESCRIPTION=One line' --setup-override OWNER=acme 'HOLDER=Acme & Co'
assert_status 0 "$ST" "run with --setup-override"
assert_eq "OWNER=acme" "$(grep '^OWNER=' "$ANS")" "  overrides a setup field for this run"
assert_eq "HOLDER=Acme & Co" "$(grep '^HOLDER=' "$ANS")" "  each field it names"
assert_eq "HOLDER=Acme & Co
OWNER=acme" "$(cat "$OUTD/setup.override.env" 2>/dev/null)" "  recorded in the run's setup.override.env"
assert_eq "$before" "$(state)" "  and leaves setup/answers.env untouched"
# A run works out again, from the effective setup values, its overrides
# included, each setup field setup/given.env does not record as given, as
# bin/ask setup does (decision 229; answers' S1 of S2's third ship gate), in
# AC29's shape: setup given nothing, the fixture's values as overrides.
fresh
ask setup
mkdir -p "$SCRATCH/home$n/Development/acme"
OUT=$(cd "$R" && HOME="$SCRATCH/home$n" bin/ask run widget 'TITLE=A' 'DESCRIPTION=B' --setup-override OWNER=acme 2>&1)
assert_status 0 "$?" "run with --setup-override OWNER=acme beside a setup given nothing"
ANS="$R/stages/01-ask/output/widget/answers.env"
assert_eq "HOLDER=acme" "$(grep '^HOLDER=' "$ANS")" "  works HOLDER out from the override"
assert_eq "TARGET_ROOT=~/Development/acme" "$(grep '^TARGET_ROOT=' "$ANS")" "  and TARGET_ROOT"
assert_eq "TARGET=$SCRATCH/home$n/Development/acme/widget" "$(grep '^TARGET=' "$ANS")" "  and TARGET from it"
assert_eq "OWNER=acme" "$(cat "$R/stages/01-ask/output/widget/setup.override.env" 2>/dev/null)" \
  "  recording only the override"
ready
ask setup HOLDER=Someone
ask run widget 'TITLE=A' 'DESCRIPTION=B' --setup-override OWNER=acme
assert_status 0 "$ST" "run with --setup-override OWNER=acme beside a setup that gave HOLDER"
assert_eq "HOLDER=Someone" "$(grep '^HOLDER=' "$ANS")" "  keeps the setup field given"
assert_eq "TARGET_ROOT=$ROOT" "$(grep '^TARGET_ROOT=' "$ANS")" "  each of them"
# A run takes its setup values only from a setup/answers.env that is what
# bin/ask setup writes from setup/given.env, as bin/check setup holds it,
# with its words and route; a setup/given.env that is missing included
# (answers' R5 of S2's fourth ship gate). Followed, the route lets it run.
ready
fixture_replace "$R/setup/answers.env" "OWNER=Okja-Engineering" "OWNER=acme"
rrefused "a run beside a setup/answers.env edited by hand" \
  "setup/answers.env is not what bin/ask setup writes from setup/given.env; run bin/ask setup" \
  run widget 'TITLE=A' 'DESCRIPTION=B'
assert_eq "gone" "$(gone "$OUTD")" "  and makes no run folder"
ask setup
ask run widget 'TITLE=A' 'DESCRIPTION=B'
assert_status 0 "$ST" "  and, bin/ask setup run as routed, the run goes on"
ready
ask setup OWNER=acme
rm "$R/setup/given.env"
rrefused "a run beside a setup/answers.env whose setup/given.env is missing" \
  "setup/given.env is missing, so bin/ask setup would set each field to its default: restore setup/given.env, or give each field again with bin/ask setup FIELD=value..." \
  run widget 'TITLE=A' 'DESCRIPTION=B'
ask setup OWNER=acme "TARGET_ROOT=$ROOT"
ask run widget 'TITLE=A' 'DESCRIPTION=B'
assert_status 0 "$ST" "  and, each field given again, the run goes on"
assert_eq "OWNER=acme" "$(grep '^OWNER=' "$ANS")" "  with the value given"
# The comparison failing is no pass and no refusal of the file.
ready
fixture_failing "$SCRATCH/cmp$n" cmp '*setup/answers.env*' 1 2
OUT=$(cd "$R" && PATH="$SCRATCH/cmp$n:$PATH" bin/ask run widget 'TITLE=A' 'DESCRIPTION=B' 2>&1)
assert_status 1 "$?" "refused: a run whose comparison of setup/answers.env fails"
assert_contains "$OUT" "cannot compare setup/answers.env with what bin/ask setup writes" "  saying so"
assert_eq "gone" "$(gone "$OUTD")" "  and makes no run folder"

# A run records what the operator gave in its given.env, written in the step
# that writes answers.env; a redo keeps only that and works each default out
# again, so a default from another field follows it (decision 229).
ready
ask run widget 'TITLE=A title' 'DESCRIPTION=One line'
assert_eq "DESCRIPTION=One line
TITLE=A title" "$(cat "$OUTD/given.env" 2>/dev/null)" "run records the fields given in given.env"
assert_eq "SUMMARY=About A title" "$(grep '^SUMMARY=' "$ANS")" "  and works SUMMARY out from TITLE"
ask run widget --redo 'TITLE=B title'
assert_status 0 "$ST" "a redo giving TITLE again"
assert_eq "SUMMARY=About B title" "$(grep '^SUMMARY=' "$ANS")" "  moves SUMMARY, worked out from TITLE, with it"
assert_eq "DESCRIPTION=One line" "$(grep '^DESCRIPTION=' "$ANS")" "  and keeps a field given before"
ask run widget --redo 'SUMMARY=Given here'
ask run widget --redo 'TITLE=C title'
assert_eq "SUMMARY=Given here" "$(grep '^SUMMARY=' "$ANS")" "  and a SUMMARY given stays as given"
assert_eq "DESCRIPTION=One line
SUMMARY=Given here
TITLE=C title" "$(cat "$OUTD/given.env" 2>/dev/null)" "  recorded in given.env"
rrefused "a pattern field's value that does not match" "does not match" \
  run widget --redo 'SUMMARY=lowercase'
printf 'DESCRIPTION=One line\nSTALE=1\nTITLE=C title\n' >"$OUTD/given.env"
ask run widget --redo
assert_status 0 "$ST" "a redo beside a given.env holding a field the schema does not list"
assert_contains "$OUT" "given.env holds STALE, which is no longer a run field; it is dropped" "  drops it, with a note"
assert_not_contains "$(cat "$OUTD/given.env")" "STALE" "  from given.env too"
printf 'DESCRIPTION=One\000line\nTITLE=C title\n' >"$OUTD/given.env"
rrefused "a given.env holding a NUL" "stages/01-ask/output/widget/given.env: the file holds a NUL byte" run widget --redo
printf 'DESCRIPTION=One line\nTITLE=C title\n' >"$OUTD/given.env"
printf 'OWNER=ac\000me\n' >"$OUTD/setup.override.env"
rrefused "a setup.override.env holding a NUL" "stages/01-ask/output/widget/setup.override.env: the file holds a NUL byte" run widget --redo
printf 'OWNER=acme\nSTALE=1\n' >"$OUTD/setup.override.env"
ask run widget --redo
assert_status 0 "$ST" "a redo beside a setup.override.env holding a field no longer a setup field"
assert_contains "$OUT" "setup.override.env holds STALE, which is no longer a setup field; it is dropped" \
  "  drops it, with a note"
assert_eq "OWNER=acme" "$(cat "$OUTD/setup.override.env" 2>/dev/null)" "  and keeps the rest"
rm -f "$OUTD/given.env"
ask run widget --redo
assert_status 1 "$ST" "a redo of a run with no given.env, a required field never given"
assert_contains "$OUT" "TITLE is missing" "  asks for it again"
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B' 'SUMMARY=Given'
ask run widget --redo 'DESCRIPTION=C' 'SUMMARY=About A'
assert_eq "SUMMARY=About A" "$(grep '^SUMMARY=' "$OUTD/given.env")" \
  "a redo giving a value equal to its default still records it as given"

ready
VALUE='Bé & back\slash = equals $HOME'
ask run widget 'TITLE=A title' "DESCRIPTION=$VALUE"
assert_status 0 "$ST" "run with non-ASCII, &, \\, = and \$ in a value"
assert_eq "DESCRIPTION=$VALUE" "$(grep '^DESCRIPTION=' "$ANS")" "  kept as written"
ready
ask run widget 'TITLE=$(touch made-by-run)' 'DESCRIPTION=`touch made-by-run2`'
assert_eq "" "$(find "$SCRATCH" -name 'made-by-run*')" "\$(touch x) and backticks in run values create nothing"

ready
rrefused "an unknown field" "BOGUS: an unknown field" run widget 'TITLE=A' 'DESCRIPTION=B' BOGUS=1
rrefused "a value its type refuses" "VISIBILITY: the value is not one of public|private" run widget 'TITLE=A' 'DESCRIPTION=B' VISIBILITY=secret
rrefused "a value holding a newline" "newline" run widget 'TITLE=A
B' 'DESCRIPTION=B'
rrefused "a value holding {{" "TITLE: the value holds {{" run widget 'TITLE=A {{NAME}}' 'DESCRIPTION=B'
rrefused "a rule word in a text field" "free text holds no rule word, and this holds \"never\"" run widget 'TITLE=It never stops' 'DESCRIPTION=B'
rrefused "an email address in a text field" "email" run widget 'TITLE=Mail a.person@example.org' 'DESCRIPTION=B'
rrefused "a missing field" "TITLE" run widget 'DESCRIPTION=B'
rrefused "a setup field given outside --setup-override" "OWNER is a setup field: give it after --setup-override" run widget 'TITLE=A' 'DESCRIPTION=B' OWNER=acme
rrefused "a run field given to --setup-override" "TITLE is a run field, not a setup field" \
  run widget 'TITLE=A' 'DESCRIPTION=B' --setup-override 'TITLE=C'
rrefused "a select value of two listed values joined" "VISIBILITY: the value is not one of public|private" \
  run widget 'TITLE=A' 'DESCRIPTION=B' 'VISIBILITY=public|private'
rrefused "a value holding a C1 control" "C1 control" run widget "$(printf 'TITLE=A\302\205')" 'DESCRIPTION=B'
rrefused "an override its type refuses" "OWNER: a GitHub login is" run widget 'TITLE=A' 'DESCRIPTION=B' --setup-override OWNER=-acme
rrefused "a NAME over GitHub's limit" "a name is at most 100 characters" run "$(rep 101 a)" 'TITLE=A' 'DESCRIPTION=B'
rrefused "a NAME its type refuses" "NAME: a name is lowercase letters" run Widget 'TITLE=A' 'DESCRIPTION=B'
rrefused "a DESCRIPTION over GitHub's limit" "a description is at most 350 characters" run widget 'TITLE=A' "DESCRIPTION=$(rep 351 'é')"
rrefused "NAME given as a field" "given as bin/ask run NAME, not as NAME=value" run widget 'NAME=gadget' 'TITLE=A' 'DESCRIPTION=B'
fixture_replace "$R/setup/answers.env" "OWNER=Okja-Engineering" "OWNER=-okja"
rrefused "a setup file the validator rejects" "setup/answers.env" run widget 'TITLE=A' 'DESCRIPTION=B'
ready
mkdir -p "$ROOT/widget"
rrefused "a present target, with no render of this run" "$ROOT/widget" run widget 'TITLE=A' 'DESCRIPTION=B'
assert_eq "yes" "$([ -d "$ROOT/widget" ] && echo yes)" "  and the target is left alone"
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
rrefused "an existing run without --redo" "--redo" run widget 'TITLE=C' 'DESCRIPTION=D'
ask run widget --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D'
assert_status 2 "$ST" "--remove without --redo is a usage error"

# --- confirm ----------------------------------------------------------------------------
ready
ask run widget 'TITLE=A title' 'DESCRIPTION=One line'
ask confirm widget --by 'A Person'
assert_status 0 "$ST" "confirm"
C=$(cat "$OUTD/confirmed.md" 2>/dev/null)
assert_contains "$C" "by: A Person" "  records who"
assert_contains "$C" "answers: $(git hash-object --no-filters "$ANS")" "  and the answers file's blob id"
assert_eq "1" "$(printf '%s\n' "$C" | grep -c '^at: [0-9]\{4\}-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$')" \
  "  and when, in UTC"
ask confirm gadget --by 'A Person'
assert_status 1 "$ST" "confirm refuses a run that does not exist"
assert_eq "no" "$([ -e "$R/stages/01-ask/output/gadget" ] && echo yes || echo no)" "  and writes nothing"
ask confirm widget
assert_status 2 "$ST" "confirm without --by is a usage error"
ask confirm widget --by 'A
Person'
assert_status 1 "$ST" "confirm refuses a name holding a newline"
rm -f "$OUTD/confirmed.md"
ask confirm widget X 'A Person'
assert_status 2 "$ST" "confirm NAME X WHO, without --by, is a usage error"
assert_eq "gone" "$(gone "$OUTD/confirmed.md")" "  and writes nothing"
ask confirm widget --by ''
assert_status 1 "$ST" "confirm refuses an empty --by"
assert_eq "gone" "$(gone "$OUTD/confirmed.md")" "  and writes nothing"
# --by meets the rule every value meets, as an answer does.
for who in "$(printf 'A\302\205Person')" "$(printf 'A\377Person')" "$(printf 'A\342\200\250Person')" 'A {{NAME}}'; do
  ask confirm widget --by "$who"
  assert_status 1 "$ST" "confirm refuses a --by the value rule refuses: $(printf '%s' "$who" | od -An -c | tr -s ' ' | tail -c 20)"
  assert_contains "$OUT" "--by names the operator on one line" "  and says so"
  assert_eq "gone" "$(gone "$OUTD/confirmed.md")" "  and writes nothing"
done
mkdir -p "$R/stages/01-ask/output"
ask confirm ../../../setup --by 'A Person'
assert_status 1 "$ST" "confirm refuses a NAME its type refuses, as ../../../setup"
assert_contains "$OUT" "a name is lowercase" "  by the NAME rule"
assert_eq "gone" "$(gone "$R/setup/confirmed.md")" "  and writes nothing outside the run's folder"
# confirm hashes as render does, in the workspace under git.sh's
# environment, whatever repository the caller stands in (render R7).
mkdir -p "$SCRATCH/sha256$n"
git init -q --template= --object-format=sha256 "$SCRATCH/sha256$n"
WANT=$(git -C "$R" hash-object --no-filters "$ANS")
OUT=$(cd "$SCRATCH/sha256$n" && "$R/bin/ask" confirm widget --by 'A Person' 2>&1)
assert_contains "$(cat "$OUTD/confirmed.md" 2>/dev/null)" "answers: $WANT" \
  "confirm run from a SHA-256 repository records the workspace's blob id"
OUT=$(cd "$R" && GIT_DIR="$SCRATCH/sha256$n/.git" bin/ask confirm widget --by 'A Person' 2>&1)
assert_contains "$(cat "$OUTD/confirmed.md" 2>/dev/null)" "answers: $WANT" \
  "  and with GIT_DIR naming one"

# confirm holds TARGET to TARGET_ROOT, ~ expanded here, then /NAME (decision
# 227): a TARGET edited by hand, or one written under another HOME, is
# refused, routing to --redo.
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
sed "s|^TARGET=.*|TARGET=$SCRATCH/elsewhere/widget|" "$ANS" >"$ANS.x" && mv "$ANS.x" "$ANS"
ask confirm widget --by 'A Person'
assert_status 1 "$ST" "confirm refuses a TARGET edited by hand"
assert_contains "$OUT" "bin/ask run widget --redo" "  and routes to --redo"
assert_eq "gone" "$(gone "$OUTD/confirmed.md")" "  and writes no confirmed.md"
fresh
mkdir -p "$SCRATCH/home$n/a" "$SCRATCH/home$n/b"
ask setup 'TARGET_ROOT=~/targets'
(cd "$R" && HOME="$SCRATCH/home$n/a" bin/ask run widget 'TITLE=A' 'DESCRIPTION=B' >/dev/null 2>&1)
OUT=$(cd "$R" && HOME="$SCRATCH/home$n/b" bin/ask confirm widget --by 'A Person' 2>&1)
assert_status 1 "$?" "confirm refuses a TARGET written under another HOME"
assert_contains "$OUT" "$SCRATCH/home$n/b/targets/widget" "  and names the TARGET this HOME gives"
OUT=$(cd "$R" && HOME="$SCRATCH/home$n/a" bin/ask confirm widget --by 'A Person' 2>&1)
assert_status 0 "$?" "  and confirms it under the HOME it was written under"

# --- --redo, and the shared discard (AC9) -------------------------------------------------
# rendered: the run as if rendered, its target and render.md in place, with
# 02 and 03 outputs to clear.
rendered() {
  ready
  ask run widget 'TITLE=A' 'DESCRIPTION=B'
  ask confirm widget --by 'A Person'
  mkdir -p "$ROOT/widget/sub" "$R/stages/02-render/output/widget" "$R/stages/03-verify/output/widget/judge/locked"
  printf 'x\n' >"$ROOT/widget/sub/file"
  printf '%s\n' '# Render of widget' '' "target: ${1:-$ROOT/widget}" >"$R/stages/02-render/output/widget/render.md"
  printf 'pass\n' >"$R/stages/03-verify/output/widget/verify.md"
  chmod 000 "$R/stages/03-verify/output/widget/judge/locked"
}

ready
rrefused "--redo on a run that does not exist" "there is no run widget to redo" run widget --redo 'TITLE=A' 'DESCRIPTION=B'
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
ask confirm widget --by 'A Person'
ask run widget --redo 'TITLE=C' 'DESCRIPTION=D'
assert_status 0 "$ST" "--redo of a run never rendered needs no --remove"
assert_eq "TITLE=C" "$(grep '^TITLE=' "$ANS")" "  and rewrites the answers"
assert_eq "gone" "$(gone "$OUTD/confirmed.md")" "  and clears the confirmation"

# --redo keeps every answer and override not given again, as setup does
# (decision 229): a field given replaces its value, and an override is
# changed by giving it again.
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B' 'VISIBILITY=private' --setup-override OWNER=acme
ask run widget --redo 'TITLE=C'
assert_status 0 "$ST" "--redo given one field"
assert_eq "TITLE=C" "$(grep '^TITLE=' "$ANS")" "  replaces it"
assert_eq "DESCRIPTION=B" "$(grep '^DESCRIPTION=' "$ANS")" "  and keeps a run answer not given again"
assert_eq "VISIBILITY=private" "$(grep '^VISIBILITY=' "$ANS")" "  even one that has a default"
assert_eq "OWNER=acme" "$(grep '^OWNER=' "$ANS")" "  and keeps an override not given again"
assert_eq "OWNER=acme" "$(cat "$OUTD/setup.override.env" 2>/dev/null)" "  still recorded in setup.override.env"
assert_eq "HOLDER=acme" "$(grep '^HOLDER=' "$ANS")" "  and a setup default not given is worked out from the override"
ask run widget --redo --setup-override OWNER=Okja-Engineering
assert_status 0 "$ST" "--redo giving an override again"
assert_eq "OWNER=Okja-Engineering" "$(grep '^OWNER=' "$ANS")" "  changes it"
assert_eq "OWNER=Okja-Engineering" "$(cat "$OUTD/setup.override.env" 2>/dev/null)" \
  "  recorded, the setup value making it harmless"
assert_eq "TITLE=C" "$(grep '^TITLE=' "$ANS")" "  and keeps the run answers"
# A kept answer the schema now refuses is refused, naming it.
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B' 'VISIBILITY=private'
sed 's/public|private/public|internal/' "$R/shared/answers.tsv" >"$R/shared/answers.tsv.x" &&
  mv "$R/shared/answers.tsv.x" "$R/shared/answers.tsv"
rrefused "a kept answer the schema now refuses" "give VISIBILITY again" run widget --redo 'TITLE=C'
ask run widget --redo 'TITLE=C' 'VISIBILITY=internal'
assert_status 0 "$ST" "  and giving it again redoes the run"
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B' --setup-override OWNER=acme
printf 'TITLE=X\n' >>"$OUTD/setup.override.env"
ask run widget --redo 'TITLE=C'
assert_status 0 "$ST" "a redo beside a kept override for a run field"
assert_contains "$OUT" "setup.override.env holds TITLE, which is no longer a setup field; it is dropped" \
  "  drops it, with a note"
assert_eq "TITLE=C" "$(grep '^TITLE=' "$ANS")" "  and the run field is the one given"
printf 'OWNER=-acme\n' >"$OUTD/setup.override.env"
rrefused "a kept override the schema refuses" "setup.override.env: OWNER" run widget --redo 'TITLE=C'

rendered
rrefused "--redo of a rendered run without --remove" "--remove" run widget --redo 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  with nothing removed"
rendered
mkdir -p "$ROOT/other"
rrefused "--remove naming another path" "$ROOT/other" run widget --redo --remove "$ROOT/other" 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  with the target not removed"
assert_eq "present" "$(gone "$ROOT/other")" "  nor the other path"
rendered
rrefused "--remove naming the target in other bytes" "is not the run's target $ROOT/widget" \
  run widget --redo --remove "$ROOT/./widget" 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  with nothing removed"
rendered
mkdir -p "$ROOT/other"
printf '%s\n' '# Render of widget' '' "target: $ROOT/other" >"$R/stages/02-render/output/widget/render.md"
rrefused "a recorded target that is not the run's target" "render.md names $ROOT/other, not the run's target $ROOT/widget" \
  run widget --redo --remove "$ROOT/other" 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ROOT/other")" "  with nothing removed"
# The answers file's TARGET edited by hand to match, under TARGET_ROOT with
# another last component.
sed "s|^TARGET=.*|TARGET=$ROOT/other|" "$ANS" >"$ANS.x" && mv "$ANS.x" "$ANS"
rrefused "a TARGET edited by hand to another name" "is not TARGET_ROOT $ROOT, expanded here, then /widget" \
  run widget --redo --remove "$ROOT/other" 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ROOT/other")" "  with nothing removed"
# The record judged before the redo removes render.md, the run's target
# gone: one naming a present path that is not the run's target is refused,
# with no --remove too, and one naming a path that is gone is dropped
# (removal M2 and M6's a03 of S2's third ship gate).
rendered
rm -rf "$ROOT/widget"
mkdir -p "$ROOT/other"
printf '%s\n' '# Render of widget' '' "target: $ROOT/other" >"$R/stages/02-render/output/widget/render.md"
rrefused "a redo whose render.md names a present path that is not the run's target" \
  "render.md names $ROOT/other, not the run's target $ROOT/widget" run widget --redo 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ROOT/other")" "  with it left"
rm -rf "$ROOT/other"
ask run widget --redo 'TITLE=C' 'DESCRIPTION=D'
assert_status 0 "$ST" "a redo whose render.md names a path that is gone"
assert_eq "gone" "$(gone "$R/stages/02-render/output/widget/render.md")" "  removes render.md"
# A first run beside a render.md left from a run removed by hand removes no
# render.md, so it judges none: no refusal of a redo, and nothing on stderr
# but its own line (removal's q02 NIT).
ready
mkdir -p "$R/stages/02-render/output/widget"
printf '%s\n' '# Render of widget' '' "target: $ROOT/widget" >"$R/stages/02-render/output/widget/render.md"
ask run widget 'TITLE=A' 'DESCRIPTION=B'
assert_status 0 "$ST" "a first run beside a stale render.md"
assert_eq "bin/ask: wrote stages/01-ask/output/widget/answers.env" "$OUT" "  says only that it wrote the answers"
ready
mkdir -p "$R/stages/02-render/output/widget" "$ROOT/widget"
printf '%s\n' '# Render of widget' '' "target: $ROOT/widget" >"$R/stages/02-render/output/widget/render.md"
rrefused "a first run beside a stale render.md, its target present" \
  "the target $ROOT/widget is present" run widget 'TITLE=A' 'DESCRIPTION=B'
assert_eq "1" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "  in one line"
rendered
mkdir -p "$SCRATCH/moved$n"
rrefused "a redo moving TARGET_ROOT while the rendered target is present" "remove $ROOT/widget" \
  run widget --redo 'TITLE=C' 'DESCRIPTION=D' --setup-override "TARGET_ROOT=$SCRATCH/moved$n"
assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  with the target left alone"
rendered
mv "$ROOT/widget" "$ROOT/real"
ln -s "$ROOT/real" "$ROOT/widget"
rrefused "a target that is a symbolic link" "symbolic link" run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ROOT/widget")" "  with the link not removed"
assert_eq "present" "$(gone "$ROOT/real/sub/file")" "  nor what it points to"
# Without --remove, a redo whose old target the discard would not take, a
# symbolic link, routes to moving it by hand, never to --remove (removal's
# N6 v40 of S2's fourth ship gate).
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
mkdir -p "$ROOT/real/sub"
printf 'x\n' >"$ROOT/real/sub/file"
ln -s "$ROOT/real" "$ROOT/widget"
rrefused "a redo whose old target is a symbolic link" "a redo may not remove it" \
  run widget --redo 'TITLE=C' 'DESCRIPTION=D'
assert_contains "$OUT" "the operator may move it away by hand" "  naming the way out"
assert_not_contains "$OUT" "--remove" "  and no --remove"
assert_eq "present" "$(gone "$ROOT/widget")" "  with the link not removed"
assert_eq "present" "$(gone "$ROOT/real/sub/file")" "  nor what it points to"
rendered "$SCRATCH/outside/widget"
mkdir -p "$SCRATCH/outside/widget"
rrefused "a path outside TARGET_ROOT, which render.md names but the run's TARGET is not" \
  "render.md names $SCRATCH/outside/widget, not the run's target $ROOT/widget" \
  run widget --redo --remove "$SCRATCH/outside/widget" 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$SCRATCH/outside/widget")" "  with nothing removed"
# The answers file's TARGET edited by hand to a path outside TARGET_ROOT:
# another root, a .. component, a symbolic link on the way; with no
# render.md, and with render.md edited to match (removal N1 of S2's second
# ship gate). The discard derives the target from TARGET_ROOT itself, so a
# plain redo never routes to removing that path, and --remove naming it is
# refused, with nothing removed.
for how in outside dotdot link; do
  for md in none edited; do
    ready
    ask run widget 'TITLE=A' 'DESCRIPTION=B'
    O="$SCRATCH/precious$n/widget"
    mkdir -p "$O"
    printf 'keep\n' >"$O/file"
    case "$how" in
      outside) P=$O ;;
      dotdot) P="$ROOT/../precious$n/widget" ;;
      link) ln -s "$SCRATCH/precious$n" "$ROOT/lnk" && P="$ROOT/lnk/widget" ;;
    esac
    sed "s|^TARGET=.*|TARGET=$P|" "$ANS" >"$ANS.x" && mv "$ANS.x" "$ANS"
    if [ "$md" = edited ]; then
      mkdir -p "$R/stages/02-render/output/widget"
      printf '%s\n' '# Render of widget' '' "target: $P" >"$R/stages/02-render/output/widget/render.md"
    fi
    ask run widget --redo 'TITLE=C'
    assert_not_contains "$OUT" "--remove \"$P\"" "a TARGET edited by hand $how TARGET_ROOT, render.md $md: no route removes it"
    assert_eq "present" "$(gone "$O/file")" "  and it is left"
    if [ "$md" = none ]; then
      assert_status 0 "$ST" "  and the redo, the route confirm and render name, rewrites the answers"
      assert_eq "TARGET=$ROOT/widget" "$(grep '^TARGET=' "$ANS")" "  with TARGET as TARGET_ROOT, then /NAME"
    fi
    sed "s|^TARGET=.*|TARGET=$P|" "$ANS" >"$ANS.x" && mv "$ANS.x" "$ANS"
    if [ "$md" = edited ]; then
      mkdir -p "$R/stages/02-render/output/widget"
      printf '%s\n' '# Render of widget' '' "target: $P" >"$R/stages/02-render/output/widget/render.md"
    fi
    rrefused "  --remove naming it" "is not TARGET_ROOT $ROOT, expanded here, then /widget" \
      run widget --redo --remove "$P" 'TITLE=C'
    assert_eq "present" "$(gone "$O/file")" "  with it left"
  done
done
# A relative path, which render.md names too, is refused (decision 227):
# run from TARGET_ROOT's parent, with TARGET_ROOT itself named widget.
fresh
ROOT="$SCRATCH/p$n/widget"
mkdir -p "$ROOT"
printf 'kept\n' >"$ROOT/kept"
ask setup "TARGET_ROOT=$ROOT"
OUTD="$R/stages/01-ask/output/widget"
ANS="$OUTD/answers.env"
ask run widget 'TITLE=A' 'DESCRIPTION=B'
mkdir -p "$R/stages/02-render/output/widget"
printf '%s\n' '# Render of widget' '' 'target: widget' >"$R/stages/02-render/output/widget/render.md"
before=$(run_state)
OUT=$(cd "$SCRATCH/p$n" && "$R/bin/ask" run widget --redo --remove widget 'TITLE=C' 'DESCRIPTION=D' 2>&1)
assert_status 1 "$?" "refused: --remove naming a relative path that render.md names"
assert_contains "$OUT" "remove widget: " "  and the refusal says so"
assert_eq "present" "$(gone "$ROOT/kept")" "  and TARGET_ROOT is left alone"
assert_eq "$before" "$(run_state)" "  and the run's files are as they were"
printf '%s\n' '# Render of widget' '' 'target: widget' >"$R/stages/02-render/output/widget/render.md"
OUT=$(cd "$SCRATCH/p$n" && "$R/bin/ask" run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D' 2>&1)
assert_status 1 "$?" "refused: a recorded target that is a relative path"
# A record names a target only as an absolute TARGET (removal N3 of S2's
# fourth ship gate).
assert_contains "$OUT" "render.md names no target: TARGET: a path is absolute" "  and the refusal says so"
assert_eq "present" "$(gone "$ROOT/kept")" "  with nothing removed"
# A run's target present with no render.md naming it, left by a render that
# was killed, or a directory made by hand: the redo names it, and removes it
# only with --remove naming it.
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
mkdir -p "$ROOT/widget/sub"
rrefused "a redo whose target is present, with no render.md" "--redo --remove \"$ROOT/widget\"" \
  run widget --redo 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ROOT/widget/sub")" "  with the target left alone"
ask run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D'
assert_status 0 "$ST" "  and --redo --remove naming it removes it"
assert_eq "gone" "$(gone "$ROOT/widget")" "  the target gone"
# A run whose answers file has lost its TARGET has no target to judge.
grep -v '^TARGET=' "$ANS" >"$ANS.x" && mv "$ANS.x" "$ANS"
rrefused "a redo of a run whose answers file holds no TARGET" "holds no TARGET" \
  run widget --redo 'TITLE=C' 'DESCRIPTION=D'
rendered
mkdir -p "$ROOT/widget/locked/deeper"
chmod 000 "$ROOT/widget/locked/deeper" "$ROOT/widget/locked"
ask run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D'
assert_status 0 "$ST" "--redo --remove the target render.md names"
assert_eq "gone" "$(gone "$ROOT/widget")" "  removes the target, chmod 000 directories and all"
assert_eq "gone" "$(gone "$R/stages/02-render/output/widget")" "  and the run's 02 outputs"
assert_eq "gone" "$(gone "$R/stages/03-verify/output/widget")" "  and its 03 outputs, a chmod 000 judge/ directory and all"
assert_eq "TITLE=C" "$(grep '^TITLE=' "$ANS")" "  then rewrites the answers"
assert_eq "gone" "$(gone "$OUTD/confirmed.md")" "  and clears the confirmation"

# A TARGET_ROOT reached through a symbolic link (decision 149).
fresh
mkdir -p "$SCRATCH/realroot$n"
ln -s "$SCRATCH/realroot$n" "$SCRATCH/linkroot$n"
ROOT="$SCRATCH/linkroot$n"
ask setup "TARGET_ROOT=$ROOT"
OUTD="$R/stages/01-ask/output/widget"
ANS="$OUTD/answers.env"
ask run widget 'TITLE=A' 'DESCRIPTION=B'
mkdir -p "$ROOT/widget" "$R/stages/02-render/output/widget"
printf '%s\n' '# Render of widget' '' "target: $ROOT/widget" >"$R/stages/02-render/output/widget/render.md"
ask run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D'
assert_status 0 "$ST" "a TARGET_ROOT through a symbolic link is accepted"
assert_eq "gone" "$(gone "$SCRATCH/realroot$n/widget")" "  and the target removed"

# A removal made to fail by a stub rm first on PATH (decision 203).
rendered
mkdir -p "$SCRATCH/stub$n"
printf '#!/bin/sh\nexit 0\n' >"$SCRATCH/stub$n/rm"
chmod +x "$SCRATCH/stub$n/rm"
before=$(run_state)
OUT=$(cd "$R" && PATH="$SCRATCH/stub$n:$PATH" bin/ask run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D' 2>&1)
ST=$?
assert_status 1 "$ST" "refused: a removal that fails"
assert_contains "$OUT" "could not remove $ROOT/widget" "  and the refusal names the path"
assert_eq "$before" "$(run_state)" "  and the run's files are as they were"
# The clear of the 03 outputs, reached once the target is gone, made to fail
# by a stub rm that fails on that path only (decision 211's L-4): refused
# naming it, with the run's files as they were, its confirmation and
# render.md among them, so the redo is asked for again.
rendered
mkdir -p "$R/stages/03-verify/output/widget/judge" "$SCRATCH/stub$n"
printf '#!/bin/sh\ncase "$*" in *03-verify*) exit 0 ;; esac\nexec %s "$@"\n' "$(command -v rm)" >"$SCRATCH/stub$n/rm"
chmod +x "$SCRATCH/stub$n/rm"
before=$(run_state)
OUT=$(cd "$R" && PATH="$SCRATCH/stub$n:$PATH" bin/ask run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D' 2>&1)
ST=$?
assert_status 1 "$ST" "refused: a redo whose clear of the 03 outputs fails"
assert_contains "$OUT" "stages/03-verify/output/widget" "  and the refusal names that path"
assert_eq "$before" "$(run_state)" "  and the run's files are as they were"
assert_eq "gone" "$(gone "$ROOT/widget")" "  the target, which the operator's yes removed, aside"

# --- what a run owns (decisions 226, 230) ---------------------------------------------------
# Everything that can refuse is settled before anything is removed: a redo
# whose answers file cannot be staged, its run folder read-only, refuses
# with the target and the run's files as they were.
if [ "$(id -u)" != 0 ]; then
  rendered
  before=$(run_state)
  chmod 555 "$OUTD"
  ask run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D'
  chmod 755 "$OUTD"
  assert_status 1 "$ST" "refused: a redo whose answers file cannot be staged"
  assert_contains "$OUT" "cannot write beside" "  and the refusal says so"
  assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  with the target as it was"
  assert_eq "$before" "$(run_state)" "  and the run's files as they were"
fi
# A signal removes what the run made: a redo signalled while it clears its
# 03 outputs ends by the signal, leaving no temporary file beside the files
# it writes. A TERM ignored when the suite began, which ask cannot trap,
# skips it (entry_ignored).
if entry_ignored TERM; then
  assert_pass "skipped: SIGTERM was ignored when the suite began, so ask cannot trap it"
else
  rendered
  mkdir -p "$SCRATCH/stub$n"
  printf '#!/bin/sh\ncase "$*" in *03-verify*) kill -s TERM "$(cat "%s")" ;; esac\nexec %s "$@"\n' \
    "$SCRATCH/pid$n" "$(command -v rm)" >"$SCRATCH/stub$n/rm"
  chmod +x "$SCRATCH/stub$n/rm"
  OUT=$(cd "$R" && PATH="$SCRATCH/stub$n:$PATH" sh -c 'echo "$$" >"$1" && shift && exec bin/ask "$@"' sh "$SCRATCH/pid$n" \
    run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D' 2>&1)
  ST=$?
  assert_status 143 "$ST" "a redo signalled during its removals ends by the signal"
  assert_eq "" "$(cd "$OUTD" && find . -name '*.tmp.*')" "  and leaves no temporary file"
fi
# In any shell mode (render R1 of S2's fourth ship gate): with POSIXLY_CORRECT
# set, where kill -l prints bare names, each command runs to the outcome it
# has without it, a redo --remove and a refusal included.
ready
OUT=$(cd "$R" && export POSIXLY_CORRECT=1 && bin/ask questionnaire 2>&1 && bin/ask setup "TARGET_ROOT=$ROOT" 2>&1 &&
  bin/ask run widget 'TITLE=A' 'DESCRIPTION=B' 2>&1 && bin/ask confirm widget --by 'A Person' 2>&1)
assert_status 0 "$?" "with POSIXLY_CORRECT set, questionnaire, setup, run and confirm${OUT:+ ($OUT)}"
rendered
OUT=$(cd "$R" && export POSIXLY_CORRECT=1 && bin/ask run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D' 2>&1)
assert_status 0 "$?" "with POSIXLY_CORRECT set, a redo --remove${OUT:+ ($OUT)}"
assert_eq "gone TITLE=C" "$(gone "$ROOT/widget") $(grep '^TITLE=' "$ANS")" "  removes the target and writes the answers"
OUT=$(cd "$R" && export POSIXLY_CORRECT=1 && bin/ask run widget 'TITLE=E' 2>&1)
assert_status 1 "$?" "with POSIXLY_CORRECT set, a refusal is a refusal"
assert_contains "$OUT" "the run widget exists" "  for its own reason"
# A shell whose signal list gives no set, or one lacking HUP, INT or TERM,
# is refused, exit 2, before ask makes anything. A trap exported as a
# function stands in for the shell's own list.
for LISTING in '' ' 1) SIGHUP	15) SIGTERM'; do
  ready
  OUT=$(
    cd "$R" &&
      trap() { if [ "${1:-}" = -l ]; then printf '%s' "$LISTING"; else builtin trap "$@"; fi; } &&
      export -f trap && bin/ask run widget 'TITLE=A' 'DESCRIPTION=B' 2>&1
  )
  assert_status 2 "$?" "refused: a run where the signals to hold give the set \"$LISTING\""
  assert_contains "$OUT" "cannot work out the signals to hold off" "  and the refusal says so"
  assert_eq "gone" "$(gone "$OUTD")" "  and nothing is made"
done
# A redo removes the staging directories a killed render left under the old
# TARGET_ROOT, so a moved TARGET_ROOT strands none (decision 226), and
# nothing else there.
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
mkdir -p "$ROOT/.widget.render.4242/a" "$ROOT/.widget.render.x1" "$SCRATCH/moved$n"
ask run widget --redo --setup-override "TARGET_ROOT=$SCRATCH/moved$n"
assert_status 0 "$ST" "a redo that moves TARGET_ROOT"
assert_eq "gone" "$(gone "$ROOT/.widget.render.4242")" "  removes a killed render's staging directory under the old one"
assert_eq "present" "$(gone "$ROOT/.widget.render.x1")" "  and nothing else there"
# The old TARGET_ROOT is the old answers file's, so a root moved by
# bin/ask setup, not by an override, strands none either (answers' R3, k22).
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
mkdir -p "$ROOT/.widget.render.4242" "$SCRATCH/moved$n"
ask setup "TARGET_ROOT=$SCRATCH/moved$n"
ask run widget --redo
assert_status 0 "$ST" "a redo after bin/ask setup moves TARGET_ROOT"
assert_eq "TARGET=$SCRATCH/moved$n/widget" "$(grep '^TARGET=' "$ANS")" "  renders under the new root"
assert_eq "gone" "$(gone "$ROOT/.widget.render.4242")" "  and removes a killed render's staging directory under the old one"
# One the removal helper cannot remove is refused, naming it (removal M6's
# a10 of S2's third ship gate).
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
mkdir -p "$ROOT/.widget.render.4242" "$SCRATCH/moved$n" "$SCRATCH/rmstub$n"
printf '#!/bin/sh\ncase "$*" in *.widget.render.4242*) exit 0 ;; esac\nexec %s "$@"\n' "$(command -v rm)" >"$SCRATCH/rmstub$n/rm"
chmod +x "$SCRATCH/rmstub$n/rm"
OUT=$(cd "$R" && PATH="$SCRATCH/rmstub$n:$PATH" bin/ask run widget --redo --setup-override "TARGET_ROOT=$SCRATCH/moved$n" 2>&1)
assert_status 1 "$?" "refused: a redo whose old staging directory cannot be removed"
assert_contains "$OUT" "could not remove $ROOT/.widget.render.4242" "  naming it"
# The answers file is staged before anything is removed, too: an entry in
# the way of its temporary file alone, whose name is bin/ask's PID, refuses
# a redo with the target and the run's files as they were.
rendered
before=$(run_state)
OUT=$(cd "$R" && sh -c ': >"$1/answers.env.tmp.$$" && shift && exec bin/ask "$@"' sh "$OUTD" \
  run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D' 2>&1)
ST=$?
assert_status 1 "$ST" "refused: a redo whose answers file's temporary name is taken"
assert_contains "$OUT" "is in the way" "  and the refusal says so"
assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  with the target as it was"
rm -f "$OUTD"/answers.env.tmp.*
assert_eq "$before" "$(run_state)" "  and the run's files as they were"
# A signal while the staged files are renamed into place is held off, so
# each file is the old one or the new, together; with TERM ignored when the
# suite began, the case would pass without the hold, so it is skipped.
if entry_ignored TERM; then
  assert_pass "skipped: SIGTERM was ignored when the suite began, so the hold cannot be told"
else
  ready
  ask run widget 'TITLE=A' 'DESCRIPTION=B'
  mkdir -p "$SCRATCH/mvstub$n"
  printf '#!/bin/sh\ncase "$*" in *given.env.tmp.*) kill -s TERM "$PPID" ;; esac\nexec %s "$@"\n' \
    "$(command -v mv)" >"$SCRATCH/mvstub$n/mv"
  chmod +x "$SCRATCH/mvstub$n/mv"
  OUT=$(cd "$R" && PATH="$SCRATCH/mvstub$n:$PATH" bin/ask run widget --redo 'TITLE=C' 2>&1)
  assert_status 0 "$?" "a TERM while a redo renames its files into place is held off"
  assert_eq "TITLE=C" "$(grep '^TITLE=' "$ANS")" "  and the answers file is the new one"
  assert_contains "$(cat "$OUTD/given.env")" "TITLE=C" "  as given.env is"
  assert_eq "" "$(cd "$OUTD" && find . -name '*.tmp.*')" "  with no temporary file left"
fi
# A second signal while cleanup runs is held off, so cleanup finishes: a
# first run whose first rename fails, then a TERM as cleanup removes the
# first of its two temporary files (answers' R9 M19 and removal's N6 v59 of
# S2's fourth ship gate).
if entry_ignored TERM; then
  assert_pass "skipped: SIGTERM was ignored when the suite began, so the hold cannot be told"
else
  ready
  mkdir -p "$SCRATCH/clstub$n"
  printf '#!/bin/sh\ncase "$*" in *given.env.tmp.*) exit 1 ;; esac\nexec %s "$@"\n' \
    "$(command -v mv)" >"$SCRATCH/clstub$n/mv"
  printf '#!/bin/sh\ncase "$*" in *given.env.tmp.*) kill -s TERM "$PPID" ;; esac\nexec %s "$@"\n' \
    "$(command -v rm)" >"$SCRATCH/clstub$n/rm"
  chmod +x "$SCRATCH/clstub$n/mv" "$SCRATCH/clstub$n/rm"
  OUT=$(cd "$R" && PATH="$SCRATCH/clstub$n:$PATH" bin/ask run widget 'TITLE=A' 'DESCRIPTION=B' 2>&1)
  assert_status 1 "$?" "a TERM while cleanup removes a refused run's temporary files is held off"
  assert_eq "gone" "$(gone "$OUTD")" "  so cleanup finishes: no temporary file, and no folder it made"
fi
# The signals are let through again once the files are placed: a run whose
# last line meets a pipe whose reader has gone ends by SIGPIPE, its files
# written (the tests lens's NIT 5 of S2's fourth ship gate).
if entry_ignored PIPE; then
  assert_pass "skipped: SIGPIPE was ignored when the suite began, so ask cannot trap it"
else
  ready
  ask_out() { (cd "$R" && exec bin/ask "$@" 2>"$SCRATCH/err$n"); }
  reader_gone "$SCRATCH/fifo$n" ask_out run widget 'TITLE=A' 'DESCRIPTION=B'
  assert_status 141 "$?" "a run whose last line meets a pipe with no reader ends by SIGPIPE"
  assert_eq "TITLE=A" "$(grep '^TITLE=' "$ANS")" "  once its answers are written"
  assert_eq "" "$(cd "$OUTD" && find . -name '*.tmp.*')" "  with no temporary file left"
fi
# git's version gate, as render has it: the root rule's `git worktree list
# -z` needs git 2.36 (answers' NIT 3 of S2's fourth ship gate).
ready
mkdir -p "$SCRATCH/oldgit$n"
printf '#!/bin/sh\nif [ "$1" = --version ]; then echo "git version 2.35.9"; exit 0; fi\nexec %s "$@"\n' "$(command -v git)" >"$SCRATCH/oldgit$n/git"
chmod +x "$SCRATCH/oldgit$n/git"
for args in "setup OWNER=acme" "run widget TITLE=A DESCRIPTION=B"; do
  before=$(state)
  # shellcheck disable=SC2086 # the arguments, split
  OUT=$(cd "$R" && PATH="$SCRATCH/oldgit$n:$PATH" bin/ask $args 2>&1)
  assert_status 1 "$?" "refused: ${args%% *} under git older than 2.36"
  assert_contains "$OUT" "older than 2.36" "  and the refusal names the floor"
  assert_eq "$before gone" "$(state) $(gone "$OUTD")" "  and nothing is written"
done
# A given file names each field once.
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
printf 'DESCRIPTION=B\nTITLE=A\nTITLE=B\n' >"$OUTD/given.env"
rrefused "a given.env naming a field twice" "given.env:3: TITLE is given twice" run widget --redo
fresh
mkdir -p "$R/setup" && printf 'OWNER=a\nOWNER=b\n' >"$R/setup/given.env"
refused "a setup/given.env naming a field twice" "setup/given.env:2: OWNER is given twice" setup
# A given file left with nothing is removed, never written empty: setup's,
# and a run's once the schema drops each field it held.
fresh
mkdir -p "$R/setup" && printf 'STALE=1\n' >"$R/setup/given.env"
ask setup
assert_status 0 "$ST" "setup beside a setup/given.env holding only a stale field"
assert_eq "gone" "$(gone "$R/setup/given.env")" "  removes it"
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
grep -v -e '^TITLE' -e '^DESCRIPTION' -e '^SUMMARY' "$R/shared/answers.tsv" >"$SCRATCH/schema$n" &&
  mv "$SCRATCH/schema$n" "$R/shared/answers.tsv"
ask run widget --redo
assert_status 0 "$ST" "a redo once the schema drops every field given.env holds"
assert_eq "gone" "$(gone "$OUTD/given.env")" "  removes given.env"



# --- a write that fails (decision 228) ------------------------------------------------------
# A write runs in this shell, never at the end of a pipeline, so a write that
# fails, or whose input fails, refuses and leaves its file as it was.
if [ "$(id -u)" != 0 ]; then
  ready
  before=$(state)
  chmod 555 "$R/setup"
  ask setup OWNER=acme
  chmod 755 "$R/setup"
  assert_status 1 "$ST" "refused: setup whose file cannot be written"
  assert_contains "$OUT" "cannot write beside $R/setup/given.env" "  and the refusal names the first it writes"
  assert_not_contains "$OUT" "wrote" "  and claims no write"
  assert_eq "$before" "$(state)" "  and setup/answers.env is as it was"
  mkdir -p "$OUTD"
  chmod 555 "$OUTD"
  ask run widget 'TITLE=A' 'DESCRIPTION=B'
  chmod 755 "$OUTD"
  assert_status 1 "$ST" "refused: run whose answers file cannot be written"
  assert_eq "absent" "$(run_state)" "  and no answers file is written"
  ask run widget 'TITLE=A' 'DESCRIPTION=B'
  chmod 555 "$OUTD"
  ask confirm widget --by 'A Person'
  chmod 755 "$OUTD"
  assert_status 1 "$ST" "refused: confirm whose confirmed.md cannot be written"
  assert_eq "gone" "$(gone "$OUTD/confirmed.md")" "  and no confirmed.md is written"
fi
ready
before=$(state)
mkdir -p "$SCRATCH/sortstub$n"
printf '#!/bin/sh\nexit 1\n' >"$SCRATCH/sortstub$n/sort"
chmod +x "$SCRATCH/sortstub$n/sort"
OUT=$(cd "$R" && PATH="$SCRATCH/sortstub$n:$PATH" bin/ask setup OWNER=acme 2>&1)
ST=$?
assert_status 1 "$ST" "refused: setup whose text cannot be sorted"
assert_eq "$before" "$(state)" "  and setup/answers.env is as it was"
# The temporary file is made exclusively: a symbolic link to /dev/null
# planted at the name this process will use, which noclobber alone would
# open, is refused and left (decision 230).
ready
before=$(state)
OUT=$(cd "$R" && sh -c 'ln -s /dev/null "setup/answers.env.tmp.$$" && exec bin/ask setup OWNER=acme' 2>&1)
ST=$?
assert_status 1 "$ST" "refused: a symbolic link to /dev/null at the temporary file's name"
assert_contains "$OUT" "is in the way" "  and the refusal says so"
assert_eq "$before" "$(state)" "  and setup/answers.env is as it was"
assert_eq "1" "$(find "$R/setup" -name 'answers.env.tmp.*' -type l | wc -l | tr -d ' ')" "  and the planted link is left"
# The temporary file is made exclusively: one already there, a symbolic link
# planted at the name this process will use, is refused, not written through.
ready
printf 'outside\n' >"$SCRATCH/outside$n"
before=$(state)
OUT=$(cd "$R" && sh -c 'ln -s "$1" "setup/answers.env.tmp.$$" && exec bin/ask setup OWNER=acme' sh "$SCRATCH/outside$n" 2>&1)
ST=$?
assert_status 1 "$ST" "refused: a write whose temporary file is already there, as a symbolic link"
assert_eq "outside" "$(cat "$SCRATCH/outside$n")" "  and nothing is written through it"
assert_eq "$before" "$(state)" "  and setup/answers.env is as it was"
rendered
mkdir -p "$SCRATCH/stub$n"
printf '#!/bin/sh\nexit 1\n' >"$SCRATCH/stub$n/sort"
chmod +x "$SCRATCH/stub$n/sort"
before=$(run_state)
OUT=$(cd "$R" && PATH="$SCRATCH/stub$n:$PATH" bin/ask run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D' 2>&1)
ST=$?
assert_status 1 "$ST" "refused: a redo whose answers cannot be sorted"
assert_eq "$before" "$(run_state)" "  and the run's files are as they were"
assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  and, judged before anything is removed, the target is left alone"
assert_eq "present" "$(gone "$OUTD/confirmed.md")" "  and the confirmation"

# --- a read that fails, refused (decision 228) ------------------------------------------------
# Every value bin/ask judges or writes comes from a command whose status is
# read: a stub tool failing one call (fixture_failing) is refused, never written
# as an empty value or a file missing its fields.
# asked TOOL PATTERN NTH ARG...: bin/ask ARG... under the stub, which exits
# FAIL_STATUS, 1 by default.
asked() {
  fixture_failing "$SCRATCH/fail$n" "$1" "$2" "$3" "${FAIL_STATUS:-1}"
  shift 3
  OUT=$(cd "$R" && PATH="$SCRATCH/fail$n:$PATH" bin/ask "$@" 2>&1)
  ST=$?
}
# q4: a first run refused once it has made the run's folder removes the
# folder it made, as render does (conformance N-C of S2's fourth ship gate).
ready
asked mv '*answers.env.tmp.*' 1 run widget 'TITLE=A' 'DESCRIPTION=B'
assert_status 1 "$ST" "refused: a first run whose answers cannot be renamed into place"
assert_eq "gone" "$(gone "$OUTD")" "  and the run's folder it made is removed"
# q6: a redo whose rename fails after its removals refuses naming what it
# removed and the route, the redo again (conformance N-D of S2's fourth ship
# gate). The removals stay first, so no new answers name a target still there.
rendered
asked mv '*answers.env.tmp.*' 1 run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D'
assert_status 1 "$ST" "refused: a redo whose answers cannot be renamed into place after its removals"
assert_contains "$OUT" "having removed $ROOT/widget" "  naming the target it removed"
assert_contains "$OUT" "stages/01-ask/output/widget/confirmed.md" "  and the confirmation"
assert_contains "$OUT" "run bin/ask run widget --redo again" "  and the route"
ask run widget --redo 'TITLE=C' 'DESCRIPTION=D'
assert_status 0 "$ST" "  and the route, followed, writes the answers"
assert_eq "TITLE=C" "$(grep '^TITLE=' "$ANS")" "  as given"
ready
before=$(state)
asked awk '*ENVIRON\["S"] == ""*' 1 setup OWNER=acme
assert_status 1 "$ST" "refused: setup whose setup fields cannot be read"
assert_contains "$OUT" "cannot read the setup fields" "  and the refusal says so"
assert_eq "$before" "$(state)" "  and setup/answers.env is as it was"
# The look, for each field setup/given.env gave, at whether it is given
# again: setup's first answers_get (answers' R9's M20 of S2's fourth ship
# gate). One that fails keeps nothing it cannot tell.
ready
before=$(state)
FAIL_STATUS=2 asked awk '*!found && i > 1*' 1 setup OWNER=acme
assert_status 1 "$ST" "refused: setup that cannot tell whether a field given before is given again"
assert_contains "$OUT" "cannot read the answers given" "  and the refusal says so"
assert_eq "$before" "$(state)" "  and setup/answers.env is as it was"
# Setup's root rule, which cannot list the workspace's working trees, cannot
# judge TARGET_ROOT, and writes nothing (removal's N6 v57 of S2's fourth
# ship gate).
ready
before=$(state)
asked git '*worktree list*' 1 setup "TARGET_ROOT=$SCRATCH/elsewhere$n"
assert_status 1 "$ST" "refused: setup whose TARGET_ROOT cannot be judged"
assert_contains "$OUT" "cannot judge TARGET_ROOT" "  and the refusal says so"
assert_eq "$before" "$(state)" "  and setup/answers.env is as it was"
# A default that cannot be worked out is refused, never written empty: in
# setup, the first schema cell read is OWNER's default; in run, the 54th is
# VISIBILITY's, and the 55th the one answers_default works it out from, the
# reads of what bin/ask setup writes, which a run compares, before them.
fresh
asked awk '*col\[$i] = i*' 1 setup
assert_status 1 "$ST" "refused: setup whose default cannot be read"
assert_contains "$OUT" "OWNER: cannot read its default" "  and the refusal says so"
assert_eq "absent" "$(state)" "  and no setup/answers.env is written"
for at in "54 VISIBILITY: cannot read its default" "55 VISIBILITY: cannot work out its default"; do
  ready
  asked awk '*col\[$i] = i*' "${at%% *}" run widget 'TITLE=A' 'DESCRIPTION=B'
  assert_status 1 "$ST" "refused: run whose default cannot be read, at read ${at%% *}"
  assert_contains "$OUT" "${at#* }" "  and the refusal says so"
  assert_eq "absent" "$(run_state)" "  and no answers file is written"
done
ready
asked awk '*BEGIN { print ENVIRON\["H"] }*' 1 questionnaire
assert_status 1 "$ST" "refused: a questionnaire whose text cannot be made"
assert_eq "gone" "$(gone "$R/setup/questionnaire.md")" "  and writes none"
# The schema's field lists a run reads, in order: setup/answers.env's check,
# what bin/ask setup writes from setup/given.env (decision 229), the setup
# fields a run works out, then the run answers' check, whose run fields are
# its second; each needle is the refusal's own first line.
for at in "1 cannot judge setup/answers.env" "2 cannot work out what bin/ask setup writes" \
  "3 cannot read the setup fields of shared/answers.tsv" "5 cannot read the run fields"; do
  ready
  asked awk '*ENVIRON\["S"] == ""*' "${at%% *}" run widget 'TITLE=A' 'DESCRIPTION=B' 'VISIBILITY=public'
  assert_status 1 "$ST" "refused: run whose schema's fields cannot be read, at read ${at%% *}"
  assert_contains "$OUT" "${at#* }" "  and the refusal says so"
  assert_eq "absent" "$(run_state)" "  and no answers file is written"
done
# answers_get's reads, in order: those working out what bin/ask setup
# writes, which a run compares first; then per setup field, its override, then
# whether setup/given.env records it, then, if so, its setup value; per
# setup field and per run field, what was given; then TARGET_ROOT.
# A read that fails, exiting 2, is never read as a field the file lacks
# (decision 228).
export FAIL_STATUS=2
ready
asked awk '*!found && i > 1*' 6 run widget 'TITLE=A' 'DESCRIPTION=B' 'VISIBILITY=public'
assert_status 1 "$ST" "refused: run whose setup/given.env's fields cannot be read"
assert_contains "$OUT" "cannot read setup/given.env's fields" "  and the refusal says so"
assert_eq "absent" "$(run_state)" "  and no answers file is written"
ready
asked awk '*!found && i > 1*' 9 run widget 'TITLE=A' 'DESCRIPTION=B' 'VISIBILITY=public'
assert_status 1 "$ST" "refused: run whose setup value cannot be read"
assert_contains "$OUT" "cannot read TARGET_ROOT from setup/answers.env" "  and the refusal says so"
assert_eq "absent" "$(run_state)" "  and no answers file is written"
ready
asked awk '*!found && i > 1*' 22 run widget 'TITLE=A' 'DESCRIPTION=B' 'VISIBILITY=public'
assert_status 1 "$ST" "refused: run whose TARGET_ROOT cannot be read back"
assert_contains "$OUT" "cannot read TARGET_ROOT from this run's answers.env" "  and the refusal says so"
assert_eq "absent" "$(run_state)" "  and no answers file is written"
# A lookup whose 1 is "none" failing, exiting 2, is refused, saying what it
# could not read, never judged as none: the email and rule-word looks in
# free text, the field's scope, the confirmed TARGET, an old run's TARGET
# and render.md's target.
ready
asked grep '-Eq -e \[A-Za-z0-9._%+-]+@*' 1 run widget 'TITLE=A' 'DESCRIPTION=write to a@b.co'
assert_status 1 "$ST" "refused: run whose look for an email address fails"
assert_contains "$OUT" "cannot look for an email address" "  and the refusal says so"
assert_eq "absent" "$(run_state)" "  and no answers file is written"
ready
asked awk '*MODE=word*' 1 run widget 'TITLE=A' 'DESCRIPTION=you must stop'
assert_status 1 "$ST" "refused: run whose look for a rule word fails"
assert_contains "$OUT" "cannot look for a rule word" "  and the refusal says so"
assert_eq "absent" "$(run_state)" "  and no answers file is written"
ready
asked awk '*col\[$i] = i*' 1 setup OWNER=acme
assert_status 1 "$ST" "refused: setup whose field's scope cannot be read"
assert_contains "$OUT" "cannot read the scope of OWNER" "  and the refusal says so, never an unknown field"
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
asked awk '*!found && i > 1*' 1 confirm widget --by 'A Person'
assert_status 1 "$ST" "refused: confirm whose TARGET cannot be read"
assert_contains "$OUT" "cannot read TARGET from the answers" "  and the refusal says so"
assert_not_contains "$OUT" "--redo" "  routing nowhere a redo would not help"
assert_eq "gone" "$(gone "$OUTD/confirmed.md")" "  and no confirmed.md is written"
rendered
before=$(run_state)
asked awk '*ENVIRON\["K"]*render.md' 1 run widget --redo 'TITLE=C' 'DESCRIPTION=D'
assert_status 1 "$ST" "refused: a redo whose render.md cannot be read"
assert_contains "$OUT" "cannot read $R/stages/02-render/output/widget/render.md" "  and the refusal says so"
assert_eq "$before" "$(run_state)" "  and the run's files are as they were"
unset FAIL_STATUS
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
asked date '-u *' 1 confirm widget --by 'A Person'
assert_status 1 "$ST" "refused: confirm whose time cannot be read"
assert_contains "$OUT" "cannot read the time" "  and the refusal says so"
assert_eq "gone" "$(gone "$OUTD/confirmed.md")" "  and no confirmed.md is written"
# The first argument-less sort is what bin/ask setup writes, which a run
# compares with setup/answers.env: failing, it is no text, never a refusal
# of setup/given.env; the second is the run's answers.
ready
asked sort '' 1 run widget 'TITLE=A' 'DESCRIPTION=B'
assert_status 1 "$ST" "refused: run whose setup text cannot be sorted"
assert_contains "$OUT" "cannot work out what bin/ask setup writes" "  and the refusal says so"
assert_not_contains "$OUT" "gives no setup/answers.env" "  never a refusal of setup/given.env"
ready
asked sort '' 2 run widget 'TITLE=A' 'DESCRIPTION=B'
assert_status 1 "$ST" "refused: run whose answers cannot be sorted"
assert_contains "$OUT" "cannot sort the answers" "  and the refusal says so"
assert_eq "absent" "$(run_state)" "  and no answers file is written"
ready
asked mkdir '-p *' 1 run widget 'TITLE=A' 'DESCRIPTION=B'
assert_status 1 "$ST" "refused: run whose output directory cannot be made"
assert_contains "$OUT" "cannot make the directory of" "  and the refusal says so"
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
asked git '*hash-object*' 1 confirm widget --by 'A Person'
assert_status 1 "$ST" "refused: confirm whose answers cannot be hashed"
assert_contains "$OUT" "cannot hash" "  and the refusal says so"
assert_eq "gone" "$(gone "$OUTD/confirmed.md")" "  and no confirmed.md is written"

# A setup.override.env left holding only a field the schema no longer
# lists as a setup field is removed by a redo; a removal that fails refuses.
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
printf 'TITLE=Z\n' >"$OUTD/setup.override.env"
asked rm '*setup.override.env' 1 run widget --redo 'TITLE=C' 'DESCRIPTION=D'
assert_status 1 "$ST" "refused: a redo whose stale setup.override.env cannot be removed"
assert_contains "$OUT" "/stages/01-ask/output/widget/setup.override.env; remove it" "  and the refusal names it"

# --- each argument and guard reached (F9 of the tests lens) ----------------------------
ready
ask run
assert_status 2 "$ST" "run with no NAME is a usage error"
assert_contains "$OUT" "run needs NAME" "  and says so"
ask run widget --redo --remove
assert_status 2 "$ST" "--remove with no PATH is a usage error"
assert_contains "$OUT" "--remove needs PATH" "  and says so"
ask run widget --bogus
assert_status 2 "$ST" "an unknown option is a usage error"
assert_contains "$OUT" "unknown option: --bogus" "  and names it"
ask confirm gadget --by 'A Person'
assert_status 1 "$ST" "refused: confirm of a run that does not exist"
assert_contains "$OUT" "there is no run gadget" "  and the refusal says so"
rm "$R/setup/answers.env"
rrefused "run with no setup/answers.env" "setup/answers.env is missing; run bin/ask setup" run widget 'TITLE=A' 'DESCRIPTION=B'
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
printf 'BROKEN\tsetup\tno-such-type\tno\t-\t-\t-\tQ?\n' >>"$R/shared/answers.tsv"
ask confirm widget --by 'A Person'
assert_status 1 "$ST" "refused: confirm under a schema that does not parse"
assert_contains "$OUT" "shared/answers.tsv does not parse:" "  and the refusal says so"
assert_eq "gone" "$(gone "$OUTD/confirmed.md")" "  and no confirmed.md is written"
# A target that is a dangling symbolic link is present.
ready
mkdir -p "$ROOT"
ln -s "$SCRATCH/nowhere$n" "$ROOT/widget"
rrefused "a target that is a dangling symbolic link" "the target $ROOT/widget is present" \
  run widget 'TITLE=A' 'DESCRIPTION=B'
# After --setup-override, --redo and --remove return the next arguments to
# the run.
rendered
ask run widget --redo --setup-override 'HOLDER=Someone' --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D'
assert_status 0 "$ST" "run fields after --setup-override then --remove"
assert_eq "TITLE=C" "$(grep '^TITLE=' "$ANS")" "  are the run's"
ask run widget --setup-override 'HOLDER=Other' --redo 'TITLE=E' 'DESCRIPTION=F'
assert_status 0 "$ST" "run fields after --setup-override then --redo"
assert_eq "TITLE=E" "$(grep '^TITLE=' "$ANS")" "  are the run's"
# --remove names the old target; a new target, under a moved TARGET_ROOT,
# that is present is refused, not taken as named.
rendered
mkdir -p "$SCRATCH/moved$n/widget"
rrefused "a redo whose new target is present, --remove naming the old one" \
  "the target $SCRATCH/moved$n/widget is present, and this run may not remove it" \
  run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D' --setup-override "TARGET_ROOT=$SCRATCH/moved$n"
assert_contains "$OUT" "move it away by hand" "  naming the way out, never a --remove the discard would refuse"
assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  with the old target left alone"
# --remove naming another path, the target present: the discard refuses it
# first, naming the path.
rendered
mkdir -p "$ROOT/other"
rrefused "--remove naming another path, the target present" "remove $ROOT/other: it is not the run's target $ROOT/widget" \
  run widget --redo --remove "$ROOT/other" 'TITLE=C' 'DESCRIPTION=D'
# A --remove refusal names the way out (answers' NIT 1 of S2's fourth ship
# gate).
assert_contains "$OUT" "without --remove, bin/ask run widget --redo names the way" "  naming the way out"
# r06: with the old and new targets both present, the new one is named
# first, so the old one's --remove route is never followed only to be
# refused for the new one.
rendered
mkdir -p "$SCRATCH/moved$n/widget"
rrefused "a redo whose old and new targets are both present" "the target $SCRATCH/moved$n/widget is present" \
  run widget --redo 'TITLE=C' --setup-override "TARGET_ROOT=$SCRATCH/moved$n"
assert_not_contains "$OUT" "--remove" "  and the old target's route waits for the new one"

# --- TARGET_ROOT outside every working tree of the workspace (decision 227) ---------------
# The root rule is the one target rule's: setup, run, confirm and the
# discard each refuse a TARGET_ROOT at or under the workspace, so no route
# removes the run's own folder (removal M3's q04 of S2's third ship gate).
INSIDE="a working tree of this workspace"
ready
refused "setup naming a TARGET_ROOT inside the workspace" "$INSIDE" setup "TARGET_ROOT=$R/stages/01-ask/output"
ready
rrefused "a run overriding TARGET_ROOT to inside the workspace" "$INSIDE" \
  run widget 'TITLE=A' 'DESCRIPTION=B' --setup-override "TARGET_ROOT=$R/stages/01-ask/output"
ready
# Both setup files, so setup/answers.env is what setup/given.env gives.
for f in answers given; do
  sed "s|^TARGET_ROOT=.*|TARGET_ROOT=$R/stages/01-ask/output|" "$R/setup/$f.env" >"$SCRATCH/setup$n"
  mv "$SCRATCH/setup$n" "$R/setup/$f.env"
done
rrefused "a run under a setup/answers.env edited by hand to a TARGET_ROOT inside the workspace" "$INSIDE" \
  run widget 'TITLE=A' 'DESCRIPTION=B'
assert_contains "$OUT" "give TARGET_ROOT again, with --setup-override or with bin/ask setup" "  naming both ways to change it"
# R3: a kept override's TARGET_ROOT, now a working tree of the workspace, is
# routed to the one leg that changes it, --setup-override, as bin/ask setup
# does not (answers' R3 of S2's fourth ship gate); followed, the redo goes on.
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B' --setup-override "TARGET_ROOT=$SCRATCH/kept$n"
git -C "$R" worktree add -q --detach "$SCRATCH/kept$n" >/dev/null 2>&1
rrefused "a redo whose kept override's TARGET_ROOT is now a working tree" \
  "give TARGET_ROOT again after --setup-override" run widget --redo 'TITLE=C'
assert_not_contains "$OUT" "bin/ask setup" "  and not bin/ask setup, which cannot change it"
ask run widget --redo 'TITLE=C' --setup-override "TARGET_ROOT=$SCRATCH/moved$n"
assert_status 0 "$ST" "  and, TARGET_ROOT given again after --setup-override, the redo goes on"
git -C "$R" worktree remove --force "$SCRATCH/kept$n"
# q04: the run's answers edited by hand to a TARGET_ROOT holding the run's
# own folder, then confirm, and the --remove route to that folder.
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
sed -e "s|^TARGET_ROOT=.*|TARGET_ROOT=$R/stages/01-ask/output|" -e "s|^TARGET=.*|TARGET=$OUTD|" "$ANS" >"$SCRATCH/ans$n"
mv "$SCRATCH/ans$n" "$ANS"
rrefused "confirm of answers whose TARGET_ROOT is inside the workspace" "$INSIDE" confirm widget --by 'A Person'
rrefused "a redo --remove naming the run's own folder" "$INSIDE" \
  run widget --redo --remove "$OUTD" 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ANS")" "  and the run's folder is left"

# --- every route can be followed (S2's third ship gate, call P6) ---------------------------
# Each refusal that routes to --redo names a step --redo can take, or the
# refusal names the way out itself. The redo works the new TARGET_ROOT out
# before it judges the old one, and an old TARGET_ROOT that gives no target
# is no target to remove, its target judged from render.md's record.
# M4: the route confirm names, from answers whose TARGET_ROOT gives no
# target, is a redo that takes the new one.
ask run widget --redo 'TITLE=C' 'DESCRIPTION=D'
assert_status 0 "$ST" "a redo of answers whose old TARGET_ROOT gives no target"
assert_eq "TARGET=$ROOT/widget" "$(grep '^TARGET=' "$ANS")" "  writes the TARGET the new TARGET_ROOT gives"
assert_eq "present" "$(gone "$OUTD/given.env")" "  and the run's folder is kept"
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
sed -e "s|^TARGET_ROOT=.*|TARGET_ROOT=$ROOT/|" -e "s|^TARGET=.*|TARGET=$ROOT//widget|" "$ANS" >"$SCRATCH/ans$n"
mv "$SCRATCH/ans$n" "$ANS"
ask confirm widget --by 'A Person'
assert_contains "$OUT" "bin/ask run widget --redo" "confirm routes a TARGET_ROOT that gives no target to --redo"
mkdir -p "$SCRATCH/moved$n"
ask run widget --redo 'TITLE=C' --setup-override "TARGET_ROOT=$SCRATCH/moved$n"
assert_status 0 "$ST" "  and the redo giving TARGET_ROOT again takes it"
assert_eq "TARGET=$SCRATCH/moved$n/widget" "$(grep '^TARGET=' "$ANS")" "  writing its TARGET"
# A recorded target, present, that the old answers give no target for is
# judged from render.md's record and left, naming the way out; moved away
# by hand, the redo goes on.
rendered
sed "s|^TARGET_ROOT=.*|TARGET_ROOT=$ROOT/|" "$ANS" >"$SCRATCH/ans$n"
mv "$SCRATCH/ans$n" "$ANS"
rrefused "a redo whose render.md names a present target the old answers give none for" \
  "render.md names $ROOT/widget, present" run widget --redo 'TITLE=C' 'DESCRIPTION=D'
assert_contains "$OUT" "move that target away by hand" "  naming the way out"
assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  and the target is left"
mv "$ROOT/widget" "$SCRATCH/away$n"
ask run widget --redo 'TITLE=C' 'DESCRIPTION=D'
assert_status 0 "$ST" "  and, once it is moved away by hand, the redo goes on"
# R1: a run rendered under one HOME, redone under another: the target
# render.md names is left, naming the way out, then the redo goes on.
fresh
mkdir -p "$SCRATCH/home$n/a/targets" "$SCRATCH/home$n/b"
ask setup 'TARGET_ROOT=~/targets'
OUTD="$R/stages/01-ask/output/widget"
ANS="$OUTD/answers.env"
(cd "$R" && HOME="$SCRATCH/home$n/a" bin/ask run widget 'TITLE=A' 'DESCRIPTION=B' >/dev/null 2>&1 &&
  HOME="$SCRATCH/home$n/a" bin/ask confirm widget --by 'A Person' >/dev/null 2>&1)
mkdir -p "$R/stages/02-render/output/widget" "$SCRATCH/home$n/a/targets/widget"
printf '%s\n' '# Render of widget' '' "target: $SCRATCH/home$n/a/targets/widget" >"$R/stages/02-render/output/widget/render.md"
OUT=$(cd "$R" && HOME="$SCRATCH/home$n/b" bin/ask run widget --redo 'TITLE=C' 2>&1)
assert_status 1 "$?" "refused: a redo under another HOME of a run rendered under the first"
assert_contains "$OUT" "move that target away by hand" "  naming the way out"
assert_eq "present present" "$(gone "$SCRATCH/home$n/a/targets/widget") $(gone "$R/stages/02-render/output/widget/render.md")" \
  "  and the target and render.md are left"
mv "$SCRATCH/home$n/a/targets/widget" "$SCRATCH/away$n"
OUT=$(cd "$R" && HOME="$SCRATCH/home$n/b" bin/ask run widget --redo 'TITLE=C' 2>&1)
assert_status 0 "$?" "  and, once it is moved away by hand, the redo goes on"
assert_eq "TARGET=$SCRATCH/home$n/b/targets/widget" "$(grep '^TARGET=' "$ANS")" "  under this HOME"
# r08: the old target is the old answers' verified target, never the old
# TARGET_ROOT expanded under this HOME (removal N5 of S2's fourth ship
# gate): under another HOME a redo neither refuses on, nor sweeps under,
# a root the run never used.
fresh
mkdir -p "$SCRATCH/home$n/a" "$SCRATCH/home$n/b/targets/widget" "$SCRATCH/home$n/b/targets/.widget.render.222"
printf 'unrelated\n' >"$SCRATCH/home$n/b/targets/widget/f"
ask setup 'TARGET_ROOT=~/targets'
OUTD="$R/stages/01-ask/output/widget"
ANS="$OUTD/answers.env"
(cd "$R" && HOME="$SCRATCH/home$n/a" bin/ask run widget 'TITLE=A' 'DESCRIPTION=B' >/dev/null 2>&1)
OUT=$(cd "$R" && HOME="$SCRATCH/home$n/b" bin/ask run widget --redo 'TITLE=C' --setup-override "TARGET_ROOT=$SCRATCH/elsewhere$n" 2>&1)
assert_status 0 "$?" "a redo under another HOME, its old target unverified, judges none there${OUT:+ ($OUT)}"
assert_eq "present present" "$(gone "$SCRATCH/home$n/b/targets/widget/f") $(gone "$SCRATCH/home$n/b/targets/.widget.render.222")" \
  "  and leaves that root's directories alone"
if [ "$(id -u)" != 0 ]; then
  # r03: the old TARGET_ROOT cannot be searched, so whether render.md's
  # target is there cannot be told: the redo is refused, never judging it
  # gone and dropping its record.
  rendered
  chmod 000 "$ROOT"
  rrefused "a redo whose old root cannot be entered, so its target cannot be judged" "$ROOT cannot be entered, so it cannot be judged" \
    run widget --redo 'TITLE=C' --setup-override "TARGET_ROOT=$SCRATCH/moved$n"
  chmod 755 "$ROOT"
  # r03b: the run's 02 output folder cannot be searched, so whether
  # render.md is there cannot be told.
  rendered
  chmod 000 "$R/stages/02-render/output/widget"
  rrefused "a redo whose render.md cannot be told there" "cannot tell whether stages/02-render/output/widget/render.md is there" \
    run widget --redo 'TITLE=C' --setup-override "TARGET_ROOT=$SCRATCH/moved$n"
  # Its way out is the search it lacks, not a removal by hand of a file it
  # cannot see (call Q6 of S2's fourth ship gate).
  assert_contains "$OUT" "give its owner search permission" "  naming the way out"
  assert_not_contains "$OUT" "by hand" "  and no step by hand"
  chmod 755 "$R/stages/02-render/output/widget"
  # The sweep under the old TARGET_ROOT: a root it cannot list is refused.
  rendered
  rm -rf "$ROOT/widget"
  mkdir -p "$ROOT/.widget.render.4242"
  rm -f "$R/stages/02-render/output/widget/render.md"
  chmod 300 "$ROOT"
  rrefused "a redo whose old TARGET_ROOT cannot be listed for leftovers" "cannot list $ROOT" \
    run widget --redo 'TITLE=C' --setup-override "TARGET_ROOT=$SCRATCH/moved$n"
  chmod 755 "$ROOT"
  assert_eq "present" "$(gone "$ROOT/.widget.render.4242")" "  and the leftover is left"
fi
# NIT4: a record file the reader refuses names the way out, which works.
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
printf 'TITLE=A\000\n' >"$OUTD/given.env"
rrefused "a redo beside a given.env holding a NUL" "remove it by hand" run widget --redo 'DESCRIPTION=D'
rm "$OUTD/given.env"
ask run widget --redo 'TITLE=A' 'DESCRIPTION=D'
assert_status 0 "$ST" "  and, once it is removed, the redo giving its fields goes on"
printf 'TITLE=A\000\n' >>"$ANS"
rrefused "a redo of an answers file holding a NUL" "remove the run's folder" run widget --redo 'DESCRIPTION=D'
# confirm refuses the file, for its NUL, with the same way out, never
# reporting a TARGET it cannot read (answers' NIT 2 of S2's fourth ship
# gate).
rrefused "confirm of an answers file holding a NUL" "stages/01-ask/output/widget/answers.env: the file holds a NUL byte" \
  confirm widget --by 'A Person'
assert_contains "$OUT" "remove the run's folder" "  naming the way out"
assert_not_contains "$OUT" "cannot read TARGET" "  and no read it did not fail"
rm -rf "$OUTD"
ask run widget 'TITLE=A' 'DESCRIPTION=D'
assert_status 0 "$ST" "  and, once it is removed, the run goes on"
printf 'OWNER=ac\000me\n' >"$R/setup/given.env"
refused "setup beside a setup/given.env holding a NUL" "remove it by hand" setup
rm "$R/setup/given.env"
ask setup
assert_status 0 "$ST" "  and, once it is removed, setup goes on"

# --- each file bin/ask writes is absent or a regular file (decision 230) ------------------
# A directory, a link to a directory or a dangling link where bin/ask would
# write a file is refused before anything is staged or removed, and left as
# it was, with nothing written into it or through it.
in_way() { # KIND PATH: a directory, a link to one or to a file, or a dangling link at PATH
  rm -rf "$2"
  mkdir -p "${2%/*}" "$SCRATCH/away$n"
  printf 'kept\n' >"$SCRATCH/file$n"
  case "$1" in
    dir) mkdir "$2" ;;
    dirlink) ln -s "$SCRATCH/away$n" "$2" ;;
    filelink) ln -s "$SCRATCH/file$n" "$2" ;;
    dangling) ln -s "$SCRATCH/nowhere$n" "$2" ;;
  esac
}
kind_of() { # PATH: dir, dirlink, filelink, dangling, file or gone
  if [ -L "$1" ]; then
    if [ -d "$1" ]; then echo dirlink; elif [ -f "$1" ]; then echo filelink; else echo dangling; fi
  elif [ -d "$1" ]; then echo dir
  elif [ -e "$1" ]; then echo file
  else echo gone
  fi
}
in_way_refused() { # KIND PATH LABEL ARG...: bin/ask ARG... refused, PATH left
  local kind=$1 path=$2 label=$3
  shift 3
  ask "$@"
  assert_status 1 "$ST" "refused: a $kind at $label"
  assert_contains "$OUT" "$label is not a file" "  and the refusal says so"
  assert_eq "$kind" "$(kind_of "$path")" "  and the $kind is left"
  assert_eq "" "$(ls -A "$SCRATCH/away$n")" "  with nothing written through it"
  assert_eq "kept" "$(cat "$SCRATCH/file$n")" "  nor through a link to a file"
  assert_eq "" "$(find "$R/setup" "$R/stages/01-ask/output" -name '*.tmp.*' 2>/dev/null)" "  and no temporary file left"
}
for kind in dir dirlink filelink dangling; do
  fresh
  in_way "$kind" "$R/setup/answers.env"
  in_way_refused "$kind" "$R/setup/answers.env" setup/answers.env setup OWNER=acme
  fresh
  ask setup OWNER=acme
  in_way "$kind" "$R/setup/given.env"
  in_way_refused "$kind" "$R/setup/given.env" setup/given.env setup OWNER=other
  # Given nothing, setup would remove setup/given.env: it is refused first.
  in_way_refused "$kind" "$R/setup/given.env" setup/given.env setup
  fresh
  in_way "$kind" "$R/setup/questionnaire.md"
  in_way_refused "$kind" "$R/setup/questionnaire.md" setup/questionnaire.md questionnaire
  ready
  in_way "$kind" "$OUTD/answers.env"
  in_way_refused "$kind" "$OUTD/answers.env" stages/01-ask/output/widget/answers.env run widget 'TITLE=A' 'DESCRIPTION=B'
  ready
  in_way "$kind" "$OUTD/given.env"
  in_way_refused "$kind" "$OUTD/given.env" stages/01-ask/output/widget/given.env run widget 'TITLE=A' 'DESCRIPTION=B'
  ready
  in_way "$kind" "$OUTD/setup.override.env"
  in_way_refused "$kind" "$OUTD/setup.override.env" stages/01-ask/output/widget/setup.override.env \
    run widget 'TITLE=A' 'DESCRIPTION=B' --setup-override 'HOLDER=Someone'
  ready
  ask run widget 'TITLE=A' 'DESCRIPTION=B'
  in_way "$kind" "$OUTD/confirmed.md"
  in_way_refused "$kind" "$OUTD/confirmed.md" stages/01-ask/output/widget/confirmed.md confirm widget --by 'A Person'
  # Every file a run removes, or reads as a record, is judged first: the
  # confirmation and render.md a redo removes, and setup's files a run reads
  # (answers' R1 and R8, conformance's N-E, removal's N4 of S2's fourth ship
  # gate).
  rendered
  in_way "$kind" "$OUTD/confirmed.md"
  in_way_refused "$kind" "$OUTD/confirmed.md" stages/01-ask/output/widget/confirmed.md \
    run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D'
  assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  and the target is left"
  rendered
  in_way "$kind" "$R/stages/02-render/output/widget/render.md"
  in_way_refused "$kind" "$R/stages/02-render/output/widget/render.md" stages/02-render/output/widget/render.md \
    run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D'
  assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  and the target is left"
  ready
  ask setup OWNER=acme "TARGET_ROOT=$ROOT"
  in_way "$kind" "$R/setup/given.env"
  in_way_refused "$kind" "$R/setup/given.env" setup/given.env run widget 'TITLE=A' 'DESCRIPTION=B'
  assert_eq "gone" "$(gone "$ANS")" "  and no answers are written"
  ready
  in_way "$kind" "$R/setup/answers.env"
  in_way_refused "$kind" "$R/setup/answers.env" setup/answers.env run widget 'TITLE=A' 'DESCRIPTION=B'
  ready
  ask run widget 'TITLE=A' 'DESCRIPTION=B'
  in_way "$kind" "$ANS"
  in_way_refused "$kind" "$ANS" stages/01-ask/output/widget/answers.env confirm widget --by 'A Person'
done
# A redo is refused alike, with the run's files and target as they were.
rendered
in_way dir "$OUTD/given.env"
before=$(run_state)
ask run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D'
assert_status 1 "$ST" "refused: a redo with a directory at the run's given.env"
assert_eq "$before" "$(run_state)" "  and the run's files are as they were"
assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  and the target is left"
# --- each step whose status a guard reads, failing (decision 228) ------------------
# Every `|| refuse` on a step's status has a case that fails without it (the
# tests lens's N2 of S2's third ship gate): a rename, a removal and a read
# that fail, a scope that cannot be read, and an old answers file edited by
# hand.
export FAIL_STATUS=1
fresh
ask setup OWNER=acme
before=$(state)
asked mv '*setup/answers.env.tmp.*' 1 setup OWNER=other
assert_status 1 "$ST" "refused: setup whose rename into place fails"
assert_contains "$OUT" "cannot write $R/setup/answers.env" "  and the refusal says so"
assert_eq "$before" "$(state)" "  and setup/answers.env is as it was"
fresh
ask setup OWNER=acme
FAIL_STATUS=2 asked awk '*col\[$i] = i*' 1 setup
assert_status 1 "$ST" "refused: setup whose kept field's scope cannot be read"
assert_contains "$OUT" "cannot read the scope of OWNER in shared/answers.tsv" "  and the refusal says so, never a field dropped"
assert_eq "OWNER=acme" "$(cat "$R/setup/given.env" 2>/dev/null)" "  and setup/given.env is as it was"
fresh
ask setup
: >"$R/setup/given.env"
asked rm '*/setup/given.env' 1 setup
assert_status 1 "$ST" "refused: setup whose removal of an empty setup/given.env fails"
assert_contains "$OUT" "could not remove $R/setup/given.env" "  and the refusal names it"
ready
asked cat '*/setup/answers.env' 2 run widget 'TITLE=A' 'DESCRIPTION=B'
assert_status 1 "$ST" "refused: run whose read of setup/answers.env fails"
assert_contains "$OUT" "setup/answers.env: cannot read the file" "  and the refusal says so"
assert_eq "absent" "$(run_state)" "  and no answers file is written"
# A denied read relies on a user the permission binds, so it skips under
# root, as its siblings do (the tests lens's T4 of S2's fourth ship gate).
if [ "$(id -u)" != 0 ]; then
  ready
  ask run widget 'TITLE=A' 'DESCRIPTION=B'
  before=$(run_state)
  chmod 000 "$ANS"
  ask run widget --redo 'TITLE=C'
  st=$ST
  chmod 644 "$ANS"
  assert_status 1 "$st" "refused: a redo whose old answers file cannot be read"
  assert_contains "$OUT" "stages/01-ask/output/widget/answers.env: cannot read the file" "  and the refusal says so"
  assert_eq "$before" "$(run_state)" "  and the run's files are as they were"
fi
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
sed '/^TARGET_ROOT=/d' "$ANS" >"$ANS.x" && mv "$ANS.x" "$ANS"
# Its old target is none verified, so the route confirm and render name,
# the redo, goes on (answers' R2 of S2's fourth ship gate).
ask run widget --redo 'TITLE=C'
assert_status 0 "$ST" "a redo whose old answers file, edited by hand, holds no TARGET_ROOT, goes on${OUT:+ ($OUT)}"
assert_eq "TARGET_ROOT=$ROOT" "$(grep '^TARGET_ROOT=' "$ANS")" "  writing setup's TARGET_ROOT"
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
before=$(run_state)
asked git '*worktree list*' 1 run widget --redo 'TITLE=C'
assert_status 1 "$ST" "refused: a redo whose old target's root cannot be judged"
assert_contains "$OUT" "stages/01-ask/output/widget/answers.env: cannot list the workspace's worktrees" \
  "  and the refusal says so, never a root with no target"
assert_eq "$before" "$(run_state)" "  and the run's files are as they were"
# A redo that gives no run field, nor any override, removes the run's
# given.env and setup.override.env; one it cannot remove is refused, naming
# it. Here each run field has a default, so a run need give none.
ready
sed -e "s/${T}-${T}What is its title?/${T}A title${T}What is its title?/" \
  -e "s/${T}-${T}One line about the repository?/${T}One line${T}One line about the repository?/" \
  "$R/shared/answers.tsv" >"$R/shared/answers.tsv.x" && mv "$R/shared/answers.tsv.x" "$R/shared/answers.tsv"
ask run widget 'TITLE=A' --setup-override 'HOLDER=Someone'
assert_status 0 "$ST" "a run giving a field and an override, beside a schema whose run fields have defaults"
: >"$OUTD/given.env"
asked rm '*/widget/given.env' 1 run widget --redo --setup-override 'HOLDER=Someone'
assert_status 1 "$ST" "refused: a redo whose removal of the run's empty given.env fails"
assert_contains "$OUT" "could not remove $OUTD/given.env" "  and the refusal names it"
ask run widget --redo 'TITLE=A' --setup-override 'HOLDER=Someone'
: >"$OUTD/setup.override.env"
# A new stub, so its count of matching calls starts again.
rm -f "$SCRATCH/fail$n/rm.count"
asked rm '*/widget/setup.override.env' 1 run widget --redo 'TITLE=A'
assert_status 1 "$ST" "refused: a redo whose removal of the run's empty setup.override.env fails"
assert_contains "$OUT" "could not remove $OUTD/setup.override.env" "  and the refusal names it"
assert_done
