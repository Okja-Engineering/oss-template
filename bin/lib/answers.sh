# shellcheck shell=bash
# The one parser and validator of the field schema, shared/answers.tsv, and
# of answers files (AC6, AC7; decisions 107, 117, 149). bin/ask and the
# `setup` check, and later render, verify and publish, read through it.
#
# The schema is tab-separated, with the header
#   field scope type render selects pattern default question
# and one row per field: FIELD in capitals; scope `setup` or `run`; a type
# below; render `yes` or `no`; selects, the product path the field's value
# chooses a variant of; pattern, an extended regular expression the whole
# value matches too, or for a `select`, its values joined by `|`; default,
# where `{{FIELD}}` stands for another field's value; the question. A cell
# of `-` is empty.
#
# Types (AC6): name, text, description, list, select, owner, login-or-team,
# email-or-url, url, path. `identity` lands with verify (decision 145).
# Every value is one line of valid UTF-8 (decision 229): not empty, no
# control character, C0, DEL or C1 (a newline, a carriage return or a tab
# among them), no U+2028 or U+2029, and no `{{`; an answers file holds no
# NUL byte, so the validator judges the bytes every reader gets. A `select`
# value is exactly one of its listed values. `text`, `description`
# and `list` are free text: no email address (decisions 109, 114) and no
# word from foundation/bin/lib/rules.sh's lists (decision 73). A `list`
# value is its items joined by `,`, each trimmed and none empty. A GitHub
# login, in `owner`, `login-or-team` and `url`, is at most 39 characters,
# and a `url`'s repository is not `.` or `..`. A `path` value, with its `~`
# expanded, meets the rule every value meets and the path rule a TARGET
# meets (decision 227).
#
# An answers file holds one FIELD=value a line, the value everything after
# the first `=`. It is read as data, never sourced, so no value runs.
#
#   answers_schema_check SCHEMA [NAME]
#                                    one line out per fault, naming the file
#                                    NAME (SCHEMA by default), a field named
#                                    TARGET, a selects cell on a type other
#                                    than select and a default naming a
#                                    field not listed before it among them;
#                                    exit 0 or 1, above 1 when SCHEMA cannot
#                                    be read
#   answers_fields SCHEMA [SCOPE]    the fields, in order, one a line
#   answers_col SCHEMA FIELD COLUMN  a cell, `-` read as empty; exit 1 when
#                                    the schema has no FIELD, 2 when it has
#                                    no COLUMN or cannot be read
#   answers_check SCHEMA FIELD VALUE the reason VALUE is refused, if it is;
#                                    exit 0 when accepted, 1 when refused,
#                                    2, saying what, when it cannot be
#                                    judged
#   answers_path VALUE               a `path` value with its `~` expanded;
#                                    exit 1 when it starts with `~` and HOME
#                                    is unset or empty
#   answers_read FILE LABEL          the one reader of an answers file:
#                                    FILE's text out once the file-level
#                                    rule holds, no NUL byte; else the
#                                    reason, naming LABEL, out, exit 1, or 2
#                                    when FILE cannot be read
#   answers_given FILE LABEL         a file of the fields the operator gave
#                                    (setup/given.env, a run's given.env
#                                    and setup.override.env), read through
#                                    answers_read: its text out once each
#                                    line is FIELD=value, its FIELD once;
#                                    else the reason out, exit 1, or 2 when
#                                    it cannot be read. Each value is judged
#                                    where it is kept
#   answers_get FILE FIELD          FIELD's value in an answers file (`-`
#                                    for standard input, read whole, so a
#                                    writer on a pipe is never cut off), a
#                                    FILE judged by the file-level rule
#                                    first; exit 1 when it does not hold
#                                    FIELD, 2 when it cannot be read
#   answers_derive SCHEMA SCOPE GIVEN BASE
#                                    the SCOPE fields' answers lines, in
#                                    schema order: each the value GIVEN,
#                                    answers lines, holds, else its default,
#                                    worked out from BASE and the lines
#                                    before it (decision 229); else one
#                                    fault a line, naming the field, exit 1,
#                                    or 2 when one cannot be judged
#   answers_setup SCHEMA GIVEN       setup/answers.env's text, sorted: the
#                                    setup fields answers_derive gives from
#                                    GIVEN, setup/given.env's lines; else
#                                    the faults out, exiting as
#                                    answers_derive does
#   answers_setup_stale HAVE_GIVEN   the refusal of a setup/answers.env
#                                    other than answers_setup gives, naming
#                                    the step that mends it and keeps what
#                                    was given: HAVE_GIVEN 1 when
#                                    setup/given.env is there, 0 when it is
#                                    missing; bin/check setup's words and
#                                    bin/ask run's (decision 229)
#   answers_default SCHEMA FIELD PAIRS
#                                    FIELD's default, each `{{OTHER}}` in it
#                                    given OTHER's value in PAIRS, answers
#                                    file lines in a string; a `{{OTHER}}`
#                                    PAIRS lacks is left, for the validator;
#                                    exit 2 when a cell or a value cannot be
#                                    read
#   answers_validate SCHEMA FILE SCOPE [NAME]
#                                    the whole file, holding exactly the
#                                    fields of SCOPE (`setup`, or `run` for
#                                    every field and TARGET), each once and
#                                    valid; one line out per refusal, naming
#                                    the file NAME (FILE by default); exit 0
#                                    or 1, or 2 when it cannot be judged
#   answers_target VALUE             a TARGET's shape: absolute, not `/`
#                                    alone, with no empty, `.` or `..`
#                                    component, the rule a `path` value meets
#                                    once expanded; exit 0 or 1, or 2 when
#                                    it cannot be judged
#   answers_root_ok ROOT             ROOT, an expanded TARGET_ROOT, is at or
#                                    under no working tree of the workspace
#                                    this library is in: its deepest
#                                    existing ancestor, resolved physically
#                                    (`cd -P`), and each physical parent up
#                                    to /, is the same file (`-ef`) as none
#                                    of `git rev-parse --show-toplevel` and
#                                    the `worktree` entries of `git worktree
#                                    list --porcelain -z` not marked `bare`
#                                    or `prunable`, read through a pipe, so
#                                    it makes no file. Exit 0, or 1 with
#                                    the reason out, or 2 when git cannot
#                                    say or a directory on the way cannot
#                                    be entered. Run git_hermetic first
#   answers_target_for TARGET_ROOT NAME
#                                    a run's TARGET, exactly TARGET_ROOT with
#                                    its `~` expanded, then `/NAME`, under
#                                    the path rule answers_target holds it
#                                    to, the root under answers_root_ok's,
#                                    and the target itself at or above none
#                                    of those working trees: no working
#                                    tree, resolved physically, nor any of
#                                    its physical parents, is the same file
#                                    as the target; else the reason out,
#                                    exit 1, or 2 when it cannot be judged,
#                                    a directory on the way not entered
#   answers_target_check FILE NAME   the run answers FILE's TARGET is still
#                                    answers_target_for its TARGET_ROOT and
#                                    NAME, under this HOME: that TARGET out,
#                                    exit 0; else the reason out, exit 1, or
#                                    2 when FILE cannot be read
#   answers_record FILE KEY          the value of a run record's `KEY: `
#                                    line (confirmed.md, render.md); exit 1
#                                    when FILE has none, above 1 when it
#                                    cannot be read
#   answers_blob FILE                FILE's git blob id, its bytes as they
#                                    stand
#   answers_questionnaire SCHEMA     setup/questionnaire.md's text: the
#                                    setup fields' questions, in one flat
#                                    numbered list, each with its field,
#                                    type and default
#
# Every lookup whose 1 means "none" or "no" reads any higher status apart,
# as a failure, never as that answer, and a pipeline's status is each of
# its stages', whatever the caller's pipefail (decision 228). The caller
# exports LC_ALL=C.

