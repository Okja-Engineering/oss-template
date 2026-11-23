# shellcheck shell=bash
# The tree reader. Every check reads files through it, so a check judges
# exactly one state of the repository: the working tree, the index, or a
# commit's objects, minus the path prefixes its caller excludes.
#
# A SOURCE is `worktree`, `index` or `commit:REV`.
#   tree_source                  the SOURCE for $CHECK_MODE (and $CHECK_HEAD)
#   tree_list SOURCE [PREFIX...] one "MODE BLOB<TAB>PATH" line per file, by path
#   tree_cat SOURCE PATH         the file's bytes; exit 1 when it is not there
# Both exit 2 when the source cannot be read. Run them at the top of the work
# tree; the caller exports LC_ALL=C.

tree_source() {
  case "${CHECK_MODE:-tree}" in
    range) printf 'commit:%s\n' "${CHECK_HEAD:-HEAD}" ;;
    staged) printf 'index\n' ;;
    *) printf 'worktree\n' ;;
  esac
}

tree_list() {
  local src=$1 listing
  shift
  case "$src" in
    worktree) listing=$(tree__worktree) || return 2 ;;
    index)
      listing=$(git -c core.quotePath=false ls-files -s) || return 2
      case "$listing" in
        *' '[123]'	'*)
          printf 'tree: the index has unmerged paths\n' >&2
          return 2
          ;;
      esac
      listing=$(printf '%s\n' "$listing" | sed 's/^\([0-7]*\) \([0-9a-f]*\) 0	/\1 \2	/')
      ;;
    commit:*)
      git rev-parse -q --verify "${src#commit:}^{commit}" >/dev/null || {
        printf 'tree: no such commit: %s\n' "${src#commit:}" >&2
        return 2
      }
      listing=$(git -c core.quotePath=false ls-tree -r --full-tree "${src#commit:}") || return 2
      listing=$(printf '%s\n' "$listing" | sed 's/^\([0-7]*\) [a-z]* /\1 /')
      ;;
    *)
      printf 'tree: unknown source: %s\n' "$src" >&2
      return 2
      ;;
  esac
  [ -n "$listing" ] || return 0
  # git quotes a path holding a quote, a backslash or a control character.
  # Such a path cannot be judged reliably, so the read fails rather than
  # skipping it.
  case "$listing" in
    *'	"'*)
      printf 'tree: a path needs quoting, which the tree reader refuses\n' >&2
      return 2
      ;;
  esac
  printf '%s\n' "$listing" | tree__exclude "$@" | sort -t '	' -k 2
}

tree_cat() {
  local src=$1 path=$2 top
  case "$src" in
    worktree)
      top=$(git rev-parse --show-toplevel) || return 2
      if [ -L "$top/$path" ]; then
        printf '%s' "$(readlink "$top/$path")"
      elif [ -f "$top/$path" ]; then
        cat "$top/$path"
      else
        return 1
      fi
      ;;
    index)
      git cat-file -e ":0:$path" 2>/dev/null || return 1
      git cat-file blob ":0:$path"
      ;;
    commit:*)
      git rev-parse -q --verify "${src#commit:}^{commit}" >/dev/null || return 2
      git cat-file -e "${src#commit:}:$path" 2>/dev/null || return 1
      git cat-file blob "${src#commit:}:$path"
      ;;
    *) return 2 ;;
  esac
}

# The working tree: tracked and untracked files that are not ignored and are
# present on disk, each hashed as its bytes stand, unfiltered.
tree__worktree() {
  local top path mode files="" blobs blob
  top=$(git rev-parse --show-toplevel) || return 2
  cd "$top" || return 2
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ -L "$path" ]; then
      printf '120000 %s\t%s\n' "$(printf '%s' "$(readlink "$path")" | git hash-object --stdin)" "$path"
    elif [ -d "$path" ]; then
      printf '160000 %s\t%s\n' "$(git rev-parse "HEAD:$path" 2>/dev/null)" "$path"
    elif [ -f "$path" ]; then
      files="$files$path
"
    fi
  done <<EOF
$(git -c core.quotePath=false ls-files -c -o --exclude-standard | sort -u)
EOF
  [ -n "$files" ] || return 0
  blobs=$(printf '%s' "$files" | git hash-object --no-filters --stdin-paths) || return 2
  printf '%s' "$files" | while IFS= read -r path; do
    IFS= read -r blob <&3
    if [ -x "$path" ]; then mode=100755; else mode=100644; fi
    printf '%s %s\t%s\n' "$mode" "$blob" "$path"
  done 3<<EOF
$blobs
EOF
}

# tree__exclude PREFIX...: drop listing lines whose path starts with a PREFIX.
tree__exclude() {
  local line path prefix keep
  while IFS= read -r line; do
    path=${line#*	}
    keep=1
    for prefix in "$@"; do
      case "$path" in "$prefix"*) keep=0 ;; esac
    done
    [ "$keep" = 1 ] && printf '%s\n' "$line"
  done
  return 0
}
