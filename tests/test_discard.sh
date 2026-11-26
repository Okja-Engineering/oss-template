#!/usr/bin/env bash
# bin/lib/discard.sh, the shared discard and its removal helper (AC9;
# decisions 123, 134, 149, 203, 211, 227), called directly: the discard
# derives the run's target itself, from the run's answers file, and each
# guard of discard_check refuses with nothing removed, a hand-edited TARGET
# or render.md among them; discard_target judges before it removes; and
# discard_remove opens every directory it must, dot-named ones included,
# without following a symbolic link or changing a file's mode, and refuses,
# naming the path, when anything remains.
# shellcheck disable=SC2088 # a TARGET_ROOT holds a literal ~
set -u
set -o pipefail
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$TEST_DIR/../foundation/tests/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/failing.sh
. "$TEST_DIR/../foundation/tests/lib/failing.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/answers.sh
. "$TEST_DIR/../bin/lib/answers.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/discard.sh
. "$TEST_DIR/../bin/lib/discard.sh"

SCRATCH=$(mktemp -d)
SCRATCH=$(CDPATH='' cd -P -- "$SCRATCH" && pwd -P)
trap 'chmod -R u+rwx "$SCRATCH" 2>/dev/null; rm -rf "$SCRATCH"' EXIT
n=0
O=""

gone() { if [ -e "$1" ] || [ -L "$1" ]; then echo present; else echo gone; fi; }
# mode PATH: PATH's permission bits, as ls shows them, not following a link;
# ls, since stat's flags differ between BSD and GNU.
# shellcheck disable=SC2012
mode() { ls -ld "$1" | cut -c2-10; }
# answers TARGET_ROOT TARGET: the run's answers file A, holding them.
answers() { printf '%s\n' 'NAME=widget' "TARGET=$2" "TARGET_ROOT=$1" >"$A"; }
# target: a fresh TARGET_ROOT, ROOT, holding the run widget's target T, and
# the run's answers file A, as bin/ask writes it, with no render.md at M.
target() {
  n=$((n + 1))
  ROOT="$SCRATCH/root$n"
  T="$ROOT/widget"
  A="$SCRATCH/answers$n.env"
  M="$SCRATCH/render$n.md"
  O=""
  mkdir -p "$T/sub"
  printf 'x\n' >"$T/sub/file"
  answers "$ROOT" "$T"
}
# outside: a directory outside TARGET_ROOT, O, named widget and holding a
# file, which no discard may remove.
outside() {
  O="$SCRATCH/outside$n/widget"
  mkdir -p "$O"
  printf 'keep\n' >"$O/file"
}
# recorded TARGET: render.md M, naming TARGET.
recorded() { printf '%s\n' '# Render of widget' '' "target: $1" >"$M"; }
# refused DESCRIPTION NEEDLE PATH: discard_target PATH, of the run widget
# with the answers A and render.md M, refuses, saying NEEDLE, and the target
# and the outside directory, when there is one, are left.
refused() {
  local what=$1 needle=$2 out st
  out=$(discard_target "$3" "$A" widget "$M")
  st=$?
  assert_status 1 "$st" "refused: $what"
  assert_contains "$out" "$needle" "  and the refusal says: $needle"
  assert_eq "present" "$(gone "$T/sub/file")" "  with nothing removed"
  if [ -n "$O" ]; then assert_eq "present" "$(gone "$O/file")" "  and the outside directory left"; fi
}

# --- the target the discard derives, and each guard of discard_check ---------------------
target
discard_target "$T" "$A" widget "$M" >/dev/null
assert_status 0 "$?" "the run's target, TARGET_ROOT then /NAME, is removed"
assert_eq "gone" "$(gone "$T")" "  and is gone"
discard_target "$T" "$A" widget "$M" >/dev/null
assert_status 0 "$?" "a target already gone is nothing to remove"
target
recorded "$T"
discard_target "$T" "$A" widget "$M" >/dev/null
assert_status 0 "$?" "the target, named by render.md too, is removed"

