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
# docs and a deny list each entry of which CONTRIBUTING.md lists; built once,
# by build_valid, and copied for each case.
valid() {
  [ -d "$SCRATCH/valid" ] || {
    R="$SCRATCH/valid"
    build_valid
  }
  n=$((n + 1))
  R="$SCRATCH/ws$n"
  ws_copy "$SCRATCH/valid" "$R"
}
build_valid() {
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
line CLAUDE.md 'Never push.'
refused "an unsourced rule line in CLAUDE.md" "CLAUDE.md:2"
valid
line AGENTS.md 'Don’t push.'
refused "a rule line with a curly apostrophe" "AGENTS.md:5"
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

# Links by reference resolve, and source a rule line, as inline ones do.
valid
line CONTEXT.md 'See [the doc][d].'
line CONTEXT.md '[d]: docs/absent.md'
refused "a reference whose definition names an unresolved path" "docs/absent.md"
valid
line CONTEXT.md '[e]: docs/workflow.md#nowhere'
refused "a definition no link uses, naming an unresolved anchor" "docs/workflow.md#nowhere"
valid
line AGENTS.md 'Never push ([workflow][w]).'
line AGENTS.md '[w]: docs/workflow.md#stages'
passes "a rule line sourced by a reference, its definition on another line"
valid
line AGENTS.md 'Never push ([workflow][]).'
line AGENTS.md '[Workflow]: docs/workflow.md#stages'
passes "a collapsed reference, its label in another case"
valid
line AGENTS.md 'Never push ([workflow]).'
line AGENTS.md '[workflow]: docs/workflow.md#stages'
passes "a shortcut reference"
valid
line AGENTS.md 'Never push ([workflow]).'
refused "a label no definition gives, which is not a link" "AGENTS.md:5"

# Anchors drop markup as GitHub does (C7).
valid
line docs/workflow.md '## The _first_ step'
line docs/workflow.md '## A snake_case name'
line docs/workflow.md '## An _emphasised snake_case_ name'
line CONTEXT.md 'See [first](docs/workflow.md#the-first-step) and [snake](docs/workflow.md#a-snake_case-name).'
line CONTEXT.md 'See [both](docs/workflow.md#an-emphasised-snake_case-name).'
passes "anchors with emphasis underscores dropped, and an underscore inside a word kept"
valid
line docs/workflow.md '## The _first_ step'
line CONTEXT.md 'See [first](docs/workflow.md#the-_first_-step).'
refused "an anchor that keeps emphasis underscores" "docs/workflow.md#the-_first_-step"
valid
line docs/workflow.md '## The `_first_` step'
line CONTEXT.md 'See [first](docs/workflow.md#the-_first_-step).'
passes "an anchor keeping the underscores of a code span"
valid
line docs/workflow.md ''
line docs/workflow.md 'A setext heading'
line docs/workflow.md '----------------'
line CONTEXT.md 'See [it](docs/workflow.md#a-setext-heading).'
passes "the anchor of a setext heading"
valid
line CONTEXT.md 'See [the settings](.claude/settings.json#permissions).'
passes "an anchor on a file that is not Markdown, which is not judged"
valid
line CONTEXT.md 'See [the stages](<docs/workflow.md#stages> "The stages").'
passes "a target in angle brackets, with a title"

# Each deny entry is listed in CONTRIBUTING.md § Agent guards.
valid
fixture_replace "$R/.claude/settings.json" '"Read(**/.env.*)"' '"Read(**/.env.*)",
      "Read(**/secrets/**)"'
fixture_commit "$R" "test: a new deny entry"
refused "an unlisted deny entry" "Read(**/secrets/**)"
# The heading that opens the section is not one of its lines, so an entry
# its words alone would hold is unlisted.
valid
fixture_replace "$R/.claude/settings.json" '"Read(**/.env.*)"' '"Read(**/.env.*)",
      "Agent guards"'
fixture_commit "$R" "test: a deny entry only the heading holds"
refused "a deny entry the section's heading alone holds" "the deny entry Agent guards is not listed"
valid
fixture_replace "$R/.claude/settings.json" '"Read(**/.env.*)"' '"Read(**/.env.*)",
      "Read(**/secrets/**)"'
fixture_append "$R/CONTRIBUTING.md" '`Read(**/secrets/**)` is listed under another heading.'
fixture_commit "$R" "test: a deny entry outside the section"
refused "a deny entry listed outside § Agent guards" "Read(**/secrets/**)"
valid
fixture_replace "$R/.claude/settings.json" '"Read(**/.env.*)"' '"Read(**/.env.*)",
      "Read(**/secrets/**)"'
fixture_replace "$R/CONTRIBUTING.md" '- `Read(**/.env.*)`' '- `Read(**/.env.*)`
```
## Not a heading, in a fence
```
- `Read(**/secrets/**)`'
fixture_commit "$R" "test: a fence in the guards section"
passes "a deny entry listed after a fence in § Agent guards"
# § Agent guards is read as the one Markdown subset reads it (conformance F3
# of S2's second ship gate): a heading in a ~~~ fence is not one, and a
# setext heading is.
valid
fixture_replace "$R/.claude/settings.json" '"Read(**/.env.*)"' '"Read(**/.env.*)",
      "Read(**/secrets/**)"'
fixture_append "$R/CONTRIBUTING.md" '
~~~
## Agent guards
- `Read(**/secrets/**)`
~~~'
fixture_commit "$R" "test: the heading in a tilde fence"
refused "a deny entry listed under an Agent guards heading inside a ~~~ fence" "Read(**/secrets/**)"
valid
fixture_replace "$R/CONTRIBUTING.md" '## Agent guards' 'Agent guards
------------'
fixture_commit "$R" "test: a setext Agent guards heading"
passes "deny entries listed under a setext § Agent guards"
valid
fixture_replace "$R/.claude/settings.json" '"Read(**/.env.*)"' '"Read(**/.env.*)",
      "Read(**/secrets/**)"'
fixture_replace "$R/CONTRIBUTING.md" '- `Read(**/.env.*)`' '- `Read(**/.env.*)`

Another section
---------------

- `Read(**/secrets/**)`'
fixture_commit "$R" "test: a setext heading ending the section"
refused "a deny entry listed after a setext heading that ends § Agent guards" "Read(**/secrets/**)"
valid
fixture_replace "$R/.claude/settings.json" '"Read(**/.env.*)"' '"Read(**/.env.*)",
      "Read(**/secrets/**)"'
fixture_replace "$R/CONTRIBUTING.md" '- `Read(**/.env.*)`' '- `Read(**/.env.*)`

### A subsection

- `Read(**/secrets/**)`'
fixture_commit "$R" "test: a subsection of the section"
passes "a deny entry listed in a subsection of § Agent guards"
valid
fixture_replace "$R/.claude/settings.json" '"Read(**/.env.*)"' '"Read(**/.env.*)",
      "Read(**/secrets/**)"'
fixture_replace "$R/CONTRIBUTING.md" '- `Read(**/.env.*)`' '- `Read(**/.env.*)`

Agents are also denied `Read(**/secrets/**)`,
which a paragraph lists.'
fixture_commit "$R" "test: a deny entry in a paragraph of the section"
passes "a deny entry listed in a paragraph of § Agent guards"
# One frontmatter rule: YAML frontmatter is no setext heading, so it makes
# no anchor.
valid
put docs/front.md '---' 'title: Front matter' '---' '' '# Body'
line CONTEXT.md 'See [it](docs/front.md#title-front-matter).'
refused "an anchor YAML frontmatter would make as a setext heading" "docs/front.md#title-front-matter"
valid
put docs/front.md '---' 'title: Front matter' '---' '' '# Body'
line CONTEXT.md 'See [it](docs/front.md#body).'
passes "an anchor of a heading after frontmatter"
valid
put AGENTS.md '---' 'see: "[it](docs/absent.md)"' '---' '' '# A fixture workspace' '' 'Start from [CONTEXT.md](CONTEXT.md).'
fixture_commit "$R" "test: a link in frontmatter"
passes "a link in frontmatter, which is not a link"

# Read through the tree reader.
valid
fixture_append "$R/CONTEXT.md" 'Never skip a checkpoint.'
run --range "" HEAD
assert_status 0 "$ST" "range mode judges HEAD, not an uncommitted edit"

# --- a failed read is a check that cannot run (decision 228) -----------------
# Each case fails one stage of one pipeline on the valid workspace, through a
# stub first on PATH: the check exits 2, never judging what that stage did not
# produce.
cannot_run() { # TOOL PATTERN NTH WHAT
  valid
  fixture_failing "$R-stub" "$1" "$2" "$3"
  OUT=$(cd "$R" && PATH="$R-stub:$PATH" bin/check trace 2>&1)
  ST=$?
  assert_status 2 "$ST" "the check cannot run when it cannot read $4"
  assert_contains "$OUT" "FAIL trace (could not run)" "  and bin/check says so"
}
cannot_run sed 's/^\[^*' 1 "the tree's paths"
cannot_run awk '*$0 == "AGENTS.md"*' 1 "the agent files"
cannot_run awk '*$1 == ENVIRON\["N"]*' 1 "a rule line's links"
cannot_run awk '*print "OK" s*' 1 "where a rule line's link leads"
cannot_run awk '*print "OK" s*' 2 "where a link leads"
cannot_run git '*:(literal)CONTRIBUTING.md' 1 "CONTRIBUTING.md"
cannot_run awk '*insec = (t == "Agent guards")*' 1 "§ Agent guards"
cannot_run awk '*s = substr(s, i + 6)*' 1 "the deny entries"
# The tree reader failing on a file's bytes, at each read, and on a commit
# that does not exist (the tests lens's F3).
cannot_run cat '/*/CONTEXT.md' 1 "CONTEXT.md, for its rule lines"
cannot_run cat '/*/CONTEXT.md' 2 "CONTEXT.md, for the links its rule lines need"
cannot_run cat '/*/CONTEXT.md' 3 "CONTEXT.md, for every link it holds"
cannot_run cat '/*/docs/workflow.md' 1 "a linked file, for its anchors"
cannot_run cat '/*/.claude/settings.json' 1 ".claude/settings.json"
cannot_run cat '/*/CONTRIBUTING.md' 1 "CONTRIBUTING.md"
valid
OUT=$(cd "$R" && CHECK_MODE=range CHECK_HEAD=no-such-commit bin/checks/trace 2>&1)
assert_status 2 "$?" "the check cannot run on a commit that does not exist"
assert_not_contains "$OUT" "examined" "  and judges nothing"

assert_done
