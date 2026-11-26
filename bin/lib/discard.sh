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
# What a run owns (decision 226): a run traps DISCARD_SIGNALS, every
# catchable signal that ends a process by default, so its EXIT trap removes
# what it made, and holds them off while it creates a path and records it
# for that cleanup, and while it renames what it wrote into place.
#   discard_traps   each of DISCARD_SIGNALS exits 128 plus its number, so
#                   the caller's EXIT trap runs
#   discard_hold    each of DISCARD_SIGNALS ignored, by this shell and the
#                   commands it starts, until discard_traps
#
# Source bin/lib/answers.sh first. The caller exports LC_ALL=C.

DISCARD_SIGNALS='HUP INT QUIT TERM PIPE USR1 USR2 ALRM XFSZ VTALRM'

discard_traps() {
  local s
  for s in $DISCARD_SIGNALS; do
    # shellcheck disable=SC2064 # the status is fixed as the trap is set
    trap "exit $((128 + $(kill -l "$s")))" "$s"
  done
}

discard_hold() {
  # shellcheck disable=SC2086 # the list, split into its signals
  trap '' $DISCARD_SIGNALS
}

discard_leftovers() {
  local root=$1 name=$2 keep=${3:-} left
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
  discard_check "$@" || return 1
  if [ -e "$1" ] || [ -L "$1" ]; then
    discard_remove "$1"
  fi
}

discard_check() {
  local path=$1 answers=$2 name=$3 render_md=$4 target recorded
  if ! target=$(answers_target_check "$answers" "$name"); then
    printf 'remove %s: %s\n' "$path" "$target"
    return 1
  fi
  if [ -f "$render_md" ]; then
    if ! recorded=$(answers_record "$render_md" target); then
      printf 'remove %s: %s names no target\n' "$path" "$render_md"
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
