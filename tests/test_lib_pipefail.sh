#!/usr/bin/env bash
# Every library a workspace script sources, run without pipefail, as a
# caller may: each guard reads every stage of its own pipelines, never
# relying on its caller's pipefail (decision 228). One guard per library,
# each failing one stage of a pipeline through a stub (fixture_failing).
# The suite sets pipefail, as every workspace script does, then turns it off
# once the libraries are sourced, so every guard below runs without it.
set -u
set -o pipefail
export LC_ALL=C
TEST_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/assert.sh
. "$TEST_DIR/../foundation/tests/lib/assert.sh"
# shellcheck source-path=SCRIPTDIR source=../foundation/tests/lib/fixture.sh
. "$TEST_DIR/../foundation/tests/lib/fixture.sh"
# shellcheck source-path=SCRIPTDIR source=../foundation/bin/lib/tree.sh
. "$TEST_DIR/../foundation/bin/lib/tree.sh"
# shellcheck source-path=SCRIPTDIR source=../foundation/bin/lib/links.sh
. "$TEST_DIR/../foundation/bin/lib/links.sh"
# shellcheck source-path=SCRIPTDIR source=../foundation/bin/lib/rules.sh
. "$TEST_DIR/../foundation/bin/lib/rules.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/answers.sh
. "$TEST_DIR/../bin/lib/answers.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/discard.sh
. "$TEST_DIR/../bin/lib/discard.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/git.sh
. "$TEST_DIR/../bin/lib/git.sh"
# shellcheck source-path=SCRIPTDIR source=../bin/lib/render.sh
. "$TEST_DIR/../bin/lib/render.sh"
set +o pipefail

SCRATCH=$(mktemp -d)
SCRATCH=$(CDPATH='' cd -P -- "$SCRATCH" && pwd -P)
trap 'rm -rf "$SCRATCH"' EXIT
k=0
# under TOOL PATTERN COMMAND...: COMMAND's output and status, OUT and ST,
# with a stub TOOL failing its first call matching PATTERN.
under() {
  k=$((k + 1))
  fixture_failing "$SCRATCH/stub$k" "$1" "$2" 1
  shift 2
  OUT=$(PATH="$SCRATCH/stub$k:$PATH" && "$@" 2>&1)
  ST=$?
}
assert_eq "off" "$(set -o | awk '$1 == "pipefail" { print $2 }')" "the libraries run without pipefail here"

# answers.sh: a description's characters, counted through tr then wc.
printf '%s\n' 'field	scope	type	render	selects	pattern	default	question' \
  'DESCRIPTION	run	description	yes	-	-	-	About it?' >"$SCRATCH/answers.tsv"
long=$(printf '%400s' '' | tr ' ' a)
under tr '-d \\200-\\277' answers_check "$SCRATCH/answers.tsv" DESCRIPTION "$long"
assert_status 2 "$ST" "answers.sh: a description whose characters cannot be counted is not judged"
assert_contains "$OUT" "cannot count the characters" "  and says so"
# answers.sh: a file's bytes but NUL, counted through tr then wc.
printf 'A=b\n' >"$SCRATCH/a.env"
under tr '-d \\000' answers_read "$SCRATCH/a.env" a.env
assert_status 2 "$ST" "answers.sh: a file whose bytes cannot be counted cannot be read"
assert_contains "$OUT" "a.env: cannot read the file" "  and says so"

# render.sh: the walk's directories, and its listing of files (render__entries).
mkdir -p "$SCRATCH/target/a" "$SCRATCH/target/extra"
printf 'x\n' >"$SCRATCH/target/a/f"
render_walk "$SCRATCH/target" a/f >/dev/null
assert_status 1 "$?" "render.sh: (an empty directory the list does not hold is refused)"
under sed '-n s/^D//p *' render_walk "$SCRATCH/target" a/f
assert_status 1 "$ST" "render.sh: a walk whose list of directories fails refuses"
assert_contains "$OUT" "the walk cannot judge the directories" "  and says so, never passing the directory"
rmdir "$SCRATCH/target/extra"
under find '. -mindepth 1 ! -type d -print0' render_walk "$SCRATCH/target" a/f
assert_status 1 "$ST" "render.sh: a walk whose listing of files fails refuses"
assert_contains "$OUT" "the walk cannot list the target" "  and says so"
under sort '' render_walk "$SCRATCH/target" a/f
assert_status 1 "$ST" "render.sh: a walk whose sort of files fails refuses"
under sed '-n s/^F//p *' render_walk "$SCRATCH/target" a/f
assert_status 1 "$ST" "render.sh: a walk whose list of files fails refuses"
assert_contains "$OUT" "the walk cannot sort" "  and says so"

