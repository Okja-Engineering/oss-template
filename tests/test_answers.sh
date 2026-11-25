#!/usr/bin/env bash
# bin/lib/answers.sh, the one parser and validator of the field schema and
# of answers files (AC6, AC7): on a fixture schema holding a field of each
# type but `identity`, which lands at 3.1 (decision 145).
# shellcheck disable=SC2016,SC2088 # values hold a literal ~, $ and backticks
set -u
set -o pipefail
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$TEST_DIR/../foundation/tests/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/answers.sh
. "$TEST_DIR/../bin/lib/answers.sh"

# The suite gives HOME its own value, so no case depends on the caller's.
export HOME=/home/someone
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
S="$SCRATCH/answers.tsv"
T='	'

row() { # the cells, joined by tabs
  local IFS="$T"
  printf '%s\n' "$*"
}
{
  row field scope type render selects pattern default question
  row NAME run name no - - - 'What is the repository called?'
  row OWNER setup owner no - - Okja-Engineering 'Which GitHub account owns the repositories?'
  row TARGET_ROOT setup path no - - '~/Development/{{OWNER}}' 'Where are targets rendered?'
  row TITLE run text yes - - - 'A title?'
  row CODE run text no - '[A-Z]{3}' - 'A code of three capitals?'
  row DESCRIPTION run description yes - - - 'One line about it?'
  row PEOPLE setup list yes - - - 'Who decides?'
  row VISIBILITY run select no - 'public|private' public 'Public or private?'
  row LICENSE run select yes LICENSE 'apache-2.0|none' apache-2.0 'Which licence?'
  row TEAM setup login-or-team yes - - '@{{OWNER}}/maintainers' 'Which team owns the code?'
  row CONTACT setup email-or-url yes - - 'not yet set, so launch waits on it' 'Where are conduct reports sent?'
  row HOME_URL setup url yes - - 'https://github.com/Okja-Engineering/oss-template' 'Where is the workspace?'
} >"$S"

ok() { # FIELD VALUE: the validator accepts VALUE for FIELD
  local out st
  out=$(answers_check "$S" "$1" "$2" 2>&1)
  st=$?
  assert_status 0 "$st" "accepted: $1=$2${out:+ ($out)}"
}
no() { # FIELD VALUE NEEDLE: the validator refuses it, saying NEEDLE
  local out st
  out=$(answers_check "$S" "$1" "$2" 2>&1)
  st=$?
  assert_status 1 "$st" "refused: $1=$(printf '%s' "$2" | tr '\n' '~')"
  assert_contains "$out" "$3" "  and the refusal says: $3"
}
rep() { # COUNT TEXT: TEXT repeated COUNT times
  local i=0 s=""
  while [ "$i" -lt "$1" ]; do
    s="$s$2"
    i=$((i + 1))
  done
  printf '%s' "$s"
}

# --- the schema ---------------------------------------------------------------
answers_schema_check "$S" >/dev/null
assert_status 0 "$?" "the fixture schema parses"
assert_eq "NAME OWNER TARGET_ROOT TITLE CODE DESCRIPTION PEOPLE VISIBILITY LICENSE TEAM CONTACT HOME_URL" \
  "$(answers_fields "$S" | tr '\n' ' ' | sed 's/ $//')" "its fields, in order"
assert_eq "OWNER TARGET_ROOT PEOPLE TEAM CONTACT HOME_URL" \
  "$(answers_fields "$S" setup | tr '\n' ' ' | sed 's/ $//')" "its setup fields"
assert_eq "path" "$(answers_col "$S" TARGET_ROOT type)" "a field's type"
assert_eq "LICENSE" "$(answers_col "$S" LICENSE selects)" "a field's selects"
assert_eq "" "$(answers_col "$S" NAME default)" "a - cell reads as empty"
assert_eq "yes" "$(answers_col "$S" TITLE render)" "a field's render column"
answers_schema_check "$TEST_DIR/../shared/answers.tsv" >/dev/null
assert_status 0 "$?" "the workspace's own schema parses"

