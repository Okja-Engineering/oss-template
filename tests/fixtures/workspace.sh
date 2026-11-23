# shellcheck shell=bash
# A fixture workspace for the workspace's suites: a repository holding the
# workspace's bin/check, bin/setup and .githooks/, the product libraries they
# source, and only the fixture checks a suite names. Git is isolated by the
# product's fixture library, whose mutations the suites also use.
#
# usage: . tests/fixtures/workspace.sh; ws_fixture DIR [CHECK...]

WS_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source-path=SCRIPTDIR source=../../foundation/tests/lib/fixture.sh
. "$WS_ROOT/foundation/tests/lib/fixture.sh"

# ws_fixture DIR [CHECK...]: the fixture workspace, on main as `Initial
# commit`, with a bare remote at DIR-origin.git that main tracks.
ws_fixture() {
  local dir=$1 c
  shift
  mkdir -p "$dir/bin/checks" "$dir/foundation/bin/lib" || return 1
  git -C "$dir" init -q -b main || return 1
  cp -p "$WS_ROOT/bin/check" "$WS_ROOT/bin/setup" "$dir/bin/" 2>/dev/null
  if [ -d "$WS_ROOT/.githooks" ]; then
    cp -Rp "$WS_ROOT/.githooks" "$dir/.githooks" || return 1
  fi
  cp -p "$WS_ROOT"/foundation/bin/lib/*.sh "$dir/foundation/bin/lib/" || return 1
  for c in "$@"; do
    cp -p "$WS_ROOT/tests/fixtures/checks/$c" "$dir/bin/checks/$c" || return 1
  done
  fixture__put "$dir/judged.txt" 'good'
  fixture_commit "$dir" 'Initial commit' || return 1
  git init -q --bare -b main "$dir-origin.git" || return 1
  git -C "$dir" remote add origin "$dir-origin.git" || return 1
  git -C "$dir" push -q -u origin main 2>/dev/null || return 1
}
