# 0001 oss-template: plan

**Status:** draft. **Decider:** Matthew Van Dusen. **Rests on:** [`spec.md`](spec.md), [`decisions.md`](decisions.md).

## Approach

One builder, serially, on `feat/initial-template`. One task is one commit, in the order below. Each task starts with the test named in its row, seen failing, then the change that makes it pass.

**Every commit is green, checked twice before it is made:** with `PATH=/usr/bin:/bin:/usr/sbin:/sbin` (macOS `/bin/bash` 3.2, no `shellcheck`), and with the normal `PATH` and `REQUIRE_SHELLCHECK=1`; each time `bin/check` and `tests/run-all.sh` pass, once they exist. The order makes that possible. A check lands after the files it judges, or with them. Human text states a rule before the code that enforces it: `CONTRIBUTING.md` and `GOVERNANCE.md` land early, and until a rule's enforcer exists, its line says "not enforced". The task that adds an enforcer rewrites that line to name it and adds its row to `CONTRIBUTING.md` § What is enforced. Each task that adds a required file adds its `bin/lib/layout.txt` entries first, so `layout` fails until the file exists.

Commits are conventional and carry no `Co-Authored-By` or tool credit; neither does the build PR body. The spec and plan stay `draft`: the decider accepts them, or doesn't, when he acks the build PR (ruling 12, `decisions.md`).

How this fits what exists:

- **The repository today** holds `README.md`, `LICENSE`, and this folder. `README.md` is rewritten (T34); `LICENSE`, `intent.md`, `research.md` and `decisions.md` are untouched. Every chain doc here already has a C1 status line and a `**Decider:**`, and `GOVERNANCE.md` (T6) lands before the `docs` check (T9) that reads § Deciders.
- **Taken from upstream where sound:** `tests/run-all.sh` with its tracked-suite cross-check, `tests/lib/assert.sh`, the throwaway-repository-and-bare-remote hook tests, the fail-closed `never-publish` list, the built-in secret patterns, the runner self-test, read-only workflow permissions.
- **Upstream defects fixed at the root:** upstream has three copies of the subject regex, which disagreed on merges, and all three refuse `Revert "…"`. Here one classifier serves every enforcement point.
- **One parser per format.** Subjects: `bin/lib/classify.sh`. Status lines: `bin/lib/docs.sh`, used by `bin/check`, `bin/new` and `guard-docs.sh`. Rule words: `bin/lib/rules.sh`, used by `trace` and `claims`. Frontmatter: inside `agents`. Git hooks and CI call `bin/check` and hold no rules of their own. `guard-bash.sh` holds the command patterns, which nothing else needs; each refusal names its source in `CONTRIBUTING.md` § Agent guards.

**Before the first commit** the builder needs `shellcheck` installed locally (`brew install shellcheck`; not a repository dependency). Installing it changes the machine, so it needs the chief of staff's go-ahead.

## File tree

```
AGENTS.md  CLAUDE.md  README.md  CONTRIBUTING.md  GOVERNANCE.md  SECURITY.md
CODE_OF_CONDUCT.md  CHANGELOG.md  LICENSE  .gitignore
.claude/settings.json  .claude/hooks/{guard-bash,guard-docs,session-start}.sh
.claude/rules/{docs,workflows,scripts}.md  .claude/skills/{new-work,new-rfc,new-adr}/SKILL.md
.claude/agents/reviewer.md
.githooks/{commit-msg,pre-commit,pre-push,never-publish}
.github/{CODEOWNERS,labels.yml,dependabot.yml,pull_request_template.md}
.github/ISSUE_TEMPLATE/{bug,change,tracking,config}.yml
.github/workflows/{ci,pr,labels,scorecard}.yml
bin/{check,setup,new,init}  bin/lib/{docs,classify,rules}.sh  bin/lib/layout.txt
docs/adr/{0001..0005}-*.md  docs/rfcs/README.md  docs/templates/{intent,spec,plan,rfc,adr}.md
docs/work/0001-oss-template/{research,intent,spec,plan,decisions}.md
tests/run-all.sh  tests/generation.sh  tests/lib/{assert,fixture}.sh  tests/fixtures/{runner,hooks}/**
tests/test_*.sh   (one per row below that names one; every one reads fixtures only)
```

## Tasks

