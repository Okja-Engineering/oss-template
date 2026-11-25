#!/usr/bin/env bash
# bin/lib/git.sh (AC10): the one version gate, comparing major and minor
# numerically against 2.36 (decisions 143, 154), and the hermetic
# environment it builds.
set -u
set -o pipefail
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$TEST_DIR/../foundation/tests/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/git.sh
. "$TEST_DIR/../bin/lib/git.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/render.sh
. "$TEST_DIR/../bin/lib/render.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
REAL_GIT=$(command -v git)
mkdir "$SCRATCH/bin"
# A git that reports the version VERSION names and is the real git otherwise.
# shellcheck disable=SC2016 # the stub's text, expanded when it runs
printf '#!/bin/sh\nif [ "$1" = --version ]; then\n  [ "$VERSION" != fail ] || { echo "fatal: bad config line 1" >&2; exit 128; }\n  printf "git version %%s\\n" "$VERSION"; exit 0\nfi\nexec %s "$@"\n' \
  "$REAL_GIT" >"$SCRATCH/bin/git"
chmod +x "$SCRATCH/bin/git"

gate() { # VERSION: run the gate under a git reporting VERSION
  OUT=$(VERSION=$1 PATH="$SCRATCH/bin:$PATH" git_version_ok 2>&1)
  ST=$?
}
gate 2.35.9
assert_status 1 "$ST" "git 2.35.9 is refused"
assert_contains "$OUT" "2.36" "  and the refusal names the floor"
for v in 2.36.0 2.100.0 3.0.0 '2.50.1 (Apple Git-155)'; do
  gate "$v"
  assert_status 0 "$ST" "git $v is accepted"
done
gate 1.99.99
assert_status 1 "$ST" "git 1.99.99 is refused"
gate fail
assert_status 1 "$ST" "a git whose --version fails is refused"
assert_contains "$OUT" "git --version failed: fatal: bad config line 1" "  with git's own reason"
assert_not_contains "$OUT" "missing" "  and not as a missing git"
OUT=$(PATH=/nonexistent git_version_ok 2>&1)
assert_contains "$OUT" "git is missing" "a git not on PATH is reported missing"
for v in 'something else' '2' '2.3x' '2..36' '.36.0'; do
  gate "$v"
  assert_status 1 "$ST" "a version the gate cannot read, '$v', is refused"
  assert_contains "$OUT" "cannot read" "  as one it cannot read"
done

# The environment, built positively.
(
  export GIT_DIR=/planted GIT_INDEX_FILE=/planted GIT_WORK_TREE=/planted GIT_ATTR_SOURCE=HEAD
  export GIT_DEFAULT_HASH=sha256 GIT_AUTHOR_NAME=Planted GIT_AUTHOR_DATE=1 GIT_COMMITTER_EMAIL=planted@example.invalid
  export GIT_CONFIG_PARAMETERS="'core.fsmonitor'='true'" GIT_CONFIG_GLOBAL=/planted GIT_DEFAULT_REF_FORMAT=reftable
  git_hermetic
  for v in GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_ATTR_SOURCE GIT_DEFAULT_HASH GIT_AUTHOR_NAME \
    GIT_AUTHOR_DATE GIT_COMMITTER_EMAIL GIT_CONFIG_PARAMETERS; do
    printf '%s=%s\n' "$v" "${!v-unset}"
  done
  for v in GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM GIT_ATTR_NOSYSTEM GIT_NO_REPLACE_OBJECTS GIT_DEFAULT_REF_FORMAT; do
    printf '%s=%s\n' "$v" "${!v-unset}"
  done
  git config --get core.attributesFile
  git config --get core.excludesFile
  git config --get core.fileMode
  git config --get commit.gpgsign
  git config --get core.hooksPath
  git config --get core.fsmonitor
) >"$SCRATCH/env" 2>&1
ENV=$(cat "$SCRATCH/env")
for v in GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_ATTR_SOURCE GIT_DEFAULT_HASH GIT_AUTHOR_NAME \
  GIT_AUTHOR_DATE GIT_COMMITTER_EMAIL GIT_CONFIG_PARAMETERS; do
  assert_contains "$ENV" "$v=unset" "git_hermetic unsets $v"
