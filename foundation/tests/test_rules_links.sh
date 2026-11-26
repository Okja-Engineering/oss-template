#!/usr/bin/env bash
# rules.sh and links.sh, the Markdown subset the rule checks read, unit by
# unit. Run without pipefail, as a caller may: a library's reads hold their
# own statuses (decision 228).
set -u
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/assert.sh
. "$TEST_DIR/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=lib/fixture.sh
. "$TEST_DIR/lib/fixture.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/tree.sh
. "$TEST_DIR/../bin/lib/tree.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/links.sh
. "$TEST_DIR/../bin/lib/links.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/rules.sh
. "$TEST_DIR/../bin/lib/rules.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
R="$SCRATCH/repo"
fixture_repo "$R"
fixture_write "$R/docs/rule.md" "Force pushes are refused by [the check](../bin/check)."
fixture_write "$R/docs/linked.md" "See [the deciders](../GOVERNANCE.md#deciders)."
fixture_commit "$R" "test: a rule line and an anchored link"

# --- a read that fails is a judgement that cannot be made ---------------------
# tree_cat, failing its FAIL_AT-th call with 2, counted in a file, since each
# call may run in its own subshell. The real reader runs every other call.
eval "$(declare -f tree_cat | sed '1s/^tree_cat/tree__real_cat/')"
tree_cat() {
  local calls=0
  [ ! -f "$SCRATCH/calls" ] || read -r calls <"$SCRATCH/calls"
  calls=$((calls + 1))
  printf '%s\n' "$calls" >"$SCRATCH/calls"
  [ "$calls" != "${FAIL_AT:-0}" ] || return 2
  tree__real_cat "$@"
}
# failing_at N CMD...: CMD's status, from R, with tree_cat failing its Nth call.
failing_at() {
  rm -f "$SCRATCH/calls"
  FAIL_AT=$1
  shift
  (cd "$R" && "$@" >/dev/null)
  ST=$?
  FAIL_AT=0
}

failing_at 0 rules_claims worktree
assert_status 0 "$ST" "rules_claims: the fixture passes when every read does"
failing_at 1 rules_claims worktree .claude/ AGENTS.md CLAUDE.md GOVERNANCE.md docs/adr/ docs/linked.md docs/rfcs/ docs/work/
assert_status 2 "$ST" "rules_claims: a file whose lines cannot be read cannot be judged"
failing_at 2 rules_claims worktree .claude/ AGENTS.md CLAUDE.md GOVERNANCE.md docs/adr/ docs/linked.md docs/rfcs/ docs/work/
assert_status 2 "$ST" "rules_claims: a rule line whose links cannot be read cannot be judged"
paths=$(cd "$R" && tree_list worktree | sed 's/^[^	]*	//')
failing_at 0 links_judge worktree docs/linked.md "$paths"
assert_status 0 "$ST" "links_judge: the fixture's link resolves when every read does"
failing_at 1 links_judge worktree docs/linked.md "$paths"
assert_status 2 "$ST" "links_judge: a file whose links cannot be read cannot be judged"
failing_at 2 links_judge worktree docs/linked.md "$paths"
assert_status 2 "$ST" "links_judge: a heading file that cannot be read cannot be judged"
fixture_failing "$SCRATCH/sedstub" sed 's/^\[^*' 1
(cd "$R" && PATH="$SCRATCH/sedstub:$PATH" rules_claims worktree >/dev/null)
assert_status 2 "$?" "rules_claims: a tree whose paths cannot be listed cannot be judged"
rules_lines nolist </dev/null 2>/dev/null
assert_status 2 "$?" "rules_lines: a list it does not hold is an error"
# A lookup whose 1 is "no", failing with a higher status, is a judgement
# that cannot be made, never that no (decision 228): the look for a rule
# word, for a path the tree holds, and for a heading.
fixture_failing "$SCRATCH/wordstub" awk '*MODE=word*' 1 2
(PATH="$SCRATCH/wordstub:$PATH" && rules_word 'You must push.' >/dev/null)
assert_status 2 "$?" "rules_word: a look for a rule word that fails is not none"
fixture_failing "$SCRATCH/holdstub" awk '*ENVIRON\["P"] "/") == 1*' 1 2
(cd "$R" && PATH="$SCRATCH/holdstub:$PATH" && links_judge worktree docs/linked.md "$paths" >/dev/null)
assert_status 2 "$?" "links_judge: a look for the linked path that fails cannot be judged"
fixture_failing "$SCRATCH/holdstub2" awk '*ENVIRON\["P"] "/") == 1*' 1 2
(cd "$R" && PATH="$SCRATCH/holdstub2:$PATH" && rules_claims worktree .claude/ AGENTS.md CLAUDE.md GOVERNANCE.md docs/adr/ docs/linked.md docs/rfcs/ docs/work/ >/dev/null)
assert_status 2 "$?" "rules_claims: a look for the check a line names that fails cannot be judged"
fixture_failing "$SCRATCH/anchorstub" grep '-Fx -e deciders' 1 2
(cd "$R" && PATH="$SCRATCH/anchorstub:$PATH" && links_judge worktree docs/linked.md "$paths" >/dev/null)
assert_status 2 "$?" "links_judge: a look for the heading that fails cannot be judged"

