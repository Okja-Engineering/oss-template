#!/usr/bin/env bash
# The tree reader lists paths, blobs and modes, and reads files, from the
# working tree, the index or a commit, minus the prefixes its caller excludes.
# Each source must see exactly its own state of the same repository.
set -u
export LC_ALL=C
TEST_DIR=$(cd "$(dirname "$0")" && pwd)
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

blob_of() { printf '%s\n' "$1" | git -C "$R" hash-object --stdin; }

# entry SOURCE PATH: the "MODE BLOB" a listing gives PATH, or "none".
entry() {
  local line
  line=$(cd "$R" && tree_list "$1" | awk -F '\t' -v p="$2" '$2 == p { print $1 }')
  printf '%s' "${line:-none}"
}
content() { (cd "$R" && tree_cat "$1" "$2" 2>/dev/null) || printf 'none'; }

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

assert_done
