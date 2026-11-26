#!/usr/bin/env bash
# The workspace's `disclosure` check (AC1-AC3): always-on budgets, the stage
# folders and routing table, contract shape, and Inputs discipline. One
# fixture case per refusal, each on an otherwise valid fixture workspace.
# shellcheck disable=SC2016 # backticks here are Markdown code spans, kept literal
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

put() {
  local f="$R/$1"
  shift
  mkdir -p "$(dirname "$f")" && printf '%s\n' "$@" >"$f"
}
pad_to() { # FILE LINES: append filler lines until FILE has LINES lines
  local have
  have=$(awk 'END { print NR }' "$R/$1")
  while [ "$have" -lt "$2" ]; do
    printf 'filler\n' >>"$R/$1"
    have=$((have + 1))
  done
}
# run [MODE...]: the check on R, its tree mode called directly, as bin/check
# would call it there (bin/check's own dispatch is test_check_cli's), and
# any other mode through bin/check.
run() {
  if [ "$#" = 0 ]; then
    OUT=$(cd "$R" && bin/checks/disclosure 2>&1)
  else
    OUT=$(cd "$R" && bin/check "$@" disclosure 2>&1)
  fi
  ST=$?
}
refused() { # DESCRIPTION NEEDLE
  run
  assert_status 1 "$ST" "refused: $1"
  assert_contains "$OUT" "$2" "  and the refusal says: $2"
}
passes() {
  run
  assert_status 0 "$ST" "passes: $1"
}

ROW1='| `stages/01-ask/` | [contract](stages/01-ask/CONTEXT.md) |'
ROW2='| `stages/02-render/` | [contract](stages/02-render/CONTEXT.md) |'
C1=stages/01-ask/CONTEXT.md
C2=stages/02-render/CONTEXT.md
# The one shape an Inputs section takes.
HEADER='| Source | File/Location | Section/Scope | Why |'
DELIM='|---|---|---|---|'

# empty: a fixture workspace with the agent files and no stage. valid: two
# stages, routed, with every optional section, an earlier stage's output as
# an input, and a named reference. Each is built once, by build_empty and
# build_valid, and copied for each case.
empty() { copy empty; }
valid() { copy valid; }
copy() { # KIND: the KIND fixture, built once, copied to a new R
  [ -d "$SCRATCH/$1" ] || {
    R="$SCRATCH/$1"
    "build_$1"
  }
  n=$((n + 1))
  R="$SCRATCH/ws$n"
  ws_copy "$SCRATCH/$1" "$R"
}
build_empty() {
  ws_fixture "$R"
  ws_real_check "$R" disclosure
  put CLAUDE.md '@AGENTS.md'
  put AGENTS.md '# A fixture workspace' '' 'Start from CONTEXT.md.'
  put CONTEXT.md '# On entry' '' '## Triggers' '' 'create: stage 01-ask.' '' \
    '## Routing' '' '| Stage | Contract |' '|---|---|'
  fixture_commit "$R" "test: an empty workspace"
}

build_valid() {
  build_empty
  put shared/answers.tsv 'field'
  printf '%s\n%s\n' "$ROW1" "$ROW2" >>"$R/CONTEXT.md"
  put "$C1" '# 01-ask' '' '## Inputs' '' "$HEADER" "$DELIM" \
    '| shared | `../../shared/answers.tsv` | all | the fields |' '' '## Process' '' 'Draft the answers.' '' \
    '## Checkpoints' '' 'The operator confirms.' '' '## Audit' '' 'Read the description.' '' \
    '## Outputs' '' '`answers.env`, `confirmed.md`'
  put stages/01-ask/output/.gitignore '*' '!.gitignore'
  put "$C2" '# 02-render' '' '## Inputs' '' "$HEADER" "$DELIM" \
    '| 01-ask | `../01-ask/output/<name>/confirmed.md` | all | the confirmed answers |' \
    '| this stage | `references/notes.md` | all | notes |' '' '## Process' '' 'Render.' '' '## Outputs' '' '`render.md`'
  put stages/02-render/output/.gitignore '*' '!.gitignore'
  put stages/02-render/references/notes.md 'notes'
  fixture_commit "$R" "test: a valid workspace"
}

# add_stage NAME: a further minimal stage, routed, otherwise valid.
add_stage() {
  put "stages/$1/CONTEXT.md" "# $1" '' '## Inputs' '' "$HEADER" "$DELIM" '' '## Process' '' 'Do it.' '' \
    '## Outputs' '' '`out.md`'
  put "stages/$1/output/.gitignore" '*' '!.gitignore'
  printf '| `stages/%s/` | [contract](stages/%s/CONTEXT.md) |\n' "$1" "$1" >>"$R/CONTEXT.md"
}

