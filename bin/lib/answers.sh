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
# value is its items joined by `,`, each trimmed and none empty.
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
#                                    exit 0 or 1
#   answers_fields SCHEMA [SCOPE]    the fields, in order, one a line
#   answers_col SCHEMA FIELD COLUMN  a cell, `-` read as empty; exit 1 when
#                                    the schema has no FIELD, 2 when it has
#                                    no COLUMN
#   answers_check SCHEMA FIELD VALUE the reason VALUE is refused, if it is;
#                                    exit 0 when accepted, 1 when refused
#   answers_path VALUE               a `path` value with its `~` expanded;
#                                    exit 1 when it starts with `~` and HOME
#                                    is unset or empty
#   answers_get FILE FIELD           FIELD's value in an answers file (`-`
#                                    for standard input, read whole, so a
#                                    writer on a pipe is never cut off);
#                                    exit 1 when the file does not hold FIELD
#   answers_default SCHEMA FIELD PAIRS
#                                    FIELD's default, each `{{OTHER}}` in it
#                                    given OTHER's value in PAIRS, answers
#                                    file lines in a string; a `{{OTHER}}`
#                                    PAIRS lacks is left, for the validator
#   answers_validate SCHEMA FILE SCOPE [NAME]
#                                    the whole file, holding exactly the
#                                    fields of SCOPE (`setup`, or `run` for
#                                    every field and TARGET), each once and
#                                    valid; one line out per refusal, naming
#                                    the file NAME (FILE by default); exit 0
#                                    or 1
#   answers_target VALUE             a TARGET's shape: absolute, not `/`
#                                    alone, with no empty, `.` or `..`
#                                    component, the rule a `path` value meets
#                                    once expanded; exit 0 or 1
#   answers_target_for TARGET_ROOT NAME
#                                    a run's TARGET, exactly TARGET_ROOT with
#                                    its `~` expanded, then `/NAME`, under
#                                    the path rule answers_target holds it
#                                    to; else the reason out, exit 1
#   answers_target_check FILE NAME   the run answers FILE's TARGET is still
#                                    answers_target_for its TARGET_ROOT and
#                                    NAME, under this HOME: that TARGET out,
#                                    exit 0; else the reason out, exit 1
#   answers_record FILE KEY          the value of a run record's `KEY: `
#                                    line (confirmed.md, render.md); exit 1
#                                    when FILE has none
#   answers_blob FILE                FILE's git blob id, its bytes as they
#                                    stand
#   answers_questionnaire SCHEMA     setup/questionnaire.md's text: the
#                                    setup fields' questions, in one flat
#                                    numbered list, each with its field,
#                                    type and default
#
# The caller exports LC_ALL=C.

