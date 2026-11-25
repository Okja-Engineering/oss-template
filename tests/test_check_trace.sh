#!/usr/bin/env bash
# The workspace's `trace` check (AC4, TAC12): in its agent files (AGENTS.md,
# CLAUDE.md, CONTEXT.md and every contract), each line holding a rule word
# links docs/workflow.md, CONTRIBUTING.md or GOVERNANCE.md; every relative
# link and anchor resolves; and each .claude/settings.json deny entry
# appears in CONTRIBUTING.md § Agent guards.
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
run() { OUT=$(cd "$R" && bin/check "$@" trace 2>&1); ST=$?; }
refused() { # DESCRIPTION NEEDLE
  run
  assert_status 1 "$ST" "refused: $1"
  assert_contains "$OUT" "$2" "  and the refusal says: $2"
}
passes() {
  run
  assert_status 0 "$ST" "passes: $1"
}
C1=stages/01-ask/CONTEXT.md

# valid: agent files whose rule lines link a source, a contract, the human
# docs and a deny list each entry of which CONTRIBUTING.md lists.
valid() {
  n=$((n + 1))
  R="$SCRATCH/ws$n"
  ws_fixture "$R"
  ws_real_check "$R" trace
  put CLAUDE.md '@AGENTS.md'
  put AGENTS.md '# A fixture workspace' '' 'Start from [CONTEXT.md](CONTEXT.md).' \
    'Do not take a reserved decision ([GOVERNANCE.md](GOVERNANCE.md#reserved-decisions)).'
  put CONTEXT.md '# On entry' '' 'Never skip a checkpoint ([docs/workflow.md](docs/workflow.md#stages)).' \
    '' '## Routing' '' '| Stage | Contract |' '|---|---|' \
    '| `stages/01-ask/` | [contract](stages/01-ask/CONTEXT.md) |'
  put "$C1" '# 01-ask' '' '## Process' '' \
    'Always stop at the checkpoint ([workflow](../../docs/workflow.md#the-target-and-its-path)).' \
    '' '## Outputs' '' '`answers.env`'
  put docs/workflow.md '# Workflow' '' '## Stages' '' 'The stages.' '' \
    '## The `target` and its path!' '' 'The target.' '' '## Stages' '' 'Again.'
  put README.md '# A fixture'
  put GOVERNANCE.md '# Governance' '' '## Reserved decisions' '' 'Deciders make them.'
  put CONTRIBUTING.md '# Contributing' '' '## Agent guards' '' '- `Read(**/.env)`' '- `Read(**/.env.*)`' \
    '' '## What is enforced' '' 'A table.'
  put .claude/settings.json '{' '  "permissions": {' '    "deny": [' '      "Read(**/.env)",' \
    '      "Read(**/.env.*)"' '    ]' '  }' '}'
  fixture_commit "$R" "test: a valid workspace"
}
# line FILE TEXT: FILE gains TEXT as its last line, committed.
line() {
  fixture_append "$R/$1" "$2"
  fixture_commit "$R" "test: a line"
}

valid
passes "rule lines each linking a source, and every link resolving"
assert_contains "$OUT" "examined" "and it says what it examined"

# An unsourced rule line (plan 2.1's first case).
valid
line CONTEXT.md 'Never skip a checkpoint.'
refused "an unsourced rule line in CONTEXT.md" "CONTEXT.md:10"
assert_contains "$OUT" "Never skip a checkpoint." "  and it quotes the line"
valid
line "$C1" 'Always stop here.'
refused "an unsourced rule line in a contract" "$C1:10"
valid
line AGENTS.md "Don't push."
refused "an unsourced rule line in AGENTS.md" "AGENTS.md:5"
valid
line AGENTS.md 'STOP here.'
refused "STOP in capitals" "AGENTS.md:5"
valid
line AGENTS.md 'Stop here.'
passes "stop not in capitals, which only trace's STOP is"
valid
line AGENTS.md 'Never push ([README](README.md)).'
refused "a rule line linking a file that is not a source" "AGENTS.md:5"
valid
line AGENTS.md 'Never push ([the guide](CONTRIBUTING.md)).'
passes "a rule line linking CONTRIBUTING.md"
valid
line AGENTS.md 'Never push, says `docs/workflow.md`.'
refused "a rule line naming a source only in a code span" "AGENTS.md:5"
valid
line AGENTS.md 'The `never` flag.'
passes "a rule word in a code span"
valid
fixture_append "$R/README.md" 'Never push.'
fixture_commit "$R" "test: a human doc"
passes "an unsourced rule line in a file that is not an agent file"
valid
put tests/fixtures/stages/01-x/CONTEXT.md 'Never push.'
put tests/fixtures/CONTEXT.md 'Never push.'
fixture_commit "$R" "test: fixtures"
passes "agent-file names under tests/fixtures/"

# Every relative link and anchor resolves.
valid
line CONTEXT.md 'See [the stages](docs/workflow.md#nowhere).'
refused "an unresolved anchor" "docs/workflow.md#nowhere"
valid
line CONTEXT.md 'See [the stages](docs/absent.md).'
refused "an unresolved path" "docs/absent.md"
valid
line CONTEXT.md 'See [the top](#nowhere).'
refused "an unresolved anchor in the same file" "#nowhere"
valid
line CONTEXT.md 'See [the routing](#routing).'
passes "an anchor in the same file"
valid
line CONTEXT.md 'See [again](docs/workflow.md#stages-1).'
passes "the anchor of a repeated heading"
valid
line CONTEXT.md 'See [the docs](docs/).'
passes "a link to a directory"
valid
line CONTEXT.md 'See [up](../outside.md).'
refused "a link climbing out of the repository" "the link ../outside.md climbs out"
valid
line "$C1" 'See [the routing](../../CONTEXT.md#routing).'
passes "a contract's link climbing to the top"
valid
line CONTEXT.md 'See [a site](https://example.com/x#y) and [mail](mailto:a@example.invalid).'
passes "links that are not relative"
valid
line CONTEXT.md 'See `[not a link](absent.md)`.'
passes "a link in a code span"

# Each deny entry is listed in CONTRIBUTING.md § Agent guards.
valid
fixture_replace "$R/.claude/settings.json" '"Read(**/.env.*)"' '"Read(**/.env.*)",
      "Read(**/secrets/**)"'
fixture_commit "$R" "test: a new deny entry"
refused "an unlisted deny entry" "Read(**/secrets/**)"
valid
fixture_replace "$R/.claude/settings.json" '"Read(**/.env.*)"' '"Read(**/.env.*)",
      "Read(**/secrets/**)"'
fixture_append "$R/CONTRIBUTING.md" '`Read(**/secrets/**)` is listed under another heading.'
fixture_commit "$R" "test: a deny entry outside the section"
refused "a deny entry listed outside § Agent guards" "Read(**/secrets/**)"

# Read through the tree reader.
valid
fixture_append "$R/CONTEXT.md" 'Never skip a checkpoint.'
run --range "" HEAD
assert_status 0 "$ST" "range mode judges HEAD, not an uncommitted edit"

assert_done
