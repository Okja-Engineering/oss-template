#!/usr/bin/env bash
# bin/render over bin/lib/render.sh (AC9-AC12): on a fixture workspace with
# its own schema and foundation, a confirmed run is rendered into its
# target, walked and fingerprinted under hermetic git, and recorded in
# render.md. Every AC9 refusal; --replace; TARGET_ROOT kept out of every
# working tree of the workspace; the walk; AC10's planted cases but
# reftable, against render's fingerprint; AC11's variations; AC12 per field.
# shellcheck disable=SC2016,SC2088 # templates hold literal {{FIELD}} and ${{ }}, a default ~
set -u
set -o pipefail
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$TEST_DIR/../foundation/tests/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=fixtures/workspace.sh
. "$TEST_DIR/fixtures/workspace.sh"

SCRATCH=$(mktemp -d)
SCRATCH=$(CDPATH='' cd -P -- "$SCRATCH" && pwd -P)
trap 'chmod -R u+rwx "$SCRATCH" 2>/dev/null; rm -rf "$SCRATCH"' EXIT
n=0
T='	'

row() { # the cells, joined by tabs
  local IFS="$T"
  printf '%s\n' "$*"
}
put() { # FILE LINE...: under the workspace R
  mkdir -p "$(dirname "$R/$1")" && {
    local f=$1
    shift
    printf '%s\n' "$@" >"$R/$f"
  }
}

# fresh: a fixture workspace holding bin/ask, bin/render, a schema with a
# field of each kind render uses, and a foundation of templates, variants
# and verbatim files; its setup sends targets to ROOT.
fresh() {
  n=$((n + 1))
  R="$SCRATCH/ws$n"
  ROOT="$SCRATCH/targets$n"
  ws_fixture "$R"
  cp -p "$WS_ROOT/bin/ask" "$WS_ROOT/bin/render" "$R/bin/"
  {
    row field scope type render selects pattern default question
    row NAME run name yes - - - 'What is the repository called?'
    row OWNER setup owner no - - Okja-Engineering 'Which GitHub account owns it?'
    row TARGET_ROOT setup path no - - '~/Development/{{OWNER}}' 'Which directory holds the targets?'
    row HOLDER setup text yes - - '{{OWNER}}' 'Who holds the copyright?'
    row PEOPLE setup list yes - - 'A Person, B Person' 'Who decides?'
    row DESCRIPTION run description yes - - - 'One line about it?'
    row VISIBILITY run select no - 'public|private' public 'Public or private?'
    row LICENSE run select yes LICENSE 'apache-2.0|none' apache-2.0 'Which licence?'
  } >"$R/shared.tsv"
  mkdir -p "$R/shared" && mv "$R/shared.tsv" "$R/shared/answers.tsv"
  put foundation/README.md.tmpl '# {{NAME}}' '' '{{DESCRIPTION}}'
  put foundation/GOVERNANCE.md.tmpl '# Governance' '' '## Deciders' '' '- {{PEOPLE}}' '' 'Listed: {{PEOPLE}}.'
  put foundation/LICENSE.apache-2.0 'The Apache licence text.'
  printf 'Copyright {{HOLDER}}. All rights reserved.' >"$R/foundation/LICENSE.none.tmpl"
  put foundation/tool 'echo ${{ github.sha }} {{NAME}}'
  chmod +x "$R/foundation/tool"
  printf 'one\r\ntwo\r\n' >"$R/foundation/crlf.txt"
  put foundation/.claude/settings.json '{}'
  ln -s README.md "$R/foundation/readme-link"
  (cd "$R" && bin/ask setup "TARGET_ROOT=$ROOT" >/dev/null && bin/ask questionnaire >/dev/null)
  fixture_commit "$R" "test: a fixture workspace to render"
}
ask() { (cd "$R" && bin/ask "$@" >/dev/null 2>&1); }
render() { OUT=$(cd "$R" && bin/render "$@" 2>&1); ST=$?; }
# confirmed NAME FIELD=value...: a run of NAME, confirmed.
confirmed() {
  local name=$1
  shift
  ask run "$name" 'DESCRIPTION=Bé & back\slash = equals' "$@" && ask confirm "$name" --by 'A Person'
}
record() { # NAME KEY: render.md's value
  awk -v k="$2: " 'index($0, k) == 1 { print substr($0, length(k) + 1); exit }' \
    "$R/stages/02-render/output/$1/render.md" 2>/dev/null
}
# tree_id DIR: DIR's git tree id, built here independently, under isolation.
tree_id() {
  local g="$SCRATCH/treeid$n"
  rm -rf "$g" && git init -q --bare --template= --object-format=sha1 "$g" &&
    (cd "$1" && find . -mindepth 1 ! -type d | sed 's|^\./||' | LC_ALL=C sort |
      GIT_DIR="$g" GIT_WORK_TREE="$1" GIT_INDEX_FILE="$g/index" git -c core.autocrlf=false add --pathspec-from-file=- >/dev/null) &&
    GIT_DIR="$g" GIT_INDEX_FILE="$g/index" git write-tree
}
gone() { if [ -e "$1" ] || [ -L "$1" ]; then echo present; else echo gone; fi; }
refused() { # DESCRIPTION NEEDLE ARGS...: refused, with nothing written to the target
  local what=$1 needle=$2 before
  shift 2
  before=$(gone "$ROOT/widget")
  render "$@"
  assert_status 1 "$ST" "refused: $what"
  assert_contains "$OUT" "$needle" "  and the refusal says: $needle"
  [ "$before" = present ] || assert_eq "gone" "$(gone "$ROOT/widget")" "  and nothing is written"
}

# --- a render ------------------------------------------------------------------------
fresh
confirmed widget
render widget
assert_status 0 "$ST" "bin/render renders a confirmed run"
assert_eq "# widget