| # | Task (one commit) | Test written first | ACs |
|---|---|---|---|
| T1 | `tests/run-all.sh`, `tests/lib/assert.sh`, runner fixtures | `test_run_all.sh`: fails on the failing fixture and on a tracked suite missing from the tree | AC27, AC43 |
| T2 | `bin/lib/docs.sh` (C1) | `test_docs_lib.sh`: each C1 state, with and without a trailing period; a bad state; a missing Decider; "Matthew Van Dusen." and "J. Smith." on a fixture `GOVERNANCE.md`; markers bare, in a code span, in a fence | AC2–AC7 |
| T3 | `tests/lib/fixture.sh`: a minimal valid repository in a temp dir; mutations that change nothing fail | `test_fixture.sh`: every file C1–C4 need; a no-op mutation is reported | AC43 |
| T4 | `bin/check` dispatcher: C4 modes and bases, `--list`, exit codes | `test_check_cli.sh`: 0/1/2 cases, unknown check, outside a repo, empty and all-zero `BASE` with and without a remote ref, merge-base selection | AC38 |
| T5 | `layout` and `bin/lib/layout.txt` (entries for `README.md`, `LICENSE`) | `test_check_layout.sh`: missing file, missing heading, missing line, blob mismatch | AC39 |
| T6 | `GOVERNANCE.md` | its `layout` entries (headings, § Deciders) | AC40 |
| T7 | `CONTRIBUTING.md`: every section of AC40, § Agent guards listing each hook rule and deny entry; unbuilt enforcers marked "not enforced" | its `layout` entries | AC1, AC24, AC40 |
| T8 | `bin/lib/rules.sh`, `claims` | `test_check_claims.sh`: the AC13 pair; ADR, `docs/work/`, `CHANGELOG.md` lines ignored; an agent-file line and a `.github/` template line checked | AC13 |
| T9 | `docs`, `docs --report` | `test_check_docs.sh`: every AC2–AC7 case, incl. plan with no spec, edited accepted ADR, ADR rename, duplicate ADR number, supersede to a missing or proposed ADR, decided state entering with an unlisted decider, unchanged inherited ADR with an unlisted decider (pass), deleted work folder (pass), RFC `0000-` with `PR_NUMBER`, RFC bad status; exact report lines | AC2–AC7 |
| T10 | `bin/lib/classify.sh`, `commits`, `commit-msg` mode | `test_check_commits.sh`: every AC8 and AC9 case as real commits (root, amended root, two-parent, amended merge, `git revert`) and as message files (comment lines, scissors line) | AC8, AC9 |
| T11 | `pr` mode | `test_check_pr.sh`: AC8/AC9 titles; body with tool credit; body with a person's `Co-authored-by:` | AC28 |
| T12 | `never-publish`, `.githooks/never-publish`, `.gitignore` | `test_check_never_publish.sh`: staged and pushed `.scuba/x`, missing list, comment-only list, deletion passes, every entry in `.gitignore` | AC32 |
| T13 | `secrets` | `test_check_secrets.sh`: each pattern family built at runtime, added since a merge base and in the index; a clean diff passes | AC33 |
| T14 | `scripts` | `test_check_scripts.sh`: mode `100644` script, syntax error, sourced lib not mode-checked, `never-publish` ignored, invalid `settings.json`, missing hook script; `shellcheck` cases skipped with a notice when absent, exit 2 when absent with `REQUIRE_SHELLCHECK=1` | AC15, AC37 |
| T15 | `workflows` | `test_check_workflows.sh`: tag ref, SHA without comment, no top-level permissions, `pull_request_target`; `permissions: {}` and `./` actions pass | AC30 |
| T16 | `.githooks/commit-msg`, `.githooks/pre-commit` | `test_githooks.sh`: bad subject refused; revert and reapply message files, `git merge`, root and amended root `Initial commit` pass; staged `.scuba/x` refused | AC9, AC31 |
| T17 | `.githooks/pre-push` | `test_githooks.sh`: fixup refused; new ref uses its merge base; ref deletion skipped; edited accepted ADR refused on a new branch | AC31 |
| T18 | `bin/setup` | `test_setup.sh`: `core.hooksPath` set; second run changes nothing | AC34 |
| T19 | `trace` | `test_check_trace.sh`: every AC12 case | AC12 |
| T20 | `.claude/hooks/guard-bash.sh` | `test_claude_hooks.sh`: every AC17 refusal and pass as JSON in `tests/fixtures/hooks/`; `jq` hidden; forced abort; both bashes | AC16, AC17 |
| T21 | `.claude/hooks/guard-docs.sh` | ADR body edit; status-line change on a draft spec; `**Decider:**` change in a `MultiEdit`'s second edit; `Write` creating an accepted doc (each exits 2); body edit of a draft spec with `&`, `"`, `\` and a newline, and a non-doc edit (each exits 0) | AC16, AC18 |
| T22 | `.claude/hooks/session-start.sh` | prints the report for an in-flight fixture folder; nothing otherwise; exits 0 when `bin/check` fails | AC19 |
| T23 | `.claude/settings.json` | its `layout` entries; `scripts` and `trace` pass | AC15 |
| T24 | `docs/templates/*`, `bin/new` | `test_new.sh`: every AC35 command; Decider from a fixture § Deciders; refusal with none listed, on a missing or marked predecessor, existing target, bad slug; template length and prompts | AC35 |
| T25 | ADRs 0001–0005, `docs/rfcs/README.md` | their `layout` entries (four sections each); `docs` passes; they link this folder only by absolute URL | AC6, AC7 |
| T26 | Issue forms, `config.yml` | their `layout` entries (`required: true`, labels, `blank_issues_enabled: false`, absolute contact links) | AC22 |
| T27 | `pull_request_template.md` | its `layout` entries: `## Summary` and upstream blob `c349e2c7…` | AC23 |
| T28 | `CODEOWNERS`, `labels.yml`, `workflows/labels.yml` | their `layout` entries (the six labels, the owner line); `workflows` passes | AC24, AC25 |
| T29 | `dependabot.yml` | its `layout` entries; `test_check_pr.sh` already passes the longest Dependabot title | AC26 |
| T30 | `workflows/ci.yml`: Ubuntu leg installs `shellcheck-v0.11.0.linux.x86_64.tar.xz`, sha256 `8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198` | its `layout` entries (job names, `fetch-depth: 0`, `REQUIRE_SHELLCHECK`); `workflows` passes | AC27 |
| T31 | `workflows/pr.yml` | its `layout` entries (`pr-text`); `workflows` passes | AC28 |
| T32 | `workflows/scorecard.yml`, pins re-resolved with `gh api` | its `layout` entries (the private condition); `workflows` passes | AC29 |
| T33 | `SECURITY.md`, `CODE_OF_CONDUCT.md` | their `layout` entries; `claims` passes | AC41 |
| T34 | `README.md` rewrite, `CHANGELOG.md` | their `layout` entries (opening line, `template-only` markers, `## [Unreleased]`); `claims` passes | AC41 |
| T35 | `AGENTS.md` | its `layout` entries (three gates); `trace` and `claims` pass | AC1, AC11 |
| T36 | `agents`, `CLAUDE.md` | `test_check_agents.sh`: `CLAUDE.md` with extra content, 101-line `AGENTS.md`, unquoted glob, CSV `paths`, unknown key, skill name ≠ directory, 1,025-character description, subagent with an unknown key | AC10, AC14, AC20, AC21 |
| T37 | `.claude/rules/*.md` | their `layout` entries; `agents`, `trace`, `claims` pass | AC14 |
| T38 | Skills `new-work`, `new-rfc`, `new-adr` | their `layout` entries; `agents`, `trace`, `claims` pass | AC20 |
| T39 | `.claude/agents/reviewer.md` | its `layout` entries; `agents`, `trace`, `claims` pass | AC21 |
| T40 | `bin/init` | `test_init.sh` on a fixture repository: bad name, dirty tree, `config.yml` rewrite with and without `origin`, no other file rewritten, ADRs kept, § Deciders placeholder, blocks stripped, deletions staged, nothing committed, itself gone; after a commit, `bin/check --range <root> HEAD` passes | AC36 |
| T41 | `tests/generation.sh`; its step in `ci.yml` | the script itself, run before `ci.yml` calls it: every AC42 build step, both ADR states; after `bin/init`, every relative Markdown link resolves; email allowlist | AC41, AC42 |

