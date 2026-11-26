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
# and verbatim files; its setup sends targets to ROOT, emptied for each
# case. ready: the same, holding a confirmed run of widget. Each is built
# once, by build_fresh and build_ready, and copied for each case.
ROOT="$SCRATCH/targets"
fresh() { copy fresh; }
ready() { copy ready; }
copy() { # KIND
  [ -d "$SCRATCH/fresh" ] || {
    R="$SCRATCH/fresh"
    build_fresh
  }
  [ -d "$SCRATCH/$1" ] || {
    R="$SCRATCH/$1"
    ws_copy "$SCRATCH/fresh" "$R" && confirmed widget
  }
  n=$((n + 1))
  R="$SCRATCH/ws$n"
  ws_copy "$SCRATCH/$1" "$R"
  if [ -e "$ROOT" ] || [ -L "$ROOT" ]; then
    chmod -R u+rwx "$ROOT" 2>/dev/null
    rm -rf "$ROOT"
  fi
}
build_fresh() {
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
ready
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
assert_eq "no no" "$([ -x "$ROOT/widget/crlf.txt" ] && echo yes || echo no) $([ -x "$ROOT/widget/README.md" ] && echo yes || echo no)" \
  "a 100644 file and a template arrive not executable"
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

ready
mkdir -p "$ROOT/widget"
render widget
assert_status 0 "$ST" "an empty target is rendered into"

# --- AC9's refusals ---------------------------------------------------------------------
fresh
ask run widget 'DESCRIPTION=One line'
refused "answers without a confirmed.md" "has no confirmed.md" widget
ready
printf 'VISIBILITY=private\n' >>"$R/stages/01-ask/output/widget/answers.env"
refused "answers whose blob id confirmed.md does not name" "is not the answers confirmed.md names" widget
fresh
refused "a run that does not exist" "there is no run widget" widget
# Each usage error (F9 of the tests lens).
render
assert_status 2 "$ST" "render with no NAME is a usage error"
assert_contains "$OUT" "NAME is required" "  and says so"
render widget --replace --remove
assert_status 2 "$ST" "--remove with no PATH is a usage error"
assert_contains "$OUT" "--remove needs PATH" "  and says so"
render widget --bogus
assert_status 2 "$ST" "an unknown argument is a usage error"
assert_contains "$OUT" "unknown argument: --bogus" "  and names it"
ready
mkdir -p "$SCRATCH/mkt$n"
fixture_failing "$SCRATCH/mkt$n" mktemp '-d *render.XXXXXX' 1
OUT=$(cd "$R" && PATH="$SCRATCH/mkt$n:$PATH" bin/render widget 2>&1)
assert_status 1 "$?" "refused: a render that cannot make its private directory"
assert_contains "$OUT" "cannot make a temporary directory" "  and the refusal says so"
# The schema render judges is HEAD's, whatever the disk holds: absent there,
# or not parsing there (T2's rest in the tests lens).
ready
git -C "$R" rm -q --cached shared/answers.tsv
git -C "$R" commit -q -m "test: no schema at HEAD"
refused "a HEAD that holds no shared/answers.tsv" "HEAD holds no shared/answers.tsv" widget
ready
cp "$R/shared/answers.tsv" "$SCRATCH/schema$n"
printf 'BROKEN\tsetup\tno-such-type\tno\t-\t-\t-\tQ?\n' >>"$R/shared/answers.tsv"
fixture_commit "$R" "test: a schema at HEAD that does not parse"
cp "$SCRATCH/schema$n" "$R/shared/answers.tsv"
refused "a shared/answers.tsv at HEAD that does not parse" "shared/answers.tsv at HEAD does not parse:" widget
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
refused "a plain file beside the variants of the path it selects" "LICENSE is a selected path" widget
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
ready
refused "a NAME the schema refuses" "NAME" 'Bad Name'
ready
sed 's/^NAME=widget$/NAME=gadget/' "$R/stages/01-ask/output/widget/answers.env" >"$SCRATCH/a$n" &&
  mv "$SCRATCH/a$n" "$R/stages/01-ask/output/widget/answers.env"
ask confirm widget --by 'A Person'
refused "answers naming another run, confirmed again" "names another run" widget
ready
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
ready
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

ready
mkdir -p "$ROOT/widget/kept"
refused "a present target without --remove" "$ROOT/widget" widget
assert_eq "present" "$(gone "$ROOT/widget/kept")" "  and it is left alone"
ready
render widget
refused "a second render without --replace" "rendered already" widget
refused "--replace without --remove while the target is present" "--remove" widget --replace
# With the target gone, render.md alone keeps a second render to --replace
# (the tests lens's F2).
mv "$ROOT/widget" "$SCRATCH/moved$n"
refused "a second render without --replace, its target gone" "the run widget is rendered already" widget
mv "$SCRATCH/moved$n" "$ROOT/widget"
mkdir -p "$ROOT/other" "$ROOT/.widget.render.4242"
refused "--replace --remove naming another path" "is not the run's target $ROOT/widget" widget --replace --remove "$ROOT/other"
assert_eq "present" "$(gone "$ROOT/widget/README.md")" "  with the target not removed"
assert_eq "present" "$(gone "$ROOT/other")" "  nor the other path"
assert_eq "present" "$(gone "$ROOT/.widget.render.4242")" "  nor, judged before anything is removed, a leftover staging directory"
rmdir "$ROOT/.widget.render.4242"
# render.md edited to name another path: the run's TARGET is the one root.
sed "s|^target: .*|target: $ROOT/other|" "$R/stages/02-render/output/widget/render.md" >"$SCRATCH/r$n" &&
  mv "$SCRATCH/r$n" "$R/stages/02-render/output/widget/render.md"
refused "--replace --remove naming a path render.md names, not the run's TARGET" \
  "render.md names $ROOT/other, not the run's target $ROOT/widget" widget --replace --remove "$ROOT/other"
assert_eq "present" "$(gone "$ROOT/other")" "  with it not removed"
render widget --remove "$ROOT/widget"
assert_status 2 "$ST" "--remove without --replace is a usage error"
ready
refused "--replace with nothing rendered" "--replace" widget --replace
ready
printf 'BOGUS\tsetup\ttext\tno\t-\t-\tx\tA new field?\n' >>"$R/shared/answers.tsv"
fixture_commit "$R" "test: the schema gains a field"
refused "answers the schema at HEAD rejects" "BOGUS" widget
ready
printf 'BOGUS\tsetup\ttext\tno\t-\t-\tx\tA new field?\n' >>"$R/shared/answers.tsv"
render widget
assert_status 0 "$ST" "render judges the answers by the schema at HEAD, not the working tree's"

# --- --replace clears 03 -----------------------------------------------------------------
ready
render widget
mkdir -p "$R/stages/03-verify/output/widget/judge/locked/deeper"
printf 'pass\n' >"$R/stages/03-verify/output/widget/verify.md"
chmod 000 "$R/stages/03-verify/output/widget/judge/locked/deeper" "$R/stages/03-verify/output/widget/judge/locked"
render widget --replace --remove "$ROOT/widget"
assert_status 0 "$ST" "--replace with 03 outputs holding a chmod 000 judge/ directory"
assert_eq "gone" "$(gone "$R/stages/03-verify/output/widget")" "  leaves no verify record"
ready
render widget
mkdir -p "$R/stages/03-verify/output/widget/judge" "$SCRATCH/stub$n"
# mktemp: a stub in DIR that is mktemp, noting each path it makes, so a test
# sees each one gone; leftover prints
# each noted path still present.
mkstub() {
  printf '#!/bin/sh\np=$(%s "$@") || exit\nprintf "%%s\\n" "$p" >>"%s"\nprintf "%%s\\n" "$p"\n' \
    "$(command -v mktemp)" "$SCRATCH/made$n" >"$1/mktemp"
  chmod +x "$1/mktemp"
}
leftover() {
  local p
  while IFS= read -r p; do
    if [ -e "$p" ] || [ -L "$p" ]; then printf '%s\n' "$p"; fi
  done <"$SCRATCH/made$n"
}
mkstub "$SCRATCH/stub$n"
# rm: a stub that leaves PATH, when PATH holds NEEDLE, and is rm otherwise,
# so render's own clean-up still runs.
rmstub() {
  printf '#!/bin/sh\ncase "$*" in *%s*) exit 0 ;; esac\nexec %s "$@"\n' "$1" "$(command -v rm)" >"$SCRATCH/stub$n/rm"
  chmod +x "$SCRATCH/stub$n/rm"
}
rmstub "$ROOT/widget"
OUT=$(cd "$R" && PATH="$SCRATCH/stub$n:$PATH" bin/render widget --replace --remove "$ROOT/widget" 2>&1)
assert_status 1 "$?" "refused: --replace whose removal fails under a stub rm"
assert_contains "$OUT" "could not remove $ROOT/widget; remove it" "  and the refusal names the path"
assert_eq "yes" "$([ -s "$SCRATCH/made$n" ] && echo yes)" "  having made temporary files"
assert_eq "" "$(leftover)" "  and leaves none of them"
# The clear of the 03 outputs, reached once the target is gone (decision
# 211's L-4): refused naming its path, render.md kept, so --replace is
# asked for again and clears them then.
rmstub 03-verify
OUT=$(cd "$R" && PATH="$SCRATCH/stub$n:$PATH" bin/render widget --replace --remove "$ROOT/widget" 2>&1)
assert_status 1 "$?" "refused: --replace whose clear of the 03 outputs fails"
assert_contains "$OUT" "could not remove stages/03-verify/output/widget" "  and the refusal names that path"
assert_eq "present" "$(gone "$R/stages/02-render/output/widget/render.md")" "  and render.md stays, asking for --replace"
# The removal of render.md, reached once the 03 outputs are gone: refused
# naming it, not overwritten by the new one (removal N4's r02).
ready
render widget
mkdir -p "$SCRATCH/stub$n"
rmstub 'rf?--?stages/02-render/output/widget/render.md'
OUT=$(cd "$R" && PATH="$SCRATCH/stub$n:$PATH" bin/render widget --replace --remove "$ROOT/widget" 2>&1)
assert_status 1 "$?" "refused: --replace whose removal of render.md fails"
assert_contains "$OUT" "could not remove stages/02-render/output/widget/render.md" "  and the refusal names it"

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
ready
mkdir -p "$ROOT/widget"
gitstub 'exit 1'
stubbed widget
assert_status 1 "$ST" "refused: a fingerprint that fails after the copy"
assert_contains "$OUT" "cannot fingerprint" "  and the refusal says why"
assert_eq "present" "$(gone "$ROOT/widget")" "  and the empty target it found is left"
assert_eq "" "$(entries "$ROOT/widget")" "  holding nothing"
assert_eq "widget " "$(left)" "  and nothing else is left, no render.md, no staging directory"
# An interrupt during the fingerprint removes all this run made.
ready
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
ready
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
ready
mkdir -p "$ROOT/widget/half"
refused "a target present with no render.md" "bin/render widget --replace --remove \"$ROOT/widget\"" widget
assert_eq "present" "$(gone "$ROOT/widget/half")" "  and it is left alone"
render widget --replace --remove "$ROOT/widget"
assert_status 0 "$ST" "  and --replace --remove naming it renders"
assert_eq "gone" "$(gone "$ROOT/widget/half")" "  having removed it"
# A target that appears while render runs is left alone.
ready
gitstub "    mkdir -p \"$ROOT/widget/late\""
stubbed widget
assert_status 1 "$ST" "refused: a target that appears while render runs"
assert_contains "$OUT" "no longer an empty directory" "  and the refusal says so"
assert_eq "present" "$(gone "$ROOT/widget/late")" "  and it is left alone"
assert_eq "widget " "$(left)" "  with nothing of this run's left"
ready
mkdir -p "$SCRATCH/elsewhere$n"
gitstub "    ln -s \"$SCRATCH/elsewhere$n\" \"$ROOT/widget\""
stubbed widget
assert_status 1 "$ST" "refused: a symbolic link to a directory that appears at the target"
assert_contains "$OUT" "appeared while render ran" "  and the refusal says so"
assert_eq "" "$(entries "$SCRATCH/elsewhere$n")" "  and nothing is left in the directory it names"
assert_eq "widget " "$(left)" "  nor beside it"
ready
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
ready
mvstub '  *.widget.render.*) kill -INT "$PPID" ;;'
mvstubbed widget
assert_status 0 "$ST" "an interrupt during the renames is held off"
assert_eq "$ROOT/widget" "$(record widget target)" "  and render.md is written"
ready
mvstub '  *render.md.tmp.*) exit 1 ;;'
mvstubbed widget
assert_status 1 "$ST" "refused: render.md's rename fails"
assert_contains "$OUT" "cannot write stages/02-render/output/widget/render.md" "  and the refusal says so"
assert_eq "" "$(left)" "  and the target this run put in place is removed, with nothing else left"
# A render.md that is not a file is refused, not written into.
ready
mkdir -p "$R/stages/02-render/output/widget/render.md/sub"
refused "a render.md that is a directory" "render.md is not a file" widget
assert_eq "present" "$(gone "$R/stages/02-render/output/widget/render.md/sub")" "  and it is left alone"
# The walk, end to end: a copy that brings a file the list does not hold,
# or an empty directory whose name holds a newline, is refused, and
# nothing is written.
cpstub() { # CODE: a cp first on PATH that copies, then runs CODE with $last
  mkdir -p "$SCRATCH/cpstub$n"
  printf '#!/bin/sh\n%s "$@" || exit\nfor a; do last=$a; done\n[ ! -d "$last" ] || { %s; }\n' "$(command -v cp)" "$1" \
    >"$SCRATCH/cpstub$n/cp"
  chmod +x "$SCRATCH/cpstub$n/cp"
}
ready
cpstub ': >"$last/extra"'
OUT=$(cd "$R" && PATH="$SCRATCH/cpstub$n:$PATH" bin/render widget 2>&1)
assert_status 1 "$?" "refused: a render whose copy brings a file the list does not hold"
assert_contains "$OUT" "the target holds a file render did not write: extra" "  and the walk says so"
assert_eq "" "$(left)" "  with nothing written"
# A staging directory the clean-up cannot remove is reported, not passed
# over in silence.
ready
cpstub ': >"$last/extra"'
printf '#!/bin/sh\ncase "$*" in *.widget.render.*) exit 0 ;; esac\nexec %s "$@"\n' "$(command -v rm)" >"$SCRATCH/cpstub$n/rm"
chmod +x "$SCRATCH/cpstub$n/rm"
OUT=$(cd "$R" && PATH="$SCRATCH/cpstub$n:$PATH" bin/render widget 2>&1)
assert_status 1 "$?" "refused: a render whose staging directory the clean-up cannot remove"
assert_contains "$OUT" "bin/render: could not remove $ROOT/.widget.render." "  and the clean-up names it"
# Each directory render makes, refused when it cannot be made.
ready
fixture_failing "$SCRATCH/mkd$n" mkdir '-p stages/02-render/output/widget' 1
OUT=$(cd "$R" && PATH="$SCRATCH/mkd$n:$PATH" bin/render widget 2>&1)
assert_status 1 "$?" "refused: a render whose render.md directory cannot be made"
assert_contains "$OUT" "cannot make stages/02-render/output/widget" "  and the refusal says so"
ready
fixture_failing "$SCRATCH/mkr$n" mkdir "-p $ROOT" 1
OUT=$(cd "$R" && PATH="$SCRATCH/mkr$n:$PATH" bin/render widget 2>&1)
assert_status 1 "$?" "refused: a render whose TARGET_ROOT cannot be made"
assert_contains "$OUT" "cannot make TARGET_ROOT $ROOT" "  and the refusal says so"
ready
cpstub 'mkdir "$last/a
b"'
OUT=$(cd "$R" && PATH="$SCRATCH/cpstub$n:$PATH" bin/render widget 2>&1)
assert_status 1 "$?" "refused: a render whose copy brings an empty directory named with a newline"
assert_contains "$OUT" "a name with a newline" "  and the walk says so"
assert_eq "" "$(left)" "  with nothing written"
# What render makes, it makes exclusively: a staging directory or a
# temporary render.md planted at its name is refused and left.
ready
OUT=$(cd "$R" && sh -c 'mkdir -p "$1/.widget.render.$$" && exec bin/render widget' sh "$ROOT" 2>&1)
assert_status 1 "$?" "refused: a staging directory planted at render's name"
assert_contains "$OUT" "cannot make the staging directory" "  and the refusal says so"
assert_eq "gone" "$(gone "$ROOT/widget")" "  and no target is written"
assert_eq "1" "$(entries "$ROOT" | grep -c '^\.widget\.render\.')" "  and the planted directory is left"
ready
mkdir -p "$R/stages/02-render/output/widget"
OUT=$(cd "$R" && sh -c 'ln -s "$1" "stages/02-render/output/widget/render.md.tmp.$$" && exec bin/render widget' \
  sh "$SCRATCH/linked$n" 2>&1)
assert_status 1 "$?" "refused: a symbolic link planted at render.md's temporary name"
assert_eq "gone" "$(gone "$SCRATCH/linked$n")" "  and nothing is written through it"
assert_eq "gone" "$(gone "$ROOT/widget")" "  nor to the target"
assert_eq "1" "$(entries "$R/stages/02-render/output/widget" | grep -c '^render\.md\.tmp\.')" "  and the planted link is left"
# A link to /dev/null, which noclobber alone would open, is in the way too.
ready
mkdir -p "$R/stages/02-render/output/widget"
OUT=$(cd "$R" && sh -c 'ln -s /dev/null "stages/02-render/output/widget/render.md.tmp.$$" && exec bin/render widget' 2>&1)
assert_status 1 "$?" "refused: a symbolic link to /dev/null planted at render.md's temporary name"
assert_contains "$OUT" "is in the way" "  and the refusal says so"
assert_eq "gone" "$(gone "$ROOT/widget")" "  and no target is written"
assert_eq "gone" "$(gone "$R/stages/02-render/output/widget/render.md")" "  nor render.md"
assert_eq "1" "$(entries "$R/stages/02-render/output/widget" | grep -c '^render\.md\.tmp\.')" "  and the planted link is left"

# --- what a run owns (decision 226) ------------------------------------------------------------
# Every temporary file, the libraries' included, lives in render's private
# directory, so a render, done or refused, leaves none in TMPDIR.
# in_tmpdir ARGS...: bin/render ARGS with TMPDIR an empty directory of its own.
in_tmpdir() {
  mkdir -p "$SCRATCH/tmpdir$n"
  OUT=$(cd "$R" && TMPDIR="$SCRATCH/tmpdir$n" bin/render "$@" 2>&1)
  ST=$?
}
ready
in_tmpdir widget
assert_status 0 "$ST" "a render with a TMPDIR of its own"
assert_eq "" "$(entries "$SCRATCH/tmpdir$n")" "  leaves nothing in it"
ready
cpstub ': >"$last/extra"'
OUT=$(cd "$R" && PATH="$SCRATCH/cpstub$n:$PATH" TMPDIR="$SCRATCH/tmpdir$n" bin/render widget 2>&1)
assert_status 1 "$?" "refused: a render the walk refuses, with a TMPDIR of its own"
assert_eq "" "$(entries "$SCRATCH/tmpdir$n")" "  leaves nothing in it"
# Each temporary file is made in render's private directory, the first,
# made under TMPDIR, on every platform: macOS's mktemp, given no template,
# ignores TMPDIR.
ready
mkdir -p "$SCRATCH/mkt$n" "$SCRATCH/tmpdir$n"
mkstub "$SCRATCH/mkt$n"
OUT=$(cd "$R" && PATH="$SCRATCH/mkt$n:$PATH" TMPDIR="$SCRATCH/tmpdir$n" bin/render widget 2>&1)
assert_status 0 "$?" "a render recording each temporary file it makes"
work=$(head -n 1 "$SCRATCH/made$n")
assert_eq "$SCRATCH/tmpdir$n/" "${work%/*}/" "  makes its private directory under TMPDIR"
assert_eq "" "$(sed 1d "$SCRATCH/made$n" | grep -v -F "$work/")" "  and every other temporary file in it"
assert_eq "yes" "$([ "$(wc -l <"$SCRATCH/made$n")" -ge 4 ] && echo yes)" "  the libraries' among them"
# A signal while render makes its private directory is held off until the
# directory is recorded for cleanup, so it is never left behind.
ready
mkdir -p "$SCRATCH/mkt$n" "$SCRATCH/tmpdir$n"
printf '#!/bin/sh\n%s "$@" && kill -s TERM "$PPID"\n' "$(command -v mktemp)" >"$SCRATCH/mkt$n/mktemp"
chmod +x "$SCRATCH/mkt$n/mktemp"
OUT=$(cd "$R" && PATH="$SCRATCH/mkt$n:$PATH" TMPDIR="$SCRATCH/tmpdir$n" bin/render widget 2>&1)
assert_eq "" "$(entries "$SCRATCH/tmpdir$n")" "a signal while render makes its private directory leaves nothing in TMPDIR"
# waitstub TOOL PATTERN: a TOOL first on PATH that, called with arguments
# matching PATTERN, says so in $SCRATCH/at$n and waits for $SCRATCH/go$n,
# then runs the real TOOL. signalled SIGNAL ARGS...: bin/render ARGS as a
# job of its own, under the stub, sent SIGNAL once the stub waits; ST is its
# status.
waitstub() {
  mkdir -p "$SCRATCH/wstub$n" "$SCRATCH/tmpdir$n"
  printf '#!/bin/sh\npat='"'"'%s'"'"'\ncase "$*" in\n  $pat) : >"%s"; while [ ! -e "%s" ]; do sleep 1; done ;;\nesac\nexec %s "$@"\n' \
    "$2" "$SCRATCH/at$n" "$SCRATCH/go$n" "$(command -v "$1")" >"$SCRATCH/wstub$n/$1"
  chmod +x "$SCRATCH/wstub$n/$1"
}
signalled() { # TARGET SIGNAL ARGS...: TARGET is "render" or "group"
  local to=$1 sig=$2 pid i=0
  shift 2
  set -m
  (cd "$R" && PATH="$SCRATCH/wstub$n:$PATH" TMPDIR="$SCRATCH/tmpdir$n" exec bin/render "$@" >"$SCRATCH/out$n" 2>&1) &
  pid=$!
  set +m
  # Render reaches the stub in seconds; one that never does fails the case.
  while [ ! -e "$SCRATCH/at$n" ] && [ "$i" -lt 120 ] && kill -0 "$pid" 2>/dev/null; do
    sleep 1 && i=$((i + 1))
  done
  assert_eq "present" "$(gone "$SCRATCH/at$n")" "  (render reached the stub: $(head -c 200 "$SCRATCH/out$n" 2>/dev/null))"
  if [ "$to" = group ]; then kill -s "$sig" -- "-$pid"; else kill -s "$sig" "$pid"; fi
  : >"$SCRATCH/go$n"
  wait "$pid"
  ST=$?
}
# A signal ignored when the suite began cannot be trapped by any shell it
# starts (POSIX), as in a background job, which ignores INT and QUIT: such a
# case is skipped, saying so.
entry_ignored() { [ "$(sh -c "kill -s $1 \$\$; echo alive" 2>/dev/null)" = alive ]; }
# A signal render traps, sent to render alone while it waits on its copy,
# a direct child, ends render by that signal's status, once the copy is
# done, with nothing it made left. One trap serves every signal of
# DISCARD_SIGNALS, each of which the renames case below sends, so four
# stand for them: INT, which a background job ignores, PROF, which a list
# by hand left out (render N1 of S2's third ship gate), and two others.
for sig in HUP INT TERM PROF; do
  if entry_ignored "$sig"; then
    assert_pass "skipped: SIG$sig was ignored when the suite began, so render cannot trap it"
    continue
  fi
  ready
  waitstub cp '-Rp *'
  signalled render "$sig" widget
  assert_status "$((128 + $(kill -l "$sig")))" "$ST" "SIG$sig while render copies ends it by that signal"
  assert_eq "" "$(left)" "  leaving no target, staging directory, render.md or temporary file"
  assert_eq "" "$(entries "$SCRATCH/tmpdir$n")" "  and nothing in TMPDIR"
done
# An interrupt to render's whole process group, as ^C sends it, during the
# fingerprint, which runs in a subshell holding its own temporary
# repository, leaves nothing in TMPDIR.
if entry_ignored INT; then
  assert_pass "skipped: SIGINT was ignored when the suite began, so render cannot trap it"
else
  ready
  waitstub git '*--literal-pathspecs add *'
  signalled group INT widget
  assert_status 130 "$ST" "an interrupt to the process group during the fingerprint ends render with 130"
  assert_eq "" "$(left)" "  leaving nothing beside the target"
  assert_eq "" "$(entries "$SCRATCH/tmpdir$n")" "  and nothing in TMPDIR, the fingerprint's repository included"
fi
# A signal outside the hold windows ends render: a TERM while it sweeps a
# killed render's staging directory, after its private directory is made
# and the signals let through again (the tests lens's N3 of S2's third).
if entry_ignored TERM; then
  assert_pass "skipped: SIGTERM was ignored when the suite began, so render cannot trap it"
else
  ready
  mkdir -p "$ROOT/.widget.render.1/x" "$SCRATCH/swstub$n"
  printf '#!/bin/sh\ncase "$*" in *.widget.render.1*) kill -s TERM "$(cat "%s")" ;; esac\nexec %s "$@"\n' \
    "$SCRATCH/swpid$n" "$(command -v rm)" >"$SCRATCH/swstub$n/rm"
  chmod +x "$SCRATCH/swstub$n/rm"
  OUT=$(cd "$R" && PATH="$SCRATCH/swstub$n:$PATH" sh -c 'echo "$$" >"$1" && exec bin/render widget' sh "$SCRATCH/swpid$n" 2>&1)
  assert_status 143 "$?" "a TERM while render sweeps a leftover ends it with 143"
  assert_eq "gone" "$(gone "$ROOT/widget")" "  and no target is written"
fi
# A second signal while cleanup runs is held off, so cleanup finishes:
# TERM during the copy, then TERM again as cleanup removes the staging
# directory (render's NIT of S2's third ship gate).
if entry_ignored TERM; then
  assert_pass "skipped: SIGTERM was ignored when the suite began, so render cannot trap it"
else
  ready
  waitstub cp '-Rp *'
  printf '#!/bin/sh\ncase "$*" in *.widget.render.*) kill -s TERM "$(ps -o ppid= -p "$PPID" | tr -d " ")" ;; esac\nexec %s "$@"\n' \
    "$(command -v rm)" >"$SCRATCH/wstub$n/rm"
  chmod +x "$SCRATCH/wstub$n/rm"
  signalled render TERM widget
  assert_status 143 "$ST" "a second signal during cleanup"
  assert_eq "" "$(left)" "  leaves cleanup to finish: no target, staging directory, render.md or temporary file"
  assert_eq "" "$(entries "$SCRATCH/tmpdir$n")" "  and nothing in TMPDIR"
fi
# A signal while render makes its staging directory is held off until the
# directory is recorded for cleanup, so it is never left behind.
ready
mkdir -p "$SCRATCH/mkstub$n"
printf '#!/bin/sh\ncase "$*" in *.widget.render.*) kill -s TERM "$PPID" ;; esac\nexec %s "$@"\n' \
  "$(command -v mkdir)" >"$SCRATCH/mkstub$n/mkdir"
chmod +x "$SCRATCH/mkstub$n/mkdir"
OUT=$(cd "$R" && PATH="$SCRATCH/mkstub$n:$PATH" bin/render widget 2>&1)
ST=$?
assert_eq "" "$(entries "$ROOT" | grep '^\.widget\.render\.')" "a signal while render makes its staging directory leaves none"
# Every signal render traps is held off during the renames: each sent in
# turn, in one render, any not held would end it.
ready
# The set is worked out here from kill -l, outside POSIX mode, as discard.sh
# does from trap -l: every signal listed but those whose default action never
# ends a process.
kills=""
for w in $(kill -l); do
  case "$w" in
    *')') num=${w%')'} ;;
    SIG*)
      case "${w#SIG}" in
        CHLD | CLD | CONT | STOP | TSTP | TTIN | TTOU | URG | WINCH | INFO | KILL) ;;
        *) kills="$kills kill -$num \"\$PPID\";" ;;
      esac
      ;;
  esac
