#!/usr/bin/env bash
# The workspace's bin/setup sets core.hooksPath to .githooks, and a second
# run changes nothing.
set -u
export LC_ALL=C
TEST_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$TEST_DIR/../foundation/tests/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=fixtures/workspace.sh
. "$TEST_DIR/fixtures/workspace.sh"

SCRATCH=$(mktemp -d)
trap 'chmod -R u+w "$SCRATCH" 2>/dev/null; rm -rf "$SCRATCH"' EXIT
R="$SCRATCH/ws"
ws_fixture "$R"

out=$(cd / && "$R/bin/setup" 2>&1)
assert_status 0 "$?" "the first run exits 0"
assert_eq ".githooks" "$(git -C "$R" config --get core.hooksPath)" \
  "core.hooksPath is .githooks, set in the workspace even when run from elsewhere"

# A second run must not write: with .git read-only, any write would fail.
before=$(cksum <"$R/.git/config")
chmod a-w "$R/.git"
out=$("$R/bin/setup" 2>&1)
st=$?
chmod u+w "$R/.git"
assert_status 0 "$st" "the second run exits 0 without writing"
assert_eq ".githooks" "$(git -C "$R" config --get core.hooksPath)" "core.hooksPath is still .githooks"
assert_eq "$before" "$(cksum <"$R/.git/config")" "the second run leaves .git/config as it was"
assert_contains "$out" "already" "and says nothing needed doing"

assert_done
