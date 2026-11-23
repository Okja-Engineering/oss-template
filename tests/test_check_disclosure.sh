#!/usr/bin/env bash
# The workspace's `disclosure` check (AC1-AC3): always-on budgets, the stage
# folders and routing table, contract shape, and Inputs discipline. One
# fixture case per refusal, each on an otherwise valid fixture workspace.
# shellcheck disable=SC2016 # backticks here are Markdown code spans, kept literal
set -u
export LC_ALL=C
TEST_DIR=$(cd "$(dirname "$0")" && pwd)
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
  put "$C1" '# 01-ask' '' '## Inputs' '' '| File | Why |' '|---|---|' \
    '| `../../shared/answers.tsv` | the fields |' '' '## Process' '' 'Draft the answers.' '' \
    '## Checkpoints' '' 'The operator confirms.' '' '## Audit' '' 'Read the description.' '' \
    '## Outputs' '' '`answers.env`, `confirmed.md`'
  put stages/01-ask/output/.gitignore '*' '!.gitignore'
  put "$C2" '# 02-render' '' '## Inputs' '' '| File | Why |' '|---|---|' \
    '| `../01-ask/output/<name>/confirmed.md` | the confirmed answers |' \
    '| `references/notes.md` | notes |' '' '## Process' '' 'Render.' '' '## Outputs' '' '`render.md`'
  put stages/02-render/output/.gitignore '*' '!.gitignore'
  put stages/02-render/references/notes.md 'notes'
  fixture_commit "$R" "test: a valid workspace"
}

# add_stage NAME: a further minimal stage, routed, otherwise valid.
add_stage() {
  put "stages/$1/CONTEXT.md" "# $1" '' '## Inputs' '' '## Process' '' 'Do it.' '' '## Outputs' '' '`out.md`'
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
fixture_append "$R/$C2" "## Notes"
refused "a section the contract shape does not allow" "$C2"

# --- AC3: Inputs discipline ----------------------------------------------------
A='`../../shared/answers.tsv`'
inputs_case() { # DESCRIPTION REPLACEMENT NEEDLE
  valid
  fixture_replace "$R/$C1" "$A" "$2"
  refused "$1" "$3"
}
inputs_case "an input that is a directory" '`../../shared/`' "directory"
inputs_case "an input that is a directory, without a slash" '`../../shared`' "directory"
inputs_case "an input that is a glob" '`../../shared/*.tsv`' "glob"
inputs_case "an input that does not resolve" '`../../shared/missing.tsv`' "does not resolve"
inputs_case "an input above the workspace" '`../../../outside.txt`' "does not resolve"
inputs_case "an input from a later stage's output" '`../02-render/output/<name>/render.md`' "later"
inputs_case "an input from a later stage's folder" '`../02-render/references/notes.md`' "later"
inputs_case "an Inputs row without a path in backticks" 'shared/answers.tsv' "one file in backticks"

# Every non-blank line of Inputs is a table row or a list item naming one
# file, judged by the same rules, or a refusal: nothing is skipped unread.
TABLE='| File | Why |
|---|---|
| `../../shared/answers.tsv` | the fields |'
list_case() { # DESCRIPTION REPLACEMENT NEEDLE
  valid
  fixture_replace "$R/$C1" "$TABLE" "$2"
  refused "$1" "$3"
}
valid
fixture_replace "$R/$C1" "$TABLE" '- `../../shared/answers.tsv`: the fields'
passes "Inputs as a list item naming one file"
list_case "a list item naming a glob" '- `../../stages/*`' "glob"
list_case "a list item naming a directory" '- `../../`' "directory"
list_case "a list item naming a stage that does not exist" '- `../09-later/output/<name>/x.md`' "does not resolve"
list_case "a list item naming two files" '- `../../shared/answers.tsv` and `../../CONTEXT.md`' "one file in backticks"
list_case "a prose line in Inputs" 'the whole repository' "the whole repository"
list_case "an indented table row" "$(printf '%s\n' "$TABLE" | sed 's/^/  /')" "  | File | Why |"
list_case "a table without its separator row" '| File | Why |
| `../../shared/answers.tsv` | the fields |' "answers.tsv"
inputs_case "an Inputs row naming two files" "$A \`../../shared/other.tsv\`" "one file in backticks"
valid
fixture_replace "$R/$C2" "| \`references/notes.md\` | notes |" \
  "| \`references/notes.md\` | notes |
| \`output/<name>/render.md\` | its own output |"
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