done
mvstub "  *.widget.render.*)$kills ;;"
mvstubbed widget
assert_status 0 "$ST" "every signal render traps, sent during the renames, is held off"
assert_eq "$ROOT/widget" "$(record widget target)" "  and render.md is written"
# In any shell mode (render R1 of S2's fourth ship gate): with POSIXLY_CORRECT
# set, where kill -l prints bare names, the set is whole, so the same render
# holds every signal off, and --replace --remove runs as it does without it.
ready
mvstub "  *.widget.render.*)$kills ;;"
OUT=$(cd "$R" && export POSIXLY_CORRECT=1 && PATH="$SCRATCH/mstub$n:$PATH" bin/render widget 2>&1)
assert_status 0 "$?" "with POSIXLY_CORRECT set, every signal sent during the renames is held off${OUT:+ ($OUT)}"
assert_eq "$ROOT/widget" "$(record widget target)" "  and render.md is written"
OUT=$(cd "$R" && export POSIXLY_CORRECT=1 && bin/render widget --replace --remove "$ROOT/widget" 2>&1)
assert_status 0 "$?" "with POSIXLY_CORRECT set, --replace --remove renders again${OUT:+ ($OUT)}"
assert_eq "present" "$(gone "$ROOT/widget/README.md")" "  into the target"
# A shell whose signal list gives no set, or one lacking HUP, INT or TERM,
# is refused, exit 2, before render makes anything: no private directory,
# no output folder, no target. A trap exported as a function stands in for
# the shell's own list.
for LISTING in '' ' 1) SIGHUP	 2) SIGINT'; do
  ready
  mkdir -p "$SCRATCH/tmpd$n"
  OUT=$(
    cd "$R" &&
      trap() { if [ "${1:-}" = -l ]; then printf '%s' "$LISTING"; else builtin trap "$@"; fi; } &&
      export -f trap && TMPDIR="$SCRATCH/tmpd$n" bin/render widget 2>&1
  )
  assert_status 2 "$?" "refused: render where the signals to hold give the set \"$LISTING\""
  assert_contains "$OUT" "cannot work out the signals to hold off" "  and the refusal says so"
  assert_eq "gone gone " "$(gone "$ROOT/widget") $(gone "$R/stages/02-render/output/widget") $(ls -A "$SCRATCH/tmpd$n")" \
    "  and nothing is made"
