# shellcheck shell=bash
# The check dispatcher (C4), given one directory of checks. A check is an
# executable file there whose second line is `# <description>` and third
# `# modes: <modes>`; it runs, at the top of the work tree, in each mode it
# lists, with CHECK_MODE, CHECK_BASE, CHECK_HEAD, CHECK_REF, DOCS_BASE and
# (in commit-msg mode) CHECK_MSG_FILE set, and exits 0 to pass, 1 to refuse,
# 2 when it cannot run.
#
# usage: . dispatch.sh; dispatch_main CHECKS_DIR [ARGS...]
#   [CHECK...]                    tree mode
#   --range BASE HEAD [CHECK...]  range mode; an empty or all-zero BASE is a new ref
#   --staged [CHECK...]           staged mode
#   commit-msg FILE               commit-msg mode
#   pr                            pr mode (PR_TITLE, PR_BODY)
#   CHECK... --report             report mode
#   --list                        each check and its description
# Exit 0 when every check passes, 1 on a refusal, 2 when any check or the
# dispatcher itself cannot run (outside a repository, an unknown check or
# option).

dispatch_main() {
  local dir=$1 mode=tree base="" head="" names="" msg="" arg top
  shift
  export LC_ALL=C

  case "${1:-}" in
    --list)
      [ "$#" -eq 1 ] || { dispatch__usage "--list takes nothing else"; return 2; }
      dispatch__list "$dir"
      return $?
      ;;
    --range)
      [ "$#" -ge 3 ] || { dispatch__usage "--range needs BASE and HEAD"; return 2; }
      mode=range base=$2 head=$3
      shift 3
      ;;
    --staged)
      mode=staged
      shift
      ;;
    commit-msg)
      [ "$#" -eq 2 ] || { dispatch__usage "commit-msg takes one FILE"; return 2; }
      mode=commit-msg msg=$2
      shift 2
      ;;
    pr)
      [ "$#" -eq 1 ] || { dispatch__usage "pr takes nothing else"; return 2; }
      mode='pr'
      shift
      ;;
  esac
  for arg in "$@"; do
    case "$arg" in
      --report)
        [ "$mode" = tree ] || [ "$mode" = report ] ||
          { dispatch__usage "--report does not combine with $mode mode"; return 2; }
        mode=report
        ;;
      -*) dispatch__usage "unknown option: $arg"; return 2 ;;
      *) names="$names $arg" ;;
    esac
  done

  if [ -n "$msg" ]; then
    case "$msg" in /*) ;; *) msg="$PWD/$msg" ;; esac
    [ -f "$msg" ] || { printf 'bin/check: no such message file: %s\n' "$msg" >&2; return 2; }
  fi
  top=$(git rev-parse --show-toplevel 2>/dev/null) ||
    { printf 'bin/check: not inside a git repository\n' >&2; return 2; }
  cd "$top" || return 2

  dispatch__bases "$mode" "$base" "$head" || return 2
  export CHECK_MODE=$mode CHECK_MSG_FILE=$msg
  dispatch__run "$dir" "$mode" "$names"
}

# dispatch__bases MODE BASE HEAD: export CHECK_BASE, CHECK_HEAD, CHECK_REF
# and DOCS_BASE for MODE. Exit 2 on a BASE or HEAD that is not a commit.
dispatch__bases() {
  local mode=$1 base=$2 head=$3 at up oldest
  at=$(git rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null) || at=""
  CHECK_REF=${CHECK_REF:-}
  CHECK_REF=${CHECK_REF#refs/heads/}
  CHECK_BASE="" CHECK_HEAD=$at DOCS_BASE=""
  case "$mode" in
    tree | report)
      # Commits over @{upstream}..HEAD, docs base their merge base; without
      # an upstream, docs base HEAD.
      CHECK_BASE=$at DOCS_BASE=$at
      if [ -n "$at" ] && up=$(git rev-parse -q --verify '@{upstream}^{commit}' 2>/dev/null); then
        CHECK_BASE=$up
        DOCS_BASE=$(git merge-base "$up" "$at" 2>/dev/null) || DOCS_BASE=""
      fi
      ;;
    staged)
      CHECK_BASE=$at DOCS_BASE=$at
      ;;
    range)
      CHECK_HEAD=$(git rev-parse -q --verify "$head^{commit}" 2>/dev/null) ||
        { printf 'bin/check: HEAD is not a commit: %s\n' "$head" >&2; return 2; }
      case "$base" in
        *[!0]*)
          CHECK_BASE=$(git rev-parse -q --verify "$base^{commit}" 2>/dev/null) ||
            { printf 'bin/check: BASE is not a commit: %s\n' "$base" >&2; return 2; }
          DOCS_BASE=$(git merge-base "$CHECK_BASE" "$CHECK_HEAD" 2>/dev/null) || DOCS_BASE=""
          ;;
        *)
          # A new ref: the checked commits are those on no remote ref but
          # CHECK_REF, and the docs base is the parent of the oldest; a root
          # has none. With nothing to check, nothing changed since HEAD.
          oldest=$(dispatch_checked_commits "$CHECK_HEAD" | head -n 1)
          if [ -z "$oldest" ]; then
            DOCS_BASE=$CHECK_HEAD
          else
            DOCS_BASE=$(git rev-parse -q --verify "$oldest^" 2>/dev/null) || DOCS_BASE=""
          fi
          ;;
      esac
      ;;
  esac
  export CHECK_BASE CHECK_HEAD CHECK_REF DOCS_BASE
}

# dispatch_checked_commits HEAD: for a range with no BASE, the commits
# reachable from HEAD and from no remote ref other than CHECK_REF, oldest
# first. Symbolic remote refs (origin/HEAD) alias real ones and are skipped.
dispatch_checked_commits() {
  local head=$1 want=${CHECK_REF:-} ref sym exclude=""
  want=${want#refs/heads/}
  while read -r ref sym; do
    [ -n "$ref" ] || continue
    [ -z "$sym" ] || continue
    [ -n "$want" ] && [ "${ref#refs/remotes/*/}" = "$want" ] && continue
    exclude="$exclude ^$ref"
  done <<EOF