Bé & back\\slash = equals" "$(cat "$ROOT/widget/README.md" 2>/dev/null)" "a template's placeholders take their values"
assert_eq "- A Person
- B Person" "$(grep '^- ' "$ROOT/widget/GOVERNANCE.md")" "a '- {{LIST}}' line repeats per item"
assert_eq "Listed: A Person, B Person." "$(grep '^Listed' "$ROOT/widget/GOVERNANCE.md")" "a list elsewhere takes its value"
assert_eq "The Apache licence text." "$(cat "$ROOT/widget/LICENSE" 2>/dev/null)" "the selected variant is used"
assert_eq 'echo ${{ github.sha }} {{NAME}}' "$(cat "$ROOT/widget/tool" 2>/dev/null)" "a verbatim file is copied as it is"
assert_eq "yes" "$([ -x "$ROOT/widget/tool" ] && echo yes)" "  with its mode"
assert_eq "$(printf 'one\r\ntwo\r\n' | cksum)" "$(cksum <"$ROOT/widget/crlf.txt")" "  byte for byte"
assert_eq "README.md" "$(readlink "$ROOT/widget/readme-link")" "a symbolic link stays one"
assert_eq "" "$(cd "$ROOT/widget" && find . -name '*.tmpl' -o -name 'LICENSE.*')" "no template or variant name reaches the target"
assert_eq "gone" "$(gone "$ROOT/widget/.git")" "no .git is made in the target"
FP=$(record widget fingerprint)
assert_eq "$(tree_id "$ROOT/widget")" "$FP" "render.md's fingerprint is the target's tree id"
assert_eq "$ROOT/widget" "$(record widget target)" "render.md records the target"
assert_eq "$(git -C "$R" rev-parse HEAD)" "$(record widget workspace)" "  the workspace SHA"
assert_eq "$(git -C "$R" hash-object --no-filters "$R/stages/01-ask/output/widget/answers.env")" \
  "$(record widget answers)" "  the answers file's blob id"
assert_eq "$(cd "$ROOT/widget" && find . -mindepth 1 ! -type d | sed 's|^\./||' | LC_ALL=C sort)" \
  "$(sed -n '/^## Files$/,$p' "$R/stages/02-render/output/widget/render.md" | sed '1,2d')" "  and the file list"

# The plan's Done-when: a second render of the same answers, the same fingerprint.
printf 'stray\n' >"$ROOT/widget/stray"
render widget --replace --remove "$ROOT/widget"
assert_status 0 "$ST" "--replace --remove the target"
assert_eq "gone" "$(gone "$ROOT/widget/stray")" "  discards it first: a file it held is gone"
assert_eq "$FP" "$(record widget fingerprint)" "  gives the same fingerprint"

fresh
confirmed widget LICENSE=none
render widget
assert_eq "Copyright Okja-Engineering. All rights reserved." "$(cat "$ROOT/widget/LICENSE")" "LICENSE=none selects the other variant"
assert_eq "$(printf 'Copyright Okja-Engineering. All rights reserved.' | cksum)" "$(cksum <"$ROOT/widget/LICENSE")" \
  "  a template's last line kept without a newline"

fresh
confirmed widget
mkdir -p "$ROOT/widget"
render widget
assert_status 0 "$ST" "an empty target is rendered into"

# --- AC9's refusals ---------------------------------------------------------------------
fresh
ask run widget 'DESCRIPTION=One line'
refused "answers without a confirmed.md" "has no confirmed.md" widget
fresh
confirmed widget
printf 'VISIBILITY=private\n' >>"$R/stages/01-ask/output/widget/answers.env"
refused "answers whose blob id confirmed.md does not name" "is not the answers confirmed.md names" widget
fresh
refused "a run that does not exist" "widget" widget
fresh
put foundation/README.md.tmpl '# {{NAME}} for {{OWNER}}'
fixture_commit "$R" "test: a placeholder that is not a render field"
confirmed widget
refused "a placeholder that is not a render field" "{{OWNER}}" widget
fresh
put foundation/README.md.tmpl '# {{BOGUS}}'
fixture_commit "$R" "test: a placeholder of no field"
confirmed widget
refused "a placeholder of no field" "{{BOGUS}}" widget
fresh
put foundation/README.md.tmpl '# {{{{HOLDER}}}}'
fixture_commit "$R" "test: a placeholder made by substitution"
confirmed widget --setup-override HOLDER=ACME
refused "a {{FIELD}} left after substitution" "left after substitution" widget
fresh
chmod +x "$R/foundation/README.md.tmpl"
fixture_commit "$R" "test: an executable template"
confirmed widget
refused "an executable template" "executable template" widget
fresh
put foundation/LICENSE.mit 'MIT'
fixture_commit "$R" "test: a variant no value selects"
confirmed widget
refused "a variant whose field selects nothing" "LICENSE.mit" widget
fresh
git -C "$R" rm -q foundation/LICENSE.none.tmpl
fixture_commit "$R" "test: no variant for none"
confirmed widget LICENSE=none
refused "a selecting field with no variant for its value" "LICENSE.none" widget
fresh
put foundation/LICENSE 'A plain licence.'
fixture_commit "$R" "test: a plain file beside its variants"
confirmed widget
refused "a path with two sources" "a second source for LICENSE" widget
fresh
ln -s README.md.tmpl "$R/foundation/link.md.tmpl"
fixture_commit "$R" "test: a template that is a symbolic link"
confirmed widget
refused "a template that is a symbolic link" "foundation/link.md.tmpl: a template that is a symbolic link" widget
fresh
git -C "$R" update-index --add --cacheinfo "160000,$(git -C "$R" rev-parse HEAD),foundation/sub"
git -C "$R" commit -q -m "test: a submodule in the foundation"
confirmed widget
refused "a submodule in the foundation" "foundation/sub: a submodule" widget
fresh
confirmed widget
refused "a NAME the schema refuses" "NAME" 'Bad Name'
fresh
confirmed widget
sed 's/^NAME=widget$/NAME=gadget/' "$R/stages/01-ask/output/widget/answers.env" >"$SCRATCH/a$n" &&
  mv "$SCRATCH/a$n" "$R/stages/01-ask/output/widget/answers.env"
