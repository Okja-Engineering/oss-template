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
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/fixture.sh
. "$TEST_DIR/../foundation/tests/lib/fixture.sh"
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
no TITLE "$(printf 'a\340\200\257b')" "not valid UTF-8"
no TITLE "$(printf 'a\360\200\200\257b')" "not valid UTF-8"
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
# A GitHub login is at most 39 characters, in every type that holds one.
ok TEAM "@$(rep 39 a)/maintainers"
no TEAM "@$(rep 40 a)/maintainers" "39"
no TEAM "@$(rep 40 a)" "39"
ok CONTACT 'https://example.com/conduct'
ok CONTACT 'not yet set, so launch waits on it'
no CONTACT 'http://example.com/conduct' "CONTACT"
no CONTACT 'nobody' "CONTACT"
ok HOME_URL 'https://github.com/Okja-Engineering/oss-template'
no HOME_URL 'https://gitlab.com/okja/oss-template' "HOME_URL"
no HOME_URL 'https://github.com/okja' "HOME_URL"
ok HOME_URL "https://github.com/$(rep 39 a)/x"
no HOME_URL "https://github.com/$(rep 40 a)/x" "39"
ok HOME_URL 'https://github.com/okja/.github'
ok HOME_URL 'https://github.com/okja/...'
no HOME_URL 'https://github.com/okja/.' "not named . or .."
no HOME_URL 'https://github.com/okja/..' "not named . or .."
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
# The expansion meets the rule every value meets (answers A2, decision 227).
for home in "$(printf '/h/new\nline')" "$(printf '/h/c1\302\205')" "$(printf '/h/bad\377')" '/h/{{OWNER}}'; do
  out=$(HOME=$home answers_check "$S" TARGET_ROOT '~/x' 2>&1)
  assert_status 1 "$?" "refused: TARGET_ROOT=~/x under a HOME the value rule refuses: $(printf '%s' "$home" | od -An -c | tr -s ' ' | tail -c 20)"
  assert_contains "$out" "TARGET_ROOT, its ~ expanded," "  and the refusal names the expansion"