# bad_schema DESCRIPTION NEEDLE: the schema in $BAD is refused. Each case
# writes $BAD first and asserts here, in this shell, never at the end of a
# pipeline, where a failed assert would not count.
BAD="$SCRATCH/bad.tsv"
bad_schema() {
  local out st
  out=$(answers_schema_check "$BAD" 2>&1)
  st=$?
  assert_status 1 "$st" "schema refused: $1"
  assert_contains "$out" "$2" "  and the refusal says: $2"
}
{ row field scope type render selects pattern default; row NAME run name no - - -; } >"$BAD"
bad_schema "a header other than the eight columns" "header"
{ head -n 1 "$S"; row X run bogus no - - - 'X?'; } >"$BAD"
bad_schema "an unknown type" "bogus"
{ head -n 1 "$S"; row X run identity no - - - 'X?'; } >"$BAD"
bad_schema "identity, before it lands at 3.1" "identity, which lands with verify at 3.1"
{ head -n 1 "$S"; row X elsewhere text no - - - 'X?'; } >"$BAD"
bad_schema "an unknown scope" "elsewhere"
{ head -n 1 "$S"; row X run select no - - - 'X?'; } >"$BAD"
bad_schema "a select with no values" "X"
{ head -n 1 "$S"; row X run text maybe - - - 'X?'; } >"$BAD"
bad_schema "a render column other than yes or no" "maybe"
{ head -n 1 "$S"; row X run text no - - - 'X?'; row X run text no - - - 'X?'; } >"$BAD"
bad_schema "a field listed twice" "X"
{ head -n 1 "$S"; row lower run text no - - - 'X?'; } >"$BAD"
bad_schema "a field name not in capitals" "lower"
{ head -n 1 "$S"; row X run text no - - - 'X?' extra; } >"$BAD"
bad_schema "a row of nine cells" "X"
: >"$BAD"
bad_schema "an empty schema, with no header" "the header is not"
{ head -n 1 "$S"; row TARGET run path no - - - 'X?'; } >"$BAD"
bad_schema "a field named TARGET, the run file's own line" "TARGET"
{ head -n 1 "$S"; row X run text no LICENSE - - 'X?'; } >"$BAD"
bad_schema "selects on a type other than select" "only a select selects"
{ head -n 1 "$S"; row X run text no - - '{{Y}} and more' 'X?'; row Y run text no - - - 'Y?'; } >"$BAD"
bad_schema "a default naming a field later in the schema" "{{Y}}"
{ head -n 1 "$S"; row X run text no - - '{{X}}' 'X?'; } >"$BAD"
bad_schema "a default naming its own field" "{{X}}"
{ head -n 1 "$S"; row Y run text no - - - 'Y?'; row X run text no - - '{{Y}} and more' 'X?'; } >"$BAD"
answers_schema_check "$BAD" >/dev/null
assert_status 0 "$?" "a default naming an earlier field is accepted"
OUT=$(answers_col "$S" NAME nosuchcolumn 2>&1)
assert_status 2 "$?" "answers_col with an unknown column exits 2"
assert_eq "answers: the schema has no column nosuchcolumn" "$OUT" "  and prints only that, not the row"

