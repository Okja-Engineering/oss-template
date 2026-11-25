# shellcheck shell=bash
# The shared discard (AC9; decisions 118, 123, 134, 136, 140, 149) and its
# removal helper (decisions 203, 211). `bin/ask --redo` is its first caller;
# `bin/render --replace` and verify's leftovers call it too.
#
#   discard_target PATH NAME RECORDED ROOT
#       remove PATH, the words of the operator's checkpoint, only when PATH
#       equals RECORDED (the target render.md names) byte for byte, its last
#       component is NAME and not a symbolic link, and its parent, resolved
#       with `pwd -P`, equals ROOT (the run's TARGET_ROOT, expanded)
#       resolved with `pwd -P`. A PATH already gone is nothing to remove.
#       Exit 0 when PATH is gone, 1 on a refusal, with the reason out.
#   discard_check PATH NAME RECORDED ROOT
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
  local path=$1 name=$2 recorded=$3 root=$4 parent real_parent real_root
  if [ "$path" != "$recorded" ]; then
    printf 'remove %s: it is not the target render.md names, %s\n' "$path" "$recorded"
    return 1
  fi
  if [ "${path##*/}" != "$name" ]; then
    printf 'remove %s: its last component is not the run name %s\n' "$path" "$name"
    return 1
  fi
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    return 0
  fi
  if [ -L "$path" ]; then
    printf 'remove %s: it is a symbolic link, not the rendered target\n' "$path"
    return 1
  fi
  parent=${path%/*}
  [ -n "$parent" ] || parent=/
  if ! real_parent=$(CDPATH='' cd -P -- "$parent" 2>/dev/null && pwd -P); then
    printf 'remove %s: its parent %s cannot be resolved\n' "$path" "$parent"
    return 1
  fi
  if ! real_root=$(CDPATH='' cd -P -- "$root" 2>/dev/null && pwd -P); then
    printf 'remove %s: TARGET_ROOT %s cannot be resolved\n' "$path" "$root"
    return 1
  fi
  if [ "$real_parent" != "$real_root" ]; then
    printf 'remove %s: it is not directly under TARGET_ROOT %s (%s is not %s)\n' \
      "$path" "$root" "$real_parent" "$real_root"
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
