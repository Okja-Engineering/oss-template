#!/usr/bin/env bash
# The tree reader lists paths, blobs and modes, and reads files, from the
# working tree, the index or a commit, minus the prefixes its caller excludes.
# Each source must see exactly its own state of the same repository.
set -u
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=lib/assert.sh
. "$TEST_DIR/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=lib/fixture.sh
. "$TEST_DIR/lib/fixture.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/tree.sh
. "$TEST_DIR/../bin/lib/tree.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
R="$SCRATCH/repo"
fixture_repo "$R"

# The committed state: an edited file, a file whose bit changes, a file under
# an excluded prefix, and one whose name merely starts like it.
fixture_write "$R/edited.txt" "committed"
fixture_write "$R/mode.sh" "echo"
fixture_write "$R/run.sh" "echo"
fixture_chmod +x "$R/run.sh"
fixture_write "$R/foundation/inner.txt" "excluded"
fixture_write "$R/foundationx.txt" "kept"
fixture_write "$R/gone.txt" "deleted on disk"
fixture_commit "$R" "test: commit the tree under test"
HEAD_SHA=$(git -C "$R" rev-parse HEAD)

# The staged state: a staged edit, a staged-only new file.
fixture_write "$R/edited.txt" "staged"
fixture_write "$R/staged-only.txt" "staged only"
git -C "$R" add edited.txt staged-only.txt
# The working state: a further uncommitted edit, a bit set on disk only, a
# file removed from disk, an untracked file and an ignored one.
fixture_write "$R/edited.txt" "uncommitted"
fixture_chmod +x "$R/mode.sh"
fixture_remove "$R/gone.txt"
fixture_write "$R/untracked.txt" "untracked"
fixture_write "$R/.git/info/exclude" "ignored.txt"
fixture_write "$R/ignored.txt" "ignored"

blob_of() { blob_of_in "$R" "$1"; }
blob_of_in() { printf '%s\n' "$2" | git -C "$1" hash-object --stdin; }

# entry_of DIR SOURCE PATH: the "MODE BLOB" DIR's listing gives PATH, or
# "none"; PATH is compared as a literal string.
entry_of() {
  local line found=""
  while IFS= read -r line; do
    [ "${line#*	}" = "$3" ] && found=${line%%	*}
  done <<EOF
$(cd "$1" && tree_list "$2")
EOF
  printf '%s' "${found:-none}"
}
entry() { entry_of "$R" "$1" "$2"; }
# content_of DIR SOURCE PATH: what tree_cat reads, or "none".
content_of() { (cd "$1" && tree_cat "$2" "$3" 2>/dev/null) || printf 'none'; }
content() { content_of "$R" "$1" "$2"; }

C="commit:$HEAD_SHA"

# --- an uncommitted edit, per source -----------------------------------------
assert_eq "100644 $(blob_of uncommitted)" "$(entry worktree edited.txt)" "worktree: the uncommitted edit"
assert_eq "100644 $(blob_of staged)" "$(entry index edited.txt)" "index: the staged edit, not the uncommitted one"
assert_eq "100644 $(blob_of committed)" "$(entry "$C" edited.txt)" "commit: the committed content"
assert_eq "uncommitted" "$(content worktree edited.txt)" "worktree: reads the uncommitted edit"
assert_eq "staged" "$(content index edited.txt)" "index: reads the staged edit"
assert_eq "committed" "$(content "$C" edited.txt)" "commit: reads the committed content"

# --- a staged-only file, per source ------------------------------------------
assert_eq "100644 $(blob_of 'staged only')" "$(entry worktree staged-only.txt)" "worktree: lists the staged-only file"
assert_eq "100644 $(blob_of 'staged only')" "$(entry index staged-only.txt)" "index: lists the staged-only file"
assert_eq "none" "$(entry "$C" staged-only.txt)" "commit: does not list the staged-only file"
assert_eq "none" "$(content "$C" staged-only.txt)" "commit: cannot read the staged-only file"

# --- an executable bit, per source -------------------------------------------
assert_eq "100755" "$(entry worktree mode.sh | cut -d' ' -f1)" "worktree: the bit set on disk"
assert_eq "100644" "$(entry index mode.sh | cut -d' ' -f1)" "index: the bit as staged"
assert_eq "100644" "$(entry "$C" mode.sh | cut -d' ' -f1)" "commit: the bit as committed"
assert_eq "100755" "$(entry worktree run.sh | cut -d' ' -f1)" "worktree: a committed executable"
assert_eq "100755" "$(entry index run.sh | cut -d' ' -f1)" "index: a committed executable"
assert_eq "100755" "$(entry "$C" run.sh | cut -d' ' -f1)" "commit: a committed executable"