# --- each type, and the pattern column ----------------------------------------
ok NAME my-repo.x_2
ok NAME "$(rep 100 a)"
no NAME "$(rep 101 a)" "100"
no NAME My-Repo "NAME"
no NAME -repo "NAME"
no NAME repo.git ".git"
ok OWNER Okja-Engineering
ok OWNER "$(rep 39 a)"
no OWNER "$(rep 40 a)" "39"
no OWNER -okja "OWNER"
no OWNER okja--eng "OWNER"
no OWNER okja_eng "OWNER"
ok TITLE 'A title, with words'
no TITLE '' "empty"
ok CODE ABC
no CODE ABCD "CODE"
no CODE abc "CODE"
ok VISIBILITY public
ok VISIBILITY private
no VISIBILITY secret "public|private"
# A select value is exactly one listed value (decision 229).
no VISIBILITY 'public|private' "public|private"
no VISIBILITY 'public|' "public|private"
no VISIBILITY 'publi' "public|private"
no LICENSE 'apache-2.0|none' "apache-2.0|none"
# Every value is valid UTF-8 with no C0, DEL or C1 control, and no U+2028 or
# U+2029 (decision 229).
ok TITLE "$(printf 'B\303\251 \342\202\254 \360\237\230\200 \302\240 \357\277\275')"
no TITLE "$(printf 'a\377\376b')" "not valid UTF-8"
no TITLE "$(printf 'a\300\257b')" "not valid UTF-8"
no TITLE "$(printf 'a\355\240\200b')" "not valid UTF-8"
no TITLE "$(printf 'a\364\220\200\200b')" "not valid UTF-8"
no TITLE "$(printf 'a\303')" "not valid UTF-8"
no TITLE "$(printf 'a\302\205b')" "C1 control"
no TITLE "$(printf 'a\302\233b')" "C1 control"
no TITLE "$(printf 'a\177b')" "control character"
no TITLE "$(printf 'a\tb')" "control character"
no TITLE "$(printf 'a\342\200\250b')" "U+2028"
no TITLE "$(printf 'a\342\200\251b')" "U+2029"
no OWNER "$(printf 'Okja\302\205')" "C1 control"
no TARGET_ROOT "$(printf '/srv/t\342\200\250')" "U+2028"
ok TEAM '@octo'
ok TEAM '@okja-eng/maintainers'
no TEAM octo "TEAM"
no TEAM '@okja/' "TEAM"
no TEAM '@-octo' "TEAM"
ok CONTACT 'https://example.com/conduct'
ok CONTACT 'not yet set, so launch waits on it'
no CONTACT 'http://example.com/conduct' "CONTACT"
no CONTACT 'nobody' "CONTACT"
ok HOME_URL 'https://github.com/Okja-Engineering/oss-template'
no HOME_URL 'https://gitlab.com/okja/oss-template' "HOME_URL"
no HOME_URL 'https://github.com/okja' "HOME_URL"
ok PEOPLE 'A Person, B Person'
ok PEOPLE 'A Person'
no PEOPLE 'A Person,, B Person' "empty item"
no PEOPLE 'A Person, ' "empty item"

# TARGET_ROOT (decisions 215, 217, 219).
ok TARGET_ROOT /srv/targets
ok TARGET_ROOT '~'
ok TARGET_ROOT '~/Development/okja'
ok TARGET_ROOT '/srv/a..b/c'
no TARGET_ROOT '/srv/../etc' ".."
no TARGET_ROOT '/srv/..' ".."
no TARGET_ROOT '~/..' ".."
no TARGET_ROOT 'targets/okja' "absolute"
no TARGET_ROOT './targets' "absolute"
no TARGET_ROOT '~user/targets' "~user"
no TARGET_ROOT '~user' "~user"
assert_eq "/h/Development/x" "$(HOME=/h answers_path '~/Development/x')" "~/ expands to the home directory"
assert_eq "/h" "$(HOME=/h answers_path '~')" "~ alone is the home directory"
assert_eq "/srv/x" "$(HOME=/h answers_path '/srv/x')" "an absolute path is kept"
# One path rule (decision 227): once ~ is expanded, absolute, not / alone,
# with no empty, . or .. component, the rule a TARGET meets.
no TARGET_ROOT '/' "not / alone"
no TARGET_ROOT '/srv/./targets' "no empty, . or .. component"
no TARGET_ROOT '/srv//targets' "no empty, . or .. component"
no TARGET_ROOT '//srv/targets' "no empty, . or .. component"
no TARGET_ROOT '/srv/targets/.' "no empty, . or .. component"
no TARGET_ROOT '/srv/targets/' "no empty, . or .. component"
no TARGET_ROOT '~/' "no empty, . or .. component"
no TARGET_ROOT '~/./x' "no empty, . or .. component"
out=$(HOME=/ answers_check "$S" TARGET_ROOT '~/x' 2>&1)
assert_status 1 "$?" "refused: TARGET_ROOT=~/x with HOME /, which expands to //x"
out=$(unset HOME; answers_check "$S" TARGET_ROOT '~/x' 2>&1)
assert_status 1 "$?" "refused: TARGET_ROOT=~/x with HOME unset"
assert_contains "$out" "HOME" "  and the refusal names HOME"
out=$(unset HOME; answers_path '~/x' 2>&1)
assert_status 1 "$?" "answers_path cannot expand ~ with HOME unset"
assert_eq "" "$out" "  and prints nothing"
out=$(HOME='' answers_path '~' 2>&1)
assert_status 1 "$?" "  nor with HOME empty"
ok TARGET_ROOT /srv/targets

