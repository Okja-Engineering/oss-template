# shellcheck shell=bash
# The shared discard (AC9; decisions 118, 123, 134, 136, 140, 149, 227)
# and its removal helper (decisions 203, 211). `bin/ask --redo` and
# `bin/render --replace` call it, and verify's leftovers will.
#
#   discard_target PATH ANSWERS NAME RENDER_MD
#       remove PATH, the words of the operator's checkpoint, only when it is
#       the run's target, which the discard derives itself and trusts from
#       no caller: the TARGET_ROOT of the run's answers file ANSWERS, under
#       the path rule, its `~` expanded under this HOME, then /NAME
#       (answers_target_check). The answers file's TARGET must be that path,
#       and so must the target RENDER_MD names when it is a file, the run's
#       render.md; PATH must equal it byte for byte and not be a symbolic
#       link. So no TARGET or render.md edited by hand points the discard
#       outside TARGET_ROOT: by another root, a `..` component or a link on
#       the way. A PATH already gone is nothing to remove. Exit 0 when PATH
#       is gone, 1 on a refusal, with the reason out.
#   discard_check PATH ANSWERS NAME RENDER_MD
#       discard_target's judgement alone, removing nothing, so a caller can
#       refuse before it changes anything.
#   discard_record ANSWERS NAME RENDER_MD
#       the record RENDER_MD keeps, judged before a caller removes it, so no
#       removal of render.md drops the record of a present target the
#       discard may not take: when RENDER_MD is a file, it must name a
#       target and be read whole, and a target it names that is present, a
#       dangling link included, must be the one the discard derives from
#       ANSWERS. Print the target it names, nothing when it is not a file;
#       exit 0, or 1 with the reason out.
#   discard_there PATH
#       exit 0 when something is at PATH, a dangling link included, 1 when
#       nothing is, and 2 when that cannot be told: a directory above PATH
#       that cannot be searched. Each judge reads its three answers apart,
#       and cannot-tell refuses (decision 228).
#   discard_remove PATH
#       the removal helper: when PATH is a directory, and not a symbolic
#       link, restore the owner's read, write and search permission on it
#       and on each directory under it, each before it is read, following
#       no symbolic link and changing no file's mode; then remove PATH with
#       `rm`, called by name, and assert it gone. Exit 0 when PATH is gone,
#       1 when it remains, naming it.
#   discard_leftovers ROOT NAME [KEEP]
#       remove, through discard_remove, each staging directory a killed
#       render of the run NAME left in ROOT: a directory, not a symbolic
#       link, named exactly `.NAME.render.` then digits, but for
#       `.NAME.render.KEEP` (decision 226). Nothing else in ROOT is touched.
#       Exit 0 when none remains, 1 naming the first that does.
#
# What a run owns (decision 226): a run traps DISCARD_SIGNALS, so its EXIT
# trap removes what it made, holds them off while it creates a path and
# records it for that cleanup, and while it renames what it wrote into
# place, and holds them off through that cleanup, so a second signal never
# ends it partway. DISCARD_SIGNALS is worked out as this library is sourced,
# from the shell's own `trap -l`, which lists each number with its name in
# any shell mode, as `kill -l` does not with POSIXLY_CORRECT set: the
# number of every signal it lists but
# those whose default action never ends a process, CHLD, CLD, CONT, STOP,
# TSTP, TTIN, TTOU, URG, WINCH and INFO, and KILL, which no process can
# catch. So it is every catchable signal that ends a process by default,
# PROF, XCPU, ABRT, SYS and the rest, and on Linux PWR, STKFLT and the
# real-time signals, which bash traps by number; and, on macOS, IO, which is
# ignored there by default and is held too. A listing that gives no set,
# or one without HUP, INT and TERM, leaves DISCARD_SIGNALS empty, and each
# caller then exits 2 before it makes anything.
#   discard_traps   each of DISCARD_SIGNALS exits 128 plus its number, so
#                   the caller's EXIT trap runs
#   discard_hold    each of DISCARD_SIGNALS ignored, by this shell and the
#                   commands it starts, until discard_traps
#
# Source bin/lib/answers.sh first. The caller exports LC_ALL=C.

DISCARD_SIGNALS=""
discard__signals() {
  local w n="" set="" names=" "
  for w in $(trap -l); do
    case "$w" in
      *')') n=${w%')'} ;;
      SIG*)
        case "${w#SIG}" in
          CHLD | CLD | CONT | STOP | TSTP | TTIN | TTOU | URG | WINCH | INFO | KILL) ;;
          *) [ -z "$n" ] || set="$set $n" names="$names${w#SIG} " ;;
        esac
        n=""
        ;;
    esac
  done
  for w in HUP INT TERM; do
    case "$names" in
      *" $w "*) ;;
      *) return 1 ;;
    esac
  done
  DISCARD_SIGNALS=$set
}
discard__signals || DISCARD_SIGNALS=""

discard_traps() {
  local s
  for s in $DISCARD_SIGNALS; do
    # shellcheck disable=SC2064 # the status is fixed as the trap is set
    trap "exit $((128 + s))" "$s"
  done
}

discard_hold() {
  # shellcheck disable=SC2086 # the list, split into its signals
  trap '' $DISCARD_SIGNALS
}