done
if [ "$(id -u)" != 0 ]; then
  ready
  mkdir -p "$ROOT/widget"
  chmod 555 "$ROOT/widget"
  render widget
  assert_status 0 "$ST" "an empty target render cannot write into is replaced"
  assert_eq "present" "$(gone "$ROOT/widget/README.md")" "  by the render"
  ready
  mkdir -p "$ROOT"
  chmod 555 "$ROOT"
  render widget
  chmod 755 "$ROOT"
  assert_status 1 "$ST" "refused: a TARGET_ROOT render cannot write into"
  assert_contains "$OUT" "cannot make the staging directory" "  and the refusal says why"
  assert_eq "" "$(left)" "  with nothing written"
  ready
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

# --- what the foundation may hold (R3, F5) ----------------------------------------------------
# A selected path comes only from its variants.
fresh
git -C "$R" rm -q foundation/LICENSE.apache-2.0 foundation/LICENSE.none.tmpl
put foundation/LICENSE 'A plain licence.'
fixture_commit "$R" "test: a plain file at a selected path, with no variant"
confirmed widget
refused "a plain file at a selected path, with no variant" "LICENSE is a selected path" widget
fresh
git -C "$R" rm -q foundation/LICENSE.apache-2.0 foundation/LICENSE.none.tmpl
put foundation/LICENSE.tmpl 'A plain licence, {{HOLDER}}.'
fixture_commit "$R" "test: a template at a selected path, with no variant"
confirmed widget
refused "a template at a selected path, with no variant" "LICENSE is a selected path" widget
# Case-only twins, refused before anything is written: planted in the
# index, since a disk that folds case cannot hold both.
twin() { # PATH MODE [TEXT]: add PATH, a file or a link to TEXT, to HEAD
  local blob
  blob=$(printf '%s' "${3:-twin}" | git -C "$R" hash-object -w --stdin) &&
    git -C "$R" update-index --add --cacheinfo "$2,$blob,$1" &&
    git -C "$R" commit -q -m "test: $1"
}
fresh
twin foundation/readme.md 100644
confirmed widget
refused "a file whose path differs from another's only in case" \
  "foundation renders README.md and readme.md, which differ only in case" widget