# Every type: a newline and {{ refused.
for f in NAME OWNER TARGET_ROOT TITLE DESCRIPTION PEOPLE VISIBILITY TEAM CONTACT HOME_URL; do
  no "$f" "public
x" "newline"
  no "$f" 'a{{B}}' "{{"
done

# An email address, refused in a text, a description and a list field only
# (decisions 109, 114).
no TITLE 'Write to a.person@example.org' "email"
no DESCRIPTION 'Write to a.person@example.org' "email"
no PEOPLE 'A Person, a.person@example.org' "email"
ok CONTACT 'conduct@example.org'
ok TARGET_ROOT '/srv/a.person@example.org/targets'

# A rule word in free text (AC7, decision 73), from either of rules.sh's lists.
no TITLE 'It never breaks' "never"
no DESCRIPTION 'Always fast' "Always"
no PEOPLE 'A Person, Must Person' "Must"
ok TARGET_ROOT '/srv/never'

# DESCRIPTION's limit, in UTF-8 characters, not bytes (decisions 120, 148).
ok DESCRIPTION "$(rep 350 'é')"
no DESCRIPTION "$(rep 351 'é')" "350"
ok DESCRIPTION "$(rep 350 a)"
no DESCRIPTION "$(rep 351 a)" "350"
ok TITLE "$(rep 351 a)"

no UNKNOWN value "unknown field"

# --- answers files -------------------------------------------------------------
A="$SCRATCH/answers.env"
VALUE='Bé & back\slash = equals \n $HOME'
printf 'OWNER=Okja-Engineering\nTITLE=%s\n' "$VALUE" >"$A"
assert_eq "$VALUE" "$(answers_get "$A" TITLE)" "non-ASCII, &, \\, = and \$ kept as written"
assert_eq "Okja-Engineering" "$(answers_get "$A" OWNER)" "a value read back"
answers_get "$A" NAME >/dev/null
assert_status 1 "$?" "an absent field reads as absent"
printf '=orphan\n' >>"$A"
answers_get "$A" '' >/dev/null
assert_status 1 "$?" "a line with no field before its = is no field's"
assert_eq "TARGET_ROOT=~/Development/{{OWNER}}" "TARGET_ROOT=$(answers_default "$S" TARGET_ROOT '')" \
  "a default's {{OWNER}} is left when the pairs lack OWNER, for the validator"

mkdir "$SCRATCH/cwd"
printf 'TITLE=$(touch made-by-value)\nCODE=`touch made-by-backticks`\n' >"$SCRATCH/cwd/answers.env"
(
  cd "$SCRATCH/cwd" || exit 1
  answers_get answers.env TITLE >/dev/null
  answers_check "$S" TITLE '$(touch made-by-check)' >/dev/null 2>&1
  answers_validate "$S" answers.env run >/dev/null 2>&1
  answers_check "$S" CODE '`touch made-by-check2`' >/dev/null 2>&1
)
assert_eq "answers.env" "$(ls "$SCRATCH/cwd")" "\$(touch x) and backticks in a value create nothing"

