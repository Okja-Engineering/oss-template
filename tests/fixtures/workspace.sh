# shellcheck shell=bash
# A fixture workspace for the workspace's suites: a repository holding the
# workspace's bin/check, bin/setup, bin/lib/ and .githooks/, the product
# libraries and bin/setup they call, and only the fixture checks a suite
# names. Git is
# isolated by the product's fixture library, whose mutations the suites also
# use.
#
# usage: . tests/fixtures/workspace.sh; ws_fixture DIR [CHECK...]
#        ws_real_check DIR NAME   (the workspace's own bin/checks/NAME)
#        ws_copy FROM DIR         (a built fixture, copied)
#        entry_ignored SIGNAL     (SIGNAL was ignored when the suite began)

WS_ROOT=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
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
  mkdir -p "$dir/bin/lib" || return 1
  cp -p "$WS_ROOT"/bin/lib/*.sh "$dir/bin/lib/" || return 1
  cp -p "$WS_ROOT/foundation/bin/setup" "$dir/foundation/bin/setup" || return 1
  for c in "$@"; do
    cp -p "$WS_ROOT/tests/fixtures/checks/$c" "$dir/bin/checks/$c" || return 1
  done
  fixture__put "$dir/judged.txt" 'good'
  fixture_commit "$dir" 'Initial commit' || return 1
  git init -q --bare -b main "$dir-origin.git" || return 1
  git -C "$dir" remote add origin "$dir-origin.git" || return 1
  git -C "$dir" push -q -u origin main 2>/dev/null || return 1
}

# entry_ignored SIGNAL: SIGNAL was ignored when the suite began, so no shell
# it starts can trap it (POSIX), as in a background job without job
# control, which ignores INT and QUIT, or under nohup, which ignores HUP. A
# case that sends it is skipped then, saying so (the tests lens's T2 of S2's
# fourth ship gate).
entry_ignored() { [ "$(sh -c "kill -s $1 \$\$; echo alive" 2>/dev/null)" = alive ]; }

# ws_copy FROM DIR: a copy of the fixture workspace FROM, and of its bare
# remote, at DIR and DIR-origin.git, DIR's origin being its own copy. A suite
# builds a fixture once and copies it for each case, rather than building
# the same repository again.
ws_copy() {
  cp -Rp "$1" "$2" && cp -Rp "$1-origin.git" "$2-origin.git" &&
    git -C "$2" remote set-url origin "$2-origin.git"
}

# ws_real_check DIR NAME: install the workspace's own check NAME, the code
# under test, into the fixture workspace's bin/checks/.
ws_real_check() {
  cp -p "$WS_ROOT/bin/checks/$2" "$1/bin/checks/$2" 2>/dev/null
}