ask confirm widget --by 'A Person'
refused "answers naming another run, confirmed again" "names another run" widget
fresh
confirmed widget
sed "s|^TARGET=.*|TARGET=$ROOT/gadget|" "$R/stages/01-ask/output/widget/answers.env" >"$SCRATCH/a$n" &&
  mv "$SCRATCH/a$n" "$R/stages/01-ask/output/widget/answers.env"
ask confirm widget --by 'A Person'
assert_status 1 "$?" "confirm refuses a TARGET edited by hand"
# confirmed.md written by hand, so render's own check is reached.
printf '%s\n' '# Confirmed: widget' '' 'by: A Person' 'at: 2026-01-01T00:00:00Z' \
  "answers: $(git -C "$R" hash-object --no-filters "$R/stages/01-ask/output/widget/answers.env")" \
  >"$R/stages/01-ask/output/widget/confirmed.md"
refused "a TARGET that is not TARGET_ROOT then /NAME, confirmed by hand" \
  "TARGET $ROOT/gadget is not TARGET_ROOT $ROOT, expanded here, then /widget" widget
assert_contains "$OUT" "bin/ask run widget --redo" "  and routes to --redo"
assert_eq "gone" "$(gone "$ROOT/gadget")" "  and writes nothing there"
# A TARGET written under another HOME (decision 227).
fresh
mkdir -p "$SCRATCH/home$n/a" "$SCRATCH/home$n/b"
(cd "$R" &&
  HOME="$SCRATCH/home$n/a" bin/ask run widget 'DESCRIPTION=One line' --setup-override 'TARGET_ROOT=~/targets' >/dev/null 2>&1 &&
  HOME="$SCRATCH/home$n/a" bin/ask confirm widget --by 'A Person' >/dev/null 2>&1)
OUT=$(cd "$R" && HOME="$SCRATCH/home$n/b" bin/render widget 2>&1)
assert_status 1 "$?" "refused: a TARGET written under another HOME"
assert_contains "$OUT" "$SCRATCH/home$n/b/targets/widget" "  and the refusal names the TARGET this HOME gives"
assert_eq "gone" "$(gone "$SCRATCH/home$n/b/targets")" "  and nothing is written under this HOME"
OUT=$(cd "$R" && HOME="$SCRATCH/home$n/a" bin/render widget 2>&1)
assert_status 0 "$?" "  and it renders under the HOME it was written under"
fresh
confirmed widget
mkdir -p "$SCRATCH/oldgit$n"
printf '#!/bin/sh\nif [ "$1" = --version ]; then echo "git version 2.35.9"; exit 0; fi\nexec %s "$@"\n' "$(command -v git)" >"$SCRATCH/oldgit$n/git"
chmod +x "$SCRATCH/oldgit$n/git"
OUT=$(cd "$R" && PATH="$SCRATCH/oldgit$n:$PATH" bin/render widget 2>&1)
assert_status 1 "$?" "refused: git older than 2.36"
assert_contains "$OUT" "older than 2.36" "  and the refusal names the floor"
fresh
put foundation/README.md.tmpl '# {{NAME}}' 'uncommitted'
confirmed widget
render widget
assert_status 0 "$ST" "render reads foundation/ at HEAD"
assert_not_contains "$(cat "$ROOT/widget/README.md")" "uncommitted" "  not the working tree"

fresh
confirmed widget
mkdir -p "$ROOT/widget/kept"
refused "a present target without --remove" "$ROOT/widget" widget
assert_eq "present" "$(gone "$ROOT/widget/kept")" "  and it is left alone"
fresh
confirmed widget
render widget
refused "a second render without --replace" "--replace" widget
refused "--replace without --remove while the target is present" "--remove" widget --replace
mkdir -p "$ROOT/other"
refused "--replace --remove naming another path" "not the target render.md names" widget --replace --remove "$ROOT/other"
assert_eq "present" "$(gone "$ROOT/widget/README.md")" "  with the target not removed"
assert_eq "present" "$(gone "$ROOT/other")" "  nor the other path"
# render.md edited to name another path: the run's TARGET is the one root.
sed "s|^target: .*|target: $ROOT/other|" "$R/stages/02-render/output/widget/render.md" >"$SCRATCH/r$n" &&
  mv "$SCRATCH/r$n" "$R/stages/02-render/output/widget/render.md"
refused "--replace --remove naming a path render.md names, not the run's TARGET" \
  "but the run's TARGET is $ROOT/widget" widget --replace --remove "$ROOT/other"
assert_eq "present" "$(gone "$ROOT/other")" "  with it not removed"
render widget --remove "$ROOT/widget"
assert_status 2 "$ST" "--remove without --replace is a usage error"
fresh
confirmed widget
refused "--replace with nothing rendered" "--replace" widget --replace
fresh
confirmed widget
printf 'BOGUS\tsetup\ttext\tno\t-\t-\tx\tA new field?\n' >>"$R/shared/answers.tsv"
fixture_commit "$R" "test: the schema gains a field"
refused "answers the schema at HEAD rejects" "BOGUS" widget
fresh
confirmed widget
printf 'BOGUS\tsetup\ttext\tno\t-\t-\tx\tA new field?\n' >>"$R/shared/answers.tsv"
render widget
assert_status 0 "$ST" "render judges the answers by the schema at HEAD, not the working tree's"