# answers_validate: a whole file, against one scope.
SETUP="$SCRATCH/setup.env"
good_setup() {
  printf '%s\n' 'CONTACT=not yet set, so launch waits on it' \
    'HOME_URL=https://github.com/Okja-Engineering/oss-template' 'OWNER=Okja-Engineering' \
    'PEOPLE=A Person' 'TARGET_ROOT=~/Development/Okja-Engineering' 'TEAM=@Okja-Engineering/maintainers' >"$SETUP"
}
vrefused() { # DESCRIPTION NEEDLE
  local out st
  out=$(answers_validate "$S" "$SETUP" setup 2>&1)
  st=$?
  assert_status 1 "$st" "file refused: $1"
  assert_contains "$out" "$2" "  and the refusal says: $2"
}
good_setup
answers_validate "$S" "$SETUP" setup >/dev/null
assert_status 0 "$?" "a valid setup file passes"
# A field found early in a long list is still this file's: the lookup reads
# the list whole, so no reader leaves a writer to a broken pipe under
# pipefail (the list here outgrows a pipe's buffer).
{
  head -n 1 "$S"
  row AAA run text no - - - 'A?'
  i=0
  while [ "$i" -lt 15000 ]; do
    row "F$i" run text no - - - 'F?'
    i=$((i + 1))
  done
} >"$SCRATCH/long.tsv"
printf 'AAA=x\n' >"$SCRATCH/long.env"
OUT=$(answers_validate "$SCRATCH/long.tsv" "$SCRATCH/long.env" run 2>&1)
assert_not_contains "$OUT" "not one of this file" "a field first in a long list is this file's"
assert_not_contains "$OUT" "Broken pipe" "  and nothing writes to a broken pipe"
good_setup
printf 'BOGUS=1\n' >>"$SETUP"
vrefused "an unknown field" "BOGUS"
good_setup
printf 'TITLE=A title\n' >>"$SETUP"
vrefused "a run field in a setup file" "TITLE"
good_setup
grep -v '^TEAM=' "$SETUP" >"$SETUP.x" && mv "$SETUP.x" "$SETUP"
vrefused "a missing field" "TEAM"
good_setup
printf 'OWNER=Other\n' >>"$SETUP"
vrefused "a field given twice" "OWNER"
good_setup
printf 'not a line\n' >>"$SETUP"
vrefused "a line that is not FIELD=value" "not a line"
good_setup
printf 'owner=x\n' >>"$SETUP"
vrefused "a field not in capitals" "owner"
good_setup
printf 'OWNER=-bad\n' | cat - "$SETUP" | grep -v '^OWNER=Okja' >"$SETUP.x" && mv "$SETUP.x" "$SETUP"
vrefused "a value its type refuses" "OWNER"
good_setup
grep -v '^PEOPLE=' "$SETUP" >"$SETUP.x" && mv "$SETUP.x" "$SETUP"
printf 'PEOPLE=B\r\n' >>"$SETUP"
vrefused "a carriage return, read as part of the value" "PEOPLE: the value holds a control character"
good_setup
grep -v '^OWNER=' "$SETUP" >"$SETUP.x" && mv "$SETUP.x" "$SETUP"
printf 'OWNER=Okja-Engineering' >>"$SETUP"
answers_validate "$S" "$SETUP" setup >/dev/null
assert_status 0 "$?" "a last line without a newline is read"
# A NUL, which bash's read drops and awk may stop at, so readers would get
# different values (decision 229).
good_setup
grep -v '^OWNER=' "$SETUP" >"$SETUP.x" && mv "$SETUP.x" "$SETUP"
printf 'OWNER=Okja-Eng\000ineering\n' >>"$SETUP"
vrefused "a NUL byte in a value" "NUL"
good_setup
grep -v '^PEOPLE=' "$SETUP" >"$SETUP.x" && mv "$SETUP.x" "$SETUP"
printf 'PEOPLE=B\302\205\n' >>"$SETUP"
vrefused "a C1 control in a setup file" "PEOPLE: the value is not valid UTF-8, or holds a C1 control character"

# A run's answers file: every field, and TARGET.
RUN="$SCRATCH/run.env"
good_run() {
  cat "$SETUP" >"$RUN"
  printf '%s\n' 'NAME=widget' 'TITLE=A title' 'CODE=ABC' 'DESCRIPTION=One line' 'VISIBILITY=public' \
    'LICENSE=none' 'TARGET=/srv/targets/widget' >>"$RUN"
}
rrefused() { # DESCRIPTION NEEDLE
  local out st
  out=$(answers_validate "$S" "$RUN" run 2>&1)
  st=$?
  assert_status 1 "$st" "run file refused: $1"
  assert_contains "$out" "$2" "  and the refusal says: $2"
}
good_setup
good_run
answers_validate "$S" "$RUN" run >/dev/null
assert_status 0 "$?" "a valid run file, with TARGET, passes"
good_run
grep -v '^TARGET=' "$RUN" >"$RUN.x" && mv "$RUN.x" "$RUN"
rrefused "a run file without TARGET" "TARGET is missing"
good_run
grep -v '^TARGET=' "$RUN" >"$RUN.x" && mv "$RUN.x" "$RUN"
printf 'TARGET=targets/widget\n' >>"$RUN"
rrefused "a relative TARGET" "TARGET"
good_run
grep -v '^TARGET=' "$RUN" >"$RUN.x" && mv "$RUN.x" "$RUN"
printf 'TARGET=/srv/../widget\n' >>"$RUN"
rrefused "a TARGET holding .." "TARGET"
for t in /srv/targets/./widget //srv/targets/widget /srv/targets//widget /srv/targets/widget/ /; do
  good_run
  grep -v '^TARGET=' "$RUN" >"$RUN.x" && mv "$RUN.x" "$RUN"
  printf 'TARGET=%s\n' "$t" >>"$RUN"
  rrefused "a TARGET of $t" "TARGET: a path holds no empty, . or .. component"