# A TARGET edited by hand in the answers file, with no render.md and with
# render.md naming it too: outside TARGET_ROOT, through a .. component, and
# through a symbolic link on the way (removal N1 of S2's second ship gate).
for how in outside dotdot link; do
  target
  outside
  case "$how" in
    outside) P=$O ;;
    dotdot) P="$ROOT/../outside$n/widget" ;;
    link) ln -s "$SCRATCH/outside$n" "$ROOT/lnk" && P="$ROOT/lnk/widget" ;;
  esac
  answers "$ROOT" "$P"
  refused "a TARGET edited by hand to a path $how TARGET_ROOT" "is not TARGET_ROOT $ROOT, expanded here, then /widget" "$P"
  recorded "$P"
  refused "  and with render.md naming it too" "is not TARGET_ROOT $ROOT, expanded here, then /widget" "$P"
done
target
outside
recorded "$O"
refused "a render.md naming another path than the run's target" "render.md names $O, not the run's target $T" "$O"
refused "the run's target while render.md names another" "render.md names $O, not the run's target $T" "$T"
target
printf '%s\n' '# Render of widget' '' 'fingerprint: x' >"$M"
refused "a render.md naming no target" "names no target" "$T"
target
refused "a relative path" "is not the run's target $T" widget
(cd "$ROOT" && discard_target widget "$A" widget "$M" >/dev/null)
assert_status 1 "$?" "refused: a relative path naming the target from its parent"
assert_eq "present" "$(gone "$T/sub/file")" "  with nothing removed"
refused "the target in other bytes" "is not the run's target $T" "$ROOT/./widget"
mkdir -p "$ROOT/other"
refused "another path under TARGET_ROOT" "is not the run's target $T" "$ROOT/other"
assert_eq "present" "$(gone "$ROOT/other")" "  nor the other path"
refused "another run's name" "is not the run's target $T" "$ROOT/gadget"
# A TARGET_ROOT the path rule refuses gives no target to remove.
for bad in relative/root "$SCRATCH/x/../root" "$SCRATCH/./root" /; do
  target
  answers "$bad" "$bad/widget"
  refused "a TARGET_ROOT the path rule refuses, $bad" "gives no target" "$bad/widget"
done
target
answers '~/t' "$T"
out=$(HOME='' discard_target "$T" "$A" widget "$M")
assert_status 1 "$?" "refused: a TARGET_ROOT under ~ with HOME unset"
assert_eq "present" "$(gone "$T/sub/file")" "  with nothing removed"
target
grep -v '^TARGET=' "$A" >"$A.x" && mv "$A.x" "$A"
refused "an answers file holding no TARGET" "no TARGET" "$T"
target
grep -v '^TARGET_ROOT=' "$A" >"$A.x" && mv "$A.x" "$A"
refused "an answers file holding no TARGET_ROOT" "no TARGET_ROOT" "$T"
target
mv "$T" "$ROOT/real"
ln -s "$ROOT/real" "$T"
out=$(discard_target "$T" "$A" widget "$M")
assert_status 1 "$?" "refused: a target that is a symbolic link"
assert_contains "$out" "symbolic link" "  and the refusal says so"
assert_eq "present" "$(gone "$T")" "  with the link left"
assert_eq "present" "$(gone "$ROOT/real/sub/file")" "  and what it points to"
discard_check "$T" "$A" widget "$M" >/dev/null
assert_status 1 "$?" "discard_check alone refuses it too"

