# shellcheck shell=bash
# Render's library (AC9-AC12; decisions 53, 60, 78, 159, 166, 192, 211, 215,
# 217, 219): the foundation rendered from a commit, the walk, the
# fingerprint.
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
#       its variants, as a plain PATH or PATH.tmpl; a submodule; a
#       foundation path holding anything but ASCII letters, digits, ., _,
#       -, / and space (decision 224); and, judged once over the final set
#       of names it would produce, .tmpl off and the variant resolved: two
#       sources for one name; a name with no final component, as
#       foundation/.tmpl gives, or with an empty, . or .. component, as
#       foundation/..tmpl gives, or a .git component in any case, as
#       foundation/.GIT.tmpl or a selected .GIT gives; a name that is a
#       directory above another; and two names or directories that differ
#       only in ASCII case, which a disk that folds case holds as one. Each
#       of those refuses before anything is written. One line out per
#       refusal; exit 0, 1 on a refusal, 2 when COMMIT cannot be read or OUT
#       written. Sets RENDER_LIST to the produced paths, sorted, one a line.
#   render_walk TARGET LIST
#       the walk, with no git: every non-directory under TARGET, listed
#       without following symbolic links, NUL-delimited, sorted with
#       duplicates kept, equals LIST; an entry named .git in any case, of
#       any kind, at the top level or nested, a name holding a newline, and a directory
#       that is not the parent of a listed path are refused. One line out
#       per refusal; exit 0 or 1.
#   render_fingerprint TARGET LIST
#       TARGET's git tree id, its fingerprint, built in a private GIT_DIR
#       made with `git init --template= --object-format=sha1`, with a fresh
#       index from LIST alone, never in TARGET: `git add` must exit 0 and
#       the index (`ls-files -z`) must hold exactly LIST. Prints the id;
#       exit 0, or 1 with the reason out.
#
# Source tree.sh, answers.sh and git.sh first, and run git_hermetic; run at
# the top of the workspace's work tree; the caller exports LC_ALL=C. Each
# pipeline whose status a guard reads sets pipefail itself, never relying on
# the caller's, and a lookup's failure is never read as its none (decision
# 228).

render_tree() {
  local commit=$1 schema=$2 answers=$3 out=$4 entries line refused=0
  local mode rel name tmpl sel selected field path values value v src produced="" plan="" tmp twins names unportable
  entries=$(tree_list "commit:$commit") || return 2
  # The selecting fields: "FIELD<TAB>PATH<TAB>VALUES<TAB>VALUE". Every
  # command a value comes from has its status read (decision 228).
  sel=$(render__selecting "$schema" "$answers") || {
    printf 'cannot read the selecting fields\n'
    return 2
  }
  # Only portable paths (decision 224), refused before anything is written:
  # a disk that folds Unicode, or another character, could open one as
  # another, and the twin check below folds ASCII alone.
  unportable=$(awk '{ p = substr($0, index($0, "\t") + 1) } p ~ /^foundation\/./ && p !~ /^[A-Za-z0-9._ \/-]+$/ {
      print p ": a path outside the portable set, ASCII letters, digits, ., _, -, / and space" }' <<<"$entries") || {
    printf 'cannot judge the foundation paths\n'
    return 2
  }
  if [ -n "$unportable" ]; then
    printf '%s\n' "$unportable"
    return 1
  fi
  # The paths a field selects, one a line.
  selected=$(cut -f 2 <<<"$sel") || {
    printf 'cannot read the selecting fields\n'
    return 2
  }
  # The plan: what each foundation path renders, "MODE<TAB>TMPL<TAB>REL<TAB>
  # NAME" a line, its name worked out, .tmpl off and the variant resolved,
  # before anything is written.
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
    if [ "$src" = verbatim ]; then
      render__holds "$selected" "$name"
      case $? in
        0)
          printf 'foundation/%s: %s is a selected path, so it comes only from its variants, %s.VALUE or %s.VALUE.tmpl\n' \
            "$rel" "$name" "$name" "$name"
          refused=1
          continue
          ;;
        1) ;;
        *)
          printf 'cannot look up the selected paths\n'
          return 2
          ;;
      esac
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
    produced="$produced$name
