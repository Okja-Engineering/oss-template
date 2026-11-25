#!/usr/bin/env bash
# The workspace's `claims` check (AC4, TAC13): in its tracked Markdown, every
# line holding a rule word names a check or says it is not enforced. A
# heading is not a sentence (decision 173). foundation/, docs/adr/,
# docs/work/ and tests/fixtures/ are not judged.
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
run() { OUT=$(cd "$R" && bin/check "$@" claims 2>&1); ST=$?; }
refused() { # DESCRIPTION NEEDLE
  run
  assert_status 1 "$ST" "refused: $1"
  assert_contains "$OUT" "$2" "  and the refusal says: $2"
}
passes() {
  run
  assert_status 0 "$ST" "passes: $1"
}

# fresh: a fixture workspace with a README and the workspace's claims.
fresh() {
  n=$((n + 1))
  R="$SCRATCH/ws$n"
  ws_fixture "$R"
  ws_real_check "$R" claims
  put README.md '# A fixture' '' 'A workspace with no rule in it.'
  fixture_commit "$R" "test: a fixture workspace"
}
# line TEXT: README.md gains TEXT as its last line, committed.
line() {
  fixture_append "$R/README.md" "$1"
  fixture_commit "$R" "test: a line"
}

fresh
passes "Markdown with no rule word"
assert_contains "$OUT" "examined" "and it says what it examined"

# TAC13's pair.
fresh
line 'Force pushes to main are refused.'
refused "a rule line naming no check" "README.md:4"
assert_contains "$OUT" "Force pushes to main are refused." "  and it quotes the line"
fresh
line 'Force pushes to main are refused by `bin/check`.'
passes "the same line naming a script under bin/"
fresh
line 'Force pushes to main are refused by `bin/check disclosure`.'
passes "the same line naming bin/check and a check"
fresh
line 'Force pushes to main are refused by [the hook](.githooks/pre-push).'
passes "the same line linking a hook under .githooks/"
fresh
line 'Force pushes to main are refused by `bin/absent`.'
refused "a line naming a path the tree does not hold" "README.md:4"
fresh
line 'Force pushes to main are refused by `docs/workflow.md`.'
refused "a line naming a path outside the enforcer folders" "README.md:4"
fresh
line 'Force pushes to main are refused; this is not enforced yet.'
passes "the line saying it is not enforced"
fresh
line 'Force pushes are refused, which is Unenforced today.'
passes "the line saying it is unenforced, in any case"

# Each word of decision 30's list, and the words it does not hold.
for w in must 'must not' required never refuse refuses refused block blocks blocked \
  reject rejects rejected enforce enforces enforced prevent prevents prevented; do
  fresh
  line "A change $w be reviewed."
  refused "the rule word '$w'" "README.md:4"
done
fresh
line 'Enforcers, blockers, refusals and a mustard seed are not rule words.'
passes "words that only start like rule words"
fresh
line 'NEVER push to main.'
refused "a rule word in capitals" "README.md:4"

# The heading rule (decision 173).
fresh
line '## What is enforced'
passes "the heading ## What is enforced"
fresh
line 'This is what is enforced.'
refused "the same words in a sentence naming no check" "README.md:4"
fresh
line '### Never pushed'
passes "a heading of any level"

# What is not prose.
fresh
line 'The `--never` flag lists them.'
passes "a rule word in a code span"
fresh
line 'Run ``a `never` b`` for a list.'
passes "a rule word in a double-backtick code span"
fresh
put README.md '# A fixture' '' '```' 'Force pushes are refused.' '```' '~~~' 'Never.' '~~~'
fixture_commit "$R" "test: fences"
passes "rule words in fenced blocks"
fresh
put README.md '---' 'title: never' '---' '' '# A fixture'
fixture_commit "$R" "test: frontmatter"
passes "a rule word in frontmatter"

# What is not judged (AC4).
for d in foundation docs/adr docs/work tests/fixtures; do
  fresh
  put "$d/notes.md" 'Force pushes to main are refused.'
  fixture_commit "$R" "test: an excluded folder"
  passes "an unsourced rule line under $d/"
done
fresh
put docs/notes.md 'Force pushes to main are refused.'
fixture_commit "$R" "test: a judged folder"
refused "an unsourced rule line in another folder" "docs/notes.md:1"
fresh
put notes.txt 'Force pushes to main are refused.'
fixture_commit "$R" "test: not Markdown"
passes "a file that is not Markdown"

# Read through the tree reader.
fresh
fixture_append "$R/README.md" 'Force pushes to main are refused.'
run --range "" HEAD
assert_status 0 "$ST" "range mode judges HEAD, not an uncommitted edit"
fresh
put docs/staged.md 'Force pushes to main are refused.'
git -C "$R" add docs/staged.md
run --staged
assert_status 1 "$ST" "staged mode judges the index"
assert_contains "$OUT" "docs/staged.md:1" "  and names the staged file"

assert_done