# --- --replace clears 03 -----------------------------------------------------------------
fresh
confirmed widget
render widget
mkdir -p "$R/stages/03-verify/output/widget/judge/locked/deeper"
printf 'pass\n' >"$R/stages/03-verify/output/widget/verify.md"
chmod 000 "$R/stages/03-verify/output/widget/judge/locked/deeper" "$R/stages/03-verify/output/widget/judge/locked"
render widget --replace --remove "$ROOT/widget"
assert_status 0 "$ST" "--replace with 03 outputs holding a chmod 000 judge/ directory"
assert_eq "gone" "$(gone "$R/stages/03-verify/output/widget")" "  leaves no verify record"
fresh
confirmed widget
render widget
mkdir -p "$R/stages/03-verify/output/widget/judge" "$SCRATCH/stub$n"
printf '#!/bin/sh\nexit 0\n' >"$SCRATCH/stub$n/rm"
chmod +x "$SCRATCH/stub$n/rm"
OUT=$(cd "$R" && PATH="$SCRATCH/stub$n:$PATH" bin/render widget --replace --remove "$ROOT/widget" 2>&1)
assert_status 1 "$?" "refused: --replace whose removal fails under a stub rm"
assert_contains "$OUT" "could not remove $ROOT/widget" "  and the refusal names the path"

# --- the write is one transaction (decision 226) ---------------------------------------------
# gitstub CODE: a git first on PATH that runs CODE when called for
# write-tree, the fingerprint's last step, after the copy and the walk.
gitstub() {
  mkdir -p "$SCRATCH/gstub$n"
  printf '#!/bin/sh\nfor a in "$@"; do\n  if [ "$a" = write-tree ]; then\n%s\n  fi\ndone\nexec %s "$@"\n' \
    "$1" "$(command -v git)" >"$SCRATCH/gstub$n/git"
  chmod +x "$SCRATCH/gstub$n/git"
}
stubbed() { OUT=$(cd "$R" && PATH="$SCRATCH/gstub$n:$PATH" bin/render "$@" 2>&1); ST=$?; }
# entries DIR: the names in DIR, dot names included, sorted; none if absent.
entries() { (cd "$1" 2>/dev/null && find . -mindepth 1 -maxdepth 1 | sed 's|^\./||' | LC_ALL=C sort); }
# left: what is in TARGET_ROOT and in the run's 02 outputs.
left() {
  { entries "$ROOT"; entries "$R/stages/02-render/output/widget" | sed 's|^|02/|'; } | tr '\n' ' '
}
fresh
confirmed widget
mkdir -p "$ROOT/widget"
gitstub 'exit 1'
stubbed widget
assert_status 1 "$ST" "refused: a fingerprint that fails after the copy"
assert_contains "$OUT" "cannot fingerprint" "  and the refusal says why"
assert_eq "present" "$(gone "$ROOT/widget")" "  and the empty target it found is left"
assert_eq "" "$(entries "$ROOT/widget")" "  holding nothing"
assert_eq "widget " "$(left)" "  and nothing else is left, no render.md, no staging directory"
# An interrupt during the fingerprint removes all this run made.
fresh
confirmed widget
gitstub ": >\"$SCRATCH/at$n\"; while [ ! -e \"$SCRATCH/go$n\" ]; do sleep 1; done; exit 1"
set -m
(cd "$R" && PATH="$SCRATCH/gstub$n:$PATH" exec bin/render widget >"$SCRATCH/out$n" 2>&1) &
pid=$!
set +m
i=0
while [ ! -e "$SCRATCH/at$n" ] && [ "$i" -lt 600 ]; do sleep 1 && i=$((i + 1)); done
kill -INT "$pid"
: >"$SCRATCH/go$n"
wait "$pid"
assert_status 130 "$?" "an interrupt during the fingerprint ends render with 130"
assert_eq "gone" "$(gone "$ROOT/widget")" "  and leaves no target"
assert_eq "" "$(left)" "  nor a staging directory, render.md or temporary file"
# --replace whose write then fails leaves the run unrendered, not a record
# naming a target that is gone.
fresh
confirmed widget
render widget
mkdir -p "$R/stages/03-verify/output/widget"
gitstub 'exit 1'
stubbed widget --replace --remove "$ROOT/widget"
assert_status 1 "$ST" "refused: --replace whose fingerprint fails"
assert_eq "gone" "$(gone "$R/stages/02-render/output/widget/render.md")" "  and no render.md names the removed target"
assert_eq "gone" "$(gone "$R/stages/03-verify/output/widget")" "  and the 03 outputs are cleared"
assert_eq "" "$(left)" "  and nothing else is left"
render widget
assert_status 0 "$ST" "  and the run renders again without --replace"
# A target a killed render left, with no render.md: named, with its route.
fresh
confirmed widget
mkdir -p "$ROOT/widget/half"
refused "a target present with no render.md" "bin/render widget --replace --remove \"$ROOT/widget\"" widget
assert_eq "present" "$(gone "$ROOT/widget/half")" "  and it is left alone"
render widget --replace --remove "$ROOT/widget"
assert_status 0 "$ST" "  and --replace --remove naming it renders"
assert_eq "gone" "$(gone "$ROOT/widget/half")" "  having removed it"
# A target that appears while render runs is left alone.
fresh
confirmed widget
gitstub "    mkdir -p \"$ROOT/widget/late\""
stubbed widget
assert_status 1 "$ST" "refused: a target that appears while render runs"
assert_contains "$OUT" "no longer an empty directory" "  and the refusal says so"
assert_eq "present" "$(gone "$ROOT/widget/late")" "  and it is left alone"
assert_eq "widget " "$(left)" "  with nothing of this run's left"
fresh
confirmed widget
mkdir -p "$SCRATCH/elsewhere$n"
gitstub "    ln -s \"$SCRATCH/elsewhere$n\" \"$ROOT/widget\""
stubbed widget
assert_status 1 "$ST" "refused: a symbolic link to a directory that appears at the target"
assert_contains "$OUT" "appeared while render ran" "  and the refusal says so"
assert_eq "" "$(entries "$SCRATCH/elsewhere$n")" "  and nothing is left in the directory it names"
assert_eq "widget " "$(left)" "  nor beside it"
fresh
confirmed widget
gitstub "    printf x >\"$ROOT/widget\""
stubbed widget
assert_status 1 "$ST" "refused: a file that appears at the target"
assert_contains "$OUT" "cannot move the render into" "  and the refusal says so"
assert_eq "x" "$(cat "$ROOT/widget")" "  and the file is left as it is"
assert_eq "widget " "$(left)" "  with nothing of this run's left"
# The renames: an interrupt is held off until both are done, and a failure
# of the second removes the target the first put there.
mvstub() {
  mkdir -p "$SCRATCH/mstub$n"
  printf '#!/bin/sh\ncase "$*" in\n%s\nesac\nexec %s "$@"\n' "$1" "$(command -v mv)" >"$SCRATCH/mstub$n/mv"
  chmod +x "$SCRATCH/mstub$n/mv"
}
mvstubbed() { OUT=$(cd "$R" && PATH="$SCRATCH/mstub$n:$PATH" bin/render "$@" 2>&1); ST=$?; }
fresh
confirmed widget
mvstub '  *.widget.render.*) kill -INT "$PPID" ;;'
mvstubbed widget
assert_status 0 "$ST" "an interrupt during the renames is held off"
assert_eq "$ROOT/widget" "$(record widget target)" "  and render.md is written"
fresh
confirmed widget
mvstub '  *render.md.tmp.*) exit 1 ;;'
mvstubbed widget
assert_status 1 "$ST" "refused: render.md's rename fails"
assert_contains "$OUT" "cannot write stages/02-render/output/widget/render.md" "  and the refusal says so"
assert_eq "" "$(left)" "  and the target this run put in place is removed, with nothing else left"
# A render.md that is not a file is refused, not written into.
fresh
confirmed widget
mkdir -p "$R/stages/02-render/output/widget/render.md/sub"
refused "a render.md that is a directory" "render.md is not a file" widget
assert_eq "present" "$(gone "$R/stages/02-render/output/widget/render.md/sub")" "  and it is left alone"
# What render makes, it makes exclusively: a staging directory or a
# temporary render.md planted at its name is refused and left.
fresh
confirmed widget
OUT=$(cd "$R" && sh -c 'mkdir -p "$1/.widget.render.$$" && exec bin/render widget' sh "$ROOT" 2>&1)
assert_status 1 "$?" "refused: a staging directory planted at render's name"
assert_contains "$OUT" "cannot make the staging directory" "  and the refusal says so"
assert_eq "gone" "$(gone "$ROOT/widget")" "  and no target is written"
assert_eq "1" "$(entries "$ROOT" | grep -c '^\.widget\.render\.')" "  and the planted directory is left"
fresh
confirmed widget
mkdir -p "$R/stages/02-render/output/widget"
OUT=$(cd "$R" && sh -c 'ln -s "$1" "stages/02-render/output/widget/render.md.tmp.$$" && exec bin/render widget' \
  sh "$SCRATCH/linked$n" 2>&1)