done
assert_contains "$ENV" "GIT_CONFIG_GLOBAL=/dev/null" "it sets GIT_CONFIG_GLOBAL=/dev/null"
assert_contains "$ENV" "GIT_CONFIG_NOSYSTEM=1" "it sets GIT_CONFIG_NOSYSTEM=1"
assert_contains "$ENV" "GIT_ATTR_NOSYSTEM=1" "it sets GIT_ATTR_NOSYSTEM=1"
assert_contains "$ENV" "GIT_NO_REPLACE_OBJECTS=1" "it sets GIT_NO_REPLACE_OBJECTS=1"
assert_contains "$ENV" "GIT_DEFAULT_REF_FORMAT=files" "it pins GIT_DEFAULT_REF_FORMAT to files"
assert_eq "/dev/null
/dev/null
true
false
/dev/null
false" "$(printf '%s\n' "$ENV" | tail -n 6)" \
  "every git it starts reads core.attributesFile, core.excludesFile, core.fileMode, commit.gpgsign, core.hooksPath and core.fsmonitor from GIT_CONFIG_COUNT"

# Each setting, seen at work alone (decision 167): a git run under the
# environment, against a setting planted where it would otherwise apply.
# GIT_DEFAULT_HASH planted before: a repository made with no
# --object-format is SHA-1.
OUT=$(export GIT_DEFAULT_HASH=sha256 && git_hermetic &&
  git init -q --template= "$SCRATCH/hash" && git -C "$SCRATCH/hash" rev-parse --show-object-format 2>&1)
assert_eq "sha1" "$OUT" "GIT_DEFAULT_HASH planted before git_hermetic does not reach git init"
# --object-format=sha1, seen alone: under a git whose default is SHA-256,
# which GIT_DEFAULT_HASH set after the environment stands for, the
# fingerprint is still a SHA-1 tree id, 40 hex digits.
mkdir -p "$SCRATCH/fp" && printf 'x\n' >"$SCRATCH/fp/file"
OUT=$(git_hermetic && export GIT_DEFAULT_HASH=sha256 && render_fingerprint "$SCRATCH/fp" file)
assert_eq "40" "${#OUT}" "the fingerprint is a SHA-1 tree id under a git that defaults to SHA-256"

# The pathspec and trace variables, and every other GIT_* outside the recipe.
OUT=$(export GIT_ICASE_PATHSPECS=1 GIT_GLOB_PATHSPECS=1 GIT_TRACE=/dev/stdout GIT_PLANTED=x &&
  git_hermetic && printf '%s %s %s %s\n' "${GIT_ICASE_PATHSPECS-unset}" "${GIT_GLOB_PATHSPECS-unset}" \
  "${GIT_TRACE-unset}" "${GIT_PLANTED-unset}" && git --version)
assert_eq "unset unset unset unset
$(git --version)" "$OUT" "GIT_ICASE_PATHSPECS, GIT_GLOB_PATHSPECS, GIT_TRACE and any other GIT_* are unset"
# core.fileMode=false in a repository's own config: an executable is still
# added as 100755.
git init -q --template= "$SCRATCH/mode"
git -C "$SCRATCH/mode" config core.fileMode false
printf '#!/bin/sh\n' >"$SCRATCH/mode/tool"
chmod 755 "$SCRATCH/mode/tool"
OUT=$(git_hermetic && git -C "$SCRATCH/mode" add tool && git -C "$SCRATCH/mode" ls-files -s tool | cut -c1-6)
assert_eq "100755" "$OUT" "a repository's core.fileMode=false does not drop the executable bit"
# core.fsmonitor naming a hook in a repository's own config: not run.
git init -q --template= "$SCRATCH/fsm"
printf '#!/bin/sh\n: >"%s"\nexit 1\n' "$SCRATCH/fsm-ran" >"$SCRATCH/fsm-hook"
chmod +x "$SCRATCH/fsm-hook"
git -C "$SCRATCH/fsm" config core.fsmonitor "$SCRATCH/fsm-hook"
(GIT_CONFIG_GLOBAL=/dev/null git -C "$SCRATCH/fsm" status >/dev/null 2>&1)
assert_eq "yes" "$([ -e "$SCRATCH/fsm-ran" ] && echo yes)" "a planted core.fsmonitor hook runs without the environment"
rm -f "$SCRATCH/fsm-ran"
(git_hermetic && git -C "$SCRATCH/fsm" status >/dev/null 2>&1)
assert_eq "no" "$([ -e "$SCRATCH/fsm-ran" ] && echo yes || echo no)" "  and not under it"
# The system config and the system attributes file, planted as git would
# find them: neither is read.
printf '[core]\n\tautocrlf = true\n' >"$SCRATCH/system.gitconfig"
OUT=$(git_hermetic && export GIT_CONFIG_SYSTEM="$SCRATCH/system.gitconfig" && git config --get core.autocrlf)
assert_eq "" "$OUT" "a system config git would read is not read"
if git var GIT_ATTR_SYSTEM >/dev/null 2>&1; then
  OUT=$(git_hermetic && git var GIT_ATTR_SYSTEM 2>/dev/null)
  assert_eq "" "$OUT" "git names no system attributes file to read"
fi

assert_done