# --- md_block: the kind of each line, in order --------------------------------
kinds() { printf '%s\n' "$@" | links_md '{ printf "%s ", md_block($0) }'; }
assert_eq "fence fence fence " "$(kinds '   ```' 'x' '   ```')" "a fence indented by three spaces is a fence"
assert_eq "text atx " "$(kinds '#hashtag' '#')" "a # with no space after is text; a # alone is a heading"
assert_eq "break blank break " "$(kinds '* * *' '' '___')" "a line of three *, _ or - marks is a thematic break"
assert_eq "item lazy lazy " "$(kinds '- an item' 'its next line' 'and the next')" "a line after an item continues it"
assert_eq "text text blank code " "$(kinds 'a paragraph' '    still it' '' '    code')" \
  "an indented line continues a paragraph, and after a blank line is code"
assert_eq "front front front text " "$(kinds '---' 'a: b' '...' 'text')" "frontmatter runs from a first --- to ... or ---"
assert_eq "text blank under " "$(kinds 'text' '' '---')" "a --- after a blank line is no frontmatter"
# A closing fence is the opening fence's character, at least as many times,
# with nothing after it but blanks (CommonMark 4.5; conformance N2 of S2's
# third ship gate).
assert_eq "fence fence fence fence text " "$(kinds '~~~' '```' 'x' '~~~' 'y')" "a tilde fence holds a backtick line"
assert_eq "fence fence fence fence text " "$(kinds '```' '~~~' '# h' '```' 'y')" "a backtick fence holds a tilde line"
assert_eq "fence fence fence fence text " "$(kinds '````' '```' 'x' '````' 'y')" "a longer fence holds a shorter one"
assert_eq "fence fence fence text " "$(kinds '```' 'x' '`````' 'y')" "a longer run closes a fence"
assert_eq "fence fence fence fence text " "$(kinds '~~~' '~~~ sh' 'x' '~~~ ' 'y')" \
  "a line with an info string closes none, and trailing blanks do not count"
# Frontmatter needs its closing line; without one, its --- is no frontmatter
# (conformance N3).
assert_eq "under text text " "$(kinds '---' 'a: b' 'text')" "an unclosed --- is no frontmatter"
assert_eq "front front text " "$(kinds '---' '---' 'text')" "an empty frontmatter is closed by the next ---"

# --- md_spans: each code span blanked, an unclosed run kept -------------------
spans() { printf '%s\n' "$1" | links_md '{ print md_spans($0) }'; }
assert_eq "a     c" "$(spans 'a `b` c')" "a code span becomes as many spaces"
assert_eq "a \`b c" "$(spans 'a `b c')" "a run with no closing run is text"