"
    plan="$plan$mode	$tmpl	$rel	$name
"
  done 3<<EOF
$entries
EOF
  # A selecting field whose value no variant matches.
  while IFS='	' read -r field path values value; do
    [ -n "$field" ] || continue
    render__holds "$produced" "$path"
    case $? in
      0) ;;
      1)
        printf '%s=%s selects foundation/%s.%s, which the foundation does not hold\n' "$field" "$value" "$path" "$value"
        refused=1
        ;;
      *)
        printf 'cannot look up the paths rendered\n'
        return 2
        ;;
    esac
  done <<EOF
$sel
EOF
  # One judgement of the final set of names, before anything is written
  # (decision 224): no name twice, from a second source; each component of
  # each name not empty, not . or .., and not .git in any case, which a disk
  # that folds case would open as one; no name a directory above another;
  # and no two names, or directories, that differ only in case, which such a
  # disk holds as one, so one would be written through the other.
  names=$(
    set -o pipefail
    cut -f 3,4 <<<"$plan" | awk -F '\t' '
      NF { rel[++n] = $1; name[n] = $2 }
      END {
        for (i = 1; i <= n; i++) {
          if (name[i] in is) {
            print "foundation/" rel[i] ": a second source for " name[i]
            dup[i] = 1
          }
          is[name[i]] = 1
        }
        for (i = 1; i <= n; i++) {
          if (i in dup) continue
          k = split(name[i], c, "/")
          if (name[i] == "" || c[k] == "") {
            print "foundation/" rel[i] ": renders no name, an empty final component"
            continue
          }
          bad = ""
          for (j = 1; j <= k; j++) {
            if (c[j] == "") bad = "an empty component"
            else if (bad == "" && (c[j] == "." || c[j] == "..")) bad = "a . or .. component"
            else if (bad == "" && tolower(c[j]) == ".git") bad = "an entry named .git"
          }
          if (bad != "") {
            print "foundation/" rel[i] ": renders " name[i] ", " bad
            continue
          }
          p = c[1]
          for (j = 2; j <= k; j++) {
            if (p in is) print "foundation renders " p " as a file and as a directory, above " name[i]
            p = p "/" c[j]
          }
        }
      }'
  ) || {
    printf 'cannot judge the names it renders\n'
    return 2
  }
  if [ -n "$names" ]; then
    printf '%s\n' "$names"
    refused=1
  fi
  twins=$(
    set -o pipefail
    printf '%s' "$produced" | awk -F / 'NF { p = $1; print p; for (i = 2; i <= NF; i++) { p = p "/" $i; print p } }' | sort -u |
      awk '{ l = tolower($0) } (l in seen) { print "foundation renders " seen[l] " and " $0 ", which differ only in case"; next } { seen[l] = $0 }'
  ) || {
    printf 'cannot compare the paths for case twins\n'
    return 2
  }
  if [ -n "$twins" ]; then
    printf '%s\n' "$twins"
    refused=1
  fi
  [ "$refused" = 0 ] || return 1
  # The writes, each name judged.
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/render.XXXXXX") || {
    printf 'cannot make a temporary directory\n'
    return 2
  }
  render__fields "$schema" "$answers" >"$tmp/fields" || {
    rm -rf "$tmp"
    printf 'cannot read the render fields\n'
    return 2
  }
  while IFS='	' read -r mode tmpl rel name <&3; do
    [ -n "$mode" ] || continue
    case "$name" in
      */*) mkdir -p "$out/${name%/*}" || { refused=2; break; } ;;
    esac
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
      else
        # grep's 1 is "none left"; a higher status is a file it could not
        # read, never read as none.
        grep -Eq '[{][{][A-Z_]+[}][}]' "$out/$name"
        case $? in
          0)
            printf 'foundation/%s: a {{FIELD}} placeholder is left after substitution\n' "$rel"
            refused=1
            ;;
          1) ;;
          *)
            printf 'cannot look for a placeholder left in %s\n' "$name"
            refused=2
            break
            ;;
        esac
      fi
    else
      tree_cat "commit:$commit" "foundation/$rel" >"$out/$name" || { refused=2; break; }
    fi
    if [ "$mode" = 100755 ]; then chmod 755 "$out/$name"; else chmod 644 "$out/$name"; fi
  done 3<<EOF
$plan
EOF
  # One clean-up, also for a read or write that failed inside the loop.
  rm -rf "$tmp"
  [ "$refused" != 2 ] || return 2
  # shellcheck disable=SC2034 # RENDER_LIST is read by the caller
  RENDER_LIST=$(
    set -o pipefail
    printf '%s' "$produced" | sort
  ) || {
    printf 'cannot sort the file list\n'
    return 2
  }
  return "$refused"
}

# render__holds LIST LINE: LIST, lines, holds LINE exactly; exit 1 when it
# does not, 2 when grep cannot look, which is never read as "not held".
render__holds() {
  grep -Fxq -e "$2" <<<"$1"
  case $? in
    0) return 0 ;;
    1) return 1 ;;
    *) return 2 ;;
  esac
}

# render__selecting SCHEMA ANSWERS: one line per selecting field,
# "FIELD<TAB>PATH<TAB>VALUES<TAB>VALUE"; exit 1 when the schema or a value
# cannot be read.
render__selecting() {
  local rows field path values value
  rows=$(awk -F '\t' 'NR > 1 && $5 != "-" && $5 != "" { print $1 "\t" $5 "\t" $6 }' "$1") || return 1
  while IFS='	' read -r field path values; do
    [ -n "$field" ] || continue
    value=$(answers_get "$2" "$field") || return 1
    printf '%s\t%s\t%s\t%s\n' "$field" "$path" "$values" "$value" || return 1
  done <<<"$rows"
}

# render__fields SCHEMA ANSWERS: one line per render field,
# "FIELD<TAB>TYPE<TAB>VALUE"; exit 1 when the schema or a value cannot be
# read.
render__fields() {
  local rows field type value
  rows=$(awk -F '\t' 'NR > 1 && $4 == "yes" { print $1 "\t" $3 }' "$1") || return 1
  while IFS='	' read -r field type; do
    [ -n "$field" ] || continue
    value=$(answers_get "$2" "$field") || return 1
    printf '%s\t%s\t%s\n' "$field" "$type" "$value" || return 1
  done <<<"$rows"
}

# render__substitute FIELDS LABEL FILE: the template FILE, rendered on
# standard output, its bytes kept but for the placeholders, its last line
# ending as FILE's does; a placeholder that is not a render field is
# reported on standard error.
render__substitute() {
  local nl=0 last
  last=$(tail -c 1 "$3") || return 2
  [ -n "$last" ] || nl=1
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
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/render.XXXXXX") || {
    printf 'the walk cannot make a temporary directory\n'
    return 1
  }
  if ! render__entries "$target" G -iname .git >"$tmp/git" ||
    ! render__entries "$target" F ! -type d >"$tmp/found" ||
    ! render__entries "$target" D -type d >"$tmp/dirs"; then
    printf 'the walk cannot list the target %s\n' "$target"
    rm -rf "$tmp"
    return 1
  fi
  # grep's 1 is "none"; anything above it is a list it could not read.
  grep -q '^G' "$tmp/git"
  case $? in
    0)
      sed -n 's/^G\(.*\)$/the target holds \1, an entry named .git/p' "$tmp/git"
      refused=1
      ;;
    1) ;;
    *) refused=2 ;;
  esac
  grep -qx N "$tmp/git" "$tmp/found" "$tmp/dirs"
  case $? in
    0)
      printf 'the target holds a name with a newline in it\n'
      refused=1
      ;;
    1) ;;
    *) refused=2 ;;
  esac
  if [ "$refused" = 2 ]; then
    printf 'the walk cannot read its lists of the target\n'
    rm -rf "$tmp"
    return 1
  fi
  # Each list the walk judges is made with its status read (decision 228).
  if ! (set -o pipefail && sed -n 's/^F//p' "$tmp/found" | sort >"$tmp/have") ||
    ! (set -o pipefail && if [ -n "$list" ]; then printf '%s\n' "$list"; fi | sort >"$tmp/want"); then
    printf 'the walk cannot sort the target'"'"'s files and the file list\n'
    rm -rf "$tmp"
    return 1
  fi
  # cmp's 1 is "they differ"; a higher status is no comparison at all.
  cmp -s "$tmp/have" "$tmp/want"
  case $? in
    0) ;;
    1)
      comm -13 "$tmp/want" "$tmp/have" | sed 's/^/the target holds a file render did not write: /'
      comm -23 "$tmp/want" "$tmp/have" | sed 's/^/the target lacks a file render wrote: /'
      refused=1
      ;;
    *)
      printf 'the walk cannot compare the target'"'"'s files with the file list\n'
      rm -rf "$tmp"
      return 1
      ;;
  esac
  # awk's 1 is "no listed file under it"; a higher status is a list it
  # could not read, which ends the loop as a failure.
  if ! (
    set -o pipefail
    sed -n 's/^D//p' "$tmp/dirs" | while IFS= read -r p; do
      P="$p/" awk 'index($0, ENVIRON["P"]) == 1 { found = 1; exit } END { exit !found }' "$tmp/want"
      case $? in
        0) ;;
        1) printf 'the target directory %s holds no listed file\n' "$p" ;;
        *) exit 2 ;;
      esac
    done >"$tmp/empty"
  ); then
    printf 'the walk cannot judge the directories of the target\n'
    rm -rf "$tmp"
    return 1
  fi
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
  g=$(mktemp -d "${TMPDIR:-/tmp}/render.XXXXXX") || {
    printf 'cannot make a temporary directory to fingerprint the target\n'
    return 1
  }
  if ! git init -q --bare --template= --object-format=sha1 "$g/repo" >/dev/null 2>&1; then
    rm -rf "$g"
    printf 'cannot make a private repository to fingerprint the target\n'
    return 1
  fi
  if ! (set -o pipefail && if [ -n "$list" ]; then printf '%s\n' "$list"; fi | tr '\n' '\0' >"$g/paths"); then
    rm -rf "$g"
    printf 'cannot list the paths to fingerprint\n'
    return 1
  fi
  GIT_DIR=$g/repo GIT_WORK_TREE=$target GIT_INDEX_FILE=$g/index \
    git --literal-pathspecs add --pathspec-from-file="$g/paths" --pathspec-file-nul >"$g/out" 2>&1
  st=$?
  if [ "$st" != 0 ]; then
    printf 'git add exited %s while fingerprinting the target:\n' "$st"
    cat "$g/out"
    rm -rf "$g"
    return 1
  fi
  if ! GIT_DIR=$g/repo GIT_INDEX_FILE=$g/index git ls-files -z >"$g/index.list"; then
    printf 'cannot list the index git built from the target\n'
    rm -rf "$g"
    return 1
  fi
  cmp -s "$g/paths" "$g/index.list"
  case $? in
    0) ;;
    1)
      printf 'the index git built from the target is not render'"'"'s file list\n'
      rm -rf "$g"
      return 1
      ;;
    *)
      printf 'cannot compare the index git built from the target with render'"'"'s file list\n'
      rm -rf "$g"
      return 1
      ;;
  esac
  if ! tree=$(GIT_DIR=$g/repo GIT_INDEX_FILE=$g/index git write-tree); then
    printf 'git write-tree failed while fingerprinting the target\n'
    rm -rf "$g"
    return 1
  fi
  rm -rf "$g"
  printf '%s\n' "$tree"
}