assert_status 1 "$?" "refused: a symbolic link planted at render.md's temporary name"
assert_eq "gone" "$(gone "$SCRATCH/linked$n")" "  and nothing is written through it"
assert_eq "gone" "$(gone "$ROOT/widget")" "  nor to the target"
assert_eq "1" "$(entries "$R/stages/02-render/output/widget" | grep -c '^render\.md\.tmp\.')" "  and the planted link is left"
if [ "$(id -u)" != 0 ]; then
  fresh
  confirmed widget
  mkdir -p "$ROOT/widget"
  chmod 555 "$ROOT/widget"
  render widget
  assert_status 0 "$ST" "an empty target render cannot write into is replaced"
  assert_eq "present" "$(gone "$ROOT/widget/README.md")" "  by the render"
  fresh
  confirmed widget
  mkdir -p "$ROOT"
  chmod 555 "$ROOT"
  render widget
  chmod 755 "$ROOT"
  assert_status 1 "$ST" "refused: a TARGET_ROOT render cannot write into"
  assert_contains "$OUT" "cannot make the staging directory" "  and the refusal says why"
  assert_eq "" "$(left)" "  with nothing written"
  fresh
  confirmed widget
  render widget
  mkdir -p "$R/stages/03-verify/output/widget"
  chmod 555 "$R/stages/02-render/output/widget"
  render widget --replace --remove "$ROOT/widget"
  chmod 755 "$R/stages/02-render/output/widget"
  assert_status 1 "$ST" "refused: --replace where render.md cannot be written"
  assert_contains "$OUT" "cannot write beside" "  and the refusal says why"
  assert_eq "present" "$(gone "$ROOT/widget/README.md")" "  before the target is removed"
  assert_eq "present" "$(gone "$R/stages/03-verify/output/widget")" "  or the 03 outputs"
  assert_eq "present" "$(gone "$R/stages/02-render/output/widget/render.md")" "  or render.md"
fi
# TARGET_ROOT's missing ancestors, made by render, stay.
fresh
confirmed widget --setup-override "TARGET_ROOT=$SCRATCH/anc$n/a/b"
gitstub 'exit 1'
stubbed widget
assert_status 1 "$ST" "refused: a failure under a TARGET_ROOT render made"
assert_eq "yes" "$([ -d "$SCRATCH/anc$n/a/b" ] && echo yes)" "  which stays, with its ancestors"
assert_eq "" "$(entries "$SCRATCH/anc$n/a/b")" "  empty"