discard_leftovers() {
  local root=$1 name=$2 keep=${3:-} left
  # A root that is not there holds none; one that cannot be listed is
  # refused, as a glob of it would give nothing (decision 228).
  discard_there "$root"
  case $? in
    0) ;;
    1) return 0 ;;
    *)
      printf 'cannot tell whether %s is there, so it cannot be swept of a killed render'"'"'s staging directories\n' "$root"
      return 1
      ;;
  esac
  if [ -d "$root" ] && { [ ! -r "$root" ] || [ ! -x "$root" ]; }; then
    printf 'cannot list %s, so it cannot be swept of a killed render'"'"'s staging directories; give its owner read and search permission on it\n' "$root"
    return 1
  fi
  for left in "$root/.$name.render."*; do
    case "${left##*/}" in
      ".$name.render."*[!0-9]* | ".$name.render." | ".$name.render.$keep") continue ;;
    esac
    if [ -d "$left" ] && [ ! -L "$left" ]; then
      discard_remove "$left" || return 1
    fi
  done
  return 0
}

discard_target() {
  # The check refuses a link, and the removal of a path already gone is
  # nothing to do, so the path checked is removed as it stands.
  discard_check "$@" || return 1
  discard_remove "$1"
}

discard_check() {
  local path=$1 answers=$2 name=$3 render_md=$4 target recorded
  if ! target=$(answers_target_check "$answers" "$name"); then
    printf 'remove %s: %s\n' "$path" "$target"
    return 1
  fi
  discard__file "$render_md" || return 1
  if [ -f "$render_md" ]; then
    if ! recorded=$(discard__recorded "$render_md"); then
      printf 'remove %s: %s\n' "$path" "$recorded"
      return 1
    fi
    if [ "$recorded" != "$target" ]; then
      printf 'remove %s: render.md names %s, not the run'"'"'s target %s\n' "$path" "$recorded" "$target"
      return 1
    fi
  fi
  if [ "$path" != "$target" ]; then
    printf 'remove %s: it is not the run'"'"'s target %s\n' "$path" "$target"
    return 1
  fi
  if [ -L "$path" ]; then
    printf 'remove %s: it is a symbolic link, not the rendered target\n' "$path"
    return 1
  fi
  return 0
}

discard_record() {
  local answers=$1 name=$2 render_md=$3 recorded target st
  discard__file "$render_md" || return 1
  [ -f "$render_md" ] || return 0
  recorded=$(discard__recorded "$render_md") || {
    printf '%s\n' "$recorded"
    return 1
  }
  discard_there "$recorded"
  st=$?
  if [ "$st" -gt 1 ]; then
    printf 'cannot tell whether %s is there, the target render.md names: a directory above it cannot be searched\n' "$recorded"
    return 1
  fi
  if [ "$st" = 0 ]; then
    if ! target=$(answers_target_check "$answers" "$name"); then
      printf 'render.md names %s, present, which the discard cannot judge: %s\n' "$recorded" "$target"
      return 1
    fi
    if [ "$recorded" != "$target" ]; then
      printf 'render.md names %s, not the run'"'"'s target %s\n' "$recorded" "$target"
      return 1
    fi
  fi
  printf '%s\n' "$recorded"
}

# discard__recorded RENDER_MD: the target RENDER_MD records; exit 1 with the
# reason out when it names none or cannot be read, a failure never read as
# none (decision 228).
discard__recorded() {
  local recorded fault
  recorded=$(answers_record "$1" target)
  case $? in
    0)
      # Only an absolute TARGET under the path rule names a target.
      fault=$(answers_target "$recorded")
      case $? in
        0) printf '%s\n' "$recorded" ;;
        1)
          printf '%s names no target: %s\n' "$1" "$fault"
          return 1
          ;;
        *)
          printf 'cannot judge the target %s names: %s\n' "$1" "$fault"
          return 1
          ;;
      esac
      ;;
    1)
      printf '%s names no target\n' "$1"
      return 1
      ;;
    *)
      printf 'cannot read %s\n' "$1"
      return 1
      ;;
  esac
}

# discard_there PATH: exit 0 when something is at PATH, a dangling symbolic
# link included; 1 when nothing is, the directory above it searched, or
# none there, or a file; 2 when that cannot be told, as a directory above
# it cannot be searched. A failure is never read as absent (decision 228).
discard_there() {
  local up
  if [ -e "$1" ] || [ -L "$1" ]; then
    return 0
  fi
  case "$1" in
    */*) up=${1%/*} ;;
    *) up=. ;;
  esac
  [ -n "$up" ] || up=/
  if [ -d "$up" ]; then
    [ -x "$up" ] || return 2
    return 1
  fi
  if [ -e "$up" ] || [ -L "$up" ]; then
    return 1
  fi
  discard_there "$up"
  [ "$?" -le 1 ] || return 2
  return 1
}

# discard__file RENDER_MD: RENDER_MD can be told there or not; else the
# reason out, exit 1.
discard__file() {
  discard_there "$1"
  [ "$?" -le 1 ] && return 0
  printf 'cannot tell whether %s is there: a directory above it cannot be searched\n' "$1"
  return 1
}

discard_remove() {
  if [ -d "$1" ] && [ ! -L "$1" ]; then
    discard__open "$1"
  fi
  rm -rf -- "$1" 2>/dev/null
  if [ -e "$1" ] || [ -L "$1" ]; then
    printf 'could not remove %s; remove it, then run the command again\n' "$1"
    return 1
  fi
  return 0
}

# discard__open DIR: give the owner read, write and search permission on DIR,
# then on each directory under it, top down, so each is opened only after.
discard__open() {
  local e
  chmod u+rwx -- "$1" 2>/dev/null
  for e in "$1"/* "$1"/.[!.]* "$1"/..?*; do
    if [ -d "$e" ] && [ ! -L "$e" ]; then
      discard__open "$e"
    fi
  done
}