ANSWERS_HEADER='field	scope	type	render	selects	pattern	default	question'
ANSWERS_TYPES='name text description list select owner login-or-team email-or-url url path'
ANSWERS_OWNER='[A-Za-z0-9](-?[A-Za-z0-9])*'
ANSWERS_EMAIL='[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}'
# Valid UTF-8 holding no C0 control, DEL or C1 control, byte by byte under
# LC_ALL=C: printable ASCII, then each well-formed sequence of two, three or
# four bytes, with no overlong form, surrogate or code point past U+10FFFF.
ANSWERS_UTF8=$'([\x20-\x7e]|\xc2[\xa0-\xbf]|[\xc3-\xdf][\x80-\xbf]|\xe0[\xa0-\xbf][\x80-\xbf]|[\xe1-\xec\xee\xef][\x80-\xbf][\x80-\xbf]|\xed[\x80-\x9f][\x80-\xbf]|\xf0[\x90-\xbf][\x80-\xbf][\x80-\xbf]|[\xf1-\xf3][\x80-\xbf][\x80-\xbf][\x80-\xbf]|\xf4[\x80-\x8f][\x80-\xbf][\x80-\xbf])*'
ANSWERS_LIB=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# The workspace this library is in, whose working trees no TARGET_ROOT is in.
ANSWERS_WS=$(CDPATH='' cd -- "$ANSWERS_LIB/../.." && pwd)
# rules.sh reads Markdown through links.sh's subset.
# shellcheck source-path=SCRIPTDIR source=../../foundation/bin/lib/links.sh
. "$ANSWERS_LIB/../../foundation/bin/lib/links.sh"
# shellcheck source-path=SCRIPTDIR source=../../foundation/bin/lib/rules.sh
. "$ANSWERS_LIB/../../foundation/bin/lib/rules.sh"