assert_eq "" "$(left)" "  with nothing written"
fresh
twin foundation/license 100644
confirmed widget
refused "a file whose path differs only in case from a selected path" \
  "foundation renders LICENSE and license, which differ only in case" widget
fresh
mkdir -p "$SCRATCH/outside$n"
printf 'kept\n' >"$SCRATCH/outside$n/x"
twin foundation/Lnk 120000 "$SCRATCH/outside$n"
twin foundation/lnk/x 100644
confirmed widget
refused "a link and a directory that differ only in case" "differ only in case" widget
assert_eq "kept" "$(cat "$SCRATCH/outside$n/x")" "  and nothing is written through the link"
# Only portable paths (decision 224), so the ASCII twin check is complete: a
# foundation path holding anything but ASCII letters, digits, ., _, -, / and
# space is refused before anything is written, as twins a disk folds by
# Unicode, a link Ä to outside and a file ä/x (render F5).
fresh
mkdir -p "$SCRATCH/outside$n"
printf 'kept\n' >"$SCRATCH/outside$n/x"
twin "$(printf 'foundation/\303\204')" 120000 "$SCRATCH/outside$n"
twin "$(printf 'foundation/\303\244/x')" 100644
confirmed widget
refused "a link and a directory whose names are outside the portable set" "outside the portable set" widget
assert_contains "$OUT" "$(printf 'foundation/\303\204')" "  naming the path"
assert_eq "kept" "$(cat "$SCRATCH/outside$n/x")" "  and nothing is written through the link"
assert_eq "x" "$(entries "$SCRATCH/outside$n")" "  or beside it"
assert_eq "" "$(left)" "  and nothing of the run is left"
for bad in 'a+b.md' 'a:b.md' "$(printf 'caf\303\251.md')" 'dir/a~b.md'; do
  fresh
  twin "foundation/$bad" 100644
  confirmed widget
  refused "a foundation path holding a character outside the portable set: $bad" "foundation/$bad" widget
  assert_eq "" "$(left)" "  with nothing written"
done
fresh
twin 'foundation/a b_c-d.e.md' 100644
confirmed widget
render widget
assert_status 0 "$ST" "a foundation path of letters, a space, _, - and . renders"
# A template with CRLF line endings repeats its list line per item, each
# item's line ending CRLF too.
fresh
put foundation/crlf-list.md.tmpl "$(printf 'Deciders:\r\n- {{PEOPLE}}\r\nEnd.\r')"
fixture_commit "$R" "test: a CRLF template with a list line"
confirmed widget
render widget
assert_eq "$(printf 'Deciders:\r\n- A Person\r\n- B Person\r\nEnd.\r')" "$(cat "$ROOT/widget/crlf-list.md")" \
  "a CRLF list line is repeated per item, each line ending CRLF"
# A template's last line ends as the template's does, judged by its bytes,
# which $(cat) would strip (the tests lens's F1).
fresh
printf 'Held by {{HOLDER}}.\n' >"$R/foundation/ends.md.tmpl"
printf 'Held by {{HOLDER}}.' >"$R/foundation/open.md.tmpl"
printf 'Line\n\n' >"$R/foundation/blank.md.tmpl"
fixture_commit "$R" "test: templates ending with and without a newline"
confirmed widget
render widget
assert_eq "$(printf 'Held by Okja-Engineering.\n' | od -An -tx1)" "$(od -An -tx1 <"$ROOT/widget/ends.md")" \
  "a template ending in a newline renders ending in one"
assert_eq "$(printf 'Held by Okja-Engineering.' | od -An -tx1)" "$(od -An -tx1 <"$ROOT/widget/open.md")" \
  "  and one ending without renders without"
assert_eq "$(printf 'Line\n\n' | od -An -tx1)" "$(od -An -tx1 <"$ROOT/widget/blank.md")" \
  "  and one ending in a blank line keeps it"
# A render that fails partway, exit 2 in render_tree, leaves no temporary
# directory.
ready
mkdir -p "$SCRATCH/gstub$n"
printf '#!/bin/sh\ncase "$*" in *"cat-file blob"*foundation/*) exit 1 ;; esac\nexec %s "$@"\n' "$(command -v git)" \
  >"$SCRATCH/gstub$n/git"