$(git for-each-ref --format='%(refname) %(symref)' refs/remotes/)
EOF
  # shellcheck disable=SC2086 # ref names hold no whitespace
  git rev-list --topo-order --reverse "$head" $exclude
}

# dispatch__run DIR MODE NAMES: run the named checks, or every check whose
# modes include MODE; print ok or FAIL per check with its output.
dispatch__run() {
  local dir=$1 mode=$2 names=$3 all="" name file modes selected="" out st worst=0 ran=0 failed=0
  if [ -d "$dir" ]; then
    for file in "$dir"/*; do
      [ -f "$file" ] && all="$all ${file##*/}"
    done
  fi
  for name in ${names:-$all}; do
    file="$dir/$name"
    case "$name" in */* | .*) file="" ;; esac
    if [ -z "$file" ] || [ ! -f "$file" ]; then
      printf 'bin/check: unknown check: %s\n' "$name" >&2
      return 2
    fi
    modes=$(dispatch__header "$file" modes) ||
      { printf 'bin/check: %s has no "# modes:" third line\n' "$name" >&2; return 2; }
    case " $modes " in
      *" $mode "*) selected="$selected $name" ;;
      *)
        if [ -n "$names" ]; then
          printf 'bin/check: %s does not run in %s mode\n' "$name" "$mode" >&2
          return 2
        fi
        ;;
    esac
  done

  for name in $selected; do
    ran=$((ran + 1))
    out=$("$dir/$name" 2>&1 </dev/null)
    st=$?
    case "$st" in
      0) printf 'ok %s\n' "$name" ;;
      1) printf 'FAIL %s\n' "$name" ;;
      *)
        st=2
        printf 'FAIL %s (could not run)\n' "$name"
        ;;
    esac
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/  /'
    [ "$st" -eq 0 ] || failed=$((failed + 1))
    [ "$st" -gt "$worst" ] && worst=$st
  done

  if [ "$ran" -eq 0 ]; then
    printf 'bin/check: no checks run in %s mode\n' "$mode"
  else
    printf 'bin/check: %d checks in %s mode, %d failed\n' "$ran" "$mode" "$failed"
  fi
  return "$worst"
}

# dispatch__header FILE desc|modes: the description or the modes a check
# declares; exit 1 when its header is malformed.
dispatch__header() {
  local line
  case "$2" in
    desc) line=$(sed -n '2p' "$1") ;;
    modes) line=$(sed -n '3p' "$1") ;;
  esac
  case "$2:$line" in
    desc:'# '?*) printf '%s\n' "${line#'# '}" ;;
    modes:'# modes: '?*) printf '%s\n' "${line#'# modes: '}" ;;
    *) return 1 ;;
  esac
}

dispatch__list() {
  local file desc
  [ -d "$1" ] || return 0
  for file in "$1"/*; do
    [ -f "$file" ] || continue
    desc=$(dispatch__header "$file" desc) || desc="(no description)"
    printf '%-16s %s\n' "${file##*/}" "$desc"
  done
}

dispatch__usage() {
  printf 'bin/check: %s\n' "$1" >&2
  printf 'usage: bin/check [CHECK...] | --range BASE HEAD [CHECK...] | --staged [CHECK...]\n' >&2
  printf '       | commit-msg FILE | pr | CHECK... --report | --list\n' >&2
}
