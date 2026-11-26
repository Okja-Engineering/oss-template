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

assert_done