done
out=$(HOME='/h/plain' answers_check "$S" TARGET_ROOT '~/x' 2>&1)
assert_status 0 "$?" "  and a HOME it accepts is accepted"
out=$(HOME="$(printf '/h/new\nline')" answers_check "$S" TARGET_ROOT '/srv/x' 2>&1)
assert_status 0 "$?" "  and a TARGET_ROOT with no ~ is not judged by HOME"
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
ok CONTACT 'conduct@example.io'
no TITLE 'Write to a.person@example.io' "email"
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
# The one reader: the file-level rule before any value is kept (answers A1).
printf 'OWNER=Okja\000-Engineering\nTITLE=x\n' >"$SCRATCH/nul.env"
out=$(answers_read "$SCRATCH/nul.env" the-label 2>&1)
assert_status 1 "$?" "answers_read refuses a file holding a NUL"
assert_contains "$out" "the-label: the file holds a NUL byte" "  naming the file by its label"
answers_get "$SCRATCH/nul.env" TITLE >/dev/null 2>&1
assert_status 2 "$?" "answers_get refuses one too, as unreadable, not as absent"
assert_eq "$(cat "$A")" "$(answers_read "$A" a)" "answers_read gives an accepted file's text"
out=$(answers_read "$SCRATCH/no-such.env" the-label 2>&1)
assert_status 2 "$?" "answers_read cannot read a file it cannot read, exiting 2"
assert_contains "$out" "the-label" "  naming it"
# answers_setup: the setup fields, each given or its default worked out from
# those before it, sorted (decision 229).
out=$(answers_setup "$S" "$(printf 'OWNER=acme\nPEOPLE=A Person')" 2>&1)
assert_status 0 "$?" "answers_setup"
assert_contains "$out" "TARGET_ROOT=~/Development/acme" "  works a default out from a field given"
assert_contains "$out" "TEAM=@acme/maintainers" "  each default"
assert_eq "$out" "$(printf '%s\n' "$out" | LC_ALL=C sort)" "  sorted"
out=$(answers_setup "$S" "$(printf 'OWNER=acme\nPEOPLE=A\nTEAM=octo')" 2>&1)
assert_status 1 "$?" "answers_setup refuses a given value its check refuses"
assert_contains "$out" "give TEAM again" "  and says to give it again"

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
# The readers given a pipe read it whole: answers_get on standard input, as
# bin/ask feeds it pairs, and rules_word, so neither fails its writer.
big=$(cut -f 1 "$SCRATCH/long.tsv" | sed 's/$/=x/')
OUT=$(printf 'AAB=first\n%s\nAAB=second\n' "$big" | answers_get - AAB 2>&1)
assert_status 0 "$?" "answers_get finds a pair first in a long pipe"
assert_eq "first" "$OUT" "  and gives the first value alone"
OUT=$(rules_word "$(printf 'You must.\n%s\nNever.\n' "$big")" 2>&1)
assert_status 0 "$?" "rules_word finds a rule word first in a long text"
assert_eq "must" "$OUT" "  and gives the first word alone"
printf '%s\n' 'target: /first' 'target: /second' >"$SCRATCH/twice.md"
assert_eq "/first" "$(answers_record "$SCRATCH/twice.md" target)" "answers_record gives a key's first value alone"
good_setup
printf 'BOGUS=1\n' >>"$SETUP"
vrefused "an unknown field" "BOGUS: an unknown field"
good_setup
printf 'TITLE=A title\n' >>"$SETUP"
vrefused "a run field in a setup file" "TITLE is a run field, not one of this file"
good_setup
grep -v '^TEAM=' "$SETUP" >"$SETUP.x" && mv "$SETUP.x" "$SETUP"
vrefused "a missing field" "TEAM is missing"
good_setup
printf 'OWNER=Other\n' >>"$SETUP"
vrefused "a field given twice" "OWNER is given twice"
good_setup
printf 'not a line\n' >>"$SETUP"
vrefused "a line that is not FIELD=value" "not a FIELD=value line"
good_setup
printf 'owner=x\n' >>"$SETUP"
vrefused "a field not in capitals" "not a FIELD=value line"
# A bare field name, with no =, gives no value, even when the name alone would
# pass as one (the tests lens's F7).
good_setup
grep -v '^OWNER=' "$SETUP" >"$SETUP.x" && mv "$SETUP.x" "$SETUP"
printf 'OWNER\n' >>"$SETUP"
vrefused "a bare field name with no =" "$SETUP:6: not a FIELD=value line"
good_setup
printf 'OWNER=-bad\n' | cat - "$SETUP" | grep -v '^OWNER=Okja' >"$SETUP.x" && mv "$SETUP.x" "$SETUP"
vrefused "a value its type refuses" "OWNER: a GitHub login is"
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
assert_eq "the answers hold no TARGET" "$out" "  and the refusal says so, and nothing else"
printf '%s\n' 'NAME=widget' 'TARGET=/srv/targets/widget' >"$SCRATCH/target.env"
out=$(answers_target_check "$SCRATCH/target.env" widget 2>&1)
assert_status 1 "$?" "refused: no TARGET_ROOT"
assert_eq "the answers hold no TARGET_ROOT" "$out" "  and the refusal says so, and nothing else"
target_file '~/t' /home/someone/t/widget
out=$( (unset HOME && answers_target_check "$SCRATCH/target.env" widget) 2>&1)
assert_status 1 "$?" "refused: a TARGET_ROOT under ~ with HOME unset"
assert_eq "TARGET_ROOT ~/t gives no target: it starts with ~, and HOME is not set" "$out" \
  "  and the refusal is why, and nothing else"
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

