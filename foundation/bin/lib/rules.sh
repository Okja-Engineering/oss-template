# shellcheck shell=bash
# The rule words, and the lines of Markdown that state rules (decision 30,
# TAC12, TAC13). Matching is by wording, one line at a time, since a rule
# sentence is kept to one line.
#
# Two lists. `claims` holds decision 30's words: must, must not, required,
# never, refuse(s/d), block(s/ed), reject(s/ed), enforce(s/d),
# prevent(s/ed). `trace` holds those and always, do not, don't and STOP,
# STOP in capitals only. A word matches whole, in any case, between
# characters that are not letters, digits or `_`.
#
#   rules_lines claims|trace   Markdown in; "NR<TAB>LINE" out for each line
#                              holding a word of that list, LINE as written.
#                              YAML frontmatter, fenced blocks and
#                              indented code are not judged, and code spans
#                              are blanked first, as links.sh's Markdown
#                              subset reads them. For
#                              `claims` a heading is not a sentence, so no
#                              heading line is judged, ATX or setext: the
#                              heading rule (decisions 173, 179), shared by
#                              the product's `claims` and the workspace's.
#   rules_word TEXT            print the first word of the `trace` list, the
#                              union of both, that TEXT holds as one line of
#                              prose; exit 1 when it holds none, above 1
#                              when TEXT cannot be read, never read as none.
#   rules_claims SRC PREFIX... judge every `.md` file the tree.sh source SRC
#                              lists, but those under a PREFIX: each line
#                              `rules_lines claims` gives names a check or
#                              says it is not enforced. One line out per
#                              refusal; exit 0 when none, 1 on a refusal, 2
#                              when SRC cannot be read. Sets RULES_FILES to
#                              the number of files judged.
#
# A line names a check when one of its code spans, or one of its relative
# link targets, inline or by reference, starts with a path the tree holds,
# as a file or a directory, under bin/, .githooks/, .claude/hooks/ or
# .github/workflows/ (so `bin/check NAME` names one); it says it is not
# enforced when it holds "not enforced" or "unenforced", in any case. Source
# tree.sh and links.sh first; the caller exports LC_ALL=C.

RULES_CLAIMS_WORDS='must|required|never|refuse[sd]?|blocks?|blocked|rejects?|rejected|enforce[sd]?|prevents?|prevented'
RULES_TRACE_WORDS="always|do not|don't|don’t"

# rules__scan LIST lines|word: the scanner both entry points share.
rules__scan() {
  local words=$RULES_CLAIMS_WORDS caps=""
  if [ "$1" = trace ]; then
    words="$words|$RULES_TRACE_WORDS"
    caps=STOP
  fi
  awk -v W="$words" -v CAPS="$caps" -v LIST="$1" -v MODE="$2" "$LINKS_MD_AWK"'
    # word S: the first rule word S holds, or "".
    function word(s,   l, w) {
      l = tolower(s)
      if (match(l, "(^|[^a-z0-9_])(" W ")([^a-z0-9_]|$)")) {
        w = substr(s, RSTART, RLENGTH)
        sub(/^[^A-Za-z]/, "", w)
        sub(/[^A-Za-z]$/, "", w)
        return w
      }
      if (CAPS != "" && match(s, "(^|[^A-Za-z0-9_])" CAPS "([^A-Za-z0-9_]|$)")) return CAPS
      return ""
    }
    # judge NR LINE: LINE out when it holds a rule word.
    function judge(nr, l) { if (word(md_spans(l)) != "") printf "%d\t%s\n", nr, l }
    # flush: judge the paragraph lines held back, which no setext underline
    # made a heading.
    function flush(   i) {
      for (i = 1; i <= held; i++) judge(hnr[i], hl[i])
      held = 0
    }
    # The first word found is the answer; the rest is read, not left, so a
    # writer on a pipe is never cut off.
    MODE == "word" {
      if (!found && (w = word(md_spans($0))) != "") { print w; found = 1 }
      next
    }
    {
      k = md_block($0)
      # For claims a paragraph line waits for the next one, an underline
      # making the paragraph a heading.
      if (LIST == "claims" && k == "text") { hnr[++held] = NR; hl[held] = $0; next }
      if (k == "under" && held) { held = 0; next }
      flush()
      if (k == "front" || k == "fence" || k == "code" || (LIST == "claims" && k == "atx")) next
      judge(NR, $0)
    }
    END {
      if (MODE == "word") exit !found
      flush()
    }'
}

