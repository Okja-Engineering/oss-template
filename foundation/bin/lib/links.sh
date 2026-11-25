# shellcheck shell=bash
# The link resolver: Markdown's links, resolved within the tree the tree
# reader lists, to a path and, for a Markdown file, a heading's anchor.
#
# The Markdown read is a subset, defined once here in LINKS_MD_AWK and
# shared with rules.sh: fenced blocks; code spans; headings, ATX (`#`) and
# setext (paragraph lines over a line of `=` or `-`); links, inline
# (`[text](target)`) and by reference (`[text][label]`, `[label][]` and
# `[label]`, with `[label]: target` anywhere in the file).
#
#   links_targets            Markdown in; "NR<TAB>TARGET" out per link or
#                            image, outside fences and code spans, TARGET
#                            without its angle brackets or title: an inline
#                            link's on its line, a reference's on the line
#                            that uses it, and each definition's on its own
#                            line, so a definition no link uses is judged
#                            too. A label no definition gives is not a link.
#   links_on NR TARGETS      the targets links_targets gave, as TARGETS, for
#                            line NR, one a line.
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
#                            GitHub makes them: markup removed, so a link
#                            keeps its text, code keeps its contents, and
#                            HTML tags, `*` and the `_` that opens or closes
#                            emphasis go (an `_` inside a word stays);
#                            lowercased; every character but a letter,
#                            digit, space, `-` and `_` dropped (bytes above
#                            0x7f kept, as letters); each space a `-`; and
#                            `-1`, `-2`... after a repeat.
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

