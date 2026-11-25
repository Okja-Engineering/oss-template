#!/usr/bin/env bash
# bin/ask (AC7, AC9): `setup` rewrites setup/answers.env and `questionnaire`
# writes setup/questionnaire.md, both from the schema; `run` writes a run's
# answers file, `confirm` its confirmed.md, and `--redo --remove` first
# discards the target through the shared discard. On a fixture workspace
# with its own schema; each refusal writes nothing and removes nothing.
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
  } >"$R/shared/answers.tsv"
  fixture_commit "$R" "test: a fixture schema"
}
ask() { OUT=$(cd "$R" && bin/ask "$@" 2>&1); ST=$?; }
setup_file() { cat "$R/setup/answers.env" 2>/dev/null; }
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
run_state() { cksum 2>/dev/null <"$ANS" || echo absent; }
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
  assert_eq "$before" "$(run_state)" "  and the answers file is as it was"
  assert_eq "$setup_before" "$(state)" "  and setup/answers.env is as it was"
}

ready
ask run widget 'TITLE=A title' 'DESCRIPTION=One line'
assert_status 0 "$ST" "run writes the answers file"
assert_eq "DESCRIPTION=One line
HOLDER=Okja-Engineering
NAME=widget
OWNER=Okja-Engineering
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

ready
before=$(state)
ask run widget 'TITLE=A title' 'DESCRIPTION=One line' --setup-override OWNER=acme 'HOLDER=Acme & Co'
assert_status 0 "$ST" "run with --setup-override"
assert_eq "OWNER=acme" "$(grep '^OWNER=' "$ANS")" "  overrides a setup field for this run"
assert_eq "HOLDER=Acme & Co" "$(grep '^HOLDER=' "$ANS")" "  each field it names"
assert_eq "HOLDER=Acme & Co
OWNER=acme" "$(cat "$OUTD/setup.override.env" 2>/dev/null)" "  recorded in the run's setup.override.env"
assert_eq "$before" "$(state)" "  and leaves setup/answers.env untouched"

ready
VALUE='Bé & back\slash = equals $HOME'
ask run widget 'TITLE=A title' "DESCRIPTION=$VALUE"
assert_status 0 "$ST" "run with non-ASCII, &, \\, = and \$ in a value"
assert_eq "DESCRIPTION=$VALUE" "$(grep '^DESCRIPTION=' "$ANS")" "  kept as written"
ready
ask run widget 'TITLE=$(touch made-by-run)' 'DESCRIPTION=`touch made-by-run2`'
assert_eq "" "$(find "$SCRATCH" -name 'made-by-run*')" "\$(touch x) and backticks in run values create nothing"

ready
rrefused "an unknown field" "BOGUS" run widget 'TITLE=A' 'DESCRIPTION=B' BOGUS=1
rrefused "a value its type refuses" "VISIBILITY" run widget 'TITLE=A' 'DESCRIPTION=B' VISIBILITY=secret
rrefused "a value holding a newline" "newline" run widget 'TITLE=A
B' 'DESCRIPTION=B'
rrefused "a value holding {{" "{{" run widget 'TITLE=A {{NAME}}' 'DESCRIPTION=B'
rrefused "a rule word in a text field" "never" run widget 'TITLE=It never stops' 'DESCRIPTION=B'
rrefused "an email address in a text field" "email" run widget 'TITLE=Mail a.person@example.org' 'DESCRIPTION=B'
rrefused "a missing field" "TITLE" run widget 'DESCRIPTION=B'
rrefused "a setup field given outside --setup-override" "OWNER" run widget 'TITLE=A' 'DESCRIPTION=B' OWNER=acme
rrefused "a run field given to --setup-override" "TITLE" run widget 'DESCRIPTION=B' --setup-override 'TITLE=A'
rrefused "an override its type refuses" "OWNER" run widget 'TITLE=A' 'DESCRIPTION=B' --setup-override OWNER=-acme
rrefused "a NAME over GitHub's limit" "100" run "$(rep 101 a)" 'TITLE=A' 'DESCRIPTION=B'
rrefused "a NAME its type refuses" "NAME" run Widget 'TITLE=A' 'DESCRIPTION=B'
rrefused "a DESCRIPTION over GitHub's limit" "350" run widget 'TITLE=A' "DESCRIPTION=$(rep 351 'é')"
rrefused "NAME given as a field" "NAME" run widget 'NAME=gadget' 'TITLE=A' 'DESCRIPTION=B'
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
gone() { if [ -e "$1" ] || [ -L "$1" ]; then echo present; else echo gone; fi; }

ready
rrefused "--redo on a run that does not exist" "widget" run widget --redo 'TITLE=A' 'DESCRIPTION=B'
ready
ask run widget 'TITLE=A' 'DESCRIPTION=B'
ask confirm widget --by 'A Person'
ask run widget --redo 'TITLE=C' 'DESCRIPTION=D'
assert_status 0 "$ST" "--redo of a run never rendered needs no --remove"
assert_eq "TITLE=C" "$(grep '^TITLE=' "$ANS")" "  and rewrites the answers"
assert_eq "gone" "$(gone "$OUTD/confirmed.md")" "  and clears the confirmation"

rendered
rrefused "--redo of a rendered run without --remove" "--remove" run widget --redo 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  with nothing removed"
rendered
mkdir -p "$ROOT/other"
rrefused "--remove naming another path" "$ROOT/other" run widget --redo --remove "$ROOT/other" 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  with the target not removed"
assert_eq "present" "$(gone "$ROOT/other")" "  nor the other path"
rendered
rrefused "--remove naming the target in other bytes" "not the target render.md names" \
  run widget --redo --remove "$ROOT/./widget" 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  with nothing removed"
rendered
mkdir -p "$ROOT/other"
printf '%s\n' '# Render of widget' '' "target: $ROOT/other" >"$R/stages/02-render/output/widget/render.md"
rrefused "a recorded target whose last component is not NAME" "last component" \
  run widget --redo --remove "$ROOT/other" 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ROOT/other")" "  with nothing removed"
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
rendered "$SCRATCH/outside/widget"
mkdir -p "$SCRATCH/outside/widget"
rrefused "a path outside TARGET_ROOT" "TARGET_ROOT" run widget --redo --remove "$SCRATCH/outside/widget" 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$SCRATCH/outside/widget")" "  with nothing removed"
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
assert_eq "$before" "$(run_state)" "  and the answers file is as it was"

assert_done