# --- a read that fails, refused (decision 228) -------------------------------------
# Each rule's input comes from a command whose status is read: a stub tool
# failing one call (fixture_failing) is refused, never judged as an empty value.
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/failing.sh
. "$TEST_DIR/../foundation/tests/lib/failing.sh"
k=0
# under TOOL PATTERN NTH COMMAND...: COMMAND's output and status, OUT and ST,
# with a stub TOOL failing as fixture_failing says. PATH is assigned in the
# subshell, not as a prefix, so bash forgets each tool it has found.
under() {
  k=$((k + 1))
  fixture_failing "$SCRATCH/fail$k" "$1" "$2" "$3" "${FAIL_STATUS:-1}"
  shift 3
  OUT=$(PATH="$SCRATCH/fail$k:$PATH" && "$@" 2>&1)
  ST=$?
}
# A judge's 1 is a refusal; one that cannot judge exits 2, saying what it
# could not read. answers_check reads a field's type, then its pattern,
# then its default.
under awk '*col\[$i] = i*' 2 answers_check "$S" CODE abc
assert_status 2 "$ST" "cannot judge: a value whose pattern cannot be read"
assert_contains "$OUT" "CODE: cannot read its row of the schema" "  and says so"
under awk '*col\[$i] = i*' 3 answers_check "$S" CONTACT 'not yet set, so launch waits on it'
assert_status 2 "$ST" "cannot judge: a value whose default cannot be read"
assert_contains "$OUT" "CONTACT: cannot read its row of the schema" "  and says so"
under tr '-d \\200-\\277' 1 answers_check "$S" DESCRIPTION "$(rep 351 a)"
assert_status 2 "$ST" "cannot judge: a description whose characters cannot be counted"
assert_contains "$OUT" "cannot count the characters" "  and says so"
good_setup
under awk '*ENVIRON\["S"] == ""*' 1 answers_validate "$S" "$SETUP" setup
assert_status 2 "$ST" "cannot judge: a file whose schema's fields cannot be read"
assert_contains "$OUT" "cannot read the fields of the schema" "  and says so"
printf 'OWNER=Ok\000ja\n' >>"$SETUP"
under tr '-d \\000' 1 answers_validate "$S" "$SETUP" setup
assert_status 2 "$ST" "cannot judge: a file holding a NUL byte, whose bytes cannot be counted without it"
assert_contains "$OUT" "cannot read the file" "  and says so"
under wc '-c' 1 answers_validate "$S" "$SETUP" setup
assert_status 2 "$ST" "cannot judge: a file holding a NUL byte, whose bytes cannot be counted"
assert_contains "$OUT" "cannot read the file" "  and says so"