# --- the working tree's own additions and removals ---------------------------
assert_eq "none" "$(entry worktree gone.txt)" "worktree: a file removed from disk is gone"
assert_eq "100644 $(blob_of 'deleted on disk')" "$(entry index gone.txt)" "index: still lists it"
assert_eq "100644 $(blob_of untracked)" "$(entry worktree untracked.txt)" "worktree: lists an untracked file"
assert_eq "none" "$(entry index untracked.txt)" "index: does not list it"
assert_eq "none" "$(entry worktree ignored.txt)" "worktree: does not list an ignored file"

# --- an excluded prefix, per source ------------------------------------------
git -C "$R" add foundation/inner.txt
for src in worktree index "$C"; do
  listing=$(cd "$R" && tree_list "$src" foundation/)
  assert_not_contains "$listing" "foundation/inner.txt" "$src: the excluded prefix is dropped"
  assert_contains "$listing" "foundationx.txt" "$src: a name that only starts like it is kept"
  listing=$(cd "$R" && tree_list "$src")
  assert_contains "$listing" "foundation/inner.txt" "$src: without the exclusion it is listed"
done

# --- the source a check reads follows its mode -------------------------------
assert_eq "worktree" "$(CHECK_MODE=tree tree_source)" "tree mode reads the working tree"
assert_eq "index" "$(CHECK_MODE=staged tree_source)" "staged mode reads the index"
assert_eq "commit:$HEAD_SHA" "$(CHECK_MODE=range CHECK_HEAD=$HEAD_SHA tree_source)" \
  "range mode reads the head commit's objects"

# --- a source that cannot be read is an error, not an empty tree -------------
(cd "$R" && tree_list nonsense >/dev/null 2>&1)
assert_status 2 "$?" "an unknown source exits 2"
(cd "$R" && tree_list commit:no-such-rev >/dev/null 2>&1)
assert_status 2 "$?" "an unknown commit exits 2"
U="$SCRATCH/unborn"
git init -q -b main "$U"
(cd "$U" && tree_list commit:HEAD >/dev/null 2>&1)
assert_status 2 "$?" "a commit source on an unborn branch exits 2"
(cd "$U" && tree_list index >/dev/null 2>&1)
assert_status 0 "$?" "the index of an unborn branch reads as empty"
(cd "$R" && tree_list worktree '' >/dev/null 2>&1)
assert_status 2 "$?" "an empty prefix exits 2 rather than excluding everything"

# --- every source judges the same set of paths ---------------------------------
# A committed, clean tree holding names git would quote or a shell would split
# or expand: the three sources list it identically, and read each file. A
# name a line reader would rewrite (one opening with a quote, read as C-quoted;
# one ending in a carriage return, stripped) sits beside the name it would
# become, so a source that reads it that way reports the sibling's blob.
O="$SCRATCH/odd"
fixture_repo "$O"
TAB=$(printf '\t')
CR=$(printf '\r')
odd_names="quo\"te.md
\"q\"
q
cr$CR
cr
back\\slash.md
tab${TAB}name.md
two  spaces.md
star*.md
glo[b].md
-dash.md
caf$(printf '\303\251').md
dir with space/inner.md"
while IFS= read -r name; do
  fixture_write "$O/$name" "content of $name"
done <<EOF
$odd_names
EOF
ln -s CLAUDE.md "$O/-link"
fixture_commit "$O" "test: odd names"
list_wt=$(cd "$O" && tree_list worktree)
assert_status 0 "$?" "worktree: a tree of odd names reads"
list_ix=$(cd "$O" && tree_list index)
assert_status 0 "$?" "index: a tree of odd names reads"
list_cm=$(cd "$O" && tree_list commit:HEAD)
assert_status 0 "$?" "commit: a tree of odd names reads"
assert_eq "$list_cm" "$list_wt" "worktree lists exactly what the commit holds"
assert_eq "$list_cm" "$list_ix" "index lists exactly what the commit holds"
for src in worktree index commit:HEAD; do
  while IFS= read -r name; do
    assert_eq "content of $name" "$(content_of "$O" "$src" "$name")" "$src: reads '$name'"
  done <<EOF
$odd_names
EOF
done
assert_contains "$list_wt" "120000 $(printf CLAUDE.md | git -C "$O" hash-object --stdin)${TAB}-link" \
  "worktree: a symbolic link whose name starts with - has its target's blob"
assert_eq "CLAUDE.md" "$(content_of "$O" worktree -link)" "worktree: reads a link as its target text"

# A path no listing line can hold (a newline) fails every source alike.
N="$SCRATCH/newline"
fixture_repo "$N"
fixture_write "$N/new
line.md" "x"
(cd "$N" && tree_list worktree >/dev/null 2>&1)
assert_status 2 "$?" "worktree: a path holding a newline exits 2"
fixture_commit "$N" "test: a newline in a name"
for src in index commit:HEAD; do
  (cd "$N" && tree_list "$src" >/dev/null 2>&1)
  assert_status 2 "$?" "$src: a path holding a newline exits 2"
done