# --- TARGET_ROOT outside every working tree of the workspace ----------------------------------
# outside_refused DESCRIPTION NEEDLE ROOT [DIR]: a run whose TARGET_ROOT is
# ROOT, asked and rendered from the workspace DIR (R by default), is
# refused before anything is written.
outside_refused() {
  local what=$1 needle=$2 troot=$3 dir=${4:-$R}
  (cd "$dir" && bin/ask run widget 'DESCRIPTION=One line' --setup-override "TARGET_ROOT=$troot" >/dev/null 2>&1 &&
    bin/ask confirm widget --by 'A Person' >/dev/null 2>&1)
  OUT=$(cd "$dir" && bin/render widget 2>&1)
  ST=$?
  assert_status 1 "$ST" "refused: a TARGET_ROOT $what"
  assert_contains "$OUT" "$needle" "  and the refusal says: $needle"
  assert_eq "gone" "$(gone "$troot/widget")" "  and nothing is written"
}
fresh
outside_refused "inside the workspace, as <ws>/<absent>" "under $R, a working tree" "$R/absent/deeper"
assert_eq "gone" "$(gone "$R/absent")" "  not even TARGET_ROOT"
fresh
mkdir -p "$R/sub"
ln -s "$R/sub" "$SCRATCH/link$n"
outside_refused "through a symbolic link to a workspace subdirectory" "under $R, a working tree" "$SCRATCH/link$n/t"
fresh
git -C "$R" worktree add -q "$SCRATCH/linked$n" -b linked$n 2>/dev/null
outside_refused "under the main checkout, from a linked worktree" "under $R, a working tree" "$R/t" "$SCRATCH/linked$n"
fresh
git -C "$R" worktree add -q "$SCRATCH/sibA$n" -b sibA$n 2>/dev/null
git -C "$R" worktree add -q "$SCRATCH/sibB$n" -b sibB$n 2>/dev/null
outside_refused "under a sibling linked worktree" "under $SCRATCH/sibB$n, a working tree" "$SCRATCH/sibB$n/t" "$SCRATCH/sibA$n"
fresh
NL="$SCRATCH/new
line$n"
git -C "$R" worktree add -q "$NL" -b nl$n 2>/dev/null
ln -s "$NL" "$SCRATCH/nllink$n"
outside_refused "under a linked worktree whose path holds a newline" "line$n, a working tree" "$SCRATCH/nllink$n/t"
fresh
git -C "$R" init -q --separate-git-dir="$SCRATCH/gitdir$n" >/dev/null
outside_refused "inside a workspace with a separate git directory" "under $R, a working tree" "$R/t"
fresh
S="$SCRATCH/super$n"
git init -q -b main "$S"
git -C "$S" -c protocol.file.allow=always submodule add -q "$R" ws >/dev/null 2>&1
git -C "$S" commit -q -m 'test: a superproject'
outside_refused "inside a submodule workspace" "under $S/ws, a working tree" "$S/ws/t" "$S/ws"
if [ "$(id -u)" != 0 ]; then
  fresh
  mkdir -p "$SCRATCH/locked$n/sub"
  chmod 000 "$SCRATCH/locked$n"
  outside_refused "under an unsearchable ancestor" "$SCRATCH/locked$n cannot be entered" "$SCRATCH/locked$n/sub/t"
  chmod 755 "$SCRATCH/locked$n"
fi
if [ "$(uname -s)" = Darwin ] && [ -d /System/Volumes/Data ]; then
  fresh
  outside_refused "naming the workspace through /System/Volumes/Data" "under $R, a working tree" "/System/Volumes/Data$R/t"
fi
# accepted: the default, beside a bare common directory, and beside a
# prunable entry.
fresh
grep -v '^TARGET_ROOT=' "$R/setup/answers.env" >"$SCRATCH/setup$n" && mv "$SCRATCH/setup$n" "$R/setup/answers.env"
(cd "$R" && bin/ask setup >/dev/null)
assert_eq "TARGET_ROOT=~/Development/Okja-Engineering" "$(grep '^TARGET_ROOT=' "$R/setup/answers.env")" \
  "setup gives TARGET_ROOT its default"
mkdir -p "$SCRATCH/home$n"
OUT=$(cd "$R" && export HOME="$SCRATCH/home$n" && bin/ask run widget 'DESCRIPTION=One line' 2>&1 &&
  bin/ask confirm widget --by 'A Person' 2>&1 && bin/render widget 2>&1)
assert_status 0 "$?" "the default TARGET_ROOT is accepted"
assert_eq "present" "$(gone "$SCRATCH/home$n/Development/Okja-Engineering/widget/README.md")" "  and the target is rendered under it"
fresh
git clone -q --bare "$R" "$SCRATCH/bare$n.git"
git -C "$SCRATCH/bare$n.git" worktree add -q "$SCRATCH/onbare$n" main 2>/dev/null
(cd "$SCRATCH/onbare$n" && bin/ask run widget 'DESCRIPTION=One line' --setup-override "TARGET_ROOT=$SCRATCH/bare$n.git/targets" >/dev/null 2>&1 &&
  bin/ask confirm widget --by 'A Person' >/dev/null 2>&1)
OUT=$(cd "$SCRATCH/onbare$n" && bin/render widget 2>&1)
assert_status 0 "$?" "a TARGET_ROOT inside a bare common directory is accepted"
fresh
git -C "$R" worktree add -q "$SCRATCH/prunable$n" -b prunable$n 2>/dev/null
rm "$SCRATCH/prunable$n/.git"
confirmed widget --setup-override "TARGET_ROOT=$SCRATCH/prunable$n/targets"
render widget
assert_status 0 "$ST" "a TARGET_ROOT under a prunable worktree entry whose directory remains is accepted"