done
good_run
grep -v '^TARGET=' "$RUN" >"$RUN.x" && mv "$RUN.x" "$RUN"
printf 'TARGET=/srv/targets/widget\r\n' >>"$RUN"
rrefused "a TARGET holding a carriage return" "TARGET: the value holds a control character"
good_run
grep -v '^TARGET=' "$RUN" >"$RUN.x" && mv "$RUN.x" "$RUN"
printf 'TARGET=/srv/targets/wid\377get\n' >>"$RUN"
rrefused "a TARGET that is not valid UTF-8" "TARGET: the value is not valid UTF-8"

# The run's TARGET is TARGET_ROOT, ~ expanded under this HOME, then /NAME,
# exactly (decision 227).
assert_eq "/srv/targets/widget" "$(answers_target_for /srv/targets widget)" "TARGET is TARGET_ROOT then /NAME"
assert_eq "/home/someone/t/widget" "$(answers_target_for '~/t' widget)" "  with ~ expanded"
target_file() { # TARGET_ROOT TARGET: a run file holding them
  printf '%s\n' 'NAME=widget' "TARGET_ROOT=$1" "TARGET=$2" >"$SCRATCH/target.env"
}
target_file /srv/targets /srv/targets/widget
answers_target_check "$SCRATCH/target.env" widget >/dev/null
assert_status 0 "$?" "a TARGET that is TARGET_ROOT then /NAME holds"
target_file '~/t' /home/someone/t/widget
answers_target_check "$SCRATCH/target.env" widget >/dev/null
assert_status 0 "$?" "  and one under ~, with this HOME"
out=$(HOME=/home/other answers_target_check "$SCRATCH/target.env" widget 2>&1)
assert_status 1 "$?" "refused: the same TARGET under another HOME"
assert_contains "$out" "/home/other/t/widget" "  and the refusal names the TARGET it would be"
target_file /srv/targets /srv/elsewhere/widget
out=$(answers_target_check "$SCRATCH/target.env" widget 2>&1)
assert_status 1 "$?" "refused: a TARGET edited to another place"
target_file /srv/targets /srv/targets/gadget
out=$(answers_target_check "$SCRATCH/target.env" widget 2>&1)
assert_status 1 "$?" "refused: a TARGET ending in another name"
printf '%s\n' 'NAME=widget' 'TARGET_ROOT=/srv/targets' >"$SCRATCH/target.env"
out=$(answers_target_check "$SCRATCH/target.env" widget 2>&1)
assert_status 1 "$?" "refused: no TARGET"
answers_validate "$S" "$SETUP" setup >/dev/null
printf 'TARGET=/srv/targets/widget\n' >>"$SETUP"
answers_validate "$S" "$SETUP" setup >/dev/null 2>&1
assert_status 1 "$?" "TARGET belongs to a run file, not a setup file"

# Run records: KEY: value lines.
printf '%s\n' '# Confirmed: widget' '' 'by: A Person: the operator' 'answers: abc123' >"$SCRATCH/record.md"
assert_eq "A Person: the operator" "$(answers_record "$SCRATCH/record.md" by)" "a record's value, read after its key"
assert_eq "abc123" "$(answers_record "$SCRATCH/record.md" answers)" "another"
answers_record "$SCRATCH/record.md" at >/dev/null
assert_status 1 "$?" "a key the record lacks reads as absent"
printf '%s\n' '# Render of widget, once at target: /old' 'target: /srv/widget' >"$SCRATCH/record.md"
assert_eq "/srv/widget" "$(answers_record "$SCRATCH/record.md" target)" "a key is read only at the start of its line"

assert_done
