#!/usr/bin/env bash
# bin/lib/discard.sh, the shared discard and its removal helper (AC9;
# decisions 123, 134, 149, 203, 211, 227), called directly: each guard of
# discard_check refuses with nothing removed, discard_target judges before
# it removes, and discard_remove opens every directory it must, dot-named
# ones included, without following a symbolic link or changing a file's
# mode, and refuses, naming the path, when anything remains.
set -u
set -o pipefail
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$TEST_DIR/../foundation/tests/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/discard.sh
. "$TEST_DIR/../bin/lib/discard.sh"

SCRATCH=$(mktemp -d)
SCRATCH=$(CDPATH='' cd -P -- "$SCRATCH" && pwd -P)
trap 'chmod -R u+rwx "$SCRATCH" 2>/dev/null; rm -rf "$SCRATCH"' EXIT
n=0

gone() { if [ -e "$1" ] || [ -L "$1" ]; then echo present; else echo gone; fi; }
# mode PATH: PATH's permission bits, as ls shows them, not following a link;
# ls, since stat's flags differ between BSD and GNU.
# shellcheck disable=SC2012
mode() { ls -ld "$1" | cut -c2-10; }
# target: a fresh TARGET_ROOT, ROOT, holding the run widget's target T.
target() {
  n=$((n + 1))
  ROOT="$SCRATCH/root$n"
  T="$ROOT/widget"
  mkdir -p "$T/sub"
  printf 'x\n' >"$T/sub/file"
}
# refused DESCRIPTION NEEDLE PATH NAME RECORDED TARGET: discard_target
# refuses, saying NEEDLE, and the target is left.
refused() {
  local what=$1 needle=$2 out st
  shift 2
  out=$(discard_target "$@")
  st=$?
  assert_status 1 "$st" "refused: $what"
  assert_contains "$out" "$needle" "  and the refusal says: $needle"
  assert_eq "present" "$(gone "$T/sub/file")" "  with nothing removed"
}

# --- discard_check's guards, each through discard_target ------------------------------
target
discard_target "$T" widget "$T" "$T" >/dev/null
assert_status 0 "$?" "the target, named as recorded, is removed"
assert_eq "gone" "$(gone "$T")" "  and is gone"
discard_target "$T" widget "$T" "$T" >/dev/null
assert_status 0 "$?" "a target already gone is nothing to remove"

target
refused "a relative path" "it is not an absolute path" widget widget widget widget
(cd "$ROOT" && discard_target widget widget "$T" "$T" >/dev/null)
assert_status 1 "$?" "refused: a relative path naming the target from its parent"
assert_eq "present" "$(gone "$T/sub/file")" "  with nothing removed"
refused "a relative recorded target" "the recorded target widget is not an absolute path" "$T" widget widget "$T"
refused "a path other than the recorded target" "not the target render.md names" "$ROOT/./widget" widget "$T" "$T"
mkdir -p "$ROOT/other"
refused "a recorded target other than the run's TARGET" "but the run's TARGET is $T" "$ROOT/other" widget "$ROOT/other" "$T"
assert_eq "present" "$(gone "$ROOT/other")" "  nor the other path"
refused "a target whose last component is not NAME" "last component" "$ROOT/other" widget "$ROOT/other" "$ROOT/other"
assert_eq "present" "$(gone "$ROOT/other")" "  nor the other path"
mv "$T" "$ROOT/real"
ln -s "$ROOT/real" "$T"
out=$(discard_target "$T" widget "$T" "$T")
assert_status 1 "$?" "refused: a target that is a symbolic link"
assert_contains "$out" "symbolic link" "  and the refusal says so"
assert_eq "present" "$(gone "$T")" "  with the link left"
assert_eq "present" "$(gone "$ROOT/real/sub/file")" "  and what it points to"
discard_check "$T" widget "$T" "$T" >/dev/null
assert_status 1 "$?" "discard_check alone refuses it too"

# --- discard_remove: open every directory, follow no link, change no file's mode ------------
if [ "$(id -u)" != 0 ]; then
  target
  mkdir -p "$T/.git/objects/deep" "$T/..odd/deeper"
  printf 'o\n' >"$T/.git/objects/deep/o"
  printf 'p\n' >"$T/..odd/deeper/p"
  chmod 000 "$T/.git/objects/deep" "$T/.git/objects" "$T/.git" "$T/..odd/deeper" "$T/..odd"
  discard_target "$T" widget "$T" "$T" >/dev/null
  assert_status 0 "$?" "a target holding chmod 000 dot-named directories is removed"
  assert_eq "gone" "$(gone "$T")" "  whole"

  target
  mkdir -p "$SCRATCH/outside$n/kept"
  chmod 500 "$SCRATCH/outside$n/kept" "$SCRATCH/outside$n"
  ln -s "$SCRATCH/outside$n" "$T/sub/link"
  ln -s "$SCRATCH/outside$n" "$T/.dotlink"
  discard_target "$T" widget "$T" "$T" >/dev/null
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
  discard_target "$T" widget "$T" "$T" >/dev/null
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

assert_done