# --- discard_remove: open every directory, follow no link, change no file's mode ------------
if [ "$(id -u)" != 0 ]; then
  target
  mkdir -p "$T/.git/objects/deep" "$T/..odd/deeper"
  printf 'o\n' >"$T/.git/objects/deep/o"
  printf 'p\n' >"$T/..odd/deeper/p"
  chmod 000 "$T/.git/objects/deep" "$T/.git/objects" "$T/.git" "$T/..odd/deeper" "$T/..odd"
  discard_target "$T" "$A" widget "$M" >/dev/null
  assert_status 0 "$?" "a target holding chmod 000 dot-named directories is removed"
  assert_eq "gone" "$(gone "$T")" "  whole"

  target
  mkdir -p "$SCRATCH/outside$n/kept"
  chmod 500 "$SCRATCH/outside$n/kept" "$SCRATCH/outside$n"
  ln -s "$SCRATCH/outside$n" "$T/sub/link"
  ln -s "$SCRATCH/outside$n" "$T/.dotlink"
  discard_target "$T" "$A" widget "$M" >/dev/null
  assert_status 0 "$?" "a target holding links to an outside directory is removed"
  assert_eq "r-x------" "$(mode "$SCRATCH/outside$n")" "  and the linked directory's mode is unchanged"
  assert_eq "r-x------" "$(mode "$SCRATCH/outside$n/kept")" "  as is its subdirectory's"

  n=$((n + 1))
  mkdir -p "$SCRATCH/outside$n"
  chmod 500 "$SCRATCH/outside$n"
  ln -s "$SCRATCH/outside$n" "$SCRATCH/link$n"
  discard_remove "$SCRATCH/link$n" >/dev/null
  assert_status 0 "$?" "discard_remove of a link to a directory"
  assert_eq "gone" "$(gone "$SCRATCH/link$n")" "  removes the link"
  assert_eq "r-x------" "$(mode "$SCRATCH/outside$n")" "  and leaves the directory's mode"

  target
  printf 'shared\n' >"$SCRATCH/hard$n"
  chmod 400 "$SCRATCH/hard$n"
  ln "$SCRATCH/hard$n" "$T/sub/hard"
  chmod 500 "$T/sub"
  discard_target "$T" "$A" widget "$M" >/dev/null
  assert_status 0 "$?" "a target holding a hard link to an outside file is removed"
  assert_eq "r--------" "$(mode "$SCRATCH/hard$n")" "  and the outside file's mode is unchanged"
fi

# --- a removal that leaves something, refused naming the path -------------------------------
target
mkdir -p "$SCRATCH/stub$n"
printf '#!/bin/sh\nexit 0\n' >"$SCRATCH/stub$n/rm"
chmod +x "$SCRATCH/stub$n/rm"
out=$(PATH="$SCRATCH/stub$n:$PATH" discard_remove "$T")
assert_status 1 "$?" "refused: a removal that leaves the path"
assert_eq "could not remove $T; remove it, then run the command again" "$out" "  naming it"
# A dangling link the removal leaves is left too, never read as gone (the
# tests lens's N9 of S2's third ship gate).
n=$((n + 1))
ln -s "$SCRATCH/nowhere$n" "$SCRATCH/dangling$n"
out=$(PATH="$SCRATCH/stub$((n - 1)):$PATH" discard_remove "$SCRATCH/dangling$n")
assert_status 1 "$?" "refused: a removal that leaves a dangling link"
assert_eq "could not remove $SCRATCH/dangling$n; remove it, then run the command again" "$out" "  naming it"

# --- the signals a run holds and traps (decision 226) -------------------------------------
# Every signal kill -l lists whose default action ends a process, worked
# out at run time; none whose default action does not (render N1 of S2's
# third ship gate). DISCARD_SIGNALS holds their numbers.
for s in HUP INT QUIT TERM PIPE ALRM USR1 USR2 XFSZ VTALRM PROF XCPU ABRT SYS TRAP BUS FPE ILL SEGV; do
  assert_contains " $DISCARD_SIGNALS " " $(kill -l "$s") " "DISCARD_SIGNALS holds SIG$s"
done
for s in CHLD CONT STOP TSTP TTIN TTOU URG WINCH KILL; do
  assert_not_contains " $DISCARD_SIGNALS " " $(kill -l "$s") " "DISCARD_SIGNALS does not hold SIG$s"
done
if kill -l RTMIN >/dev/null 2>&1; then
  assert_contains " $DISCARD_SIGNALS " " $(kill -l RTMIN) " "DISCARD_SIGNALS holds the first real-time signal"
