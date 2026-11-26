# shellcheck shell=bash
# AC1's always-on budget, judged through the tree reader (source tree.sh
# first): CLAUDE.md is exactly the line @AGENTS.md, and AGENTS.md is at most
# MAX lines, a final line without a newline counted.
#
#   agents_judge SOURCE MAX  print one line per refusal; exit 0 when both
#                            hold, 1 on a refusal, 2 when SOURCE cannot be
#                            read. Sets AGENTS_LINES to AGENTS.md's lines.
#
# The product's `agents` check and the workspace's `disclosure` both call it.

agents_judge() {
  local src=$1 max=$2 claude agents refused=0
  AGENTS_LINES=0

  claude=$(tree_cat "$src" CLAUDE.md && printf x)
  case $? in
    0)
      claude=${claude%x}
      if [ "$claude" != "@AGENTS.md" ] && [ "$claude" != "@AGENTS.md
" ]; then
        printf 'CLAUDE.md is not exactly the line @AGENTS.md\n'
        refused=1
      fi
      ;;
    1)
      printf 'CLAUDE.md is missing\n'
      refused=1
      ;;
    *) return 2 ;;
  esac

  agents=$(tree_cat "$src" AGENTS.md && printf x)
  case $? in
    0)
      AGENTS_LINES=$(printf '%s' "${agents%x}" | awk 'END { print NR }') || return 2
      if [ "$AGENTS_LINES" -gt "$max" ]; then
        printf 'AGENTS.md has %s lines, over %s\n' "$AGENTS_LINES" "$max"
        refused=1
      fi
      ;;
    1)
      printf 'AGENTS.md is missing\n'
      refused=1
      ;;
    *) return 2 ;;
  esac
  return "$refused"
}
