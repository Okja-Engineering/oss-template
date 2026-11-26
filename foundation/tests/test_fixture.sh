#!/usr/bin/env bash
# The fixture library builds a minimal valid repository holding every file
# the contracts C1-C4 need, and a mutation that changes nothing is reported
# rather than leaving a test that proves nothing.
set -u
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/assert.sh
. "$TEST_DIR/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=lib/fixture.sh
. "$TEST_DIR/lib/fixture.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
R="$SCRATCH/repo"
fixture_repo "$R"

# --- C1, C2: chain docs with status lines, and the deciders they name -------
for f in GOVERNANCE.md docs/work/0001-example/intent.md docs/adr/0001-example.md \
  docs/rfcs/0001-example.md; do
  assert_file_exists "$R/$f" "the fixture holds $f"
done
assert_contains "$(cat "$R/GOVERNANCE.md")" "## Deciders" "GOVERNANCE.md has § Deciders"
for f in docs/work/0001-example/intent.md docs/adr/0001-example.md docs/rfcs/0001-example.md; do
  line=$(head -n 5 "$R/$f" | grep '^\*\*Status:\*\* ' || true)
  assert_contains "$line" "**Decider:** A Person" "$f has a C1 status line naming a listed decider"
done

# --- C3: one file of each frontmatter kind ----------------------------------
for f in .claude/rules/docs.md .claude/skills/example/SKILL.md .claude/agents/example.md; do
  assert_file_exists "$R/$f" "the fixture holds $f"
  assert_eq "---" "$(head -n 1 "$R/$f")" "$f opens with frontmatter"
done

# --- C4: a committed repository on main with an upstream --------------------
assert_eq "main" "$(git -C "$R" symbolic-ref --short HEAD)" "the fixture is on main"
assert_eq "origin/main" "$(git -C "$R" rev-parse --abbrev-ref '@{upstream}' 2>&1)" \
  "main tracks origin/main"
assert_eq "$(git -C "$R" rev-parse HEAD)" "$(git -C "$R" rev-parse origin/main)" \
  "origin/main is at HEAD"
assert_eq "" "$(git -C "$R" status --porcelain)" "the fixture's working tree is clean"
if [ -d "$FIXTURE_FOUNDATION/bin" ]; then
  diff -r "$FIXTURE_FOUNDATION/bin" "$R/bin" >/dev/null 2>&1
  assert_status 0 "$?" "the fixture carries the product's bin/"
else
  assert_eq "absent" "$([ -e "$R/bin" ] && echo present || echo absent)" \
    "with no product bin/ yet, the fixture has none"
fi

# --- the product's checks pass the fixture as built -------------------------
assert_eq "@AGENTS.md" "$(cat "$R/CLAUDE.md")" "CLAUDE.md imports AGENTS.md"
if [ -x "$R/bin/check" ]; then
  (cd "$R" && bin/check >/dev/null 2>&1)
  assert_status 0 "$?" "bin/check passes the fixture"
fi

# --- the caller's git configuration does not leak in -----------------------
assert_eq "/dev/null" "${GIT_CONFIG_GLOBAL:-}" "global git configuration is ignored"

