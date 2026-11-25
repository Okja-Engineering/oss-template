# shellcheck shell=bash
# Render's library (AC9-AC12; decisions 53, 60, 78, 159, 166, 192, 211, 215,
# 217, 219): the foundation rendered from a commit, the walk, the
# fingerprint, and the check that keeps TARGET_ROOT out of the workspace.
# bin/render runs it; verify will.
#
#   render_tree COMMIT SCHEMA ANSWERS OUT
#       render `foundation/` as COMMIT holds it, read through the tree
#       reader, into the empty directory OUT. A verbatim file is copied byte
#       for byte; a template, PATH.tmpl, has each {{FIELD}} replaced by the
#       render field's value in ANSWERS, and a line that is exactly
#       `- {{FIELD}}` repeated per item of a `list` field; a variant,
#       PATH.VALUE (or PATH.VALUE.tmpl), is used for PATH when VALUE is the
#       value of the `select` field whose `selects` column is PATH. Modes
#       come from the tree. Refused: a placeholder that is not a render
#       field; a {{[A-Z_]+}} left after substitution; an executable
#       template, or one that is a symbolic link; a variant whose field
#       selects nothing (no value of the field is VALUE); a selecting field
#       with no variant for its value; a selected PATH from anything but
#       its variants, as a plain PATH or PATH.tmpl; two sources for one
#       path; a submodule; and, before anything is written, two paths or
#       directories that differ only in ASCII case, which a disk that folds
#       case holds as one. One line out per refusal; exit 0, 1 on a
#       refusal, 2 when
#       COMMIT cannot be read or OUT written. Sets RENDER_LIST to the
#       produced paths, sorted, one a line.
#   render_walk TARGET LIST
#       the walk, with no git: every non-directory under TARGET, listed
#       without following symbolic links, NUL-delimited, sorted with
#       duplicates kept, equals LIST; an entry named .git, of any kind, at
#       the top level or nested, a name holding a newline, and a directory
#       that is not the parent of a listed path are refused. One line out
#       per refusal; exit 0 or 1.
#   render_fingerprint TARGET LIST
#       TARGET's git tree id, its fingerprint, built in a private GIT_DIR
#       made with `git init --template= --object-format=sha1`, with a fresh
#       index from LIST alone, never in TARGET: `git add` must exit 0 and
#       the index (`ls-files -z`) must hold exactly LIST. Prints the id;
#       exit 0, or 1 with the reason out.
#   render_root_ok ROOT WS
#       ROOT, a TARGET_ROOT, is at or under no working tree of the
#       workspace WS: its deepest existing ancestor, resolved physically
#       (`cd -P`), and each physical parent up to /, is the same file (`-ef`)
#       as none of `git rev-parse --show-toplevel` and the `worktree`
#       entries of `git worktree list --porcelain -z` not marked `bare` or
#       `prunable`. A `cd -P` that fails refuses with the path. Exit 0, or 1
#       with the reason out.
#
# Source tree.sh, answers.sh and git.sh first, and run git_hermetic; run at
# the top of the workspace's work tree; the caller exports LC_ALL=C.

