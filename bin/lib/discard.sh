# shellcheck shell=bash
# The shared discard (AC9; decisions 118, 123, 134, 136, 140, 149, 227) and
# its removal helper (decisions 203, 211). `bin/ask --redo` and
# `bin/render --replace` call it, and verify's leftovers will.
#
#   discard_target PATH NAME RECORDED TARGET
#       remove PATH, the words of the operator's checkpoint, only when PATH
#       and RECORDED are absolute, PATH equals RECORDED byte for byte,
#       RECORDED equals TARGET, and its last component is NAME and not a
#       symbolic link. RECORDED is the target the run's render.md records,
#       or, with no render.md, the run's TARGET; TARGET is the run's
#       recorded TARGET, which bin/ask wrote as TARGET_ROOT, `~` expanded,
#       then /NAME. So both callers use one root, the parent of the
#       recorded target. A PATH already gone is nothing to remove. Exit 0
#       when PATH is gone, 1 on a refusal, with the reason out.
#   discard_check PATH NAME RECORDED TARGET
#       discard_target's judgement alone, removing nothing, so a caller can
#       refuse before it changes anything.
#   discard_remove PATH
#       the removal helper: when PATH is a directory, and not a symbolic
#       link, restore the owner's read, write and search permission on it
#       and on each directory under it, each before it is read, following
#       no symbolic link and changing no file's mode; then remove PATH with
#       `rm`, called by name, and assert it gone. Exit 0 when PATH is gone,
#       1 when it remains, naming it.
#
# The caller exports LC_ALL=C.

discard_target() {
  discard_check "$@" || return 1
  if [ -e "$1" ] || [ -L "$1" ]; then
    discard_remove "$1"
  fi
}

discard_check() {
  local path=$1 name=$2 recorded=$3 target=$4
  case "$path" in
    /*) ;;
    *)
      printf 'remove %s: it is not an absolute path\n' "$path"
      return 1
      ;;
  esac
  case "$recorded" in
    /*) ;;
    *)
      printf 'remove %s: the recorded target %s is not an absolute path\n' "$path" "$recorded"
      return 1
      ;;
  esac
  if [ "$path" != "$recorded" ]; then
    printf 'remove %s: it is not the target render.md names, %s\n' "$path" "$recorded"
    return 1
  fi
  if [ "$recorded" != "$target" ]; then
    printf 'remove %s: render.md names it, but the run'"'"'s TARGET is %s\n' "$path" "$target"
    return 1
  fi
  if [ "${path##*/}" != "$name" ]; then
    printf 'remove %s: its last component is not the run name %s\n' "$path" "$name"
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