# --- the working tree is what git add -A would stage ----------------------------
fixture_write "$O/ignored.md" "ignored"
fixture_write "$O/.git/info/exclude" "ignored.md"
fixture_write "$SCRATCH/outside.txt" "outside"
assert_eq "none" "$(content_of "$O" worktree ignored.md)" "worktree: an ignored file cannot be read"
assert_eq "none" "$(content_of "$O" worktree ../outside.txt)" "worktree: a path outside the repository cannot be read"
assert_eq "none" "$(content_of "$O" commit:HEAD ../outside.txt)" "commit: nor through the commit source"
assert_eq "none" "$(content_of "$O" worktree 'dir with space')" "worktree: a directory is not a file"
# A path written other than as a listing writes it names no file, in any
# source, though git would resolve some of them in a tree.
for src in worktree index commit:HEAD; do
  for p in ./AGENTS.md /AGENTS.md AGENTS.md/ 'dir with space//inner.md' \
    'dir with space/./inner.md' 'dir with space/../AGENTS.md'; do
    assert_eq "none" "$(content_of "$O" "$src" "$p")" "$src: '$p' is not a path a listing writes"
  done
done

# A submodule moved forward: the worktree lists its checked-out commit, the
# index the recorded one. A nested repository not yet added is listed as
# git add -A would add it.
git init -q -b main "$O/sub"
git -C "$O/sub" commit -q --allow-empty -m "test: sub one"
(cd "$O" && git add sub 2>/dev/null && git commit -q -m "test: add a gitlink")
git -C "$O/sub" commit -q --allow-empty -m "test: sub two"
assert_eq "160000 $(git -C "$O/sub" rev-parse HEAD)" "$(entry_of "$O" worktree sub)" \
  "worktree: a submodule's checked-out commit"
assert_eq "160000 $(git -C "$O/sub" rev-parse HEAD~1)" "$(entry_of "$O" index sub)" "index: the recorded commit"
git init -q -b main "$O/nested"
git -C "$O/nested" commit -q --allow-empty -m "test: nested"
assert_eq "160000 $(git -C "$O/nested" rev-parse HEAD)" "$(entry_of "$O" worktree nested)" \
  "worktree: an untracked nested repository, named without a slash"
git init -q -b main "$O/unborn-nested"
(cd "$O" && tree_list worktree >/dev/null 2>&1)
assert_status 2 "$?" "worktree: a nested repository with no commit, which git add cannot add, exits 2"
rm -rf "$O/unborn-nested" "$O/nested"

# --- staged mode judges the tree the commit would hold --------------------------
fixture_write "$O/later.md" "later"
git -C "$O" add -N later.md
assert_eq "none" "$(entry_of "$O" index later.md)" "index: an intent-to-add entry is not listed"
assert_eq "none" "$(content_of "$O" index later.md)" "index: nor read"
assert_eq "100644 $(blob_of_in "$O" later)" "$(entry_of "$O" worktree later.md)" "worktree: lists it from disk"
git -C "$O" rm -q --cached later.md

# --- a git failure is an error, never an empty or partial tree ------------------
F="$SCRATCH/failing"
fixture_repo "$F"
printf 'not an index' >"$F/.git/index"
for src in worktree index; do
  (cd "$F" && tree_list "$src" >/dev/null 2>&1)
  assert_status 2 "$?" "$src: an unreadable index exits 2"
done
M="$SCRATCH/merge"
fixture_repo "$M"
git -C "$M" checkout -q -b other
fixture_write "$M/AGENTS.md" "other"
fixture_commit "$M" "test: other side"
git -C "$M" checkout -q main
fixture_write "$M/AGENTS.md" "main"
fixture_commit "$M" "test: main side"
git -C "$M" merge -q other >/dev/null 2>&1
(cd "$M" && tree_list index >/dev/null 2>&1)
assert_status 2 "$?" "index: unmerged paths exit 2"
(cd "$M" && tree_list worktree >/dev/null 2>&1)
assert_status 0 "$?" "worktree: a conflicted file reads as it stands on disk"
assert_eq 1 "$(cd "$M" && tree_list worktree | grep -c "${TAB}AGENTS.md\$")" "worktree: listed once, not per stage"

# --- the listing is sorted by path, and hashed without filters ----------------
# git lists untracked files before tracked ones; the listing is by path.
list_r=$(cd "$R" && tree_list worktree)
assert_eq "$(printf '%s\n' "$list_r" | sort -t "$TAB" -k 2)" "$list_r" \
  "the listing is sorted by path, untracked files among tracked ones"
printf '* text=auto eol=crlf\n' >"$O/.gitattributes"
printf 'a\r\nb\r\n' >"$O/crlf.txt"
assert_eq "100644 $(printf 'a\r\nb\r\n' | git -C "$O" hash-object --no-filters --stdin)" \
  "$(entry_of "$O" worktree crlf.txt)" "worktree: a file's bytes as they stand, unfiltered"

assert_done
