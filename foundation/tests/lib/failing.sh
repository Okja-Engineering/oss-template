# shellcheck shell=bash
# A stub tool that fails one stage of one pipeline, so a suite sees a script
# refuse rather than judge or record what that stage did not produce. It
# changes nothing when sourced.
#
# usage: . failing.sh; fixture_failing DIR TOOL PATTERN [NTH [STATUS]]
#
# fixture_failing DIR TOOL PATTERN [NTH [STATUS]]: a stub TOOL in DIR, put
# first on PATH by the caller, that fails, exiting STATUS (1 by default)
# with its input read and nothing written, on the NTH call (the first by
# default) whose arguments, joined by spaces, match the glob PATTERN (escape
# a `[` as `\[`); every other call runs the real TOOL. The stub runs no tool
# by its name, so any TOOL, cat included, can be stubbed.
fixture_failing() {
  local real cat pat
  real=$(command -v "$2") || return 1
  cat=$(command -v cat) || return 1
  mkdir -p "$1" || return 1
  pat=$(printf '%s' "$3" | sed "s/'/'\\\\''/g") || return 1
  printf '#!/bin/sh\npat='"'"'%s'"'"'\ncase "$*" in\n  $pat)\n    n=0\n    [ ! -f "%s" ] || read -r n <"%s"\n    n=$((n + 1))\n    echo "$n" >"%s"\n    if [ "$n" = %s ]; then\n      [ -t 0 ] || "%s" >/dev/null\n      exit %s\n    fi\n    ;;\nesac\nexec "%s" "$@"\n' \
    "$pat" "$1/$2.count" "$1/$2.count" "$1/$2.count" "${4:-1}" "$cat" "${5:-1}" "$real" >"$1/$2" &&
    chmod +x "$1/$2"
}
