# shellcheck shell=bash
# The link resolver: Markdown's inline links, resolved within the tree the
# tree reader lists, to a path and, for a Markdown file, a heading's anchor.
#
#   links_targets            Markdown in; "NR<TAB>TARGET" out per inline link
#                            or image, outside fences and code spans, TARGET
#                            without its angle brackets or title.
#   links_resolve FROM TARGET
#                            TARGET as written in the file FROM, both
#                            relative to the top of the tree: print
#                            "PATH#ANCHOR" (the anchor part only when TARGET
#                            has one), PATH normalized, FROM itself for a
#                            bare "#ANCHOR". Exit 0; 1 when TARGET is not
#                            relative (a scheme, `//`, or a leading `/`),
#                            which is not judged; 2 when it climbs above the
#                            top of the tree.
#   links_anchors            Markdown in; the anchor of each heading out, as
#                            GitHub makes them: lowercased, every character
#                            but a letter, digit, space, `-` and `_`
#                            dropped (bytes above 0x7f kept, as letters),
#                            each space a `-`, and `-1`, `-2`... after a
#                            repeat. Inline code and emphasis marks go, and
#                            a link keeps its text.
#   links_judge SRC FILE PATHS
#                            each relative link in FILE, read from the
#                            tree.sh source SRC, must reach a path PATHS (the
#                            tree's paths, one a line) holds, as a file or a
#                            directory, and an anchor must be one of that
#                            Markdown file's headings. One line out per
#                            refusal; exit 0 when none, 1 on a refusal, 2
#                            when SRC cannot be read.
#
# Source tree.sh first; the caller exports LC_ALL=C.

links_targets() {
  awk '
    /^ ? ? ?(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      s = $0
      out = ""
      # Blank code spans, so a link written as code is not a link.
      while ((i = index(s, "`")) > 0) {
        out = out substr(s, 1, i - 1)
        s = substr(s, i)
        match(s, /^`+/)
        n = RLENGTH
        run = substr(s, 1, n)
        j = index(substr(s, n + 1), run)
        if (j == 0) { out = out run; s = substr(s, n + 1); continue }
        out = out sprintf("%" (j - 1 + 2 * n) "s", "")
        s = substr(s, n + j + n)
      }
      s = out s
      while (match(s, /\]\([^)]*\)/)) {
        t = substr(s, RSTART + 2, RLENGTH - 3)
        s = substr(s, RSTART + RLENGTH)
        sub(/^[ \t]+/, "", t)
        if (t ~ /^</) { sub(/^</, "", t); sub(/>.*$/, "", t) }
        else sub(/[ \t].*$/, "", t)
        if (t != "") printf "%d\t%s\n", NR, t
      }
    }'
}

links_resolve() {
  local from=$1 target=$2 path anchor="" dir
  case "$target" in
    *'#'*)
      anchor=${target#*#}
      path=${target%%#*}
      ;;
    *) path=$target ;;
  esac
  case "$path" in
    /* | *:*) return 1 ;;
  esac
  if [ -z "$path" ]; then
    path=$from
  else
    case "$from" in
      */*) dir=${from%/*} ;;
      *) dir="" ;;
    esac
    path=$(
      printf '%s\n' "${dir:+$dir/}$path" | awk -F/ '{
        n = 0
        for (i = 1; i <= NF; i++) {
          if ($i == "" || $i == ".") continue
          if ($i == "..") {
            if (n == 0) { print "UP"; exit }
            n--
            continue
          }
          p[++n] = $i
        }
        s = ""
        for (i = 1; i <= n; i++) s = s (i > 1 ? "/" : "") p[i]
        print "OK" s
      }'
    )
    case "$path" in
      UP) return 2 ;;
      OK*) path=${path#OK} ;;
    esac
  fi
  case "$target" in
    *'#'*) printf '%s#%s\n' "$path" "$anchor" ;;
    *) printf '%s\n' "$path" ;;
  esac
}

links_anchors() {
  awk '
    /^ ? ? ?(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^ ? ? ?#+([ \t]|$)/ {
      h = $0
      sub(/^ *#+[ \t]*/, "", h)
      sub(/[ \t]+#+[ \t]*$/, "", h)
      sub(/[ \t]+$/, "", h)
      # A link keeps its text; code and emphasis marks go.
      while (match(h, /\[[^]]*\]\([^)]*\)/)) {
        t = substr(h, RSTART + 1, RLENGTH)
        sub(/\]\(.*$/, "", t)
        h = substr(h, 1, RSTART - 1) t substr(h, RSTART + RLENGTH)
      }
      gsub(/[`*]/, "", h)
      h = tolower(h)
      a = ""
      for (i = 1; i <= length(h); i++) {
        c = substr(h, i, 1)
        if (c ~ /[a-z0-9_-]/ || c > "~") a = a c
        else if (c == " ") a = a "-"
      }
      if (a in seen) { k = seen[a]++; print a "-" k }
      else { seen[a] = 1; print a }
    }'
}

links_judge() {
  local src=$1 file=$2 paths=$3 targets nr target resolved st path anchor refused=0
  targets=$(tree_cat "$src" "$file" | links_targets) || return 2
  [ -n "$targets" ] || return 0
  while IFS='	' read -r nr target; do
    resolved=$(links_resolve "$file" "$target")
    st=$?
    case "$st" in
      1) continue ;;
      2)
        printf '%s:%s: the link %s climbs out of the repository\n' "$file" "$nr" "$target"
        refused=1
        continue
        ;;
    esac
    path=${resolved%%#*}
    if ! links__holds "$paths" "$path"; then
      printf '%s:%s: the link %s does not resolve: no %s\n' "$file" "$nr" "$target" "$path"
      refused=1
      continue
    fi
    case "$resolved" in *'#'*) ;; *) continue ;; esac
    anchor=${resolved#*#}
    case "$path" in *.md) ;; *) continue ;; esac
    if ! tree_cat "$src" "$path" | links_anchors | grep -Fx -e "$anchor" >/dev/null; then
      printf '%s:%s: the link %s does not resolve: %s has no heading #%s\n' \
        "$file" "$nr" "$target" "$path" "$anchor"
      refused=1
    fi
  done <<EOF
$targets
EOF
  return "$refused"
}

# links__holds PATHS PATH: PATHS holds PATH as a file, or as a directory
# (an empty PATH, the top, always).
links__holds() {
  [ -n "$2" ] || return 0
  printf '%s\n' "$1" | P="$2" awk '
    $0 == ENVIRON["P"] || index($0, ENVIRON["P"] "/") == 1 { found = 1 }
    END { exit !found }'
}