## Gate steps before the build PR is ready (no commits)

Each records the SHA it ran on and is rerun when the head moves.

- **G1** On the installed Claude Code: `.claude/settings.json` loads with `onFailure` present, and each hook fires under `claude -p` on one refused and one allowed call. If `onFailure` is rejected rather than ignored, drop it and say so in the PR.
- **G2** A person runs `/memory` and confirms each rule loads only for its paths.
- **G3** The reviewer subagent's dry run on the build PR, output pasted into the PR.
- **G4** Simulated generation (AC42): two throwaway repositories, public and private; root commit `Initial commit` pushed as `main`; run conclusions and URLs in the PR; repositories deleted. Creating and deleting them needs the chief of staff's go-ahead.

## ADRs the build creates (T25, all `proposed`)

| ADR | Decision |
|---|---|
| 0001 | Record decisions as ADRs; once decided, only the status line changes; a reversal is a new ADR |
| 0002 | `AGENTS.md` is the single agent file; `CLAUDE.md` is `@AGENTS.md` |
| 0003 | A capability goes through intent, spec and plan in a work folder, each decided by a named person |
| 0004 | Agent files only link to, summarize or operationalize human docs in this repository; `trace` checks it |
| 0005 | Subjects git or GitHub writes pass one classifier; tool credit, not human co-authorship, is banned |

