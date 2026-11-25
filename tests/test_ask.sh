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
refused "a TARGET_ROOT holding a . component" "component" setup 'TARGET_ROOT=/srv/./targets'
refused "a TARGET_ROOT ending in /" "component" setup 'TARGET_ROOT=/srv/targets/'
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
gone() { if [ -e "$1" ] || [ -L "$1" ]; then echo present; else echo gone; fi; }
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
rrefused "a run field given to --setup-override" "TITLE is a run field, not a setup field" \
  run widget 'TITLE=A' 'DESCRIPTION=B' --setup-override 'TITLE=C'
rrefused "a select value of two listed values joined" "VISIBILITY" \
  run widget 'TITLE=A' 'DESCRIPTION=B' 'VISIBILITY=public|private'
rrefused "a value holding a C1 control" "C1 control" run widget "$(printf 'TITLE=A\302\205')" 'DESCRIPTION=B'
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
rm -f "$OUTD/confirmed.md"
ask confirm widget X 'A Person'
assert_status 2 "$ST" "confirm NAME X WHO, without --by, is a usage error"
assert_eq "gone" "$(gone "$OUTD/confirmed.md")" "  and writes nothing"
ask confirm widget --by ''
assert_status 1 "$ST" "confirm refuses an empty --by"
assert_eq "gone" "$(gone "$OUTD/confirmed.md")" "  and writes nothing"
mkdir -p "$R/stages/01-ask/output"
ask confirm ../../../setup --by 'A Person'
assert_status 1 "$ST" "confirm refuses a NAME its type refuses, as ../../../setup"
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
rrefused "--redo on a run that does not exist" "widget" run widget --redo 'TITLE=A' 'DESCRIPTION=B'
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
assert_eq "HOLDER=Okja-Engineering" "$(grep '^HOLDER=' "$ANS")" "  and a setup field not overridden comes from setup"
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
rrefused "a kept override that is not a setup field" "TITLE, which is not a setup field" run widget --redo 'TITLE=C'
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
rrefused "--remove naming the target in other bytes" "not the target render.md names" \
  run widget --redo --remove "$ROOT/./widget" 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ROOT/widget/sub/file")" "  with nothing removed"
rendered
mkdir -p "$ROOT/other"
printf '%s\n' '# Render of widget' '' "target: $ROOT/other" >"$R/stages/02-render/output/widget/render.md"
rrefused "a recorded target that is not the run's TARGET" "but the run's TARGET is $ROOT/widget" \
  run widget --redo --remove "$ROOT/other" 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$ROOT/other")" "  with nothing removed"
# The answers file's TARGET edited by hand to match: the last component.
sed "s|^TARGET=.*|TARGET=$ROOT/other|" "$ANS" >"$ANS.x" && mv "$ANS.x" "$ANS"
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
rrefused "a path outside TARGET_ROOT, which render.md names but the run's TARGET is not" \
  "but the run's TARGET is $ROOT/widget" run widget --redo --remove "$SCRATCH/outside/widget" 'TITLE=C' 'DESCRIPTION=D'
assert_eq "present" "$(gone "$SCRATCH/outside/widget")" "  with nothing removed"
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
assert_contains "$OUT" "remove widget: it is not an absolute path" "  and the refusal says so"
assert_eq "present" "$(gone "$ROOT/kept")" "  and TARGET_ROOT is left alone"
assert_eq "$before" "$(run_state)" "  and the run's files are as they were"
printf '%s\n' '# Render of widget' '' 'target: widget' >"$R/stages/02-render/output/widget/render.md"
OUT=$(cd "$SCRATCH/p$n" && "$R/bin/ask" run widget --redo --remove "$ROOT/widget" 'TITLE=C' 'DESCRIPTION=D' 2>&1)
assert_status 1 "$?" "refused: a recorded target that is a relative path"
assert_contains "$OUT" "the recorded target widget is not an absolute path" "  and the refusal says so"
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
  assert_contains "$OUT" "setup/answers.env" "  and the refusal names it"
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
assert_done