ANSWERS_HEADER='field	scope	type	render	selects	pattern	default	question'
ANSWERS_TYPES='name text description list select owner login-or-team email-or-url url path'
ANSWERS_OWNER='[A-Za-z0-9](-?[A-Za-z0-9])*'
ANSWERS_EMAIL='[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}'
# Valid UTF-8 holding no C0 control, DEL or C1 control, byte by byte under
# LC_ALL=C: printable ASCII, then each well-formed sequence of two, three or
# four bytes, with no overlong form, surrogate or code point past U+10FFFF.
ANSWERS_UTF8=$'([\x20-\x7e]|\xc2[\xa0-\xbf]|[\xc3-\xdf][\x80-\xbf]|\xe0[\xa0-\xbf][\x80-\xbf]|[\xe1-\xec\xee\xef][\x80-\xbf][\x80-\xbf]|\xed[\x80-\x9f][\x80-\xbf]|\xf0[\x90-\xbf][\x80-\xbf][\x80-\xbf]|[\xf1-\xf3][\x80-\xbf][\x80-\xbf][\x80-\xbf]|\xf4[\x80-\x8f][\x80-\xbf][\x80-\xbf])*'
ANSWERS_LIB=$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)
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
  type=$(answers_col "$schema" "$field" type) || {
    printf '%s: an unknown field\n' "$field"
    return 1
  }
  pattern=$(answers_col "$schema" "$field" pattern)
  default=$(answers_col "$schema" "$field" default)
  answers__value "$field" "$v" || return 1
  case "$type" in
    name)
      answers__ere "$v" '[a-z0-9][a-z0-9._-]*' ||
        { answers__no "$field" "a name is lowercase letters, digits, ., _ and -, starting with a letter or digit"; return 1; }
      [ "${#v}" -le 100 ] || { answers__no "$field" "a name is at most 100 characters"; return 1; }
      case "$v" in *.git) answers__no "$field" "a name does not end .git"; return 1 ;; esac
      ;;
    owner)
      answers__ere "$v" "$ANSWERS_OWNER" ||
        { answers__no "$field" "a GitHub login is letters, digits and single hyphens between them"; return 1; }
      [ "${#v}" -le 39 ] || { answers__no "$field" "a GitHub login is at most 39 characters"; return 1; }
      ;;
    text) answers__free "$field" "$v" || return 1 ;;
    description)
      answers__free "$field" "$v" || return 1
      [ "$(printf '%s' "$v" | tr -d '\200-\277' | wc -c | tr -d ' ')" -le 350 ] ||
        { answers__no "$field" "a description is at most 350 characters"; return 1; }
      ;;
    list)
      rest=$v,
      while [ -n "$rest" ]; do
        item=${rest%%,*}
        rest=${rest#*,}
        item=$(printf '%s' "$item" | sed 's/^ *//; s/ *$//')
        [ -n "$item" ] || { answers__no "$field" "a list holds an empty item"; return 1; }
        answers__free "$field" "$item" || return 1
      done
      ;;
    select)
      rest=$pattern'|'
      while [ -n "$rest" ]; do
        item=${rest%%|*}
        rest=${rest#*|}
        [ "$item" != "$v" ] || break
      done
      [ "$item" = "$v" ] || { answers__no "$field" "the value is not one of $pattern"; return 1; }
      ;;
    login-or-team)
      answers__ere "$v" "@$ANSWERS_OWNER(/[A-Za-z0-9]([A-Za-z0-9_-]*[A-Za-z0-9])?)?" ||
        { answers__no "$field" "the value is not @login or @organization/team"; return 1; }
      ;;
    email-or-url)
      [ "$v" = "$default" ] || answers__ere "$v" 'https://[^[:space:]]+' ||
        answers__ere "$v" "$ANSWERS_EMAIL" ||
        { answers__no "$field" "the value is not an https:// URL or an email address"; return 1; }
      ;;
    url)
      answers__ere "$v" "https://github\\.com/$ANSWERS_OWNER/[A-Za-z0-9._-]+" ||
        { answers__no "$field" "the value is not https://github.com/OWNER/REPOSITORY"; return 1; }
      ;;
    path)
      # shellcheck disable=SC2088 # a literal ~, as the value holds it
      case "$v" in
        '~' | '~/'*) ;;
        '~'*) answers__no "$field" "a path does not start with ~user; write ~/ or an absolute path"; return 1 ;;
      esac
      expanded=$(answers_path "$v") ||
        { answers__no "$field" "a path starting with ~ needs HOME, which is not set"; return 1; }
      answers__abs "$field" "$expanded" || return 1
      ;;
    *)
      printf '%s: the type %s is not one this validator knows\n' "$field" "$type"
      return 1
      ;;
  esac
  if [ "$type" != select ] && [ -n "$pattern" ]; then
    answers__ere "$v" "$pattern" || { answers__no "$field" "the value does not match $pattern"; return 1; }
  fi
  return 0
}

answers_target() {
  answers__value TARGET "$1" || return 1
  answers__abs TARGET "$1"
}

answers_target_for() {
  local root fault
  root=$(answers_path "$1") || {
    printf 'TARGET_ROOT %s gives no target: it starts with ~, and HOME is not set\n' "$1"
    return 1
  }
  fault=$(answers_target "$root/$2") || {
    printf 'TARGET_ROOT %s, then /%s, gives no target: %s\n' "$1" "$2" "$fault"
    return 1
  }
  printf '%s/%s\n' "$root" "$2"
}