# --- the walk (decisions 166, 192), on render's own list ------------------------------------
# shellcheck source-path=SCRIPTDIR source=../bin/lib/render.sh
. "$TEST_DIR/../bin/lib/render.sh"
W="$SCRATCH/walk"
walk_case() { # DESCRIPTION NEEDLE: the walk of W against the list a, d/b
  OUT=$(render_walk "$W" "a
d/b" 2>&1)
  ST=$?
  assert_status 1 "$ST" "the walk refuses $1"
  assert_contains "$OUT" "$2" "  and says: $2"
}
fresh_walk() { rm -rf "$W" && mkdir -p "$W/d" && printf 'a' >"$W/a" && printf 'b' >"$W/d/b"; }
fresh_walk
OUT=$(render_walk "$W" "a
d/b" 2>&1)
assert_status 0 "$?" "the walk passes a target holding exactly its list"
fresh_walk
printf 'x' >"$W/new
line"
walk_case "a file named with a newline" "newline"
fresh_walk
mkdir "$W/empty"
walk_case "an empty extra directory" "holds no listed file"
fresh_walk
mkdir "$W/.git"
walk_case "a .git at the top level" "holds .git, an entry named .git"
fresh_walk
printf 'gitdir: /nowhere\n' >"$W/d/.git"
walk_case "a nested .git" "holds d/.git, an entry named .git"
fresh_walk
printf 'x' >"$W/extra"
walk_case "an extra file" "extra"
fresh_walk
rm "$W/d/b"
walk_case "a missing file" "d/b"
if [ "$(id -u)" != 0 ]; then
  fresh_walk
  chmod 000 "$W/d"
  walk_case "a directory it cannot list whole" "the walk cannot list the target"
  chmod 755 "$W/d"
fi

# The fingerprint's index check (decision 166): git adds nothing under a
# nested repository and still exits 0.
fresh_walk
OUT=$(render_fingerprint "$W" "a
d/b" 2>&1)
assert_status 0 "$?" "the fingerprint of a target holding its list"
assert_eq "$(tree_id "$W")" "$OUT" "  is its tree id"
git init -q "$W/d"
OUT=$(render_fingerprint "$W" "a
d/b" 2>&1)
assert_status 1 "$?" "the fingerprint refuses an index lacking a file under a nested repository"
assert_contains "$OUT" "not render's file list" "  and says so"
rm -rf "$W/d/.git"
OUT=$(render_fingerprint "$W" "a
d/b
d/missing" 2>&1)
assert_status 1 "$?" "the fingerprint refuses a git add that exits nonzero, for a listed file the target lacks"
assert_contains "$OUT" "git add exited" "  and says so"

# --- AC10's planted cases, against render's fingerprint ----------------------------------------
# planted DESCRIPTION ENV...: render with ENV planted, giving the baseline
# fingerprint, and the workspace's .git gaining no object or ref.
fresh
confirmed widget
render widget
BASE=$(record widget fingerprint)
objects() { (cd "$R/.git" && find objects refs -type f | LC_ALL=C sort | cksum); }
planted() {
  local what=$1 before
  shift
  before=$(objects)
  OUT=$(cd "$R" && env "$@" bin/render widget --replace --remove "$ROOT/widget" 2>&1)
  ST=$?
  assert_status 0 "$ST" "render with $what planted"
  assert_eq "$BASE" "$(record widget fingerprint)" "  gives the baseline fingerprint"
  assert_eq "$before" "$(objects)" "  and the workspace's .git gains no object or ref"
}
mkdir -p "$SCRATCH/xdg/git" "$SCRATCH/tpl/info"
printf '.claude/\nbin/\ntool\n' >"$SCRATCH/excludes"
printf '[core]\n\texcludesFile = %s\n\tfileMode = false\n\tautocrlf = true\n[commit]\n\tgpgsign = true\n' \
  "$SCRATCH/excludes" >"$SCRATCH/global.gitconfig"
planted "a global config excluding .claude/ and bin/, core.fileMode=false and commit.gpgsign=true" \
  "GIT_CONFIG_GLOBAL=$SCRATCH/global.gitconfig"
printf '.claude/\nbin/\n' >"$SCRATCH/xdg/git/ignore"
planted "\$XDG_CONFIG_HOME/git/ignore" "XDG_CONFIG_HOME=$SCRATCH/xdg"
rm "$SCRATCH/xdg/git/ignore"
printf '* text\n' >"$SCRATCH/xdg/git/attributes"
planted "\$XDG_CONFIG_HOME/git/attributes holding * text over a CRLF file" "XDG_CONFIG_HOME=$SCRATCH/xdg"
printf '* filter=planted\n' >"$SCRATCH/tpl/info/attributes"
printf '[filter "planted"]\n\tclean = sed s/A/Z/\n' >"$SCRATCH/tpl/config"
planted "a template directory whose attributes name a filter its config defines" "GIT_TEMPLATE_DIR=$SCRATCH/tpl"
planted "GIT_ATTR_SOURCE=HEAD" GIT_ATTR_SOURCE=HEAD
planted "GIT_DEFAULT_HASH=sha256" GIT_DEFAULT_HASH=sha256
planted "GIT_INDEX_FILE, GIT_DIR and GIT_WORK_TREE from another repository" \
  "GIT_INDEX_FILE=$SCRATCH/other.index" "GIT_DIR=$SCRATCH/other.git" "GIT_WORK_TREE=$SCRATCH"
# A replace ref in the workspace swapping a foundation file's blob, which
# GIT_NO_REPLACE_OBJECTS keeps render from reading.
blob=$(git -C "$R" rev-parse HEAD:foundation/LICENSE.apache-2.0)
swap=$(printf 'A replaced licence.\n' | git -C "$R" hash-object -w --stdin)
git -C "$R" replace "$blob" "$swap"
planted "a replace ref swapping a foundation blob" PLANTED=replace
git -C "$R" replace -d "$blob" >/dev/null

# Render run from a pre-commit hook during `git commit -a`.
mkdir -p "$R/.git/hooks"
printf '#!/bin/sh\nbin/render widget --replace --remove "%s/widget" >"%s/hook.out" 2>&1\n' "$ROOT" "$SCRATCH" >"$R/.git/hooks/pre-commit"
chmod +x "$R/.git/hooks/pre-commit"
printf 'changed\n' >>"$R/judged.txt"
git -C "$R" -c core.hooksPath="$R/.git/hooks" commit -q -a -m 'test: a commit whose hook renders'
assert_eq "$BASE" "$(record widget fingerprint)" "render from a pre-commit hook during git commit -a gives the baseline fingerprint"
assert_eq "judged.txt" "$(git -C "$R" show --name-only --format= HEAD)" "  and the commit holds only its own change"

# --- AC11: the same fingerprint, whatever the environment --------------------------------------
for env in "TZ=Asia/Tokyo" "LC_ALL=en_US.UTF-8" "HOME=$SCRATCH" "TZ=UTC0"; do
  OUT=$(cd "$R" && env "$env" bin/render widget --replace --remove "$ROOT/widget" 2>&1)
  assert_eq "$BASE" "$(record widget fingerprint)" "the fingerprint with $env"
done
OUT=$(cd / && "$R/bin/render" widget --replace --remove "$ROOT/widget" 2>&1)
assert_eq "$BASE" "$(record widget fingerprint)" "the fingerprint run from another working directory"
OUT=$(cd "$R" && umask 077 && bin/render widget --replace --remove "$ROOT/widget" 2>&1)
assert_eq "$BASE" "$(record widget fingerprint)" "the fingerprint under umask 077"
assert_eq "$(tree_id "$ROOT/widget")" "$(record widget fingerprint)" "  and it is still the target's tree id"

# --- AC12: one field changes exactly the paths it reaches ------------------------------------------
# sums DIR: "PATH CKSUM" per file under DIR, a link by its text.
sums() {
  (cd "$1" && find . -mindepth 1 ! -type d | sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r p; do
    if [ -L "$p" ]; then printf '%s link %s\n' "$p" "$(readlink "$p")"; else printf '%s %s\n' "$p" "$(cksum <"$p")"; fi
  done)
}
changed() { # A B: the paths whose bytes differ, or that one of them lacks
  diff <(sums "$1") <(sums "$2") | sed -n 's/^[<>] \([^ ]*\) .*/\1/p' | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//'
}
# variant LICENSE FIELD=value...: widget redone with these answers under
# the LICENSE given, its old target removed, rendered, and copied to $SCRATCH/v.
variant() {
  local lic=$1 old
  shift
  old=$(record widget target)
  ask run widget --redo --remove "$old" "DESCRIPTION=$DESC" "LICENSE=$lic" "$@" &&
    ask confirm widget --by 'A Person' && render widget
  rm -rf "$SCRATCH/v" && cp -R "$(record widget target)" "$SCRATCH/v"
}
fresh
DESC='One line'
for lic in apache-2.0 none; do
  ask run widget "DESCRIPTION=$DESC" "LICENSE=$lic" && ask confirm widget --by 'A Person' && render widget
  rm -rf "$SCRATCH/base" && cp -R "$ROOT/widget" "$SCRATCH/base"
  variant "$lic"
  assert_eq "" "$(changed "$SCRATCH/base" "$SCRATCH/v")" "LICENSE=$lic: the same answers change nothing"
  variant "$lic" --setup-override OWNER=acme
  assert_eq "" "$(changed "$SCRATCH/base" "$SCRATCH/v")" "LICENSE=$lic: OWNER, not a render field, changes nothing"
  variant "$lic" VISIBILITY=private
  assert_eq "" "$(changed "$SCRATCH/base" "$SCRATCH/v")" "LICENSE=$lic: VISIBILITY, not a render field, changes nothing"
  variant "$lic" --setup-override "TARGET_ROOT=$SCRATCH/elsewhere$n"
  assert_eq "$SCRATCH/elsewhere$n/widget" "$(record widget target)" "LICENSE=$lic: TARGET_ROOT moves the target"
  assert_eq "" "$(changed "$SCRATCH/base" "$SCRATCH/v")" "  and, not a render field, changes nothing in it"
  variant "$lic"
  DESC='Another line'
  variant "$lic"
  assert_eq "README.md" "$(changed "$SCRATCH/base" "$SCRATCH/v")" "LICENSE=$lic: DESCRIPTION changes README.md"
  DESC='One line'
  variant "$lic" --setup-override 'PEOPLE=C Person'
  assert_eq "GOVERNANCE.md" "$(changed "$SCRATCH/base" "$SCRATCH/v")" "LICENSE=$lic: PEOPLE changes GOVERNANCE.md"
  variant "$lic" --setup-override 'HOLDER=Acme'
  if [ "$lic" = none ]; then want=LICENSE; else want=""; fi
  assert_eq "$want" "$(changed "$SCRATCH/base" "$SCRATCH/v")" "LICENSE=$lic: HOLDER changes ${want:-nothing}"
  if [ "$lic" = none ]; then other=apache-2.0; else other=none; fi
  variant "$other"
  assert_eq "LICENSE" "$(changed "$SCRATCH/base" "$SCRATCH/v")" "LICENSE=$lic: LICENSE=$other changes LICENSE"
  ask run gadget "DESCRIPTION=$DESC" "LICENSE=$lic" && ask confirm gadget --by 'A Person' && render gadget
  assert_eq "README.md" "$(changed "$SCRATCH/base" "$(record gadget target)")" \
    "LICENSE=$lic: NAME changes README.md, and not tool, whose {{NAME}} is verbatim text"
  rm -rf "${ROOT:?}"/* "$R/stages/01-ask/output"/* "$R/stages/02-render/output"/*
done

assert_done
