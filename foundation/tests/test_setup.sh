#!/usr/bin/env bash
# bin/setup points git at .githooks/, in the repository it belongs to, and a
# second run changes nothing.
set -u
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/assert.sh
. "$TEST_DIR/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=lib/fixture.sh
. "$TEST_DIR/lib/fixture.sh"

SCRATCH=$(mktemp -d)
trap 'chmod -R u+w "$SCRATCH" 2>/dev/null; rm -rf "$SCRATCH"' EXIT
R="$SCRATCH/repo"
fixture_repo "$R"

out=$(cd / && "$R/bin/setup" 2>&1)
assert_status 0 "$?" "bin/setup exits 0"
assert_eq ".githooks" "$(git -C "$R" config --get core.hooksPath)" \
  "core.hooksPath is .githooks, in its own repository even when run from elsewhere"

# A second run must not write: with .git read-only, any write would fail.
before=$(cksum <"$R/.git/config")
chmod a-w "$R/.git"
out=$("$R/bin/setup" 2>&1)
st=$?
chmod u+w "$R/.git"
assert_status 0 "$st" "a second run exits 0 without writing"
assert_eq "$before" "$(cksum <"$R/.git/config")" "a second run leaves .git/config as it was"
assert_contains "$out" "already" "and says nothing needed doing"

git -C "$R" config core.hooksPath /dev/null
"$R/bin/setup" >/dev/null 2>&1
assert_eq ".githooks" "$(git -C "$R" config --get core.hooksPath)" "another hooks path is replaced"

mkdir -p "$SCRATCH/nogit/bin"
cp -p "$R/bin/setup" "$SCRATCH/nogit/bin/setup"
out=$("$SCRATCH/nogit/bin/setup" 2>&1)
assert_status 2 "$?" "outside a git repository it exits 2"

# A caller's CDPATH does not move a script off its own directory: run by a
# relative path, `cd bin` must not resolve through CDPATH.
git -C "$R" config --unset core.hooksPath
out=$(cd "$R" && CDPATH=.:/nonexistent bin/setup 2>&1)
assert_status 0 "$?" "bin/setup run by a relative path under CDPATH exits 0"
assert_eq ".githooks" "$(git -C "$R" config --get core.hooksPath)" "  and sets core.hooksPath"

# The clone's own setting decides, not one inherited from the user's
# global config, which could change under it.
git -C "$R" config --unset core.hooksPath
printf '[core]\n\thooksPath = .githooks\n' >"$SCRATCH/global.gitconfig"
out=$(GIT_CONFIG_GLOBAL="$SCRATCH/global.gitconfig" "$R/bin/setup" 2>&1)
assert_eq ".githooks" "$(git -C "$R" config --local --get core.hooksPath)" \
  "a global core.hooksPath does not stand in for the clone's own"

assert_done
