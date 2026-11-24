#!/usr/bin/env bash
# The workspace's `disclosure` check (AC1-AC3): always-on budgets, the stage
# folders and routing table, contract shape, and Inputs discipline. One
# fixture case per refusal, each on an otherwise valid fixture workspace.
# shellcheck disable=SC2016 # backticks here are Markdown code spans, kept literal
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
run() { OUT=$(cd "$R" && bin/check "$@" disclosure 2>&1); ST=$?; }
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

# empty: a fixture workspace with the agent files and no stage.
empty() {
  n=$((n + 1))
  R="$SCRATCH/ws$n"
  ws_fixture "$R"
  ws_real_check "$R" disclosure
  put CLAUDE.md '@AGENTS.md'
  put AGENTS.md '# A fixture workspace' '' 'Start from CONTEXT.md.'
  put CONTEXT.md '# On entry' '' '## Triggers' '' 'create: stage 01-ask.' '' \
    '## Routing' '' '| Stage | Contract |' '|---|---|'
  fixture_commit "$R" "test: an empty workspace"
}

# valid: two stages, routed, with every optional section, an earlier stage's
# output as an input, and a named reference.
valid() {
  empty
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
# A case-insensitive disk (macOS's) opens a path spelled in another case as
# the file it folds to, so the stage order and references/ are judged without
# regard to case. Such a disk writes a file into the folder of the same name
# in any case, and git there folds a plain add to that folder's spelling, so
# each entry is made by name; a case-sensitive disk holds both folders.
variant() { # PATH: track PATH as spelled
  put "$1" 'notes'
  git -C "$R" update-index --add --cacheinfo "100644,$(git -C "$R" hash-object -w -- "$1"),$1"
}
valid
variant Stages/02-render/notes.md
fixture_replace "$R/$C1" "$A" '`../../Stages/02-render/notes.md`'
every_mode "a later stage's file spelled in another case" \
  "Inputs \`../../Stages/02-render/notes.md\` is in a later stage"
valid
variant Stages/01-ask/notes.md
fixture_replace "$R/$C1" "$A" '`../../Stages/01-ask/notes.md`'
every_mode "the stage's own file spelled in another case" \
  "Inputs \`../../Stages/01-ask/notes.md\` is in this stage, spelled in another case"
valid
variant Stages/01-ask/notes.md
fixture_replace "$R/$C2" '`references/notes.md` | all | notes |' \
  '`references/notes.md` | all | notes |
| 01-ask | `../../Stages/01-ask/notes.md` | all | notes |'
fixture_commit "$R" "test: an earlier stage's file spelled in another case"
passes "an earlier stage's file spelled in another case"
valid
variant stages/02-render/References/extra.md
every_mode "a file in References/ its Inputs do not name" \
  "stages/02-render/References/extra.md: in references/ but not in the stage's Inputs"
inputs_case "an input from a later stage's output" '`../02-render/output/<name>/render.md`' "later"
inputs_case "an input from a later stage's folder" '`../02-render/references/notes.md`' "later"
inputs_case "an Inputs row without a path in backticks" 'shared/answers.tsv' \
  "a File/Location cell that is not one path in backticks"
inputs_case "an Inputs row naming two files" "$A \`../../shared/other.tsv\`" \
  "a File/Location cell that is not one path in backticks"

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
put 'shared/a|b.tsv' 'fields'
fixture_replace "$R/$C1" "$A" '`../../shared/a\|b.tsv`'
passes "a File/Location span holding an escaped pipe, read as the path GitHub shows"
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

# --- paths are judged literally, never split or expanded -------------------------
valid
put 'stages/01-ask/output/.gitignor[e]' 'TOKEN=x'
git -C "$R" add -f 'stages/01-ask/output/.gitignor[e]'
refused "a tracked file under output/ whose name globs to .gitignore" 'stages/01-ask/output/.gitignor[e]'
valid
put 'stages/02-render/references/note[s].md' 'unnamed'
refused "an unnamed reference whose name globs to a named one" 'stages/02-render/references/note[s].md'
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

assert_done