# A lookup whose 1 is "none" or "no", a grep or an awk-backed helper,
# failing with a higher status, is never read as that answer (decision
# 228): the judge exits 2, saying what it could not read.
export FAIL_STATUS=2
under awk '*col\[$i] = i*' 1 answers_check "$S" CODE ABC
assert_status 2 "$ST" "cannot judge: a value whose type cannot be read, never an unknown field"
assert_contains "$OUT" "CODE: cannot read its row of the schema" "  and says so"
under grep '-Eq -e \[A-Za-z0-9._%+-]+@*' 1 answers_check "$S" TITLE 'write to a@b.co'
assert_status 2 "$ST" "cannot judge: free text whose look for an email address fails"
assert_contains "$OUT" "TITLE: cannot look for an email address in the value" "  and says so"
under awk '*MODE=word*' 1 answers_check "$S" TITLE 'you must stop'
assert_status 2 "$ST" "cannot judge: free text whose look for a rule word fails"
assert_contains "$OUT" "TITLE: cannot look for a rule word in the value" "  and says so"
under grep '-Eq -e ^((\[*' 1 answers_check "$S" TITLE 'plain'
assert_status 2 "$ST" "cannot judge: a value whose UTF-8 match fails"
assert_contains "$OUT" "TITLE: cannot match the value against its rule" "  and says so"
under grep '-Eq -e ^(\[a-z0-9]*' 1 answers_check "$S" NAME 'widget'
assert_status 2 "$ST" "cannot judge: a name whose match fails, never a name refused"
assert_contains "$OUT" "NAME: cannot match the value against its rule" "  and says so"
under grep '-Eq -e ^(\[A-Z]{3})*' 1 answers_check "$S" CODE 'abc'
assert_status 2 "$ST" "cannot judge: a value whose pattern's match fails"
good_setup
under grep '-Eq -e ^((\[*' 1 answers_validate "$S" "$SETUP" setup
assert_status 2 "$ST" "cannot judge: a file with a line that cannot be judged"
under grep '-Eq -e ^(\[A-Z]\[A-Z0-9_]*' 1 answers_validate "$S" "$SETUP" setup
assert_status 2 "$ST" "cannot judge: a file whose line's field name cannot be matched"
under grep '-Fxq -e CONTACT' 1 answers_validate "$S" "$SETUP" setup
assert_status 2 "$ST" "cannot judge: a file whose field cannot be looked up in the schema"
printf 'OWNER=acme\n' >"$SCRATCH/given.env"
under grep '-Eq -e ^(\[A-Z]\[A-Z0-9_]*' 1 answers_given "$SCRATCH/given.env" given.env
assert_status 2 "$ST" "cannot read: a given file whose field name cannot be matched"
under awk '*!found && i > 1*' 1 answers_default "$S" TEAM 'OWNER=acme'
assert_status 2 "$ST" "cannot work out: a default whose field's value cannot be read, never one left as {{OWNER}}"
under awk '*!found && i > 1*' 1 answers_derive "$S" setup 'OWNER=acme' ''
assert_status 2 "$ST" "cannot derive: what was given cannot be read"
assert_contains "$OUT" "cannot read what was given" "  and says so"
target_file /srv/targets /srv/targets/widget
under awk '*!found && i > 1*' 1 answers_target_check "$SCRATCH/target.env" widget
assert_status 2 "$ST" "cannot read: a TARGET that cannot be read, never one the answers lack"
assert_eq "cannot read TARGET from the answers" "$OUT" "  and says so"
under awk '*!found && i > 1*' 2 answers_target_check "$SCRATCH/target.env" widget
assert_status 2 "$ST" "cannot read: a TARGET_ROOT that cannot be read, never one the answers lack"
assert_eq "cannot read TARGET_ROOT from the answers" "$OUT" "  and says so"
unset FAIL_STATUS

# A type the validator does not know is refused, even in a schema the
# schema check has not read.
{ head -n 1 "$S"; row X run bogus no - - - 'X?'; } >"$SCRATCH/bogus.tsv"
OUT=$(answers_check "$SCRATCH/bogus.tsv" X value 2>&1)
assert_status 1 "$?" "refused: a value of a type the validator does not know"
assert_contains "$OUT" "the type bogus is not one this validator knows" "  and the refusal says so"
# A default of - is none, in the questionnaire as in the validator.
assert_contains "$(answers_questionnaire "$S")" "(\`PEOPLE\`, list; no default)" "the questionnaire says a - default is none"
# A select's value is one of its values, compared as a string, never as a
# pattern, so a value holding a pattern's characters is still one of them.
{ head -n 1 "$S"; row LANG run select no - 'c++|c' c 'Which language?'; } >"$SCRATCH/select.tsv"
OUT=$(answers_check "$SCRATCH/select.tsv" LANG 'c++' 2>&1)
assert_status 0 "$?" "a select value holding + is one of its values${OUT:+ ($OUT)}"
# The blob id confirm records is of the file's bytes, whatever the
# repository's attributes would make of them.
mkdir -p "$SCRATCH/attr"
git -C "$SCRATCH/attr" init -q
printf '* ident\n' >"$SCRATCH/attr/.gitattributes"
printf 'TITLE=$Id: kept $\n' >"$SCRATCH/attr/answers.env"
assert_eq "$(printf 'TITLE=$Id: kept $\n' | git hash-object -t blob --no-filters --stdin)" \
  "$(cd "$SCRATCH/attr" && answers_blob answers.env)" "answers_blob is the id of the bytes, under an ident attribute"

assert_done