# A fixture built by a caller carrying a hook's GIT_DIR, a git ignore file
# under XDG_CONFIG_HOME, a ~/.gitconfig and a template whose pre-commit hook
# refuses everything is still its own clean repository.
E="$SCRATCH/env"
mkdir -p "$E/xdg/git" "$E/home" "$E/template/hooks"
printf 'untracked.txt\n' >"$E/xdg/git/ignore"
printf '[core]\n\texcludesFile = %s/xdg/git/ignore\n' "$E" >"$E/home/.gitconfig"
printf '#!/bin/sh\nexit 1\n' >"$E/template/hooks/pre-commit"
chmod +x "$E/template/hooks/pre-commit"
out=$(GIT_DIR="$R/.git" XDG_CONFIG_HOME="$E/xdg" HOME="$E/home" GIT_TEMPLATE_DIR="$E/template" bash -c '
  . "$1/lib/assert.sh"
  . "$1/lib/fixture.sh"
  fixture_repo "$2/iso" >/dev/null 2>&1 || echo "fixture_repo failed"
  printf "git dir: %s\n" "$(cd "$(git -C "$2/iso" rev-parse --absolute-git-dir)" && pwd -P)"
  printf x >"$2/iso/untracked.txt"
  printf "untracked: %s\n" "$(git -C "$2/iso" ls-files -o --exclude-standard)"
' _ "$TEST_DIR" "$E" 2>&1)
assert_not_contains "$out" "fixture_repo failed" "a template's hooks are not installed in a fixture"
assert_contains "$out" "git dir: $(cd "$E" && pwd -P)/iso/.git" "an inherited GIT_DIR does not redirect a fixture"
assert_contains "$out" "untracked: untracked.txt" "the caller's git ignore files are not read"
assert_eq "" "$(CHECK_REF=main bash -c '. "$1"; printf %s "${CHECK_REF:-}"' _ "$TEST_DIR/lib/fixture.sh")" \
  "an inherited CHECK_REF is unset"
# Every inherited GIT_* goes, the trace and pathspec ones among them, so a
# caller's GIT_TRACE=1 adds nothing to a git the suites run.
out=$(GIT_TRACE=1 GIT_TRACE_PERFORMANCE=1 GIT_ICASE_PATHSPECS=1 bash -c '
  . "$1/lib/assert.sh"
  . "$1/lib/fixture.sh"
  printf "%s %s %s\n" "${GIT_TRACE-unset}" "${GIT_TRACE_PERFORMANCE-unset}" "${GIT_ICASE_PATHSPECS-unset}"
  git --version
' _ "$TEST_DIR" 2>&1)
assert_eq "unset unset unset
$(git --version)" "$out" "an inherited GIT_TRACE, GIT_TRACE_PERFORMANCE and GIT_ICASE_PATHSPECS are unset"

# --- mutations that change something pass -----------------------------------
fixture_replace "$R/GOVERNANCE.md" "- A Person" "- Another Person"
assert_contains "$(cat "$R/GOVERNANCE.md")" "- Another Person" "fixture_replace changes the file"
fixture_write "$R/new.md" "text"
assert_eq "text" "$(cat "$R/new.md")" "fixture_write writes the file"
fixture_append "$R/new.md" "more"
assert_eq "$(printf 'text\nmore')" "$(cat "$R/new.md")" "fixture_append adds a line"
fixture_chmod +x "$R/new.md"
assert_eq "yes" "$([ -x "$R/new.md" ] && echo yes || echo no)" "fixture_chmod sets the bit"
fixture_remove "$R/new.md"
assert_eq "gone" "$([ -e "$R/new.md" ] && echo here || echo gone)" "fixture_remove removes it"

# --- a mutation that changes nothing is reported, and fails its suite -------
# Each no-op runs, inside the fixture, in a suite of its own (one control
# assertion that passes), which must exit 1 naming the file.
# The suite takes its paths as arguments, never pasted into its source.
noop() {
  local suite="$SCRATCH/noop_suite.sh"
  # shellcheck disable=SC2016 # expanded by the generated suite, not here
  printf '%s\n' '#!/usr/bin/env bash' 'set -u' 'lib=$1 dir=$2' 'shift 2' \
    '. "$lib/assert.sh"' '. "$lib/fixture.sh"' 'cd "$dir" || exit 2' '"$@"' \
    'assert_eq a a control' 'assert_done' >"$suite"
  bash "$suite" "$TEST_DIR/lib" "$R" "$@" 2>&1
}
out=$(noop fixture_replace GOVERNANCE.md "no such text" "x")
assert_status 1 "$?" "replacing absent text fails the suite"
assert_contains "$out" "mutation changed nothing: GOVERNANCE.md" "and names the file"
out=$(noop fixture_replace GOVERNANCE.md "Another" "Another")
assert_status 1 "$?" "replacing text with itself fails the suite"
out=$(noop fixture_write GOVERNANCE.md "$(cat "$R/GOVERNANCE.md")")
assert_status 1 "$?" "rewriting a file with its own content fails the suite"
out=$(noop fixture_chmod -x GOVERNANCE.md)
assert_status 1 "$?" "clearing a bit that is not set fails the suite"
out=$(noop fixture_remove no-such-file)
assert_status 1 "$?" "removing a missing file fails the suite"
assert_contains "$out" "mutation changed nothing: no-such-file" "and names the file"

assert_done