render_tree() {
  local commit=$1 schema=$2 answers=$3 out=$4 entries line refused=0
  local mode rel name tmpl sel field path values value v src produced="" tmp twins
  entries=$(tree_list "commit:$commit") || return 2
  # The selecting fields: "FIELD<TAB>PATH<TAB>VALUES<TAB>VALUE".
  sel=$(awk -F '\t' 'NR > 1 && $5 != "-" && $5 != "" { print $1 "\t" $5 "\t" $6 }' "$schema" |
    while IFS='	' read -r field path values; do
      value=$(answers_get "$answers" "$field") || value=""
      printf '%s\t%s\t%s\t%s\n' "$field" "$path" "$values" "$value"
    done)
  # Paths, or directories, that differ only in case, refused before anything
  # is written: on a disk that folds case, one would be written through the
  # other. Each foundation path, without .tmpl, and each selected path.
  twins=$({
    printf '%s\n' "$entries" |
      awk '{ p = substr($0, index($0, "\t") + 1) } p ~ /^foundation\/./ { p = substr(p, 12); print p; if (sub(/\.tmpl$/, "", p)) print p }'
    printf '%s\n' "$sel" | cut -f 2
  } | awk -F / 'NF { p = $1; print p; for (i = 2; i <= NF; i++) { p = p "/" $i; print p } }' | sort -u |
    awk '{ l = tolower($0) } (l in seen) { print "foundation renders " seen[l] " and " $0 ", which differ only in case"; next } { seen[l] = $0 }')
  if [ -n "$twins" ]; then
    printf '%s\n' "$twins"
    return 1
  fi
  tmp=$(mktemp -d) || return 2
  render__fields "$schema" "$answers" >"$tmp/fields"
  while IFS= read -r line <&3; do
    rel=${line#*	}
    case "$rel" in
      foundation/?*) rel=${rel#foundation/} ;;
      *) continue ;;
    esac
    mode=${line%% *}
    name=$rel
    tmpl=0
    case "$name" in
      *.tmpl)
        name=${name%.tmpl}
        tmpl=1
        ;;
    esac
    # A variant: PATH.VALUE, for a PATH a field selects.
    src=verbatim
    while IFS='	' read -r field path values value; do
      [ -n "$field" ] || continue
      case "$name" in
        "$path".*) ;;
        *) continue ;;
      esac
      v=${name#"$path".}
      case "$v" in */*) continue ;; esac
      case "|$values|" in
        *"|$v|"*) ;;
        *)
          printf 'foundation/%s: a variant of %s for %s, which no value of %s selects\n' "$rel" "$path" "$v" "$field"
          refused=1
          src=skip
          break
          ;;
      esac
      if [ "$v" = "$value" ]; then
        name=$path
        src=variant
      else
        src=skip
      fi
      break
    done <<EOF
$sel
EOF
    [ "$src" != skip ] || continue
    if [ "$src" = verbatim ] && N=$name awk -F '\t' '$2 == ENVIRON["N"] { f = 1 } END { exit !f }' <<<"$sel"; then
      printf 'foundation/%s: %s is a selected path, so it comes only from its variants, %s.VALUE or %s.VALUE.tmpl\n' \
        "$rel" "$name" "$name" "$name"
      refused=1
      continue
    fi
    case "$mode" in
      160000)
        printf 'foundation/%s: a submodule, which render cannot copy\n' "$rel"
        refused=1
        continue
        ;;
    esac
    if [ "$tmpl" = 1 ] && [ "$mode" = 100755 ]; then
      printf 'foundation/%s: an executable template; a template is rendered as a plain file\n' "$rel"
      refused=1
      continue
    fi
    if [ "$tmpl" = 1 ] && [ "$mode" = 120000 ]; then
      printf 'foundation/%s: a template that is a symbolic link\n' "$rel"
      refused=1
      continue
    fi
    if grep -Fxq -e "$name" <<<"$produced"; then
      printf 'foundation/%s: a second source for %s\n' "$rel" "$name"
      refused=1
      continue
    fi
    produced="$produced$name
"
    mkdir -p "$out/$(dirname "$name")" || { refused=2; break; }
    if [ "$mode" = 120000 ]; then
      v=$(tree_cat "commit:$commit" "foundation/$rel" && printf x) || { refused=2; break; }
      ln -s "${v%x}" "$out/$name" || { refused=2; break; }
      continue
    fi
    if [ "$tmpl" = 1 ]; then
      tree_cat "commit:$commit" "foundation/$rel" >"$tmp/in" || { refused=2; break; }
      render__substitute "$tmp/fields" "foundation/$rel" "$tmp/in" >"$out/$name" 2>"$tmp/err" || { refused=2; break; }
      if [ -s "$tmp/err" ]; then
        cat "$tmp/err"
        refused=1
      elif grep -Eq '[{][{][A-Z_]+[}][}]' "$out/$name"; then
        printf 'foundation/%s: a {{FIELD}} placeholder is left after substitution\n' "$rel"
        refused=1
      fi
    else
      tree_cat "commit:$commit" "foundation/$rel" >"$out/$name" || { refused=2; break; }
    fi
    if [ "$mode" = 100755 ]; then chmod 755 "$out/$name"; else chmod 644 "$out/$name"; fi
  done 3<<EOF
$entries
EOF
  # One clean-up, also for a read or write that failed inside the loop.
  rm -rf "$tmp"
  [ "$refused" != 2 ] || return 2
  # A selecting field whose value no variant matches.
  while IFS='	' read -r field path values value; do
    [ -n "$field" ] || continue
    grep -Fxq -e "$path" <<<"$produced" && continue
    printf '%s=%s selects foundation/%s.%s, which the foundation does not hold\n' "$field" "$value" "$path" "$value"
    refused=1
  done <<EOF
$sel
EOF
  # shellcheck disable=SC2034 # RENDER_LIST is read by the caller
  RENDER_LIST=$(printf '%s' "$produced" | sort)
  return "$refused"
}

# render__fields SCHEMA ANSWERS: one line per render field,
# "FIELD<TAB>TYPE<TAB>VALUE".
render__fields() {
  local field type value
  awk -F '\t' 'NR > 1 && $4 == "yes" { print $1 "\t" $3 }' "$1" |
    while IFS='	' read -r field type; do
      value=$(answers_get "$2" "$field") || value=""
      printf '%s\t%s\t%s\n' "$field" "$type" "$value"
    done
}

# render__substitute FIELDS LABEL FILE: the template FILE, rendered on
# standard output, its bytes kept but for the placeholders, its last line
# ending as FILE's does; a placeholder that is not a render field is
# reported on standard error.
render__substitute() {
  local nl=0
  [ -n "$(tail -c 1 "$3")" ] || nl=1
  F=$1 L=$2 NL=$nl awk '
    BEGIN {
      while ((getline line < ENVIRON["F"]) > 0) {
        i = index(line, "\t"); name = substr(line, 1, i - 1); rest = substr(line, i + 1)
        j = index(rest, "\t"); type[name] = substr(rest, 1, j - 1); val[name] = substr(rest, j + 1)
      }
    }
    function sub_line(s,   out, i, name) {
      out = ""
      while ((i = index(s, "{{")) > 0) {
        out = out substr(s, 1, i - 1)
        s = substr(s, i)
        if (match(s, /^[{][{][A-Z_][A-Z0-9_]*[}][}]/)) {
          name = substr(s, 3, RLENGTH - 4)
          if (name in val) out = out val[name]
          else {
            printf "%s: the placeholder {{%s}} is not a render field\n", ENVIRON["L"], name > "/dev/stderr"
            out = out substr(s, 1, RLENGTH)
          }
          s = substr(s, RLENGTH + 1)
        } else {
          out = out "{{"
          s = substr(s, 3)
        }
      }
      return out s
    }
    {
      if (NR > 1) printf "\n"
      # A list line, `- {{FIELD}}`, its CR kept on the line of each item.
      if (match($0, /^- [{][{][A-Z_][A-Z0-9_]*[}][}]\r?$/)) {
        cr = ($0 ~ /\r$/) ? "\r" : ""
        name = substr($0, 5, length($0) - 6 - length(cr))
        if ((name in val) && type[name] == "list") {
          n = split(val[name], items, ",")
          for (k = 1; k <= n; k++) {
            item = items[k]
            sub(/^ +/, "", item); sub(/ +$/, "", item)
            printf "%s- %s%s", (k == 1 ? "" : "\n"), item, cr
          }
          next
        }
      }
      printf "%s", sub_line($0)
    }
    END { if (ENVIRON["NL"] == "1" && NR > 0) printf "\n" }' "$3"
}

render_walk() {
  local target=$1 list=$2 p refused=0 tmp
  tmp=$(mktemp -d) || return 1
  if ! render__entries "$target" G -name .git >"$tmp/git" ||
    ! render__entries "$target" F ! -type d >"$tmp/found" ||
    ! render__entries "$target" D -type d >"$tmp/dirs"; then
    printf 'the walk cannot list the target %s\n' "$target"
    rm -rf "$tmp"
    return 1
  fi
  if grep -q '^G' "$tmp/git"; then
    sed -n 's/^G\(.*\)$/the target holds \1, an entry named .git/p' "$tmp/git"
    refused=1
  fi
  if grep -qx N "$tmp/git" "$tmp/found" "$tmp/dirs"; then
    printf 'the target holds a name with a newline in it\n'
    refused=1
  fi
  sed -n 's/^F//p' "$tmp/found" | sort >"$tmp/have"
  if [ -n "$list" ]; then printf '%s\n' "$list"; fi | sort >"$tmp/want"
  if ! cmp -s "$tmp/have" "$tmp/want"; then
    comm -13 "$tmp/want" "$tmp/have" | sed 's/^/the target holds a file render did not write: /'
    comm -23 "$tmp/want" "$tmp/have" | sed 's/^/the target lacks a file render wrote: /'
    refused=1
  fi
  sed -n 's/^D//p' "$tmp/dirs" | while IFS= read -r p; do
    if ! P="$p/" awk 'index($0, ENVIRON["P"]) == 1 { found = 1; exit } END { exit !found }' "$tmp/want"; then
      printf 'the target directory %s holds no listed file\n' "$p"
    fi
  done >"$tmp/empty"
  if [ -s "$tmp/empty" ]; then
    cat "$tmp/empty"
    refused=1
  fi
  rm -rf "$tmp"
  return "$refused"
}

# render__entries DIR TAG FIND-TEST...: each entry under DIR that the find
# tests select, listed without following symbolic links, one a line as TAG
# then its path, or N for a name holding a newline; exit 1 when DIR cannot be
# listed whole.
render__entries() (
  set -o pipefail
  dir=$1 tag=$2
  shift 2
  (cd -P -- "$dir" && find . -mindepth 1 "$@" -print0) | while IFS= read -r -d '' p; do
    case "$p" in
      *'
'*) printf 'N\n' ;;
      *) printf '%s%s\n' "$tag" "${p#./}" ;;
    esac
  done
)

render_fingerprint() {
  local target=$1 list=$2 g st tree
  g=$(mktemp -d) || return 1
  if ! git init -q --bare --template= --object-format=sha1 "$g/repo" >/dev/null 2>&1; then
    rm -rf "$g"
    printf 'cannot make a private repository to fingerprint the target\n'
    return 1
  fi
  if [ -n "$list" ]; then printf '%s\n' "$list"; fi | tr '\n' '\0' >"$g/paths"
  GIT_DIR=$g/repo GIT_WORK_TREE=$target GIT_INDEX_FILE=$g/index \
    git --literal-pathspecs add --pathspec-from-file="$g/paths" --pathspec-file-nul >"$g/out" 2>&1
  st=$?
  if [ "$st" != 0 ]; then
    printf 'git add exited %s while fingerprinting the target:\n' "$st"
    cat "$g/out"
    rm -rf "$g"
    return 1
  fi
  if ! GIT_DIR=$g/repo GIT_INDEX_FILE=$g/index git ls-files -z >"$g/index.list" ||
    ! cmp -s "$g/paths" "$g/index.list"; then
    printf 'the index git built from the target is not render'"'"'s file list\n'
    rm -rf "$g"
    return 1
  fi
  if ! tree=$(GIT_DIR=$g/repo GIT_INDEX_FILE=$g/index git write-tree); then
    printf 'git write-tree failed while fingerprinting the target\n'
    rm -rf "$g"
    return 1
  fi
  rm -rf "$g"
  printf '%s\n' "$tree"
}

render_root_ok() {
  local root=$1 ws=$2 dir rec path flag list
  local -a tops=()
  path=$(git -C "$ws" rev-parse --show-toplevel) || {
    printf 'cannot find the workspace'"'"'s working tree\n'
    return 1
  }
  tops+=("$path")
  list=$(mktemp) || {
    printf 'cannot make a temporary file\n'
    return 1
  }
  if ! git -C "$ws" worktree list --porcelain -z >"$list"; then
    rm -f "$list"
    printf 'cannot list the workspace'"'"'s worktrees\n'
    return 1
  fi
  path="" flag=""
  while IFS= read -r -d '' rec; do
    case "$rec" in
      'worktree '*) path=${rec#worktree } flag="" ;;
      bare | 'prunable' | 'prunable '*) flag=skip ;;
      '')
        [ -z "$path" ] || [ -n "$flag" ] || tops+=("$path")
        path="" flag=""
        ;;
    esac
  done <"$list"
  rm -f "$list"
  [ -z "$path" ] || [ -n "$flag" ] || tops+=("$path")
  dir=$root
  while [ ! -d "$dir" ]; do
    dir=${dir%/*}
    [ -n "$dir" ] || dir=/
  done
  (
    CDPATH='' cd -P -- "$dir" 2>/dev/null || {
      printf 'TARGET_ROOT %s: its existing ancestor %s cannot be entered\n' "$root" "$dir"
      exit 1
    }
    while :; do
      for path in "${tops[@]}"; do
        if [ . -ef "$path" ]; then
          printf 'TARGET_ROOT %s is at or under %s, a working tree of this workspace; choose a TARGET_ROOT outside it\n' "$root" "$path"
          exit 1
        fi
      done
      [ ! . -ef / ] || exit 0
      cd -P .. 2>/dev/null || {
        printf 'TARGET_ROOT %s: the parent of %s cannot be entered\n' "$root" "$(pwd -P)"
        exit 1
      }
    done
  )
}