# --- links_anchors: GitHub's anchors ------------------------------------------
anchors() { printf '%s\n' "$@" | links_anchors | tr '\n' ' '; }
assert_eq "see-the-docs " "$(anchors '## See [the docs](x.md)')" "a heading's inline link keeps its text"
assert_eq "see-the-docs " "$(anchors '## See [the docs][d]')" "a heading's reference link keeps its text"
assert_eq "a-b-c " "$(anchors '## A <b>b</b> *c*')" "HTML tags and * go"
assert_eq "a_x_ " "$(anchors '## a*_x_')" "a * goes before the _ runs are read, so an _ after a letter stays"
assert_eq "café " "$(anchors '## Café')" "a byte above 0x7f is kept, as a letter"
assert_eq "café_x_ " "$(anchors '## Café_x_')" "an _ after such a byte is inside a word, and stays"
assert_eq "title " "$(anchors '## Title ##')" "closing #s go"

# --- links_targets: targets, inline and by reference --------------------------
targets() { printf '%s\n' "$@" | links_targets | tr '\t\n' ': '; }
assert_eq "1:x.md " "$(targets '[a](x.md "A title")')" "an inline target loses its title"
assert_eq "1:one.md 3:one.md " "$(targets '[a]: one.md' '[a]: two.md' '[it][a]')" \
  "a label's first definition is the one it gives"
assert_eq "1:d.md 2:t.md " "$(targets '[text]: d.md' '[text](t.md)')" "an inline link is not also a reference"
assert_eq "1:x.md 2:x.md " "$(targets '[The  Label]: x.md' '[the label][]')" "a label folds case and spacing"
assert_eq "" "$(targets '---' '[a]: x.md' '---' '[it][a]')" "frontmatter holds no definition"
assert_eq "2:x.md " "$(targets '---' '[a](x.md)')" "an unclosed --- hides no link"
assert_eq "5:y.md " "$(targets '```' '~~~' '[a](x.md)' '```' '[b](y.md)')" "a mixed fence hides its links, and only them"
assert_eq "2	It never ends." "$(printf '%s\n' '---' 'It never ends.' | rules_lines trace)" "an unclosed --- hides no rule line"

# --- links_resolve: a target, relative to the file --------------------------------
assert_eq "docs/b.md" "$(links_resolve docs/a.md ./b.md)" "a . component goes"
links_resolve docs/a.md /etc/passwd >/dev/null
assert_status 1 "$?" "a target from the root is not judged"

# --- links_judge: what it does not judge, and the top -----------------------------
fixture_write "$R/top.md" "See [the web](https://example.org), [the top](.) and [an anchor](#top).

# Top"
fixture_commit "$R" "test: links it does not judge, and the top"
paths=$(cd "$R" && tree_list worktree | sed 's/^[^	]*	//')
(cd "$R" && links_judge worktree top.md "$paths")
assert_status 0 "$?" "links_judge: a link that is not relative is not judged, and . is the top"

# --- rules: the words, and what names a check -------------------------------------
assert_eq "do not" "$(rules_word 'You do not push.')" "trace holds do not"
rules_word 'The BUSSTOP sign.' >/dev/null
assert_status 1 "$?" "STOP is a word only whole"
fixture_write "$R/claims.md" 'Pushes are refused by `bin/`.
Pushes are refused by `bin/check
Pushes are refused by `` bin/check ``.'
fixture_commit "$R" "test: code spans that name no check, and one that does"
OUT=$(cd "$R" && rules_claims worktree docs/ top.md)
assert_contains "$OUT" "claims.md:1:" "rules_claims: bin/ alone names no check"
assert_contains "$OUT" "claims.md:2:" "rules_claims: a backtick that opens no span names no check"
assert_not_contains "$OUT" "claims.md:3:" "rules_claims: a span's padding is not part of its path"

assert_done
