#!/usr/bin/env bash
# bin/lib/git.sh (AC10): the one version gate, comparing major and minor
# numerically against 2.36 (decisions 143, 154), and the hermetic
# environment it builds.
set -u
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$TEST_DIR/../foundation/tests/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/git.sh
. "$TEST_DIR/../bin/lib/git.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
REAL_GIT=$(command -v git)
mkdir "$SCRATCH/bin"
# A git that reports the version VERSION names and is the real git otherwise.
# shellcheck disable=SC2016 # the stub's text, expanded when it runs
printf '#!/bin/sh\nif [ "$1" = --version ]; then printf "git version %%s\\n" "$VERSION"; exit 0; fi\nexec %s "$@"\n' \
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
for v in 'something else' '2' '2.3x'; do
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

assert_done