# tree.sh: the listing, sorted by path.
R="$SCRATCH/repo"
fixture_repo "$R"
(cd "$R" && tree_list worktree >/dev/null)
assert_status 0 "$?" "tree.sh: (the fixture lists)"
fixture_failing "$SCRATCH/sortstub" sort '-t * -k 2' 1
(cd "$R" && PATH="$SCRATCH/sortstub:$PATH" && tree_list worktree >/dev/null)
assert_status 2 "$?" "tree.sh: a listing whose sort fails cannot be read"

# render.sh: the case-twin check, whose sort stands mid-pipeline.
F="$SCRATCH/frepo"
fixture_repo "$F"
mkdir -p "$F/foundation"
printf 'a\n' >"$F/foundation/a.md"
(cd "$F" && git add -A && git -c user.name=t -c user.email=t@example.com commit -qm f)
printf 'field	scope	type	render	selects	pattern	default	question\n' >"$SCRATCH/schema.tsv"
: >"$SCRATCH/empty.env"
mkdir -p "$SCRATCH/rout1" "$SCRATCH/rout2"
(cd "$F" && render_tree HEAD "$SCRATCH/schema.tsv" "$SCRATCH/empty.env" "$SCRATCH/rout1" >/dev/null)
assert_status 0 "$?" "render.sh: (the foundation renders)"
fixture_failing "$SCRATCH/sortu" sort '-u' 1
OUT=$(cd "$F" && PATH="$SCRATCH/sortu:$PATH" && render_tree HEAD "$SCRATCH/schema.tsv" "$SCRATCH/empty.env" "$SCRATCH/rout2")
assert_status 2 "$?" "render.sh: a twin check whose sort fails cannot judge"
assert_contains "$OUT" "cannot compare the paths for case twins" "  and says so"

# rules.sh and links.sh: a Markdown file read through tree_cat, whose cat
# fails, then judged.
printf '%s\n' '# Rule' '' 'This must hold.' '' '[link](missing.md)' >"$R/RULE.md"
(cd "$R" && rules_claims worktree >/dev/null)
assert_status 1 "$?" "rules.sh: (the claim naming no check is refused)"
fixture_failing "$SCRATCH/catstub" cat '*/RULE.md' 1
(cd "$R" && PATH="$SCRATCH/catstub:$PATH" && rules_claims worktree >/dev/null)
assert_status 2 "$?" "rules.sh: a file whose read fails cannot be judged"
paths=$(cd "$R" && tree_list worktree | cut -f 2)
(cd "$R" && links_judge worktree RULE.md "$paths" >/dev/null)
assert_status 1 "$?" "links.sh: (the link to a missing file is refused)"
fixture_failing "$SCRATCH/catstub2" cat '*/RULE.md' 1
(cd "$R" && PATH="$SCRATCH/catstub2:$PATH" && links_judge worktree RULE.md "$paths" >/dev/null)
assert_status 2 "$?" "links.sh: a file whose read fails cannot be judged"
# rules.sh: a claim saying it is not enforced, its case folded through tr.
printf '%s\n' '# Rule' '' 'This must hold, not enforced.' >"$R/RULE.md"
(cd "$R" && rules_claims worktree >/dev/null)
assert_status 0 "$?" "rules.sh: (a claim not enforced is not judged)"
fixture_failing "$SCRATCH/trstub" tr '\[:upper:\] \[:lower:\]' 1
(cd "$R" && PATH="$SCRATCH/trstub:$PATH" && rules_claims worktree >/dev/null)
assert_status 2 "$?" "rules.sh: a claim whose case cannot be folded cannot be judged"

# discard.sh: render.md's record, read before a target is judged.
mkdir -p "$SCRATCH/root/widget" "$SCRATCH/out"
printf '%s\n' 'NAME=widget' "TARGET=$SCRATCH/root/widget" "TARGET_ROOT=$SCRATCH/root" >"$SCRATCH/out/answers.env"
printf '%s\n' '# Render of widget' '' "target: $SCRATCH/root/widget" >"$SCRATCH/out/render.md"
fixture_failing "$SCRATCH/recstub" awk '*ENVIRON\["K"]*render.md' 1 2
OUT=$(PATH="$SCRATCH/recstub:$PATH" && discard_check "$SCRATCH/root/widget" "$SCRATCH/out/answers.env" widget "$SCRATCH/out/render.md")
assert_status 1 "$?" "discard.sh: a render.md that cannot be read is refused"
assert_contains "$OUT" "cannot read" "  and says so"

# git.sh: the version gate.
under git '--version' git_version_ok
assert_status 1 "$ST" "git.sh: a git --version that fails is refused"

assert_done