They stay in generated repositories as inherited decisions (`decisions.md` #17). They cite this folder by absolute URL to the template, because `bin/init` deletes it.

## Risks

- **R1, most likely to need rework: the wording-based checks (`claims`, `trace`).** `claims` now reads every tracked Markdown file but the records, so false positives will push authors to reword. If T7–T39 need more than one round of tuning, narrow the word list rather than add exceptions; there is no escape hatch.
- **R2 Claude Code drift.** Hooks are tested against the documented input on the installed version. A format change on a later release makes them fail closed and block every tool call they guard until fixed. Re-verification on the current release is a launch item.
- **R3 All-skipped run conclusion** (Scorecard on a private repository) is undocumented. G4 observes it; `decisions.md` #32 counts `skipped` as not failed. If it concludes otherwise, add a separate always-running job that prints why analysis was skipped.
- **R4 Number races.** Two open PRs can take the same work-folder or ADR number; the second to merge turns `main` red. Mitigation: require branches to be up to date; renumber.
- **R5 Secret patterns matching the template's own text.** T41 scans the whole root commit; reword, don't exempt.
- **R6 Upstream PR template drift.** `layout` pins upstream's blob; an upstream change needs a matching change here.

## Rollout (the decider's steps; listed, not executed)

1. Accept or amend this spec and plan; decide ADRs 0001–0005.
2. Set the code of conduct contact; create the `maintainers` team with write access.
3. Post `Ack at <head SHA>` on the build PR. The chief of staff, or whoever merges, merges with a merge commit, keeping one task per commit, and quotes the ack in its body.
4. Mark `oss-template` as a template repository; run the labels workflow (`gh workflow run labels.yml`).
5. Repository and organization settings: allow only squash and merge commits (rebase merging off); turn off "Allow GitHub Actions to create and approve pull requests" and any setting that lets agent or app approvals count toward merge requirements; ruleset on the default branch requiring a pull request, checks `check (ubuntu-latest)`, `check (macos-latest)`, `pr-text`, and blocking force push and deletion; a required review only where two or more deciders are listed.
6. Turn on private vulnerability reporting for new public repositories.
7. Write the M3 rubric; re-verify the hooks on the current Claude Code release; run M1 on a real generation of each visibility and M3 (AC42, AC44). Launch after both pass.
8. After launch: M5 key written before the reader starts; M6 and M7 counts scheduled.

**Upstream follow-ups** (issues in `ai-native-sdlc`, not done here): the `## Summary` section; the generated-subject exemption; tool credit versus human `Co-authored-by:`; approval as an `Ack at <SHA>` comment rather than the merge; the `CLAUDE.md` import shim for Claude Code before 2.1.277; issue forms; dropping the imperative-mood check; deciders listed in `GOVERNANCE.md` and named in a status line, replacing `DECIDERS.md` and `decided_by:`; the denylist in `guard-bash.sh`; SHA-pinned actions; the caveats on the Kubernetes template figure (research source 1).
