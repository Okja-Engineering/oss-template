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
#   --range BASE HEAD [CHECK...]  range mode; an empty or all-zero BASE is a
#                                 new ref, and so is an object id this clone
#                                 does not have (a remote's unfetched commit)
#   --staged [CHECK...]           staged mode
#   commit-msg FILE               commit-msg mode
#   pr                            pr mode (PR_TITLE, PR_BODY)
#   CHECK... --report             report mode
#   --list                        each check and its description
# Exit 0 when every check passes, 1 on a refusal, 2 when any check or the
# dispatcher itself cannot run (outside a repository, an unknown check or
# option, no checks directory, a check whose third line names no mode or an
# unknown one): a check it cannot schedule is never "nothing ran".
# Each status a guard reads is its own, never the caller's pipefail.

dispatch_main() {
  local dir=$1 mode=tree base="" head="" msg="" arg top named=0
  local -a names=()
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
      *)
        names+=("$arg")
        named=1
        ;;
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
  dispatch__run "$dir" "$mode" "$named" ${names[@]+"${names[@]}"}
}

# dispatch__bases MODE BASE HEAD: export CHECK_BASE, CHECK_HEAD, CHECK_REF
# and DOCS_BASE for MODE. Exit 2 on a HEAD that is not a commit, a BASE that
# names no commit and is not an object id, or a git failure.
dispatch__bases() {
  local mode=$1 base=$2 head=$3 at up commits newref=1
  # Each lookup's 1 is "none": an unborn HEAD, no upstream, no merge base, a
  # root with no parent. Any higher status is git failing, never that none
  # (decision 228).
  at=$(git rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null)
  case $? in
    0) ;;
    1) at="" ;;
    *)
      printf 'bin/check: cannot read HEAD\n' >&2
      return 2
      ;;
  esac
  CHECK_REF=${CHECK_REF:-}
  CHECK_REF=${CHECK_REF#refs/heads/}
  CHECK_BASE="" CHECK_HEAD=$at DOCS_BASE=""
  case "$mode" in
    tree | report)
      # Commits over @{upstream}..HEAD, docs base their merge base; without
      # an upstream, docs base HEAD.
      CHECK_BASE=$at DOCS_BASE=$at
      if [ -n "$at" ]; then
        up=$(git rev-parse -q --verify '@{upstream}^{commit}' 2>/dev/null)
        case $? in
          0)
            CHECK_BASE=$up
            dispatch__merge_base "$up" "$at" || return 2
            ;;
          1) ;;
          *)
            printf 'bin/check: cannot read the upstream of HEAD\n' >&2
            return 2
            ;;
        esac
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
          CHECK_BASE=$(git rev-parse -q --verify "$base^{commit}" 2>/dev/null)
          case $? in
            0) ;;
            1) CHECK_BASE="" ;;
            *)
              printf 'bin/check: cannot read BASE %s\n' "$base" >&2
              return 2
              ;;
          esac
          if [ -n "$CHECK_BASE" ]; then
            dispatch__merge_base "$CHECK_BASE" "$CHECK_HEAD" || return 2
            newref=0
          elif dispatch__object_id "$base"; then
            # The remote moved to a commit this clone never fetched, so what
            # it holds is unknown here: judge HEAD as a new ref.
            printf 'bin/check: BASE %s is not in this clone; judging %s as a new ref\n' \
              "$base" "$head" >&2
            CHECK_BASE=""
          else
            printf 'bin/check: BASE is not a commit: %s\n' "$base" >&2
            return 2
          fi
          ;;
      esac
      if [ "$newref" = 1 ]; then
        # A new ref: the checked commits are those on no remote ref but
        # CHECK_REF, and the docs base is the parent of the oldest; a root
        # has none. With nothing to check, nothing changed since HEAD.
        commits=$(dispatch_checked_commits "$CHECK_HEAD") || {
          printf 'bin/check: could not list the commits %s adds\n' "$head" >&2
          return 2
        }
        if [ -z "$commits" ]; then
          DOCS_BASE=$CHECK_HEAD
        else
          # The oldest is the first line; a root has no parent.
          DOCS_BASE=$(git rev-parse -q --verify "${commits%%[!0-9a-f]*}^" 2>/dev/null)
          case $? in
            0) ;;
            1) DOCS_BASE="" ;;
            *)
              printf 'bin/check: cannot read the parent of %s\n' "${commits%%[!0-9a-f]*}" >&2
              return 2
              ;;
          esac
        fi
      fi
      ;;
  esac
  export CHECK_BASE CHECK_HEAD CHECK_REF DOCS_BASE
}