answers_schema_check() {
  H=$ANSWERS_HEADER T=" $ANSWERS_TYPES " L=${2:-$1} awk -F '\t' '
    function bad(why) { printf "%s:%d: %s\n", ENVIRON["L"], FNR, why; refused = 1 }
    FNR == 1 {
      if ($0 != ENVIRON["H"]) bad("the header is not: " ENVIRON["H"])
      next
    }
    NF != 8 { bad("a row of " NF " cells, not 8: " $0); next }
    $1 !~ /^[A-Z][A-Z0-9_]*$/ { bad("a field name not in capitals: " $1) }
    $1 in seen { bad("the field " $1 " is listed twice") }
    { seen[$1] = 1 }
    $2 != "setup" && $2 != "run" { bad($1 ": an unknown scope " $2 ", not setup or run") }
    index(ENVIRON["T"], " " $3 " ") == 0 {
      if ($3 == "identity") bad($1 ": the type identity, which lands with verify at 3.1")
      else bad($1 ": an unknown type " $3)
    }
    $4 != "yes" && $4 != "no" { bad($1 ": a render column of " $4 ", not yes or no") }
    $3 == "select" && ($6 == "-" || $6 == "") { bad($1 ": a select with no values in its pattern column") }
    $1 == "TARGET" { bad("the field TARGET, which is a run file'"'"'s own line, not a field") }
    $5 != "-" && $5 != "" && $3 != "select" { bad($1 ": selects " $5 ", but only a select selects a path") }
    # A default names only fields listed before it, which are given first.
    {
      d = $7
      while (match(d, /[{][{][A-Z][A-Z0-9_]*[}][}]/)) {
        x = substr(d, RSTART + 2, RLENGTH - 4)
        if (!(x in before)) bad($1 ": a default naming {{" x "}}, which no earlier field is")
        d = substr(d, RSTART + RLENGTH)
      }
      before[$1] = 1
    }
    # An empty schema has no header line either.
    END {
      if (NR == 0) printf "%s:1: the header is not: %s\n", ENVIRON["L"], ENVIRON["H"]
      exit refused || NR == 0
    }' "$1"
}

answers_fields() {
  S=${2:-} awk -F '\t' 'NR > 1 && (ENVIRON["S"] == "" || $2 == ENVIRON["S"]) { print $1 }' "$1"
}

answers_col() {
  F=$2 C=$3 awk -F '\t' '
    NR == 1 {
      for (i = 1; i <= NF; i++) col[$i] = i
      if (!(ENVIRON["C"] in col)) {
        printf "answers: the schema has no column %s\n", ENVIRON["C"] >"/dev/stderr"
        nocol = 1
        exit
      }
      next
    }
    $1 == ENVIRON["F"] {
      v = $(col[ENVIRON["C"]])
      print (v == "-" ? "" : v)
      found = 1
      exit
    }
    END {
      if (nocol) exit 2
      exit !found
    }' "$1"
}

# shellcheck disable=SC2088 # a literal ~, matched and expanded here by hand
answers_path() {
  case "$1" in
    '~' | '~/'*) [ -n "${HOME:-}" ] || return 1 ;;
  esac
  case "$1" in
    '~') printf '%s\n' "$HOME" ;;
    '~/'*) printf '%s/%s\n' "$HOME" "${1#'~/'}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