answers_target_check() {
  local target root want
  target=$(answers_get "$1" TARGET) || { printf 'the answers hold no TARGET\n'; return 1; }
  root=$(answers_get "$1" TARGET_ROOT) || { printf 'the answers hold no TARGET_ROOT\n'; return 1; }
  want=$(answers_target_for "$root" "$2") || { printf '%s\n' "$want"; return 1; }
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
  F=$2 awk '
    { i = index($0, "=") }
    !found && i > 1 && substr($0, 1, i - 1) == ENVIRON["F"] { print substr($0, i + 1); found = 1 }
    END { exit !found }' "$1"
}

answers_default() {
  local d rest out="" name value
  d=$(answers_col "$1" "$2" default) || return 1
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
    if value=$(printf '%s\n' "$3" | answers_get - "$name"); then
      out="$out$value"
    else
      out="$out{{$name}}"
    fi
  done
  printf '%s\n' "$out$rest"
}

answers_questionnaire() {
  # shellcheck disable=SC2016 # backticks here are Markdown code spans
  printf '%s\n' '# Setup questionnaire' '' \
    '`bin/ask questionnaire` writes this file from `shared/answers.tsv`, so a change goes in the schema, not here. Answer every question at once, then record the answers with `bin/ask setup FIELD=value…`, which writes `setup/answers.env`. In a default, `{{FIELD}}` stands for that field'"'"'s answer.' ''
  awk -F '\t' '
    NR > 1 && $2 == "setup" {
      d = ($7 == "-" || $7 == "") ? "no default" : "default `" $7 "`"
      printf "%d. %s (`%s`, %s; %s)\n", ++n, $8, $1, $3, d
    }' "$1"
}

answers_validate() {
  local schema=$1 file=$2 scope=$3 label=${4:-$2} line n=0 key seen=" " refused=0 want field
  if [ "$scope" = run ]; then
    want="$(answers_fields "$schema")
TARGET"
  else
    want=$(answers_fields "$schema" "$scope")
  fi
  if [ "$(tr -d '\000' <"$file" | wc -c)" -ne "$(wc -c <"$file")" ]; then
    printf '%s: the file holds a NUL byte, which some readers drop and others stop at\n' "$label"
    return 1
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    key=${line%%=*}
    case "$line" in
      *=*) ;;
      *) key="" ;;
    esac
    if ! answers__ere "$key" '[A-Z][A-Z0-9_]*'; then
      printf '%s:%d: not a FIELD=value line: %s\n' "$label" "$n" "$line"
      refused=1
      continue
    fi
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
    if ! grep -Fxq -e "$key" <<<"$want"; then
      if answers_col "$schema" "$key" scope >/dev/null; then
        printf '%s:%d: %s is a %s field, not one of this file\n' "$label" "$n" "$key" \
          "$(answers_col "$schema" "$key" scope)"
      else
        printf '%s:%d: %s: an unknown field\n' "$label" "$n" "$key"
      fi
      refused=1
      continue
    fi
    if [ "$key" = TARGET ]; then
      answers_target "${line#*=}" | P="$label:$n: " awk '{ print ENVIRON["P"] $0 }'
    else
      answers_check "$schema" "$key" "${line#*=}" | P="$label:$n: " awk '{ print ENVIRON["P"] $0 }'
    fi
    [ "${PIPESTATUS[0]}" = 0 ] || refused=1
  done <"$file"
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
  answers__ere "$2" "$ANSWERS_UTF8" ||
    answers__no "$1" "the value is not valid UTF-8, or holds a C1 control character"
}

# answers__ere VALUE ERE: the whole of VALUE, one line, matches ERE.
answers__ere() {
  grep -Eq -e "^($2)\$" <<<"$1"
}

# answers__free FIELD VALUE: free text holds no email address and no rule
# word.
answers__free() {
  local word
  if grep -Eq -e "$ANSWERS_EMAIL" <<<"$2"; then
    answers__no "$1" "free text holds no email address"
    return 1
  fi
  if word=$(rules_word "$2"); then
    answers__no "$1" "free text holds no rule word, and this holds \"$word\" (foundation/bin/lib/rules.sh)"
    return 1
  fi
}
