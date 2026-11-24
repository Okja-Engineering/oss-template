# shellcheck shell=bash
# The tree reader. Every check reads files through it, so a check judges
# exactly one state of the repository: the working tree, the index or a
# commit's objects, minus the path prefixes its caller excludes.
#
# A SOURCE is `worktree`, `index` or `commit:REV`.
#   tree_source                  the SOURCE for $CHECK_MODE (and $CHECK_HEAD)
#   tree_list SOURCE [PREFIX...] one "MODE BLOB<TAB>PATH" line per file, by path
#   tree_cat SOURCE PATH         the bytes of a file tree_list lists; exit 1
#                                for any other path
# Both exit 2 when the source cannot be read. Run them at the top of the work
# tree; the caller exports LC_ALL=C.
#
# Every source takes its paths from git's NUL-delimited output, so all three
# list the same paths for the same state, whatever their names hold. The one
# name a listing line cannot carry, one holding a newline, fails the read in
# every source. The index source is the tree `git commit` would write from
# it, so an intent-to-add entry is not in it. The working tree is what
# `git add -A` would stage, each file hashed as its bytes stand, unfiltered.

tree_source() {
  case "${CHECK_MODE:-tree}" in
    range) printf 'commit:%s\n' "${CHECK_HEAD:-HEAD}" ;;
    staged) printf 'index\n' ;;
    *) printf 'worktree\n' ;;
  esac
}

tree_list() {
  local src=$1 prefix tree listing
  shift
  for prefix in "$@"; do
    [ -n "$prefix" ] || {
      printf 'tree: an empty prefix would exclude every path\n' >&2
      return 2
    }
  done
  case "$src" in
    worktree) listing=$(tree__worktree) || return 2 ;;
    index | commit:*)
      tree=$(tree__tree "$src") || return 2
      listing=$(
        set -o pipefail
        git ls-tree -r -z --full-tree "$tree" | tree__tree_lines
      ) || return 2
      ;;
    *)
      printf 'tree: unknown source: %s\n' "$src" >&2
      return 2
      ;;
  esac
  [ -n "$listing" ] || return 0
  printf '%s\n' "$listing" | tree__exclude "$@" | sort -t '	' -k 2
}

tree_cat() {
  local src=$1 path=$2 top listed tree type
  tree__path_ok "$path" || return 1
  case "$src" in
    worktree)
      top=$(git rev-parse --show-toplevel) || return 2
      listed=$(
        set -o pipefail
        cd "$top" &&
          git ls-files -z -c -o --exclude-standard -- ":(literal)$path" | tr '\0' '\n'
      ) || return 2
      printf '%s\n' "$listed" | grep -Fxq -e "$path" || return 1
      if [ -L "$top/$path" ]; then
        printf '%s' "$(readlink "$top/$path")"
      elif [ -f "$top/$path" ]; then
        cat "$top/$path"
      else
        return 1
      fi
      ;;
    index | commit:*)
      tree=$(tree__tree "$src") || return 2
      type=$(git cat-file -t "$tree:$path" 2>/dev/null) || return 1
      [ "$type" = blob ] || return 1
      git cat-file blob "$tree:$path"
      ;;
    *) return 2 ;;
  esac
}

# tree__path_ok PATH: PATH names something inside the tree, written the way
# a listing writes it: relative, no empty, `.` or `..` segment, no newline.
tree__path_ok() {
  case "/$1/" in
    //* | */./* | */../* | *//* | *'
'*) return 1 ;;
  esac
  return 0
}

# tree__tree index|commit:REV: the id of the tree the source holds. For the
# index, the tree `git commit` would write; unmerged paths cannot be judged.
tree__tree() {
  local rev unmerged
  case "$1" in
    index)
      unmerged=$(git ls-files -u) || return 2
      if [ -n "$unmerged" ]; then
        printf 'tree: the index has unmerged paths\n' >&2
        return 2
      fi
      git write-tree || return 2
      ;;
    commit:*)
      rev=${1#commit:}
      git rev-parse -q --verify "$rev^{commit}" >/dev/null || {
        printf 'tree: no such commit: %s\n' "$rev" >&2
        return 2
      }
      git rev-parse -q --verify "$rev^{tree}" || return 2
      ;;
    *) return 2 ;;
  esac
}

# tree__tree_lines: `git ls-tree -r -z` records in, listing lines out.
tree__tree_lines() {
  local rec mode
  while IFS= read -r -d '' rec; do
    tree__no_newline "$rec" || return 2
    mode=${rec%% *}
    rec=${rec#* }
    printf '%s %s\n' "$mode" "${rec#* }"
  done
}

tree__no_newline() {
  case "$1" in
    *'
'*)
      printf 'tree: a path holds a newline, which the tree reader refuses\n' >&2
      return 1
      ;;
  esac
}

# tree__worktree: the working tree's listing, unsorted.
tree__worktree() (
  set -o pipefail
  top=$(git rev-parse --show-toplevel) || exit 2
  cd "$top" || exit 2
  git ls-files -z -c -o --exclude-standard | tree__worktree_lines
)

# tree__worktree_lines: `git ls-files -z` paths in, listing lines out. A
# path missing from disk is not in the working tree. A directory git lists
# is a repository: a submodule, or one nested but not yet added (git lists
# that with a trailing slash), at the commit it has checked out.
tree__worktree_lines() {
  local path last="" files="" blobs blob id mode
  while IFS= read -r -d '' path; do
    tree__no_newline "$path" || return 2
    path=${path%/}
    # An unmerged path comes once per stage.
    [ "$path" != "$last" ] || continue
    last=$path
    if [ -L "$path" ]; then
      id=$(readlink "./$path") || return 2
      id=$(printf '%s' "$id" | git hash-object --stdin) || return 2
      printf '120000 %s\t%s\n' "$id" "$path"
    elif [ -d "$path" ]; then
      if [ -e "$path/.git" ]; then
        id=$(git -C "$path" rev-parse -q --verify 'HEAD^{commit}') || {
          printf 'tree: %s is a repository with no commit, which git cannot add\n' "$path" >&2
          return 2
        }
      else
        # A submodule that is not checked out keeps its recorded commit. Any
        # other directory git lists is a tracked file replaced by one, which
        # git add -A removes; the files it holds are listed in their own right.
        id=$(tree__gitlink "$path") || return 2
        [ -n "$id" ] || continue
      fi
      printf '160000 %s\t%s\n' "$id" "$path"
    elif [ -f "$path" ]; then
      files="$files$path
"
    fi
  done
  [ -n "$files" ] || return 0
  # Names go to git as arguments, never through --stdin-paths, whose line
  # reader unquotes a name opening with a quote and strips a final CR.
  blobs=$(
    set -o pipefail
    printf '%s' "$files" | tr '\n' '\0' | xargs -0 git hash-object --no-filters --
  ) || return 2
  while IFS= read -r path <&3 && IFS= read -r blob <&4; do
    if [ -x "$path" ]; then mode=100755; else mode=100644; fi
    printf '%s %s\t%s\n' "$mode" "$blob" "$path"
  done 3<<EOF 4<<EOF2
$files
EOF
$blobs
EOF2
}

# tree__gitlink PATH: the commit the index records at PATH when it holds a
# gitlink there, else nothing.
tree__gitlink() (
  set -o pipefail
  git ls-files -s -z -- ":(literal)$1" | tr '\0' '\n' | P=$1 awk '
    {
      i = index($0, "\t")
      split(substr($0, 1, i - 1), f, " ")
      if (!done && f[1] == "160000" && substr($0, i + 1) == ENVIRON["P"]) { print f[2]; done = 1 }
    }'
)

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