# --- passes ------------------------------------------------------------------
empty
passes "no stage and an empty routing table"
assert_contains "$OUT" "examined" "and it says what it examined"
valid
passes "two routed stages with optional sections, an earlier output and a named reference"
add_stage 03-verify-it
passes "a stage name with two hyphenated words"
pad_to AGENTS.md 80
pad_to CONTEXT.md 60
passes "an 80-line AGENTS.md and a 60-line CONTEXT.md"

# --- AC1 ---------------------------------------------------------------------
valid
fixture_append "$R/CLAUDE.md" "More."
refused "CLAUDE.md with extra content" "CLAUDE.md"
valid
fixture_remove "$R/CLAUDE.md"
refused "a missing CLAUDE.md" "CLAUDE.md"
valid
pad_to AGENTS.md 81
refused "an 81-line AGENTS.md" "81 lines"
valid
pad_to AGENTS.md 80
printf 'filler without a newline' >>"$R/AGENTS.md"
refused "an AGENTS.md of 80 lines and a final one without a newline" "81 lines"
valid
fixture_write "$R/CLAUDE.md" "@README.md"
refused "CLAUDE.md importing another file" "CLAUDE.md is not exactly"

# --- AC2: CONTEXT.md and the routing table -----------------------------------
valid
pad_to CONTEXT.md 61
refused "a 61-line CONTEXT.md" "61 lines"
valid
fixture_replace "$R/CONTEXT.md" "$ROW2" ""
refused "a stage the routing table does not name" "02-render"
valid
fixture_append "$R/CONTEXT.md" '| `stages/01-ask/` | again |'
refused "a stage the routing table names twice" "01-ask"
valid
fixture_append "$R/CONTEXT.md" '| `stages/09-gone/` | nowhere |'
refused "a routed stage that does not exist" "09-gone"
valid
fixture_replace "$R/CONTEXT.md" "## Routing" "## Stages"
refused "a CONTEXT.md with no routing table" "Routing"
valid
fixture_remove "$R/CONTEXT.md"
refused "a missing CONTEXT.md" "CONTEXT.md: missing"

# --- AC2: stage folders --------------------------------------------------------
for bad in 3-verify 03_verify 03-Verify 03-verify-; do
  valid
  add_stage "$bad"
  refused "a stage folder named $bad" "$bad"
done
valid
fixture_remove "$R/$C2"
refused "a stage without CONTEXT.md" "stages/02-render"
valid
fixture_remove "$R/stages/01-ask/output/.gitignore"
refused "a stage without output/.gitignore" "output/.gitignore"
valid
fixture_write "$R/stages/01-ask/output/.gitignore" '*'
refused "an output/.gitignore other than * and !.gitignore" "output/.gitignore"
valid
printf '*\n!.gitignore\n\n' >"$R/stages/01-ask/output/.gitignore"
refused "an output/.gitignore with a trailing blank line" "output/.gitignore"
valid
printf '*\n!.gitignore' >"$R/stages/01-ask/output/.gitignore"
passes "an output/.gitignore of the two lines without a final newline"
valid
put stages/01-ask/output/run/answers.env 'NAME=x'
git -C "$R" add -f stages/01-ask/output/run/answers.env
refused "another tracked file under output/" "stages/01-ask/output/run/answers.env"

# --- AC2: contract shape -------------------------------------------------------
valid
pad_to "$C2" 81
refused "a contract over 80 lines" "81 lines"
for section in Inputs Process Outputs; do
  valid
  fixture_replace "$R/$C1" "## $section" "## Other"
  refused "a contract without ## $section" "$C1"
done
valid
fixture_replace "$R/$C1" "## Checkpoints

The operator confirms.

## Audit

Read the description." "## Audit

Read the description.

## Checkpoints

The operator confirms."
refused "Audit before Checkpoints" "$C1"
valid
fixture_replace "$R/$C2" "## Process

Render.

## Outputs