chmod +x "$SCRATCH/gstub$n/git"
mkstub "$SCRATCH/gstub$n"
OUT=$(cd "$R" && PATH="$SCRATCH/gstub$n:$PATH" bin/render widget 2>&1)
assert_status 1 "$?" "refused: a foundation file git cannot read"
assert_contains "$OUT" "cannot read foundation/ at HEAD" "  as a read that failed partway"
assert_eq "yes" "$([ -s "$SCRATCH/made$n" ] && echo yes)" "  having made temporary files"
assert_eq "" "$(leftover)" "  and leaves none of them"
# A staging directory a killed render left, by its own staging name for this
# run, is removed before staging, also when it holds a chmod 000 directory;
# nothing else beside the target is touched (decision 226).
ready
mkdir -p "$ROOT/.widget.render.4242/a/b" "$ROOT/.widget.render.17" "$ROOT/.widget.render.x1" \
  "$ROOT/.other.render.5" "$ROOT/.widget.render.6.extra"
printf 'half\n' >"$ROOT/.widget.render.4242/a/b/README.md"
printf 'kept\n' >"$ROOT/.widget.render.99"
mkdir -p "$SCRATCH/outside$n"
printf 'kept\n' >"$SCRATCH/outside$n/x"
ln -s "$SCRATCH/outside$n" "$ROOT/.widget.render.55"
chmod 000 "$ROOT/.widget.render.4242/a/b" "$ROOT/.widget.render.4242/a"
render widget
assert_status 0 "$ST" "a render with a killed render's staging directories beside its target"
assert_eq "gone gone" "$(gone "$ROOT/.widget.render.4242") $(gone "$ROOT/.widget.render.17")" \
  "  removes them, the chmod 000 one whole"
assert_eq "present present present present present" \
  "$(gone "$ROOT/.widget.render.x1") $(gone "$ROOT/.other.render.5") $(gone "$ROOT/.widget.render.6.extra") $(gone "$ROOT/.widget.render.99") $(gone "$ROOT/.widget.render.55")" \
  "  and nothing else: another name, another run's, a file and a symbolic link to a directory"
assert_eq "kept" "$(cat "$SCRATCH/outside$n/x")" "  nor anything through the link"
assert_eq "present" "$(gone "$ROOT/widget/README.md")" "  and renders"
# A leftover the removal helper cannot remove is refused, naming it, before
# anything is written.
ready
mkdir -p "$ROOT/.widget.render.4242" "$SCRATCH/stub$n"
rmstub .widget.render.4242
OUT=$(cd "$R" && PATH="$SCRATCH/stub$n:$PATH" bin/render widget 2>&1)
assert_status 1 "$?" "refused: a leftover staging directory that cannot be removed"
assert_contains "$OUT" "could not remove $ROOT/.widget.render.4242" "  and the refusal names it"
assert_eq "gone gone" "$(gone "$ROOT/widget") $(gone "$R/stages/02-render/output/widget/render.md")" \
  "  with nothing written"
# p24: a TARGET_ROOT the sweep cannot list is refused, never read as
# holding no leftover (render R4 of S2's fourth ship gate).
if [ "$(id -u)" != 0 ]; then
  ready
  mkdir -p "$ROOT/.widget.render.4242"
  chmod 300 "$ROOT"
  render widget
  chmod 755 "$ROOT"
  assert_status 1 "$ST" "refused: a TARGET_ROOT the sweep cannot list"
  assert_contains "$OUT" "cannot list $ROOT" "  and the refusal says so"
  assert_eq "present gone" "$(gone "$ROOT/.widget.render.4242") $(gone "$ROOT/widget")" \
    "  with the leftover left and nothing written"
fi
# The worktree list's exit status is read.
ready
mkdir -p "$SCRATCH/gstub$n"
printf '#!/bin/sh\ncase "$*" in *"worktree list"*) exit 1 ;; esac\nexec %s "$@"\n' "$(command -v git)" >"$SCRATCH/gstub$n/git"
chmod +x "$SCRATCH/gstub$n/git"
stubbed widget
assert_status 1 "$ST" "refused: a worktree list that fails"
assert_contains "$OUT" "cannot list the workspace's worktrees" "  and the refusal says so"
assert_eq "" "$(left)" "  with nothing written"

# --- every stage a guard or record reads, its failure refused (decision 228) ----------------
# failing TOOL PATTERN [NTH] [SETUP] [STATUS]: a confirmed run rendered with
# a stub TOOL that fails, exiting STATUS, its NTH call matching PATTERN
# (fixture_failing); SETUP, when given and not empty, runs once the run is
# confirmed. stage_refused DESCRIPTION NEEDLE:
# the render refused, saying NEEDLE, what could not be done, with nothing of
# this run left, no target, no render.md, and its output folder as it was,
# none when render made it (conformance N7 of S2's third ship gate).
failing() {
  ready
  [ -z "${4:-}" ] || "$4"
  OUT02=$(gone "$R/stages/02-render/output/widget")
  fixture_failing "$SCRATCH/fail$n" "$1" "$2" "${3:-1}" "${5:-1}"
  OUT=$(cd "$R" && PATH="$SCRATCH/fail$n:$PATH" bin/render widget 2>&1)
  ST=$?
}
stage_refused() {
  assert_status 1 "$ST" "refused: $1"
  assert_contains "$OUT" "$2" "  saying: $2"
  assert_eq "" "$(left)" "  with nothing of this run left, no target and no render.md"
  assert_eq "${OUT02:-gone}" "$(gone "$R/stages/02-render/output/widget")" "  and its output folder as it was"
  OUT02=""
}
failing git '*ls-tree -r -z --full-tree *'
stage_refused "the listing of HEAD's tree fails" "cannot read foundation/ at HEAD"
failing cp '*/answers.env *'
stage_refused "the run's answers cannot be read" "cannot read stages/01-ask/output/widget/answers.env"
failing git '*hash-object*'
stage_refused "the run's answers cannot be hashed" "cannot hash stages/01-ask/output/widget/answers.env"
failing cp '-Rp *'
stage_refused "the render cannot be copied into its staging directory" "cannot copy the render into"
# Each private directory that cannot be made is refused, saying so, never
# read as a path under / (the tests lens's N13 and N14 of S2's third ship
# gate): render's own, its rendered foundation's, the walk's and the
# fingerprint's.
failing mkdir '*/out'
stage_refused "the rendered foundation's directory cannot be made" "cannot make a temporary directory"
assert_eq "bin/render: cannot make a temporary directory" "$OUT" "  and says only that"
for at in "2 cannot read foundation/ at HEAD" "3 the walk refuses the render:" "4 cannot fingerprint the render:"; do
  failing mktemp '-d *render.XXXXXX' "${at%% *}"
  stage_refused "the private directory of mktemp's call ${at%% *} cannot be made" "${at#* }"
  assert_contains "$OUT" "cannot make a temporary directory" "  and says it cannot make its directory"