answers_check() {
  local schema=$1 field=$2 v=$3 type pattern default item rest expanded
  type=$(answers_col "$schema" "$field" type)
  case $? in
    0) ;;
    1) answers__no "$field" "an unknown field" ;;
    *) answers__cannot "$field" "read its row of the schema" ;;
  esac || return
  # Every cell a rule reads has its status read (decision 228).
  if ! pattern=$(answers_col "$schema" "$field" pattern) || ! default=$(answers_col "$schema" "$field" default); then
    answers__cannot "$field" "read its row of the schema"
    return
  fi
  answers__value "$field" "$v" || return
  case "$type" in
    name)
      answers__want "$field" "$v" '[a-z0-9][a-z0-9._-]*' \
        "a name is lowercase letters, digits, ., _ and -, starting with a letter or digit" || return
      [ "${#v}" -le 100 ] || { answers__no "$field" "a name is at most 100 characters"; return; }
      case "$v" in *.git) answers__no "$field" "a name does not end .git"; return ;; esac
      ;;
    owner)
      answers__want "$field" "$v" "$ANSWERS_OWNER" \
        "a GitHub login is letters, digits and single hyphens between them" || return
      [ "${#v}" -le 39 ] || { answers__no "$field" "a GitHub login is at most 39 characters"; return; }
      ;;
    text) answers__free "$field" "$v" || return ;;
    description)
      answers__free "$field" "$v" || return
      # UTF-8 characters: the bytes that are not continuation bytes.
      item=$(
        set -o pipefail
        printf '%s' "$v" | tr -d '\200-\277' | wc -c
      ) || { answers__cannot "$field" "count the characters of the description"; return; }
      [ "$((item + 0))" -le 350 ] || { answers__no "$field" "a description is at most 350 characters"; return; }
      ;;
    list)
      rest=$v,
      while [ -n "$rest" ]; do
        item=${rest%%,*}
        rest=${rest#*,}
        # Trimmed of spaces at each end.
        item=${item#"${item%%[! ]*}"}
        item=${item%"${item##*[! ]}"}
        [ -n "$item" ] || { answers__no "$field" "a list holds an empty item"; return; }
        answers__free "$field" "$item" || return
      done
      ;;
    select)
      rest=$pattern'|'
      while [ -n "$rest" ]; do
        item=${rest%%|*}
        rest=${rest#*|}
        [ "$item" != "$v" ] || break
      done
      [ "$item" = "$v" ] || { answers__no "$field" "the value is not one of $pattern"; return; }
      ;;
    login-or-team)
      answers__want "$field" "$v" "@$ANSWERS_OWNER(/[A-Za-z0-9]([A-Za-z0-9_-]*[A-Za-z0-9])?)?" \
        "the value is not @login or @organization/team" || return
      item=${v#@}
      item=${item%%/*}
      [ "${#item}" -le 39 ] || { answers__no "$field" "a GitHub login is at most 39 characters"; return; }
      ;;
    email-or-url)
      [ "$v" = "$default" ] || answers__want "$field" "$v" "https://[^[:space:]]+|$ANSWERS_EMAIL" \
        "the value is not an https:// URL or an email address" || return
      ;;
    url)
      answers__want "$field" "$v" "https://github\\.com/$ANSWERS_OWNER/[A-Za-z0-9._-]+" \
        "the value is not https://github.com/OWNER/REPOSITORY" || return
      item=${v#https://github.com/}
      rest=${item#*/}
      item=${item%%/*}
      [ "${#item}" -le 39 ] || { answers__no "$field" "a GitHub login is at most 39 characters"; return; }
      case "$rest" in
        . | ..) answers__no "$field" "a repository is not named . or .."; return ;;
      esac
      ;;
    path)
      # shellcheck disable=SC2088 # a literal ~, as the value holds it
      case "$v" in
        '~' | '~/'*) ;;
        '~'*) answers__no "$field" "a path does not start with ~user; write ~/ or an absolute path"; return ;;
      esac
      expanded=$(answers_path "$v") ||
        { answers__no "$field" "a path starting with ~ needs HOME, which is not set"; return; }
      # The expansion meets the value rule and the path rule a TARGET meets.
      # What the value holds after ~/ is judged as the value's; the rest,
      # HOME's, is named by the expansion (answers' NIT 1 of S2's third).
      if [ "$expanded" = "$v" ]; then
        answers__abs "$field" "$v" || return
      else
        answers__value "$field, its ~ expanded from HOME" "$expanded" || return
        case "$v" in
          '~/'*) answers__abs "$field" "/${v#'~/'}" || return ;;
        esac
        answers__abs "$field, its ~ expanded to $expanded" "$expanded" || return
      fi
      ;;
    *)
      answers__no "$field" "the type $type is not one this validator knows"
      return
      ;;
  esac
  if [ "$type" != select ] && [ -n "$pattern" ]; then
    answers__want "$field" "$v" "$pattern" "the value does not match $pattern" || return
  fi
  return 0
}

answers_target() {
  answers__value TARGET "$1" || return
  answers__abs TARGET "$1"
}

answers_target_for() {
  local root fault st
  root=$(answers_path "$1") || {
    printf 'TARGET_ROOT %s gives no target: it starts with ~, and HOME is not set\n' "$1"
    return 1
  }
  fault=$(answers_target "$root/$2")
  st=$?
  case $st in
    0) ;;
    1) printf 'TARGET_ROOT %s, then /%s, gives no target: %s\n' "$1" "$2" "$fault" ;;
    *) printf '%s\n' "$fault" ;;
  esac
  [ "$st" = 0 ] || return "$st"
  answers__trees "$root" "$root/$2" || return
  printf '%s/%s\n' "$root" "$2"
}

answers_root_ok() {
  answers__trees "$1"
}

# answers__trees ROOT [TARGET]: answers_root_ok's rule for ROOT, and, given
# TARGET, the target's too: no working tree of the workspace is at or under
# TARGET. The worktrees are read from git through a pipe, with git's status
# as the last record, so the rule makes no file (decision 227).
answers__trees() {
  local top
  top=$(git -C "$ANSWERS_WS" rev-parse --show-toplevel) || {
    printf 'cannot find the workspace'"'"'s working tree\n'
    return 2
  }
  # The list is NUL-delimited, as a worktree's path may hold a newline.
  # The judge reads it whole, so the writer's status is always 0 and the
  # pipeline's is the judge's, whatever the caller's pipefail.
  {
    git -C "$ANSWERS_WS" worktree list --porcelain -z
    printf 'git exited %d\0' "$?"
  } | answers__judge "$top" "$@"
}

# answers__judge TOP ROOT [TARGET]: the judgement of answers__trees, the
# worktree records on standard input.
answers__judge() {
  local root=$2 target=${3:-} dir rec path="" flag="" last=""
  # tops: the working trees; pruned: the entries git marks prunable, which
  # name no working tree it can see, yet may be one it cannot reach.
  local -a tops=("$1") pruned=()
  while IFS= read -r -d '' rec; do
    last=$rec
    case "$rec" in
      'worktree '*) path=${rec#worktree } flag="" ;;
      bare) flag=bare ;;
      'prunable' | 'prunable '*) [ -n "$flag" ] || flag=pruned ;;
      '') answers__entry ;;
    esac
  done
  if [ "$last" != "git exited 0" ]; then
    printf 'cannot list the workspace'"'"'s worktrees\n'
    return 2
  fi
  answers__entry
  dir=$root
  while [ ! -d "$dir" ]; do
    dir=${dir%/*}
    [ -n "$dir" ] || dir=/
  done
  (
    CDPATH='' cd -P -- "$dir" 2>/dev/null || {
      printf 'TARGET_ROOT %s: its existing ancestor %s cannot be entered, so it cannot be judged\n' "$root" "$dir"
      exit 2
    }
    while :; do
      for path in "${tops[@]}"; do
        if [ . -ef "$path" ]; then
          printf 'TARGET_ROOT %s is at or under %s, a working tree of this workspace; choose a TARGET_ROOT outside it\n' "$root" "$path"
          exit 1
        fi
      done
      [ ! . -ef / ] || exit 0
      cd -P .. 2>/dev/null || {
        printf 'TARGET_ROOT %s: the parent of %s cannot be entered, so it cannot be judged\n' "$root" "$(pwd -P)"
        exit 2
      }
    done
  ) || return
  # The root is outside every working tree, so the target is under none;
  # it is above none, nor one itself, when none is at or under it. A target
  # that is not there holds nothing.
  [ -n "$target" ] && [ -e "$target" ] || return 0
  # Each working tree and its parents, as git lists it and physically, a
  # working tree that cannot be entered refused; a prunable entry's path as
  # listed, as git may mark one prunable because it cannot reach it.
  for path in "${tops[@]}" ${pruned[@]+"${pruned[@]}"}; do
    answers__above "$target" "$path" || return
  done
  for path in "${tops[@]}"; do
    (
      CDPATH='' cd -P -- "$path" 2>/dev/null || {
        printf 'TARGET %s: the working tree %s of this workspace cannot be entered, so whether the target holds it cannot be told\n' "$target" "$path"
        exit 2
      }
      while :; do
        if [ . -ef "$target" ]; then
          printf 'TARGET %s is at or above %s, a working tree of this workspace; choose another TARGET_ROOT\n' "$target" "$path"
          exit 1
        fi
        [ ! . -ef / ] || exit 0
        cd -P .. 2>/dev/null || {
          printf 'TARGET %s: the parent of %s cannot be entered, so whether the target holds it cannot be told\n' "$target" "$(pwd -P)"
          exit 2
        }
      done
    ) || return
  done
}

# answers__entry: the worktree entry answers__judge has read, PATH and
# FLAG, kept in its list, unless bare; then none.
answers__entry() {
  case "$path:$flag" in
    :*) ;;
    *:) tops+=("$path") ;;
    *:pruned) pruned+=("$path") ;;
  esac
  path="" flag=""
}

# answers__above TARGET PATH: no parent of PATH, as written, PATH itself
# included, is the same file as TARGET; else the reason out, exit 1.
answers__above() {
  local p=$2
  while [ -n "$p" ]; do
    if [ "$p" -ef "$1" ]; then
      printf 'TARGET %s is at or above %s, a working tree of this workspace; choose another TARGET_ROOT\n' "$1" "$2"
      return 1
    fi
    p=${p%/*}
  done
}

answers_target_check() {
  local target root want st
  target=$(answers_get "$1" TARGET)
  case $? in
    0) ;;
    1) printf 'the answers hold no TARGET\n'; return 1 ;;
    *) printf 'cannot read TARGET from the answers\n'; return 2 ;;
  esac
  root=$(answers_get "$1" TARGET_ROOT)
  case $? in
    0) ;;
    1) printf 'the answers hold no TARGET_ROOT\n'; return 1 ;;
    *) printf 'cannot read TARGET_ROOT from the answers\n'; return 2 ;;
  esac
  want=$(answers_target_for "$root" "$2")
  st=$?
  if [ "$st" != 0 ]; then
    printf '%s\n' "$want"
    return "$st"
  fi
  if [ "$target" = "$want" ]; then
    printf '%s\n' "$want"
    return 0
  fi
  printf 'TARGET %s is not TARGET_ROOT %s, expanded here, then /%s, which is %s\n' "$target" "$root" "$2" "$want"
  return 1
}

answers_record() {
  K="$2: " awk '!found && index($0, ENVIRON["K"]) == 1 { print substr($0, length(ENVIRON["K"]) + 1); found = 1 }
    END { exit !found }' "$1"
}

answers_blob() {
  git hash-object -t blob --no-filters --stdin <"$1"
}

answers_get() {
  if [ "$1" != - ]; then
    answers__file "$1" "$1" >&2 || return 2
  fi
  F=$2 awk '
    { i = index($0, "=") }
    !found && i > 1 && substr($0, 1, i - 1) == ENVIRON["F"] { print substr($0, i + 1); found = 1 }
    END { exit !found }' "$1"
}

answers_read() {
  answers__file "$1" "$2" || return
  cat -- "$1" || answers__cannot "$2" "read the file"
}

answers_given() {
  local text line n=0 seen=" " key st
  text=$(answers_read "$1" "$2")
  st=$?
  if [ "$st" != 0 ]; then
    printf '%s\n' "$text"
    return "$st"
  fi
  [ -z "$text" ] || while IFS= read -r line; do
    n=$((n + 1))
    key=${line%%=*}
    case "$line" in
      *=*)
        answers__ere "$key" '[A-Z][A-Z0-9_]*'
        case $? in
          0) ;;
          1) key="" ;;
          *) answers__cannot "$2:$n" "read the line"; return ;;
        esac
        ;;
      *) key="" ;;
    esac
    if [ -z "$key" ]; then
      printf '%s:%d: not a FIELD=value line: %s\n' "$2" "$n" "$line"
      return 1
    fi
    case "$seen" in
      *" $key "*)
        printf '%s:%d: %s is given twice\n' "$2" "$n" "$key"
        return 1
        ;;
    esac
    seen="$seen$key "
  done <<<"$text"
  [ -z "$text" ] || printf '%s\n' "$text"
}

answers_derive() {
  local schema=$1 scope=$2 given=$3 base=$4 fields field value fault out="" faults="" st worst=0
  fields=$(answers_fields "$schema" "$scope") || {
    printf 'cannot read the %s fields of the schema\n' "$scope"
    return 2
  }
  while IFS= read -r field; do
    [ -n "$field" ] || continue
    value=$(answers_get - "$field" <<<"$given")
    case $? in
      0)
        fault=$(answers_check "$schema" "$field" "$value")
        st=$?
        if [ "$st" = 1 ]; then
          fault="$fault; give $field again"
        fi
        ;;
      1)
        if ! value=$(answers_col "$schema" "$field" default); then
          fault="$field: cannot read its default" st=2
        elif [ -z "$value" ]; then
          fault="$field is missing; give $field=value" st=1
        elif ! value=$(answers_default "$schema" "$field" "$base$out"); then
          fault="$field: cannot work out its default" st=2
        else
          fault=$(answers_check "$schema" "$field" "$value")
          st=$?
        fi
        ;;
      *) fault="$field: cannot read what was given" st=2 ;;
    esac
    if [ "$st" != 0 ]; then
      faults="$faults$fault
"
      [ "$st" = 1 ] || st=2
      [ "$st" -le "$worst" ] || worst=$st
      continue
    fi
    out="$out$field=$value
"
  done <<<"$fields"
  if [ -n "$faults" ]; then
    printf '%s' "$faults"
    return "$worst"
  fi
  printf '%s' "$out"
}

answers_setup() {
  local out st
  out=$(answers_derive "$1" setup "$2" "")
  st=$?
  if [ "$st" != 0 ]; then
    printf '%s\n' "$out"
    return "$st"
  fi
  # A sort that fails is a text not worked out, 2, never a refusal.
  [ -z "$out" ] || sort <<<"$out" || return 2
}

answers_setup_stale() {
  if [ "$1" = 1 ]; then
    printf 'setup/answers.env is not what bin/ask setup writes from setup/given.env; run bin/ask setup'
  else
    printf 'setup/answers.env is not what bin/ask setup writes, and setup/given.env is missing, so bin/ask setup would set each field to its default: restore setup/given.env, or give each field again with bin/ask setup FIELD=value...'
  fi
}

answers_default() {
  local d rest out="" name value
  d=$(answers_col "$1" "$2" default) || return 2
  rest=$d
  while :; do
    case "$rest" in
      *'{{'*'}}'*) ;;
      *) break ;;
    esac
    out="$out${rest%%'{{'*}"
    rest=${rest#*'{{'}
    name=${rest%%'}}'*}
    rest=${rest#*'}}'}
    value=$(answers_get - "$name" <<<"$3")
    case $? in
      0) out="$out$value" ;;
      1) out="$out{{$name}}" ;;
      *) return 2 ;;
    esac
  done
  printf '%s\n' "$out$rest"
}

answers_questionnaire() {
  # One command writes the whole text, so its status is the write's.
  # shellcheck disable=SC2016 # backticks here are Markdown code spans
  H='# Setup questionnaire

`bin/ask questionnaire` writes this file from `shared/answers.tsv`, so a change goes in the schema, not here. Answer every question at once, then record the answers with `bin/ask setup FIELD=value…`, which writes `setup/answers.env`. In a default, `{{FIELD}}` stands for that field'"'"'s answer.
' awk -F '\t' '
    BEGIN { print ENVIRON["H"] }
    NR > 1 && $2 == "setup" {
      d = ($7 == "-" || $7 == "") ? "no default" : "default `" $7 "`"
      printf "%d. %s (`%s`, %s; %s)\n", ++n, $8, $1, $3, d
    }' "$1"
}

answers_validate() {
  local schema=$1 file=$2 scope=$3 label=${4:-$2} line n=0 key seen=" " refused=0 want field text fault in
  if [ "$scope" = run ]; then
    want=$(answers_fields "$schema") && want="$want
TARGET"
  else
    want=$(answers_fields "$schema" "$scope")
  fi || {
    printf '%s: cannot read the fields of the schema\n' "$label"
    return 2
  }
  # Read through the one reader, then line by line exactly: the text less
  # the newline that ends its last line, a blank line before it kept.
  text=$(answers_read "$file" "$label" && printf x)
  case $? in
    0) ;;
    1)
      printf '%s\n' "$text"
      return 1
      ;;
    *)
      printf '%s\n' "$text"
      return 2
      ;;
  esac
  text=${text%x}
  [ -z "$text" ] || while IFS= read -r line; do
    n=$((n + 1))
    key=${line%%=*}
    case "$line" in
      *=*) ;;
      *) key="" ;;
    esac
    answers__ere "$key" '[A-Z][A-Z0-9_]*'
    case $? in
      0) ;;
      1)
        printf '%s:%d: not a FIELD=value line: %s\n' "$label" "$n" "$line"
        refused=1
        continue
        ;;
      *)
        answers__cannot "$label:$n" "read the line"
        return
        ;;
    esac
    case "$seen" in
      *" $key "*)
        printf '%s:%d: %s is given twice\n' "$label" "$n" "$key"
        refused=1
        continue
        ;;
    esac
    seen="$seen$key "
    # A here-string, not a pipe: grep -q stops at its match, and under
    # pipefail a writer it leaves mid-list fails the lookup.
    grep -Fxq -e "$key" <<<"$want"
    case $? in
      0) ;;
      1)
        in=$(answers_col "$schema" "$key" scope)
        case $? in
          0) printf '%s:%d: %s is a %s field, not one of this file\n' "$label" "$n" "$key" "$in" ;;
          1) printf '%s:%d: %s: an unknown field\n' "$label" "$n" "$key" ;;
          *)
            answers__cannot "$label:$n" "read the scope of $key in the schema"
            return
            ;;
        esac
        refused=1
        continue
        ;;
      *)
        answers__cannot "$label:$n" "look $key up among the fields of the schema"
        return
        ;;
    esac
    if [ "$key" = TARGET ]; then
      fault=$(answers_target "${line#*=}")
    else
      fault=$(answers_check "$schema" "$key" "${line#*=}")
    fi
    case $? in
      0) ;;
      1)
        printf '%s:%d: %s\n' "$label" "$n" "$fault"
        refused=1
        ;;
      *)
        printf '%s:%d: %s\n' "$label" "$n" "$fault"
        return 2
        ;;
    esac
  done <<<"${text%$'\n'}"
  while IFS= read -r field; do
    [ -n "$field" ] || continue
    case "$seen" in
      *" $field "*) ;;
      *)
        printf '%s: %s is missing\n' "$label" "$field"
        refused=1
        ;;
    esac
  done <<EOF
$want
EOF
  return "$refused"
}

answers__no() {
  printf '%s: %s\n' "$1" "$2"
  return 1
}
# answers__cannot WHAT DOING: "WHAT: cannot DOING" out, and exit 2: a lookup
# or a read failed, so nothing is judged.
answers__cannot() {
  printf '%s: cannot %s\n' "$1" "$2"
  return 2
}

# answers__file FILE LABEL: the rule an answers file meets as a whole, before
# any value from it is kept: it holds no NUL byte, which bash's read and
# command substitution drop and awk may stop at. Each count has its status
# read. The reason out, naming LABEL, and exit 1 when refused, 2 when FILE
# cannot be read.
answers__file() {
  local all kept
  if ! all=$(wc -c <"$1") || ! kept=$(
    set -o pipefail
    tr -d '\000' <"$1" | wc -c
  ); then
    answers__cannot "$2" "read the file"
    return
  fi
  if [ "$((all + 0))" -ne "$((kept + 0))" ]; then
    printf '%s: the file holds a NUL byte, which some readers drop and others stop at\n' "$2"
    return 1
  fi
}

# answers__abs FIELD PATH: PATH is absolute, not `/` alone, with no empty,
# `.` or `..` component; the one path rule, for a `path` value once expanded
# and for a TARGET (decision 227).
answers__abs() {
  case "$2" in
    /*) ;;
    *) answers__no "$1" "a path is absolute once ~ is expanded"; return 1 ;;
  esac
  case "$2/" in
    *//* | */./* | */../*)
      answers__no "$1" "a path holds no empty, . or .. component, and is not / alone"
      return 1
      ;;
  esac
}

# answers__value FIELD VALUE: the rule every value meets, whatever its type.
answers__value() {
  case "$2" in
    '') answers__no "$1" "the value is empty" ;;
    *'
'*) answers__no "$1" "the value holds a newline" ;;
    *[[:cntrl:]]*) answers__no "$1" "the value holds a control character" ;;
    *$'\xe2\x80\xa8'* | *$'\xe2\x80\xa9'*) answers__no "$1" "the value holds U+2028 or U+2029, a line or paragraph separator" ;;
    *'{{'*) answers__no "$1" "the value holds {{" ;;
  esac || return 1
  answers__want "$1" "$2" "$ANSWERS_UTF8" "the value is not valid UTF-8, or holds a C1 control character"
}

# answers__ere VALUE ERE: the whole of VALUE, one line, matches ERE; exit 1
# when it does not, 2 when grep cannot match it.
answers__ere() {
  grep -Eq -e "^($2)\$" <<<"$1"
  case $? in
    0) return 0 ;;
    1) return 1 ;;
    *) return 2 ;;
  esac
}
# answers__want FIELD VALUE ERE WHY: VALUE matches ERE; else "FIELD: WHY"
# out and exit 1, or, when the match cannot be made, that out and exit 2.
answers__want() {
  answers__ere "$2" "$3"
  case $? in
    0) ;;
    1) answers__no "$1" "$4" ;;
    *) answers__cannot "$1" "match the value against its rule" ;;
  esac
}

# answers__free FIELD VALUE: free text holds no email address and no rule
# word; exit 2 when either cannot be looked for.
answers__free() {
  local word
  grep -Eq -e "$ANSWERS_EMAIL" <<<"$2"
  case $? in
    0) answers__no "$1" "free text holds no email address" ;;
    1) ;;
    *) answers__cannot "$1" "look for an email address in the value" ;;
  esac || return
  word=$(rules_word "$2")
  case $? in
    0) answers__no "$1" "free text holds no rule word, and this holds \"$word\" (foundation/bin/lib/rules.sh)" ;;
    1) ;;
    *) answers__cannot "$1" "look for a rule word in the value" ;;
  esac
}