rules_lines() {
  case "$1" in
    claims | trace) rules__scan "$1" lines ;;
    *)
      printf 'rules: unknown list: %s\n' "$1" >&2
      return 2
      ;;
  esac
}

rules_word() {
  rules__scan trace word <<<"$1"
}

rules_claims() {
  local src=$1 listing paths file hits targets nr text on refused=0
  shift
  RULES_FILES=0
  listing=$(tree_list "$src" "$@") || return 2
  paths=$(printf '%s\n' "$listing" | sed 's/^[^	]*	//') || return 2
  while IFS= read -r file; do
    case "$file" in *.md) ;; *) continue ;; esac
    RULES_FILES=$((RULES_FILES + 1))
    hits=$(set -o pipefail; tree_cat "$src" "$file" | rules_lines claims) || return 2
    [ -n "$hits" ] || continue
    # The file's links, read whole, since a reference's definition may sit on
    # any line.
    targets=$(set -o pipefail; tree_cat "$src" "$file" | links_targets) || return 2
    while IFS='	' read -r nr text; do
      rules__unenforced "$text" && continue
      on=$(links_on "$nr" "$targets") || return 2
      rules__names_check "$file" "$text" "$paths" "$on"
      case $? in
        0) continue ;;
        1) ;;
        *) return 2 ;;
      esac
      printf '%s:%s: a rule line that names no check and does not say it is not enforced: %s\n' \
        "$file" "$nr" "$text"
      refused=1
    done <<EOF
$hits
EOF
  done <<EOF
$paths
EOF
  return "$refused"
}

rules__unenforced() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    *'not enforced'* | *unenforced*) return 0 ;;
  esac
  return 1
}

# rules__names_check FILE LINE PATHS TARGETS: LINE, in FILE, names an
# enforcer that PATHS (the tree's paths, one per line) holds, by a code span
# or by one of TARGETS, its link targets, one per line. Exit 2 when LINE
# cannot be read.
rules__names_check() {
  local file=$1 text=$2 paths=$3 cands target resolved cand
  cands=$(rules__spans "$text") || return 2
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    resolved=$(links_resolve "$file" "$target")
    case $? in
      0) ;;
      3) return 2 ;;
      *) continue ;;
    esac
    cands="$cands
${resolved%%#*}"
  done <<EOF
$4
EOF
  while IFS= read -r cand; do
    case "$cand" in
      bin/?* | .githooks/?* | .claude/hooks/?* | .github/workflows/?*) ;;
      *) continue ;;
    esac
    links__holds "$paths" "${cand%/}"
    case $? in
      0) return 0 ;;
      1) ;;
      *) return 2 ;;
    esac
  done <<EOF
$cands
EOF
  return 1
}

# rules__spans LINE: the first word of each code span in LINE, one a line.
rules__spans() {
  printf '%s\n' "$1" | awk '{
    s = $0
    while ((i = index(s, "`")) > 0) {
      s = substr(s, i)
      match(s, /^`+/)
      n = RLENGTH
      run = substr(s, 1, n)
      j = index(substr(s, n + 1), run)
      if (j == 0) { s = substr(s, n + 1); continue }
      span = substr(s, n + 1, j - 1)
      sub(/^[ ]+/, "", span)
      split(span, w, " ")
      print w[1]
      s = substr(s, n + j + n)
    }
  }'
}