done
ready
git -C "$R" update-ref -d refs/heads/main
render widget
stage_refused "a workspace with no commit at HEAD" "the workspace has no commit at HEAD"
failing awk '*$5 != "" { print $1*'
stage_refused "the selecting fields' awk fails" "cannot read the selecting fields"
failing awk '*p !~ /^\[A-Za-z0-9*'
stage_refused "the portability check fails" "cannot judge the foundation paths"
failing awk '*substr(p, 12)*'
stage_refused "the twin check's list of foundation paths fails" "cannot compare the paths for case twins"
failing cut '-f 2'
stage_refused "the twin check's list of selected paths fails" "cannot compare the paths for case twins"
failing awk '*for (i = 2; i <= NF*'
stage_refused "the twin check's directories fail" "cannot compare the paths for case twins"
failing awk '*{ l = tolower($0) } (l in seen)*'
stage_refused "the twin check's comparison fails" "cannot compare the paths for case twins"
# The twin check's sort -u, over case-only twins through a link to outside
# (conformance p3b of S2's second ship gate): refused before anything is
# written, through the link or otherwise.
outside_twins() {
  mkdir -p "$SCRATCH/outside$n"
  printf 'kept\n' >"$SCRATCH/outside$n/x"
  twin foundation/Lnk 120000 "$SCRATCH/outside$n"
  twin foundation/lnk/x 100644
}
failing sort '-u*' 1 outside_twins
stage_refused "the twin check's sort -u fails, over case twins" "cannot compare the paths for case twins"
assert_eq "kept" "$(cat "$SCRATCH/outside$n/x")" "  and nothing is written through the link"
failing awk '*$4 == "yes"*'
stage_refused "the render fields' awk fails" "cannot read the render fields"
# Each value read from the answers, by answers_get's awk, in the order render
# reads them: NAME first; then TARGET and TARGET_ROOT; then the one
# selecting field, LICENSE; then the first render field.
failing awk '*!found && i > 1*' 1
stage_refused "the read of NAME fails" "cannot read NAME"
failing awk '*!found && i > 1*' 4
stage_refused "the read of a selecting field's value fails" "cannot read the selecting fields"
failing awk '*!found && i > 1*' 5
stage_refused "the read of a render field's value fails" "cannot read the render fields"
failing tail '-c 1 *'
stage_refused "a template's last byte cannot be read" "cannot read foundation/"
# Each read of a file's bytes from HEAD: a template, a verbatim file, a link.
failing git 'cat-file blob *:foundation/README.md.tmpl'
stage_refused "a template's bytes cannot be read" "cannot read foundation/ at HEAD"
failing git 'cat-file blob *:foundation/tool'
stage_refused "a verbatim file's bytes cannot be read" "cannot read foundation/ at HEAD"
failing git 'cat-file blob *:foundation/readme-link'
stage_refused "a link's target cannot be read" "cannot read foundation/ at HEAD"
failing git '-C * rev-parse --show-toplevel'
stage_refused "the workspace's working tree cannot be found" "cannot find the workspace's working tree"
# Every argument-less sort, in order: the file list, then the walk's have and
# want (render p07 and conformance p3 of S2's second ship gate).
failing sort '' 1
stage_refused "the file list's sort fails" "cannot sort the file list"
failing sort '' 2
stage_refused "the walk's sort of what the target holds fails" "the walk cannot sort"
failing sort '' 3
stage_refused "the walk's sort of the file list fails" "the walk cannot sort"
failing sed '-n s/^F//p *'
stage_refused "the walk's list of files fails" "the walk cannot sort"
failing sed '-n s/^D//p *'
stage_refused "the walk's list of directories fails" "the walk cannot judge the directories"
failing tr '\\n \\0'
stage_refused "the fingerprint's path list fails" "cannot list the paths to fingerprint"
# grep's 1 is "none found"; a grep that cannot read a list exits 2, which
# the walk never reads as none.
failing grep '-q ^G *' 1 "" 2
stage_refused "the walk's look for a .git entry fails" "the walk cannot read its lists of the target"
failing grep '-qx N *' 1 "" 2
stage_refused "the walk's look for a name with a newline fails" "the walk cannot read its lists of the target"
# Every lookup whose 1 is "none", failing with a higher status, refuses,
# saying what it could not read, never reading it as none (decision 228):
# HEAD's commit, its schema, confirmed.md's blob id, the selected paths,
# the paths rendered so far, a placeholder left, and the walk's directories.
failing git 'rev-parse -q --verify HEAD^{commit}' 1 "" 128
stage_refused "HEAD cannot be read" "cannot read the workspace's HEAD"
failing git 'cat-file -t *:shared/answers.tsv' 1 "" 128
stage_refused "HEAD's schema cannot be read" "cannot read shared/answers.tsv at HEAD"
failing awk '*ENVIRON\["K"]*confirmed.md' 1 "" 2
stage_refused "confirmed.md's blob id cannot be read" "cannot read stages/01-ask/output/widget/confirmed.md"
failing grep '-Fxq -e README.md' 1 "" 2
stage_refused "the look up of the selected paths fails" "cannot look up the selected paths"
failing grep '-Fxq -e README.md' 2 "" 2
stage_refused "the look for a second source fails" "cannot look up the paths rendered so far"
failing grep '-Fxq -e LICENSE' 2 "" 2
stage_refused "the look for a selected path's variant fails" "cannot look up the paths rendered"
failing grep '-Eq \[{]\[{]*' 1 "" 2
stage_refused "the look for a placeholder left fails" "cannot look for a placeholder left in"
failing awk '*{ found = 1; exit } END { exit !found }*' 1 "" 2
stage_refused "the walk's look for a directory's listed file fails" "the walk cannot judge the directories"
# render.md's record, read by the discard, failing: refused, saying so,
# with the target and render.md left.
ready
render widget
fixture_failing "$SCRATCH/rec$n" awk '*ENVIRON\["K"]*render.md' 1 2
OUT=$(cd "$R" && PATH="$SCRATCH/rec$n:$PATH" bin/render widget --replace --remove "$ROOT/widget" 2>&1)
assert_status 1 "$?" "refused: --replace --remove whose render.md cannot be read"
assert_contains "$OUT" "cannot read stages/02-render/output/widget/render.md" "  and the refusal says so"
assert_eq "present present" "$(gone "$ROOT/widget/README.md") $(gone "$R/stages/02-render/output/widget/render.md")" \
  "  with the target and render.md left"
kept_target() { mkdir -p "$ROOT/widget/kept"; }
failing ls '-A -- *' 1 kept_target
assert_status 1 "$ST" "refused: the listing of a present target fails"
assert_contains "$OUT" "the target $ROOT/widget is present" "  judged present, never empty"
assert_eq "present" "$(gone "$ROOT/widget/kept")" "  and it is left alone"

# --- each refusal reached, and each path rendered as it must be (T3, T6) ---------------------
# A render.md that names no target.
ready
render widget
printf '%s\n' '# Render of widget' '' 'fingerprint: x' >"$R/stages/02-render/output/widget/render.md"
refused "--replace when render.md names no target" "render.md names no target" widget --replace
# The record judged before render.md is removed, whatever the target's
# state: one naming no target, its target moved away (removal M1 of S2's
# third ship gate); one naming a present target that is not the run's,
# TARGET_ROOT and TARGET edited by hand and confirmed (its M2). Each is
# refused, with render.md and the target it names left.
mv "$ROOT/widget" "$ROOT/moved"
render widget --replace
assert_status 1 "$ST" "refused: --replace when render.md names no target, its target gone"
assert_contains "$OUT" "render.md names no target" "  and the refusal says so"
assert_eq "present" "$(gone "$R/stages/02-render/output/widget/render.md")" "  and render.md is left"
ready
render widget
sed -e "s|^TARGET_ROOT=.*|TARGET_ROOT=$ROOT/b|" -e "s|^TARGET=.*|TARGET=$ROOT/b/widget|" \
  "$R/stages/01-ask/output/widget/answers.env" >"$SCRATCH/edited$n"
mv "$SCRATCH/edited$n" "$R/stages/01-ask/output/widget/answers.env"
ask confirm widget --by 'A Person'
render widget --replace
assert_status 1 "$ST" "refused: --replace when render.md names a present target that is not the run's"
assert_contains "$OUT" "render.md names $ROOT/widget, not the run's target $ROOT/b/widget" "  with the discard's reason"
assert_eq "present present gone" \
  "$(gone "$ROOT/widget/README.md") $(gone "$R/stages/02-render/output/widget/render.md") $(gone "$ROOT/b/widget")" \
  "  and the target it names, and render.md, are left, and nothing is rendered"
mv "$ROOT/widget" "$ROOT/moved"
render widget --replace
assert_status 0 "$ST" "--replace when render.md names a target that is gone, which no removal orphans"
assert_eq "$ROOT/b/widget" "$(record widget target)" "  records the new target"
# A present target that only looks empty: unreadable, or a link to an empty
# directory. Each is refused with the route, and left.
if [ "$(id -u)" != 0 ]; then
  ready
  mkdir -p "$ROOT/widget/kept"
  chmod 000 "$ROOT/widget"
  refused "an unreadable target holding a directory" "--replace --remove" widget
  chmod 755 "$ROOT/widget"
  assert_eq "present" "$(gone "$ROOT/widget/kept")" "  and it is left whole"
fi
ready
mkdir -p "$ROOT" "$SCRATCH/emptydir$n"
ln -s "$SCRATCH/emptydir$n" "$ROOT/widget"
refused "a symbolic link to an empty directory at the target" "it is a symbolic link, not the rendered target" widget
assert_not_contains "$OUT" "--remove \"" "  with no route to a --remove the discard would refuse"
assert_eq "yes" "$([ -L "$ROOT/widget" ] && echo yes)" "  and the link is left"
assert_eq "" "$(entries "$SCRATCH/emptydir$n")" "  and nothing is written through it"
# A directory named like a variant is not one: its files are verbatim.
fresh
put foundation/LICENSE.extra/notes.md 'Notes.'
fixture_commit "$R" "test: a directory named like a variant"
confirmed widget
render widget
assert_status 0 "$ST" "a directory named like a variant renders"
assert_eq "Notes." "$(cat "$ROOT/widget/LICENSE.extra/notes.md" 2>/dev/null)" "  its files copied verbatim"
# Render's file list is sorted: doc.md, then doc.tmpl's doc, in tree order,
# are doc and doc.md in the list git builds the fingerprint from.
# The same render holds the edges of a file's bytes: a link whose target
# ends in x, an empty template, and a `- {{FIELD}}` line whose field is text,
# not a list. It runs under an operator's git environment that would make
# sha256 repositories from a template ignoring every path; the fingerprint is
# still the sha1 tree id.
fresh
put foundation/doc.md 'Doc.'
put foundation/doc.tmpl '{{NAME}}'
ln -s box "$R/foundation/box-link"
: >"$R/foundation/empty.md.tmpl"
put foundation/holder.md.tmpl '- {{HOLDER}}'
fixture_commit "$R" "test: a file and a template whose names sort apart"
confirmed widget --setup-override 'HOLDER=Acme, Inc'
mkdir -p "$SCRATCH/tpl$n/info"
printf '*\n' >"$SCRATCH/tpl$n/info/exclude"
OUT=$(cd "$R" && GIT_DEFAULT_HASH=sha256 GIT_TEMPLATE_DIR="$SCRATCH/tpl$n" bin/render widget 2>&1)
ST=$?
assert_status 0 "$ST" "a file and a template whose rendered names sort apart render"
assert_eq "doc
doc.md" "$(grep -E -x 'doc|doc\.md' "$R/stages/02-render/output/widget/render.md")" \
  "  and render.md lists them sorted"
assert_eq "box" "$(readlink "$ROOT/widget/box-link")" "a link's target ending in x is kept whole"
assert_eq "0" "$(wc -c <"$ROOT/widget/empty.md" | tr -d ' ')" "an empty template renders empty"
assert_eq "- Acme, Inc" "$(cat "$ROOT/widget/holder.md")" "a '- {{TEXT}}' line is not split at its commas"
assert_eq "$(tree_id "$ROOT/widget")" "$(record widget fingerprint)" \
  "the fingerprint is the sha1 tree id under an operator's sha256 default and template"