\`render.md\`" "## Outputs

\`render.md\`

## Process

Render."
refused "Outputs before Process" "$C2"
valid
fixture_replace "$R/$C1" "## Checkpoints

The operator confirms.

" ""
passes "a contract with Audit and no Checkpoints"
valid
fixture_append "$R/$C2" "## Notes"
refused "a section the contract shape does not allow" "$C2"

# --- AC3: Inputs discipline ----------------------------------------------------
A='`../../shared/answers.tsv`'
inputs_case() { # DESCRIPTION REPLACEMENT NEEDLE
  valid
  fixture_replace "$R/$C1" "$A" "$2"
  refused "$1" "$3"
}
inputs_case "an input that is a directory, without a slash" '`../../shared`' "directory"
inputs_case "an input that is a glob" '`../../shared/*.tsv`' "glob"
inputs_case "an input that is a ? glob" '`../../shared/answers.ts?`' "glob"
inputs_case "an input that is a [ glob" '`../../shared/answers.[t]sv`' "glob"
inputs_case "an input that does not resolve" '`../../shared/missing.tsv`' "does not resolve"
inputs_case "an input above the workspace" '`../../../outside.txt`' "does not resolve"
# A path leaves its stage folder only by its leading run of ../; any other
# . or .. is refused, so no path is judged by a name it never reaches.
DOTDOT="has a . or .. outside its leading ../ run"
inputs_case "an input going up through a file" '`../02-render/CONTEXT.md/../../../AGENTS.md`' "$DOTDOT"
inputs_case "an input going up through a directory that does not exist" '`../../no-such-dir/../AGENTS.md`' "$DOTDOT"
inputs_case "an input whose name holds a space before a .." '`../02-render/CONTEXT.md ../../../../AGENTS.md`' "$DOTDOT"
inputs_case "an input opening with ./" '`./../../shared/answers.tsv`' "$DOTDOT"
inputs_case "an input with a .. after a directory it holds" '`../../shared/sub/../answers.tsv`' "$DOTDOT"
inputs_case "an input with a . segment" '`../../shared/./answers.tsv`' "$DOTDOT"
inputs_case "an input that is only .." '`..`' "Inputs \`..\` is a directory"
inputs_case "an input that is only ../.." '`../..`' "Inputs \`../..\` is a directory"

# A path is accepted only when, opened as written from its stage folder, it
# reaches a tracked regular file. Each case is committed and judged in every
# mode, since pre-push and CI judge the commit, not the disk.
every_mode() { # DESCRIPTION NEEDLE
  fixture_commit "$R" "test: $1"
  modes_refuse "$1" "$2"
}
modes_refuse() { # DESCRIPTION NEEDLE: the committed workspace, in every mode
  run
  assert_status 1 "$ST" "tree mode refuses $1"
  assert_contains "$OUT" "$2" "  and the refusal says: $2"
  run --staged
  assert_status 1 "$ST" "staged mode refuses $1"
  assert_contains "$OUT" "$2" "  and the refusal says: $2"
  run --range HEAD~1 HEAD
  assert_status 1 "$ST" "range mode refuses $1"
  assert_contains "$OUT" "$2" "  and the refusal says: $2"
}
path_case() { # DESCRIPTION PATH NEEDLE
  valid
  fixture_replace "$R/$C1" "$A" "\`$2\`"
  every_mode "$1" "$3"
}
link_case() { # DESCRIPTION LINK TARGET NEEDLE
  valid
  ln -s "$3" "$R/shared/$2"
  fixture_replace "$R/$C1" "$A" "\`../../shared/$2\`"
  every_mode "$1" "$4"
}
path_case "an absolute input" /CONTEXT.md "Inputs \`/CONTEXT.md\` is absolute"
path_case "an absolute input with a doubled slash" //CONTEXT.md "Inputs \`//CONTEXT.md\` is absolute"
path_case "an absolute input naming the stage's own file" /output/.gitignore \
  "Inputs \`/output/.gitignore\` is absolute"
link_case "a link to a later stage's file" later.md ../stages/02-render/CONTEXT.md \
  "Inputs \`../../shared/later.md\` is a symbolic link"
link_case "a link to a directory" stages ../stages "Inputs \`../../shared/stages\` is a symbolic link"
link_case "a link outside the workspace" hosts /etc/hosts "Inputs \`../../shared/hosts\` is a symbolic link"
valid
ln -s . "$R/shared/here"
fixture_replace "$R/$C1" "$A" '`../../shared/here/answers.tsv`'
every_mode "a path through a link to a directory" "Inputs \`../../shared/here/answers.tsv\` does not resolve"
valid
git init -q -b main "$R/shared/nested"
git -C "$R/shared/nested" commit -q --allow-empty -m "test: nested"
fixture_replace "$R/$C1" "$A" '`../../shared/nested`'
every_mode "a submodule" "Inputs \`../../shared/nested\` is a submodule"
# Inputs name files: a path ending in / is refused as such, whatever it names.
path_case "a directory with a trailing /" ../../shared/ "Inputs \`../../shared/\` ends in /"
path_case "a file with a trailing /" ../../shared/answers.tsv/ "Inputs \`../../shared/answers.tsv/\` ends in /"
path_case "nothing, with a trailing /" ../../nothere/ "Inputs \`../../nothere/\` ends in /"
valid
ln -s ../stages/02-render/CONTEXT.md "$R/shared/later.md"
fixture_replace "$R/$C1" "$A" '`../../shared/later.md/`'
every_mode "a link with a trailing /" "Inputs \`../../shared/later.md/\` ends in /"
inputs_case "an input from a later stage's output" '`../02-render/output/<name>/render.md`' "later"
inputs_case "an input from a later stage's folder" '`../02-render/references/notes.md`' "later"
inputs_case "an Inputs row without a path in backticks" 'shared/answers.tsv' \
  "a File/Location cell that is not one path in backticks"
inputs_case "an Inputs row naming two files" "$A \`../../shared/other.tsv\`" \
  "a File/Location cell that is not one path in backticks"
# The stage order is judged on the literal path: a stage of the same number
# is not a later one.
valid
add_stage 01-bar
put stages/01-bar/notes.md 'notes'
fixture_replace "$R/$C1" "$A" '`../01-bar/notes.md`'
fixture_commit "$R" "test: a same-numbered sibling stage"
passes "a file of a sibling stage with the same number"

# Inputs takes one closed shape: the table, its delimiter row, then rows of
# four cells whose File/Location is one code span and whose other cells hold
# none. Any other line is refused, each refusal naming its cause and line.
ROW="| shared | $A | all | the fields |"
TAB=$(printf '\t')
TABLE="$HEADER
$DELIM
$ROW"
OUTSIDE="a line outside its $HEADER table"
valid
fixture_replace "$R/$C1" "$TABLE" "$HEADER
|:---|:---:|---:|---|
$ROW${TAB}
"
passes "the table, its delimiter row aligned, a row with trailing space, a blank line after it"
shape_case() { # DESCRIPTION REPLACEMENT NEEDLE
  valid
  fixture_replace "$R/$C1" "$TABLE" "$2"
  refused "$1" "$3"
}
# A cell is split as GitHub splits it: an escaped pipe is text, not a border.
valid
fixture_replace "$R/$C1" "$TABLE" "$HEADER
$DELIM
| shared | $A | all | the fields \\| the schema |"
passes "a row whose Why holds an escaped pipe"
valid
fixture_replace "$R/$C1" "$A" '`../../shared/a\|b.tsv`'
refused "a File/Location span holding an escaped pipe, read as the path GitHub shows" \
  "Inputs \`../../shared/a|b.tsv\` does not resolve"
shape_case "a File/Location span padded with spaces" "$HEADER
$DELIM
| shared | \` ../../shared/answers.tsv \` | all | x |" \
  "a File/Location cell that is not one path in backticks: | shared |"
shape_case "Inputs as a list, not the table" "- $A" "$OUTSIDE: - $A"
shape_case "  and the refusal names the table it needs" "- $A" "no $HEADER table"
shape_case "a list item naming a second file after a colon (B1)" "$TABLE

- $A: and \`../../stages/*\`" "$OUTSIDE: - $A: and"
shape_case "a list item naming a later stage's file after a dash (B2)" "$TABLE

- $A — then \`../02-render/CONTEXT.md\`" "$OUTSIDE: - $A — then"
shape_case "a row of two cells naming a directory (B3)" "$HEADER
$DELIM
| $A | and \`../../\` |" "a row without four cells: | $A |"
shape_case "a code span on the line after a row (B4)" "$TABLE
  \`../../stages/*\`" "a row without four cells:   \`../../stages/*\`"
shape_case "a code span on its own line after the table" "$TABLE

  \`../../stages/*\`" "$OUTSIDE:   \`../../stages/*\`"
shape_case "a code span after an HTML comment (B5)" "$TABLE

<!-- x --> \`../../stages/*\`" "$OUTSIDE: <!-- x --> \`../../stages/*\`"
shape_case "a code span after the end of an HTML comment (B6)" "<!-- x
--> \`../../stages/*\`
$TABLE" "$OUTSIDE: --> \`../../stages/*\`"
# Source, Section/Scope and Why are plain text, each judged on its own: a
# backtick, <, [, ], @, &, a carriage return, :// or www. in any case in one
# is refused, the refusal naming the cell and what it holds, whatever GitHub
# would make of it.
cell_row() { printf '| %s | %s | %s | %s |' "$1" "$A" "$2" "$3"; }
cell_passes() { # DESCRIPTION SOURCE SCOPE WHY
  valid
  fixture_replace "$R/$C1" "$TABLE" "$HEADER
$DELIM
$(cell_row "$2" "$3" "$4")"
  passes "$1"
}
cell_case() { # DESCRIPTION SOURCE SCOPE WHY NEEDLE
  shape_case "$1" "$HEADER
$DELIM
$(cell_row "$2" "$3" "$4")" "Inputs: $5"
}
cell_passes "plain prose with an aside" "shared answers (stage 00)" "all (see Process)" "the fields (all)"
cell_passes "e.g., i.e. and version numbers" "shared (v1.2.3)" "git 2.36.0+" "e.g. the fields, i.e. all"
cell_passes "a path written as prose" shared all "then ../02-render/CONTEXT.md"
cell_passes "www without its dot" www wwwx "the www prefix"
cell_case "a code span in Why" shared all 'see `Process`' "Why holds a backtick"
cell_case "a code span in Source" '`../../`' all x "Source holds a backtick"
cell_case "a code span in Section/Scope" shared '`../../stages/*`' x "Section/Scope holds a backtick"
cell_case "HTML code in Why" shared all 'also <code>../../stages/*</code>' "Why holds <"
cell_case "an HTML tag GitHub drops" shared all 'the <codec> field' "Why holds <"
cell_case "an escaped <" shared all 'the \<code> tag' "Why holds <"
cell_case "an HTML link" shared all '<a href="../02-render/CONTEXT.md">this</a>' "Why holds <"
cell_case "an HTML image" shared all '<img src="../02-render/CONTEXT.md">' "Why holds <"
cell_case "a mailto autolink" shared all '<mailto:ops@example.com>' "Why holds <"
cell_case "monospace HTML" shared all '<tt>../../stages/*</tt>' "Why holds <"
cell_case "sample HTML" shared all '<samp>../../stages/*</samp>' "Why holds <"
cell_case "keyboard HTML" shared all '<kbd>../../stages/*</kbd>' "Why holds <"
cell_case "preformatted HTML" shared all '<pre>../../stages/*</pre>' "Why holds <"
cell_case "a < at the end of Source" 'x <' code y "Source holds <"
cell_case "an inline link" shared all 'also [this](../02-render/CONTEXT.md)' "Why holds ["
cell_case "a link split by an escaped pipe" shared all '[a\|b](../02-render/CONTEXT.md)' "Why holds ["
cell_case "a shortcut reference" shared all 'see [later]' "Why holds ["
cell_case "a collapsed reference" shared all 'see [later][]' "Why holds ["
cell_case "a full reference in Source" '[the spec][1]' all x "Source holds ["
cell_case "brackets with no definition" shared 'a[1][2]' x "Section/Scope holds ["
cell_case "a bracketed [sic]" shared 'all: every field [sic]' x "Section/Scope holds ["
cell_case "a lone ]" shared all 'a ] b' "Why holds ]"
cell_case "an email address" shared all 'ask ops@example.com' "Why holds @"
cell_case "a URL" shared 'https://example.com/x' x "Section/Scope holds ://"
cell_case "a URL GitHub does not link" shared all 's3://bucket' "Why holds ://"
cell_case "www. after a space" shared all 'see www.example.com' "Why holds www."
cell_case "www. opening the cell" 'www.example.com' all x "Source holds www."
cell_case "the word www. alone" shared all 'the www. prefix' "Why holds www."
cell_case "www. inside a word" shared 'awww.yes' x "Section/Scope holds www."
# GitHub's file view links www. in any case after any character but a letter
# or digit, and decodes a character reference before it links; a carriage
# return ends the row for it.
for w in 'WWW.example.com' 'Www.example.com' 'x.www.example.com' '-www.example.com' \
  '/www.example.com' ':www.example.com' "'www.example.com'" '“www.example.com”'; do
  cell_case "www. as $w" shared all "$w" "Why holds www."
done
for w in 'ops&#64;example.com' 'ops&commat;example.com' 'https&#58;//example.com' \
  'https&colon;//example.com' '&#x77;ww.example.com' '&#119;&#119;&#119;.example.com' \
  'see www&period;example.com' 'see mailto&#58;ops&#64;example.com' 'R&D'; do
  cell_case "a character reference: $w" shared all "$w" "Why holds &"
done
cell_case "an & in Source" 'R&D' all x "Source holds &"
cell_case "a carriage return" shared all "see$(printf '\r')www.example.com" "Why holds a carriage return"
cell_case "a carriage return in Section/Scope" shared "all$(printf '\r')" x \
  "Section/Scope holds a carriage return"
shape_case "HTML code in File/Location" "$HEADER
$DELIM
| shared | <code>../../shared/answers.tsv</code> | all | x |" \
  "a File/Location cell that is not one path in backticks: | shared | <code>"
shape_case "an empty File/Location cell" "$HEADER
$DELIM
| shared |  | all | x |" "a File/Location cell that is not one path in backticks: | shared |  |"
shape_case "a row of five cells" "$HEADER
$DELIM
$ROW x |" "a row without four cells: $ROW x |"
shape_case "a table of another header" '| File | Why |
|---|---|
| `../../shared/answers.tsv` | the fields |' "$OUTSIDE: | File | Why |"
shape_case "a header whose last cell is not Why" "| Source | File/Location | Section/Scope | Anything |
$DELIM
$ROW" "$OUTSIDE: | Source | File/Location | Section/Scope | Anything |"
valid
fixture_replace "$R/$C1" "$TABLE

## Process" "$HEADER
## Process"
refused "a header that ends the section" "its header without its delimiter row"
shape_case "a header without its delimiter row" "$HEADER
$ROW" "the line after its header is not its delimiter row: $ROW"
shape_case "a header, then a blank line" "$HEADER

$DELIM
$ROW" "its header without its delimiter row"
shape_case "a second table" "$TABLE

$TABLE" "$OUTSIDE: $HEADER"
shape_case "a sentence before the table" "Load only this file.

$TABLE" "$OUTSIDE: Load only this file."
shape_case "an indented table" "$(printf '%s\n' "$TABLE" | sed 's/^/ /')" "$OUTSIDE:  $HEADER"
shape_case "a fenced block" '```
- `../../shared/answers.tsv`
```' "$OUTSIDE: \`\`\`"
shape_case "an empty Inputs section" "" "no $HEADER table"
valid
fixture_replace "$R/$C2" "| \`references/notes.md\` | all | notes |" \
  "| \`references/notes.md\` | all | notes |
| this stage | \`output/<name>/render.md\` | all | its own output |"
refused "an input from the same stage's output" "same"
valid
fixture_replace "$R/$C2" "confirmed.md\` |" "missing.md\` |"
refused "an earlier stage's output its Outputs do not list" "Outputs"
valid
put stages/02-render/references/extra.md 'extra'
refused "a file in references/ its Inputs do not name" "stages/02-render/references/extra.md"

# --- AC2: the tree is portable ------------------------------------------------
# A path is judged by its literal spelling, which a disk that folds case or
# Unicode would open as another: so every tracked path is ASCII letters,
# digits, ., _, -, / and space, and no two spellings of a path or of its
# directories differ only in case. Such a disk writes a file into the folder
# it folds to, and git there folds a plain add to that folder's spelling, so
# each entry is made by name; a case-sensitive disk holds both.
variant() { # PATH: track PATH as spelled
  put "$1" 'notes'
  git -C "$R" update-index --add --cacheinfo "100644,$(git -C "$R" hash-object -w -- "$1"),$1"
}
TWIN="tracked paths that differ only in case"
NONPORT="not a portable path: only ASCII letters, digits, ., _, -, / and space"
LS=$(printf '\305\277') # U+017F, a long s, which such a disk folds to s
valid
variant Stages/02-render/notes.md
fixture_replace "$R/$C1" "$A" '`../../Stages/02-render/notes.md`'
every_mode "a later stage's file through a case twin of stages/ (q13)" "Stages/ and stages/: $TWIN"
assert_not_contains "$OUT" "Stages/02-render/ and" "  and names the twins once, at their shortest prefix"
valid
variant Stages/01-ask/output/x.md
fixture_replace "$R/$C2" '`references/notes.md` | all | notes |' \
  '`references/notes.md` | all | notes |
| 01-ask | `../../Stages/01-ask/output/x.md` | all | x |'
every_mode "an earlier stage's output/ through a case twin (H8)" "Stages/ and stages/: $TWIN"
valid
variant "${LS}tages/02-render/notes.md"
fixture_replace "$R/$C1" "$A" "\`../../${LS}tages/02-render/notes.md\`"
every_mode "a later stage's file through a non-ASCII twin (H9)" "${LS}tages/02-render/notes.md: $NONPORT"
valid
variant "${LS}tages/01-ask/references/r.md"
every_mode "an unnamed reference through a non-ASCII twin (H10)" \
  "${LS}tages/01-ask/references/r.md: $NONPORT"
valid
variant shared/Answers.tsv
every_mode "two files that differ only in case" "shared/Answers.tsv and shared/answers.tsv: $TWIN"
valid
put 'shared/a:b.md' 'x'
every_mode "a path holding a colon" "shared/a:b.md: $NONPORT"
# One name from each class outside the charset; a mutant allowing any one
# of them fails here.
for c in '~' '[' ']' '|' '"' ':' "$TAB" "$(printf '\303\251')" '*'; do
  valid
  put "shared/a${c}b.md" 'x'
  refused "a path holding $c" "shared/a${c}b.md: $NONPORT"
done
# Each set of twins is named once, where its spellings first differ, so one
# run names every twin: here both A/ and a/, and a/x and a/X under a/.
valid
variant A/x
variant a/x
variant a/X
# A case-insensitive disk holds one file for all three, so git add -A there
# refuses the aliases; the index is committed as it stands.
git -C "$R" commit -q --no-verify -m "test: twins under one folder"
modes_refuse "twins under one folder, beside that folder's twin" "a/X and a/x: $TWIN"
assert_contains "$OUT" "A/ and a/: $TWIN" "  and names the folders' twins too"
assert_not_contains "$OUT" "A/x and" "  and names no set twice"

# --- each reader's edge (F9 of the tests lens) -------------------------------------
# A `## ` line in a fence is no section: neither a heading in the order nor
# the start of one.
valid
fixture_replace "$R/$C1" 'Draft the answers.' 'Draft the answers.

```
## Inputs
| x |
```'
passes "a contract whose Process holds a fenced ## Inputs line"
# A row is bounded by pipes; the delimiter row's every cell is dashes.
valid
fixture_replace "$R/$C1" '| shared | `../../shared/answers.tsv` | all | the fields |' \
  'shared | `../../shared/answers.tsv` | all | the fields |'
refused "an Inputs row with no leading pipe" "a row without four cells"
valid
fixture_replace "$R/$C1" "$DELIM" '|---|---|x|y|'
refused "a delimiter row whose last cells are not dashes" "the line after its header is not its delimiter row"
# An earlier stage's output, named by the folder it is in: the stage must
# exist, and its Outputs may name the file by its output/<name>/ path.
valid
fixture_replace "$R/$C2" '`../01-ask/output/<name>/confirmed.md`' '`../00-none/output/<name>/confirmed.md`'
refused "an output of a stage folder that does not exist" \
  "Inputs \`../00-none/output/<name>/confirmed.md\` does not resolve"
valid
fixture_replace "$R/$C1" '`answers.env`, `confirmed.md`' '`answers.env`, `output/<name>/confirmed.md`'
passes "an earlier stage's Outputs naming the file by its output/<name>/ path"
valid
fixture_replace "$R/$C1" '| shared | `../../shared/answers.tsv` | all | the fields |' \
  '| above | `../../../outside.md` | all | the fields |'
refused "an input that climbs above the workspace" "Inputs \`../../../outside.md\` does not resolve"
# A stage folder with no number orders before no stage: its input of an
# output is refused, and of a tracked file in another stage judged with no
# shell error.
valid
put stages/zz-x/CONTEXT.md '# zz-x' '' '## Inputs' '' "$HEADER" "$DELIM" \
  '| 01-ask | `../01-ask/output/<name>/confirmed.md` | all | the answers |' \
  '| 01-ask | `../01-ask/CONTEXT.md` | all | the contract |' '' '## Process' '' 'Do it.' '' '## Outputs' '' '`out.md`'
put stages/zz-x/output/.gitignore '*' '!.gitignore'
printf '| `stages/zz-x/` | [contract](stages/zz-x/CONTEXT.md) |\n' >>"$R/CONTEXT.md"
refused "a stage folder with no number taking an output" "is an output of the same or a later stage"
assert_not_contains "$OUT" "integer expression" "  and no comparison fails"
# The tree's listing failing is a check that cannot run.
valid
fixture_failing "$R-stub" git '*ls-files -z -c -o --exclude-standard' 1
OUT=$(cd "$R" && PATH="$R-stub:$PATH" bin/checks/disclosure 2>&1)
assert_status 2 "$?" "the check cannot run when it cannot list the tree"
assert_not_contains "$OUT" "examined" "  and judges nothing"

# --- paths are judged literally, never split or expanded -------------------------
# A portable name can still hold a space or a . that a split or a pattern
# would misread.
valid
put 'stages/01-ask/output/run/a b.env' 'TOKEN=x'
git -C "$R" add -f 'stages/01-ask/output/run/a b.env'
refused "a tracked file under output/ whose name holds a space" \
  'stages/01-ask/output/run/a b.env: a tracked file under output/'
valid
put stages/02-render/references/n.tes.md 'unnamed'
refused "an unnamed reference whose name, read as a pattern, matches a named one" \
  "stages/02-render/references/n.tes.md: in references/ but not in the stage's Inputs"
valid
git -C "$R" mv stages/02-render/references/notes.md 'stages/02-render/references/my notes.md'
fixture_replace "$R/$C2" '`references/notes.md`' '`references/my notes.md`'
passes "a named reference whose name holds a space"
valid
add_stage '04-a b'
refused "a stage folder whose name holds a space" 'stages/04-a b/: the name is not NN-slug'

# --- judged through the tree reader --------------------------------------------
valid
fixture_append "$R/CLAUDE.md" "More."
run --range HEAD~1 HEAD
assert_status 0 "$ST" "range mode ignores an uncommitted violation"

# Every mode judges the same files: a stage folder whose name git would
# quote, with no contract, is refused in each, not skipped in one.
valid
put 'stages/01-a"b/notes.md' 'notes'
run
assert_status 1 "$ST" "tree mode: a stage folder whose name git quotes is judged"
assert_contains "$OUT" 'stages/01-a"b/: no CONTEXT.md' "  and the refusal names it"
git -C "$R" add -A
run --staged
assert_status 1 "$ST" "staged mode: the same refusal"
git -C "$R" commit -q --no-verify -m "test: a quoted stage name"
run --range HEAD~1 HEAD
assert_status 1 "$ST" "range mode: the same refusal"

# A stage found early in a long list of stage folders is still a stage
# folder: each lookup reads the list whole, so no reader leaves a writer to a
# broken pipe under pipefail (the list here outgrows a pipe's buffer).
valid
long=$(printf '%0240d' 0 | tr 0 x)
i=100
while [ "$i" -lt 500 ]; do
  put "stages/zz-$long$i/notes.md" 'notes'
  i=$((i + 1))
done
run
assert_contains "$OUT" "stages/zz-${long}100/: no CONTEXT.md" "a long list of stage folders is judged"
assert_not_contains "$OUT" "stages/01-ask/, which is not a stage folder" "  and a routed stage early in it is a stage folder"
assert_not_contains "$OUT" "does not resolve" "  and an earlier stage's output in it still resolves"

# --- a failed read is a check that cannot run (decision 228) -----------------
# Each case fails one stage of one pipeline on the valid workspace, through a
# stub first on PATH: the check exits 2, never judging the list that stage did
# not produce. NTH counts the stub's matching calls, in the check's order.
cannot_run() { # TOOL PATTERN NTH WHAT
  valid
  fixture_failing "$R-stub" "$1" "$2" "$3"
  OUT=$(cd "$R" && PATH="$R-stub:$PATH" bin/check disclosure 2>&1)
  ST=$?
  assert_status 2 "$ST" "the check cannot run when it cannot read $4"
  assert_contains "$OUT" "FAIL disclosure (could not run)" "  and bin/check says so"
}
cannot_run sed 's/^\[^*' 1 "the tree's paths"
cannot_run awk 'END { print NR }' 1 "AGENTS.md's lines"
cannot_run awk '!/^\[A-Za-z0-9.*' 1 "the unportable paths"
cannot_run awk '*parent = parent $i*' 1 "the paths, for case twins"
cannot_run sort '' 1 "the sorted case twins"
cannot_run awk '*$1 == "stages" && NF >= 3*' 1 "the stage folders"
cannot_run sort '-u' 1 "the sorted stage folders"
cannot_run git '*:(literal)stages/01-ask/output/.gitignore' 1 "a stage's output/.gitignore"
cannot_run awk "*index(\$0, ENVIRON\[\"P\"]) == 1*" 1 "a stage's output/"
cannot_run awk 'END { print NR }' 2 "CONTEXT.md's lines"
cannot_run awk '*insec = ($0 == want)*' 1 "the routing table"
cannot_run awk '*n++; if (n > 2) print*' 1 "the routing table's rows"
cannot_run awk '*split("", seen)*' 1 "the routed stages"
cannot_run awk '*$0 == ENVIRON\["S"] { n++ }*' 1 "how often a stage is routed"
cannot_run sort '-u' 2 "the routed stages, sorted"
cannot_run awk 'END { print NR }' 3 "a contract's lines"
cannot_run awk '*printf "%s%s", sep*' 1 "a contract's sections"
cannot_run awk '*insec = ($0 == want)*' 2 "a contract's Inputs section"
cannot_run awk '*BEGIN { H = "| Source*' 1 "a contract's Inputs table"
cannot_run awk '*if (n == 0) { print ""; exit }*' 1 "an input's path"
cannot_run awk '*!found && substr($0, i + 1)*' 1 "an input's mode"
cannot_run awk "*index(\$0, ENVIRON\[\"P\"]) == 1*" 4 "whether an input is a directory"
cannot_run awk "*index(\$0, ENVIRON\[\"P\"]) == 1*" 5 "a stage's references/"
# A lookup whose 1 is "no", grep failing with a higher status, is a check
# that cannot run, never a path the tree lacks (decision 228): a stage's
# CONTEXT.md, the top CONTEXT.md, and the contract whose rules would be
# skipped; a stage's name; a routed stage; an earlier stage's Outputs; a
# file in references/.
cannot_look() { # PATTERN NTH WHAT
  valid
  fixture_failing "$R-stub" grep "$1" "$2" 2
  OUT=$(cd "$R" && PATH="$R-stub:$PATH" bin/checks/disclosure 2>&1)
  assert_status 2 "$?" "the check cannot run when it cannot look up $3"
  assert_not_contains "$OUT" "examined" "  and judges nothing"
}
cannot_look '-Fxq -- stages/01-ask/CONTEXT.md' 1 "a stage's CONTEXT.md"
cannot_look '-Fxq -- CONTEXT.md' 1 "CONTEXT.md"
cannot_look '-Fxq -- stages/01-ask/CONTEXT.md' 2 "a contract"
cannot_look '-Eq*^\[0-9]\[0-9]-*' 1 "a stage's name"
cannot_look '-Fxq -- 01-ask' 1 "a routed stage"
# The tree reader failing on a file's bytes, at each of its reads, and on a
# commit that does not exist (the tests lens's F3). PATH is the file's path
# in the workspace, NTH its read; the stub matches it under the workspace's
# own folder name, as git names the top with links resolved.
cannot_read() { # PATH NTH WHAT
  valid
  fixture_failing "$R-stub" cat "*/${R##*/}/$1" "$2"
  OUT=$(cd "$R" && PATH="$R-stub:$PATH" bin/checks/disclosure 2>&1)
  assert_status 2 "$?" "the check cannot run when it cannot read $3"
  assert_not_contains "$OUT" "examined" "  and judges nothing"
}
cannot_read CLAUDE.md 1 "CLAUDE.md"
cannot_read AGENTS.md 1 "AGENTS.md"
cannot_read CONTEXT.md 1 "CONTEXT.md, for its lines"
cannot_read CONTEXT.md 2 "CONTEXT.md, for its ## Routing heading"
cannot_read CONTEXT.md 3 "CONTEXT.md, for its routing table"
cannot_read "$C1" 1 "a contract, for its lines"
valid
OUT=$(cd "$R" && CHECK_MODE=range CHECK_HEAD=no-such-commit bin/checks/disclosure 2>&1)
assert_status 2 "$?" "the check cannot run on a commit that does not exist"
assert_not_contains "$OUT" "examined" "  and judges nothing"

assert_done