fi
# The set is the same in any shell mode: in POSIX mode kill -l prints bare
# names, which once gave an empty set (render R1 of S2's fourth ship gate).
# signals_of: DISCARD_SIGNALS, as a shell sourcing discard.sh works it out.
signals_of() { bash -c '. "$1/answers.sh" && . "$1/discard.sh" && printf "%s" "$DISCARD_SIGNALS"' _ "$TEST_DIR/../bin/lib"; }
assert_eq "$DISCARD_SIGNALS" "$(POSIXLY_CORRECT=1 signals_of)" "DISCARD_SIGNALS is the same with POSIXLY_CORRECT set"
# A listing that gives no set, or one lacking HUP, INT or TERM, gives none,
# so each caller refuses before it makes anything (its own cases); a trap
# exported as a function stands in for the shell's own list.
listed() {
  (
    trap() { if [ "${1:-}" = -l ]; then printf '%s' "$LISTING"; else builtin trap "$@"; fi; }
    export -f trap
    signals_of
  )
}
for LISTING in '' ' 1) SIGHUP	 2) SIGINT	 3) SIGQUIT' ' 2) SIGINT	15) SIGTERM' 'HUP INT TERM'; do
  assert_eq "" "$(LISTING=$LISTING listed)" "no set from the listing \"$LISTING\""
done
LISTING=' 1) SIGHUP	 2) SIGINT	15) SIGTERM	20) SIGCHLD'
assert_eq " 1 2 15" "$(LISTING=$LISTING listed)" "the set from a listing holding HUP, INT and TERM"

# --- the root rule: no path in a working tree of the workspace (decision 227) ---------------
# The workspace is the one these libraries are sourced from.
target
WSD=$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)
answers "$WSD/stages/01-ask/output" "$WSD/stages/01-ask/output/widget"
out=$(discard_check "$WSD/stages/01-ask/output/widget" "$A" widget "$M")
assert_status 1 "$?" "refused: the run's target derived under a TARGET_ROOT inside the workspace"
assert_contains "$out" "a working tree of this workspace" "  and the refusal says so"

# --- discard_record: render.md's record, judged before anything removes it -----------------
# recjudge: discard_record of the run widget, with the answers A and
# render.md M, its output and status in OUT and ST.
recjudge() { OUT=$(discard_record "$A" widget "$M"); ST=$?; }
target
recjudge
assert_status 0 "$ST" "no render.md is no record to judge"
assert_eq "" "$OUT" "  and names no target"
recorded "$T"
recjudge
assert_status 0 "$ST" "a render.md naming the run's target, present"
assert_eq "$T" "$OUT" "  prints it"
printf '%s\n' '# Render of widget' '' 'fingerprint: x' >"$M"
recjudge
assert_status 1 "$ST" "refused: a render.md naming no target"
assert_contains "$OUT" "$M names no target" "  and the refusal says so"
rm -rf "$T"
recjudge
assert_status 1 "$ST" "refused: a render.md naming no target, the target gone"
target
outside
recorded "$O"
recjudge
assert_status 1 "$ST" "refused: a render.md naming a present path that is not the run's target"
assert_contains "$OUT" "render.md names $O, not the run's target $T" "  with the discard's reason"
rm -rf "$T"
recjudge
assert_status 1 "$ST" "  refused with the run's target gone too"
rm -rf "$O"
recjudge
assert_status 0 "$ST" "a render.md naming a path that is gone, which no removal of it orphans"
assert_eq "$O" "$OUT" "  prints it"
target
answers "$SCRATCH/x/../root$n" "$T"
recorded "$T"
recjudge
assert_status 1 "$ST" "refused: a present recorded target the answers give no target for"
assert_contains "$OUT" "gives no target" "  with the discard's reason"
target
recorded "$T"
fixture_failing "$SCRATCH/rec$n" awk '*ENVIRON\["K"]*' 1 2
OUT=$(PATH="$SCRATCH/rec$n:$PATH" && discard_record "$A" widget "$M")
assert_status 1 "$?" "refused: a render.md whose record cannot be read"
assert_contains "$OUT" "cannot read $M" "  and the refusal says so"

assert_done