# Two sources for one path: a file and a template that renders to it.
fresh
put foundation/doc.md 'Doc.'
put foundation/doc.md.tmpl '{{NAME}}'
fixture_commit "$R" "test: a file and a template for the same path"
confirmed widget
refused "a file and a template for the same path" "foundation/doc.md.tmpl: a second source for doc.md" widget

# --- each name render produces (render N4 of S2's third ship gate) ----------------------------
# A non-empty final component, never .git in any case; an authoring error
# is a refusal, 1, with nothing written.
for case in '.GIT.tmpl:renders .GIT, an entry named .git' '.git.tmpl:renders .git, an entry named .git' \
  'sub/.Git.tmpl:renders sub/.Git, an entry named .git' '.tmpl:renders no name' 'sub/.tmpl:renders no name'; do
  file=${case%%:*}
  fresh
  put "foundation/$file" 'x'
  fixture_commit "$R" "test: foundation/$file"
  confirmed widget
  refused "foundation/$file" "foundation/$file: ${case#*:}" widget
done

# --- render's private directory, render.md's temporary file and its last line --------------------
# A relative TMPDIR: the private directory is still absolute, so render
# runs and leaves nothing there (render N2).
ready
mkdir -p "$R/reltmp$n"
OUT=$(cd "$R" && TMPDIR="reltmp$n" bin/render widget 2>&1)
assert_status 0 "$?" "render under a relative TMPDIR"
assert_eq "" "$(entries "$R/reltmp$n")" "  leaves nothing in it"
# Its last line, written once the render is done, cannot turn it into a
# refusal: with standard output closed, it exits 0.
ready
(cd "$R" && exec bin/render widget >&- 2>/dev/null)
assert_status 0 "$?" "render with standard output closed, once the render is done"
assert_eq "$ROOT/widget" "$(record widget target)" "  and render.md is written"
# render.md's text, written to its temporary file, is checked: a write that
# fails refuses, so no partial render.md is recorded (render N6's v03).
ready
waitstub cp '-Rp *'
(cd "$R" && PATH="$SCRATCH/wstub$n:$PATH" exec bin/render widget >"$SCRATCH/out$n" 2>&1) &
pid=$!
i=0
while [ ! -e "$SCRATCH/at$n" ] && [ "$i" -lt 120 ] && kill -0 "$pid" 2>/dev/null; do sleep 1 && i=$((i + 1)); done
for t in "$R/stages/02-render/output/widget/render.md.tmp."*; do rm -f "$t" && mkdir "$t"; done
: >"$SCRATCH/go$n"
wait "$pid"
assert_status 1 "$?" "refused: a render.md text that cannot be written"
assert_contains "$(cat "$SCRATCH/out$n")" "cannot write" "  and the refusal says so"
assert_eq "gone gone" "$(gone "$ROOT/widget") $(gone "$R/stages/02-render/output/widget/render.md")" \
  "  with no target and no render.md"
# The sweep keeps a staging name with no process id, which no render makes
# (render N6's v01), and sweeps under a TARGET_ROOT holding a space and
# glob characters (removal M6's d14).
ready
mkdir -p "$ROOT/.widget.render." "$ROOT/.widget.render.4242"
render widget
assert_eq "present gone" "$(gone "$ROOT/.widget.render.") $(gone "$ROOT/.widget.render.4242")" \
  "the sweep keeps .widget.render., with no process id, and removes .widget.render.4242"
fresh
GROOT="$SCRATCH/a [b]* c$n"
confirmed widget --setup-override "TARGET_ROOT=$GROOT"
mkdir -p "$GROOT/.widget.render.4242"
render widget
assert_status 0 "$ST" "render under a TARGET_ROOT holding a space and glob characters"
assert_eq "gone present" "$(gone "$GROOT/.widget.render.4242") $(gone "$GROOT/widget/README.md")" \
  "  sweeps its leftover staging directory, and renders"
# A dangling symbolic link at render.md is not a file (render N6's v02).
ready
mkdir -p "$R/stages/02-render/output/widget"
ln -s "$SCRATCH/nowhere$n" "$R/stages/02-render/output/widget/render.md"
refused "a dangling symbolic link at render.md" "render.md is not a file" widget

# --- TARGET_ROOT outside every working tree of the workspace ----------------------------------
# The root rule is the one target rule's (decision 227): bin/ask run
# refuses such a root before it writes the answers, and render refuses
# answers edited by hand to one, confirmed again.
# outside_refused DESCRIPTION NEEDLE ROOT [DIR]: a run whose TARGET_ROOT is
# ROOT, asked from the workspace DIR (R by default), is refused before
# anything is written.
outside_refused() {
  local what=$1 needle=$2 troot=$3 dir=${4:-$R}
  OUT=$(cd "$dir" && bin/ask run widget 'DESCRIPTION=One line' --setup-override "TARGET_ROOT=$troot" 2>&1)
  ST=$?
  assert_status 1 "$ST" "refused: a TARGET_ROOT $what"
  assert_contains "$OUT" "$needle" "  and the refusal says: $needle"
  assert_eq "gone gone" "$(gone "$troot/widget") $(gone "$dir/stages/01-ask/output/widget/answers.env")" \
    "  and nothing is written"
}
ready
A="$R/stages/01-ask/output/widget/answers.env"
sed -e "s|^TARGET_ROOT=.*|TARGET_ROOT=$R/inside|" -e "s|^TARGET=.*|TARGET=$R/inside/widget|" "$A" >"$SCRATCH/ans$n"
mv "$SCRATCH/ans$n" "$A"
printf '%s\n' '# Confirmed: widget' '' 'by: A Person' 'at: 2026-01-01T00:00:00Z' \
  "answers: $(git hash-object -t blob --no-filters --stdin <"$A")" >"$R/stages/01-ask/output/widget/confirmed.md"
render widget
assert_status 1 "$ST" "refused: render of answers edited by hand to a TARGET_ROOT inside the workspace"
assert_contains "$OUT" "under $R, a working tree" "  and the refusal says so"
assert_eq "gone" "$(gone "$R/inside")" "  and nothing is written"
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
rm -f "$R/setup/given.env"
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

