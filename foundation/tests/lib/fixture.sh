# shellcheck shell=bash
# Fixtures for the suites: a minimal valid repository in a temporary
# directory, and mutations that fail when they change nothing, so a planted
# violation that silently did not land cannot pass as a test.
#
# usage: . fixture.sh (after assert.sh); fixture_repo DIR; fixture_replace ...
# Sourcing it isolates git from the caller's configuration and environment.

FIXTURE_FOUNDATION=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# Git in a fixture reads no global or system configuration, inherits no
# repository from its caller (a hook's GIT_DIR, say) and has an identity.
fixture__isolate() {
  local v
  for v in $(git rev-parse --local-env-vars); do
    unset "$v"
  done
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME='A Person' GIT_AUTHOR_EMAIL='person@example.invalid'
  export GIT_COMMITTER_NAME='A Person' GIT_COMMITTER_EMAIL='person@example.invalid'
}
fixture__isolate

# fixture_repo DIR: a repository on main, committed as `Initial commit`, with
# a bare remote at DIR-origin.git that main tracks. It holds what the
# contracts need: chain docs whose status lines name a decider in
# GOVERNANCE.md § Deciders (C1) under C2's names; one rule, skill and
# subagent with C3 frontmatter; and the product's bin/, when it has one (C4).
fixture_repo() {
  local dir=$1
  mkdir -p "$dir" || return 1
  git -C "$dir" init -q -b main || return 1

  fixture__put "$dir/GOVERNANCE.md" '# Governance' '' '## Deciders' '' '- A Person'
  fixture__put "$dir/docs/work/0001-example/intent.md" '# 0001 example: intent' '' \
    '**Status:** draft. **Decider:** A Person.'
  fixture__put "$dir/docs/adr/0001-example.md" '# 0001 Example' '' \
    '**Status:** proposed. **Decider:** A Person.' '' '## Context' '' '## Decision' '' \
    '## Consequences' '' '## Alternatives considered'
  fixture__put "$dir/docs/rfcs/0001-example.md" '# RFC 0001: example' '' \
    '**Status:** draft. **Decider:** A Person.'
  fixture__put "$dir/.claude/rules/docs.md" '---' 'paths:' '  - "docs/**"' \
    'source: "GOVERNANCE.md#deciders"' '---' '' 'A rule for documents.'
  fixture__put "$dir/.claude/skills/example/SKILL.md" '---' 'name: example' \
    'description: An example skill' '---' '' 'Steps.'
  fixture__put "$dir/.claude/agents/example.md" '---' 'name: example' \
    'description: An example subagent' 'tools: Read, Grep, Glob, Bash' '---' '' 'Instructions.'
  if [ -d "$FIXTURE_FOUNDATION/bin" ]; then
    cp -Rp "$FIXTURE_FOUNDATION/bin" "$dir/bin" || return 1
  fi

  git -C "$dir" add -A || return 1
  git -C "$dir" commit -q -m 'Initial commit' || return 1
  git init -q --bare -b main "$dir-origin.git" || return 1
  git -C "$dir" remote add origin "$dir-origin.git" || return 1
  git -C "$dir" push -q -u origin main 2>/dev/null || return 1
}

# fixture_commit DIR MESSAGE: stage everything in DIR and commit it.
fixture_commit() {
  git -C "$1" add -A && git -C "$1" commit -q -m "$2"
}

# fixture__put FILE LINE...: write the lines, creating directories.
fixture__put() {
  local file=$1
  shift
  mkdir -p "$(dirname "$file")" && printf '%s\n' "$@" >"$file"
}

# fixture__state FILE: what a mutation can change (presence, bit, bytes).
fixture__state() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    printf 'present %s %s' "$([ -x "$1" ] && echo x || echo -)" "$(cksum <"$1" 2>/dev/null)"
  else
    printf 'absent'
  fi
}

# fixture__changed BEFORE FILE: report a mutation that left FILE as it was.
fixture__changed() {
  [ "$1" != "$(fixture__state "$2")" ] && return 0
  if command -v assert_fail >/dev/null 2>&1; then
    assert_fail "fixture mutation changed nothing: $2"
  else
    printf 'fixture mutation changed nothing: %s\n' "$2" >&2
  fi
  return 1
}

# fixture_write FILE CONTENT: write CONTENT and a newline.
fixture_write() {
  local before
  before=$(fixture__state "$1")
  fixture__put "$1" "$2"
  fixture__changed "$before" "$1"
}

# fixture_append FILE LINE: add a line at the end.
fixture_append() {
  local before
  before=$(fixture__state "$1")
  printf '%s\n' "$2" >>"$1"
  fixture__changed "$before" "$1"
}

# fixture_replace FILE OLD NEW: replace the first OLD, matched literally.
fixture_replace() {
  local file=$1 old=$2 new=$3 before content head
  before=$(fixture__state "$file")
  content=$(cat "$file" 2>/dev/null && printf x)
  content=${content%x}
  head=${content%%"$old"*}
  if [ "$head" != "$content" ]; then
    printf '%s%s%s' "$head" "$new" "${content#*"$old"}" >"$file"
  fi
  fixture__changed "$before" "$file"
}

# fixture_remove FILE
fixture_remove() {
  local before
  before=$(fixture__state "$1")
  rm -f "$1"
  fixture__changed "$before" "$1"
}

# fixture_chmod +x|-x FILE
fixture_chmod() {
  local before
  before=$(fixture__state "$2")
  chmod "$1" "$2" 2>/dev/null
  fixture__changed "$before" "$2"
}