# dispatch__merge_base A B: DOCS_BASE, the merge base of A and B, or none
# when they have none (git's 1); exit 2 when git fails.
dispatch__merge_base() {
  DOCS_BASE=$(git merge-base "$1" "$2" 2>/dev/null)
  case $? in
    0) ;;
    1) DOCS_BASE="" ;;
    *)
      printf 'bin/check: cannot read the merge base of %s and %s\n' "$1" "$2" >&2
      return 2
      ;;
  esac
}

# dispatch_checked_commits HEAD: for a range with no BASE, the commits
# reachable from HEAD and from no remote ref other than CHECK_REF, oldest
# first. Symbolic remote refs (origin/HEAD) alias real ones and are skipped.
# Exit nonzero when git fails.
dispatch_checked_commits() {
  local head=$1 want=${CHECK_REF:-} refs ref sym
  local -a exclude=()
  want=${want#refs/heads/}
  refs=$(git for-each-ref --format='%(refname) %(symref)' refs/remotes/) || return 2
  while read -r ref sym; do
    [ -n "$ref" ] || continue
    [ -z "$sym" ] || continue
    [ -n "$want" ] && [ "${ref#refs/remotes/*/}" = "$want" ] && continue
    exclude+=("^$ref")
  done <<EOF
$refs
EOF
  git rev-list --topo-order --reverse "$head" ${exclude[@]+"${exclude[@]}"}
}

# dispatch__object_id WORD: WORD is a full object id (SHA-1 or SHA-256).
dispatch__object_id() {
  case "$1" in *[!0-9a-f]*) return 1 ;; esac
  [ "${#1}" -eq 40 ] || [ "${#1}" -eq 64 ]
}

# dispatch__run DIR MODE NAMED [NAME...]: run the NAMEs given (NAMED is 1),
# or every check whose modes include MODE; print ok or FAIL per check with
# its output. A name is taken as given, never split or expanded.
dispatch__run() {
  local dir=$1 mode=$2 named=$3 name file modes out st worst=0 ran=0 failed=0
  local -a selected=()
  shift 3
  [ -d "$dir" ] || { printf 'bin/check: no checks directory: %s\n' "$dir" >&2; return 2; }
  if [ "$named" = 0 ]; then
    for file in "$dir"/*; do
      [ -f "$file" ] && set -- "$@" "${file##*/}"
    done
  fi
  for name in "$@"; do
    file="$dir/$name"
    case "$name" in '' | */* | .*) file="" ;; esac
    if [ -z "$file" ] || [ ! -f "$file" ]; then
      printf 'bin/check: unknown check: %s\n' "$name" >&2
      return 2
    fi
    modes=$(dispatch__header "$file" modes) ||
      { dispatch__bad_modes "$name"; return 2; }
    case " $modes " in
      *" $mode "*) selected+=("$name") ;;
      *)
        if [ "$named" = 1 ]; then
          printf 'bin/check: %s does not run in %s mode\n' "$name" "$mode" >&2
          return 2
        fi
        ;;
    esac
  done

  for name in ${selected[@]+"${selected[@]}"}; do
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
    [ -z "$out" ] || sed 's/^/  /' <<<"$out"
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
    modes:'# modes: '?*) dispatch__modes "${line#'# modes: '}" ;;
    *) return 1 ;;
  esac
}

DISPATCH_MODES="tree staged range commit-msg pr report"

# dispatch__modes WORDS: WORDS, space-separated, when there is at least one
# and each is a mode; exit 1 otherwise.
dispatch__modes() {
  local word known=""
  while IFS= read -r word; do
    [ -n "$word" ] || continue
    case " $DISPATCH_MODES " in
      *" $word "*) known="$known $word" ;;
      *) return 1 ;;
    esac
  done <<EOF
${1// /
}
EOF
  [ -n "$known" ] || return 1
  printf '%s\n' "${known# }"
}

dispatch__bad_modes() {
  printf 'bin/check: %s: the third line is not "# modes: " and one or more of: %s\n' \
    "$1" "$DISPATCH_MODES" >&2
}

dispatch__list() {
  local file desc
  [ -d "$1" ] || { printf 'bin/check: no checks directory: %s\n' "$1" >&2; return 2; }
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