# The awk functions of the subset, prefixed to each awk program that reads
# Markdown:
#   md_block(LINE)  the kind of LINE, read in order: "fence" for a fence line
#                   or one inside a fence, "blank", "atx", "under" (a line
#                   of `=` or of `-`: a setext underline after "text", else
#                   a thematic break), "break", "item" (a list item or a
#                   block quote), "lazy" (a line continuing an item), "code"
#                   (indented, not continuing a paragraph) or "text".
#   md_spans(S)     S with each code span, its backticks included, blanked;
#                   a run of backticks with no closing run of the same
#                   length is text.
#   md_plain(S)     S with its markup removed, as links_anchors describes.
# shellcheck disable=SC2016 # awk code, its $ kept for awk
LINKS_MD_AWK='
function md_block(l,   k) {
  if (l ~ /^ ? ? ?(```|~~~)/) { md_fence = !md_fence; k = "fence" }
  else if (md_fence) k = "fence"
  else if (l ~ /^[ \t]*$/) k = "blank"
  else if (l ~ /^ ? ? ?#+([ \t]|$)/) k = "atx"
  else if (l ~ /^ ? ? ?(=+|-+)[ \t]*$/) k = "under"
  else if (l ~ /^ ? ? ?([-*_][ \t]*)([-*_][ \t]*)([-*_][ \t]*)+$/) k = "break"
  else if (l ~ /^ ? ? ?([-*+]|[0-9]+[.)])([ \t]|$)/ || l ~ /^ ? ? ?>/) k = "item"
  else if (md_prev == "item" || md_prev == "lazy") k = "lazy"
  else if (l ~ /^(    |\t)/ && md_prev != "text") k = "code"
  else k = "text"
  md_prev = k
  return k
}
function md_spans(s,   out, i, n, run, j) {
  out = ""
  while ((i = index(s, "`")) > 0) {
    out = out substr(s, 1, i - 1)
    s = substr(s, i)
    match(s, /^`+/)
    n = RLENGTH
    run = substr(s, 1, n)
    j = index(substr(s, n + 1), run)
    if (j == 0) {
      out = out run
      s = substr(s, n + 1)
      continue
    }
    out = out sprintf("%" (j - 1 + 2 * n) "s", "")
    s = substr(s, n + j + n)
  }
  return out s
}
function md_plain(s,   out, i, n, run, j) {
  out = ""
  while ((i = index(s, "`")) > 0) {
    out = out md_marks(substr(s, 1, i - 1))
    s = substr(s, i)
    match(s, /^`+/)
    n = RLENGTH
    run = substr(s, 1, n)
    j = index(substr(s, n + 1), run)
    if (j == 0) {
      out = out run
      s = substr(s, n + 1)
      continue
    }
    out = out substr(s, n + 1, j - 1)
    s = substr(s, n + j + n)
  }
  return out md_marks(s)
}
# md_marks S: text outside code with its marks gone: HTML tags, `*`, and
# each pair of `_` runs that opens and closes emphasis. A run opens when no
# letter or digit comes before it and no space after, and closes the other
# way round, so an `_` inside a word, or one left unpaired, stays.
function md_marks(s,   i, n, p, q, m, k, open, out) {
  gsub(/<\/?[A-Za-z][^>]*>/, "", s)
  gsub(/\*/, "", s)
  m = 0
  i = 1
  while (i <= length(s)) {
    if (substr(s, i, 1) != "_") { i++; continue }
    n = 1
    while (substr(s, i + n, 1) == "_") n++
    p = i > 1 ? substr(s, i - 1, 1) : ""
    q = substr(s, i + n, 1)
    m++
    md_at[m] = i
    md_len[m] = n
    md_opens[m] = q != "" && q !~ /[ \t]/ && (p == "" || !md_word(p))
    md_closes[m] = p != "" && p !~ /[ \t]/ && (q == "" || !md_word(q))
    md_drop[m] = 0
    i += n
  }
  open = 0
  for (k = 1; k <= m; k++) {
    if (md_closes[k] && open) { md_drop[open] = 1; md_drop[k] = 1; open = 0 }
    else if (md_opens[k]) open = k
  }
  out = ""
  i = 1
  for (k = 1; k <= m; k++) {
    out = out substr(s, i, md_at[k] - i)
    if (!md_drop[k]) out = out substr(s, md_at[k], md_len[k])
    i = md_at[k] + md_len[k]
  }
  return out substr(s, i)
}
function md_word(c) { return c ~ /[A-Za-z0-9]/ || c > "~" }
'

links_targets() {
  awk "$LINKS_MD_AWK"'
    # label L: a reference label, its case and spacing folded.
    function label(l) {
      l = tolower(l)
      gsub(/[ \t]+/, " ", l)
      sub(/^ /, "", l)
      sub(/ $/, "", l)
      return l
    }
    # dest T: a target without its angle brackets or title.
    function dest(t) {
      sub(/^[ \t]+/, "", t)
      if (t ~ /^</) { sub(/^</, "", t); sub(/>.*$/, "", t) }
      else sub(/[ \t].*$/, "", t)
      return t
    }
    # A definition holds for the whole file, so every line is read first.
    {
      line[NR] = $0
      kind[NR] = md_block($0)
      if (kind[NR] == "fence" || kind[NR] == "code") next
      if (match($0, /^ ? ? ?\[[^]]+\]:/)) {
        l = substr($0, 1, RLENGTH - 2)
        sub(/^ *\[/, "", l)
        l = label(l)
        t = dest(substr($0, RLENGTH + 1))
        kind[NR] = "def"
        if (t != "" && l != "" && !(l in def)) { def[l] = t; deft[NR] = t }
      }
    }
    END {
      for (i = 1; i <= NR; i++) {
        if (kind[i] == "fence" || kind[i] == "code") continue
        if (kind[i] == "def") {
          if (i in deft) printf "%d\t%s\n", i, deft[i]
          continue
        }
        s = md_spans(line[i])
        r = s
        while (match(r, /\]\([^)]*\)/)) {
          t = dest(substr(r, RSTART + 2, RLENGTH - 3))
          r = substr(r, RSTART + RLENGTH)
          if (t != "") printf "%d\t%s\n", i, t
        }
        r = s
        while (match(r, /\[[^]]*\]/)) {
          l = substr(r, RSTART + 1, RLENGTH - 2)
          r = substr(r, RSTART + RLENGTH)
          if (r ~ /^\(/) continue
          if (match(r, /^\[[^]]*\]/)) {
            if (RLENGTH > 2) l = substr(r, 2, RLENGTH - 2)
            r = substr(r, RLENGTH + 1)
          }
          l = label(l)
          if (l in def) printf "%d\t%s\n", i, def[l]
        }
      }
    }'
}

links_on() {
  printf '%s\n' "$2" | N="$1" awk -F '\t' '$1 == ENVIRON["N"] { print substr($0, index($0, "\t") + 1) }'
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
  awk "$LINKS_MD_AWK"'
    # anchor H: the anchor of the heading text H, out.
    function anchor(h,   t, a, c, i, k) {
      # A link keeps its text: inline, and by reference.
      while (match(h, /\[[^]]*\]\([^)]*\)/)) {
        t = substr(h, RSTART + 1, RLENGTH)
        sub(/\]\(.*$/, "", t)
        h = substr(h, 1, RSTART - 1) t substr(h, RSTART + RLENGTH)
      }
      gsub(/\]\[[^]]*\]/, "]", h)
      h = tolower(md_plain(h))
      a = ""
      for (i = 1; i <= length(h); i++) {
        c = substr(h, i, 1)
        if (c ~ /[a-z0-9_-]/ || c > "~") a = a c
        else if (c == " ") a = a "-"
      }
      if (a in seen) { k = seen[a]++; print a "-" k }
      else { seen[a] = 1; print a }
    }
    # trim S: S without its leading and trailing blanks.
    function trim(s) {
      sub(/^[ \t]+/, "", s)
      sub(/[ \t]+$/, "", s)
      return s
    }
    {
      k = md_block($0)
      # Paragraph lines are held: an underline makes them a setext heading.
      if (k == "text") { para = held++ ? para " " trim($0) : trim($0); next }
      if (k == "under" && held) { held = 0; anchor(para); next }
      held = 0
      if (k != "atx") next
      h = $0
      sub(/^ *#+[ \t]*/, "", h)
      sub(/[ \t]+#+[ \t]*$/, "", h)
      anchor(trim(h))
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