# The target rule judges the target, not only its root (removal N1 of S2's
# fourth ship gate): no derived target is a working tree of the workspace,
# or holds one, so render and ask refuse it, no route names it to
# --remove, and the discard takes none.
# tree_refused DESCRIPTION TARGET KEPT: render, its --replace --remove, and
# a redo --remove of TARGET each refuse it, and the file KEPT, uncommitted
# in a working tree, is left.
tree_refused() {
  local what=$1 tgt=$2 kept=$3
  render widget
  assert_status 1 "$ST" "refused: a render whose target $what"
  assert_contains "$OUT" "TARGET $tgt is at or above" "  and the refusal names the target"
  assert_contains "$OUT" "a working tree of this workspace" "  and the working tree"
  render widget --replace --remove "$tgt"
  assert_status 1 "$ST" "refused: --replace --remove naming a target that $what"
  assert_contains "$OUT" "a working tree of this workspace" "  and the refusal says so"
  OUT=$(cd "$R" && bin/ask run widget --redo --remove "$tgt" 'DESCRIPTION=Other' 2>&1)
  assert_status 1 "$?" "refused: a redo --remove naming a target that $what"
  assert_contains "$OUT" "a working tree of this workspace" "  and the refusal says so"
  assert_eq "present" "$(gone "$kept")" "  and the working tree is left whole"
}
ready
git -C "$R" worktree add -q "$ROOT/widget" -b wtat$n 2>/dev/null
printf 'precious\n' >"$ROOT/widget/uncommitted"
tree_refused "is a linked worktree of the workspace" "$ROOT/widget" "$ROOT/widget/uncommitted"
ready
mkdir -p "$ROOT/widget"
git -C "$R" worktree add -q "$ROOT/widget/inner" -b wtin$n 2>/dev/null
printf 'precious\n' >"$ROOT/widget/inner/uncommitted"
tree_refused "holds a linked worktree of the workspace" "$ROOT/widget" "$ROOT/widget/inner/uncommitted"
fresh
git -C "$R" worktree add -q "$ROOT/widget" -b wtnew$n 2>/dev/null
OUT=$(cd "$R" && bin/ask run widget 'DESCRIPTION=One line' 2>&1)
assert_status 1 "$?" "refused: a run whose new target is a linked worktree of the workspace"
assert_contains "$OUT" "TARGET $ROOT/widget is at or above" "  and the refusal says so"
assert_contains "$OUT" "give TARGET_ROOT again" "  naming the way out"
assert_eq "gone" "$(gone "$R/stages/01-ask/output/widget/answers.env")" "  and nothing is written"
# r02: TARGET_ROOT the workspace's parent, NAME the workspace's folder: the
# root passes, the target is the workspace itself.
fresh
OUT=$(cd "$R" && bin/ask run "ws$n" 'DESCRIPTION=One line' --setup-override "TARGET_ROOT=$SCRATCH" 2>&1)
assert_status 1 "$?" "refused: a run whose target is the workspace itself"
assert_contains "$OUT" "TARGET $SCRATCH/ws$n is at or above" "  and the refusal says so"
assert_eq "gone" "$(gone "$R/stages/01-ask/output/ws$n")" "  and nothing is written"
(cd "$R" && bin/ask run "ws$n" 'DESCRIPTION=One line' >/dev/null 2>&1)
A="$R/stages/01-ask/output/ws$n/answers.env"
sed -e "s|^TARGET_ROOT=.*|TARGET_ROOT=$SCRATCH|" -e "s|^TARGET=.*|TARGET=$SCRATCH/ws$n|" "$A" >"$SCRATCH/ans$n"
mv "$SCRATCH/ans$n" "$A"
OUT=$(cd "$R" && bin/ask confirm "ws$n" --by 'A Person' 2>&1)
assert_status 1 "$?" "refused: confirm of answers edited by hand to the workspace as the target"
assert_contains "$OUT" "a working tree of this workspace" "  and the refusal says so"
OUT=$(cd "$R" && bin/ask run "ws$n" --redo --remove "$R" 'DESCRIPTION=Other' 2>&1)
assert_status 1 "$?" "refused: a redo --remove naming the workspace"
assert_contains "$OUT" "a working tree of this workspace" "  and the refusal says so"
OUT=$(cd "$R" && bin/ask run "ws$n" --redo 'DESCRIPTION=Other' --setup-override "TARGET_ROOT=$SCRATCH" 2>&1)
assert_status 1 "$?" "refused: a redo keeping the workspace as its target"
assert_contains "$OUT" "give TARGET_ROOT again" "  naming the way out"
assert_not_contains "$OUT" "--remove" "  never --remove"
assert_eq "present present" "$(gone "$R/.git") $(gone "$A")" "  and the workspace is left whole"
OUT=$(cd "$R" && bin/ask run "ws$n" --redo 'DESCRIPTION=Other' 2>&1)
assert_status 0 "$?" "  and a redo under setup's TARGET_ROOT, the way out, takes it${OUT:+ ($OUT)}"
assert_eq "TARGET=$ROOT/ws$n" "$(grep '^TARGET=' "$A")" "  writing a target outside the workspace"

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
printf 'x' >"$W/d/.GIT"
walk_case "a .git in another case, which a disk folding case opens as .git" "holds d/.GIT, an entry named .git"
# An empty list, on an empty target, passes the walk and fingerprints as the
# empty tree (render N6's v04 and v05 of S2's third ship gate).
rm -rf "$W" && mkdir -p "$W"
OUT=$(render_walk "$W" "" 2>&1)
assert_status 0 "$?" "the walk passes an empty target against an empty list"
OUT=$(render_fingerprint "$W" "" 2>&1)
assert_status 0 "$?" "the fingerprint of an empty target and list"
assert_eq "4b825dc642cb6eb9a060e54bf8d69288fbee4904" "$OUT" "  is the empty tree"
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
# fingerprint, and the workspace's .git as it was.
ready
render widget
BASE=$(record widget fingerprint)
# objects: every entry of the workspace's .git, by name, and every file's
# bytes, so a render that writes anything there is seen (render N6).
objects() { (cd "$R/.git" && find . | LC_ALL=C sort && find . -type f -exec cksum {} + | LC_ALL=C sort); }
planted() {
  local what=$1 before
  shift
  before=$(objects)
  OUT=$(cd "$R" && env "$@" bin/render widget --replace --remove "$ROOT/widget" 2>&1)
  ST=$?
  assert_status 0 "$ST" "render with $what planted"
  assert_eq "$BASE" "$(record widget fingerprint)" "  gives the baseline fingerprint"
  assert_eq "$before" "$(objects)" "  and the workspace's .git is as it was, every entry and byte"
}
mkdir -p "$SCRATCH/xdg/git" "$SCRATCH/tpl/info"
printf '.claude/\nbin/\ntool\n' >"$SCRATCH/excludes"
printf '[core]\n\texcludesFile = %s\n\tfileMode = false\n\tautocrlf = true\n[commit]\n\tgpgsign = true\n' \
  "$SCRATCH/excludes" >"$SCRATCH/global.gitconfig"
planted "a global config excluding .claude/ and bin/, core.fileMode=false and commit.gpgsign=true" \
  "GIT_CONFIG_GLOBAL=$SCRATCH/global.gitconfig"
printf '.claude/\nbin/\n' >"$SCRATCH/xdg/git/ignore"
planted "\$XDG_CONFIG_HOME/git/ignore" "XDG_CONFIG_HOME=$SCRATCH/xdg"
# The whole GIT_* namespace outside the recipe is neutralised (R4).
planted "GIT_ICASE_PATHSPECS=1" "GIT_ICASE_PATHSPECS=1"
planted "GIT_GLOB_PATHSPECS=1" "GIT_GLOB_PATHSPECS=1"
planted "GIT_TRACE=/dev/stdout" "GIT_TRACE=/dev/stdout"
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
# stale: a line render.md must lose, so a render.md left by an earlier run
# is not taken for this one's.
stale() { printf 'stale: yes\n' >>"$R/stages/02-render/output/widget/render.md"; }
# anew STATUS WHAT: the run exited 0 and wrote render.md, with the baseline.
anew() {
  assert_status 0 "$1" "render $2"
  assert_eq "" "$(grep '^stale:' "$R/stages/02-render/output/widget/render.md")" "  writes its own render.md"
  assert_eq "$BASE" "$(record widget fingerprint)" "  with the baseline fingerprint"
}
for env in "TZ=Asia/Tokyo" "LC_ALL=en_US.UTF-8" "TZ=UTC0"; do
  stale
  OUT=$(cd "$R" && env "$env" bin/render widget --replace --remove "$ROOT/widget" 2>&1)
  anew "$?" "with $env"
done
# A real HOME, holding a global config and attributes, with the suite's own
# isolation lifted: git would read them, and render does not.
mkdir -p "$SCRATCH/home/.config/git"
printf '.claude/\nbin/\n' >"$SCRATCH/home/excludes"
printf '[core]\n\tautocrlf = true\n\texcludesFile = %s\n' "$SCRATCH/home/excludes" >"$SCRATCH/home/.gitconfig"
printf '* text\n' >"$SCRATCH/home/.config/git/attributes"
assert_eq "true" "$(env -u GIT_CONFIG_GLOBAL -u XDG_CONFIG_HOME HOME="$SCRATCH/home" git config --get core.autocrlf)" \
  "a git run under that HOME reads its config"
stale
OUT=$(cd "$R" && env -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_NOSYSTEM -u GIT_ATTR_NOSYSTEM -u XDG_CONFIG_HOME \
  HOME="$SCRATCH/home" bin/render widget --replace --remove "$ROOT/widget" 2>&1)
anew "$?" "with a real HOME holding a global config and attributes"
stale
OUT=$(cd / && "$R/bin/render" widget --replace --remove "$ROOT/widget" 2>&1)
anew "$?" "run from another working directory"
stale
OUT=$(cd "$R" && umask 077 && bin/render widget --replace --remove "$ROOT/widget" 2>&1)
anew "$?" "under umask 077"
assert_eq "$(tree_id "$ROOT/widget")" "$(record widget fingerprint)" "  and it is still the target's tree id"
# shellcheck disable=SC2012 # ls shows the mode; stat's flags differ between BSD and GNU
assert_eq "-rwxr-xr-x -rw-r--r--" "$(ls -l "$ROOT/widget/tool" | cut -c1-10) $(ls -l "$ROOT/widget/README.md" | cut -c1-10)" \
  "  with each file's mode from the tree, not the umask"

# --- AC12: one field changes exactly the paths it reaches ------------------------------------------
# sums DIR: "PATH CKSUM" per file under DIR, a link by its text.
sums() {
  (cd "$1" && find . -mindepth 1 ! -type d | sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r p; do
    if [ -L "$p" ]; then
      printf '%s link %s\n' "$p" "$(readlink "$p")"
    else
      printf '%s %s %s\n' "$p" "$([ -x "$p" ] && echo x || echo -)" "$(cksum <"$p")"
    fi
  done)
}
changed() { # A B: the paths whose bytes differ, or that one of them lacks
  diff <(sums "$1") <(sums "$2") | sed -n 's/^[<>] \([^ ]*\) .*/\1/p' | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//'
}
# variant LICENSE FIELD=value...: widget run afresh with these answers and
# overrides alone under the LICENSE given, its old run and target removed,
# since a --redo keeps what it is not given (decision 229); rendered, and
# copied to $SCRATCH/v.
variant() {
  local lic=$1
  shift
  rm -rf "$(record widget target)" "$R/stages/01-ask/output/widget" "$R/stages/02-render/output/widget"
  ask run widget "DESCRIPTION=$DESC" "LICENSE=$lic" "$@" &&
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
  # OWNER is no render field, but HOLDER's default, {{OWNER}}, is worked out
  # again from the override, as setup works it out (decision 229), so it
  # reaches what HOLDER reaches.
  variant "$lic" --setup-override OWNER=acme
  if [ "$lic" = none ]; then want=LICENSE; else want=""; fi
  assert_eq "$want" "$(changed "$SCRATCH/base" "$SCRATCH/v")" \
    "LICENSE=$lic: OWNER, not a render field, changes only what HOLDER's default reaches: ${want:-nothing}"
  variant "$lic" VISIBILITY=private
  assert_eq "" "$(changed "$SCRATCH/base" "$SCRATCH/v")" "LICENSE=$lic: VISIBILITY, not a render field, changes nothing"
  variant "$lic" --setup-override "TARGET_ROOT=$SCRATCH/elsewhere$n"
  assert_eq "$SCRATCH/elsewhere$n/widget" "$(record widget target)" "LICENSE=$lic: TARGET_ROOT moves the target"
  assert_eq "" "$(changed "$SCRATCH/base" "$SCRATCH/v")" "  and, not a render field, changes nothing in it"
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
