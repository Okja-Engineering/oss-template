# 0001 oss-template: plan

**Status:** draft. **Decider:** Matthew Van Dusen. **Rests on:** [`spec.md`](spec.md).

## Approach

One builder, serially, on `feat/initial-template`. One task is one commit, in the order below. Each task starts with the test named in its row, seen failing, then the change that makes it pass. **Every commit is green**: before committing, the builder runs `CI=true bin/check` and `tests/run-all.sh` (once they exist) under macOS `/bin/bash` 3.2, and both pass. The order makes that possible: a check lands only after the files it judges exist, or in the same commit; a human doc that names a script lands after the script.

Commits are conventional, carry no `Co-Authored-By` or tool credit, and neither does the build PR body (upstream `AGENTS.md` § Commits).

How this fits what exists:

- **The repository today** holds `README.md`, `LICENSE`, and this folder. `README.md` is rewritten (T32); `LICENSE`, `intent.md` and `research.md` are untouched. The intent's status line already conforms to C1, and `GOVERNANCE.md` (T16) lands before the `docs` check (T17) that reads its § Deciders.
- **Taken from upstream where sound:** `tests/run-all.sh` with its tracked-suite cross-check, `tests/lib/assert.sh`, the throwaway-repository-and-bare-remote hook tests, the fail-closed `never-publish` list, the built-in secret patterns, the runner self-test, read-only workflow permissions.
- **Upstream defects fixed at the root:** upstream had three copies of the subject regex that disagreed on merges, and all three refuse `Revert "…"`; here one classifier serves every enforcement point. Also: tool-credit matching narrowed, imperative check dropped, actions pinned by SHA.
- **One parser per format.** Subjects: `bin/lib/classify.sh`. Status lines: `bin/lib/docs.sh`, used by `bin/check`, `bin/new` and `guard-docs.sh`. Frontmatter: inside `bin/check`'s `agents` check. Git hooks and CI call `bin/check`; they hold no rules of their own. Claude Code hooks hold their own command patterns (`guard-bash.sh`), which no other component needs.

**Before T9** the builder needs `shellcheck` installed locally (`brew install shellcheck`; not a repository dependency). Installing it is a change to the machine, so it needs the chief of staff's go-ahead.

## File tree

```
AGENTS.md  CLAUDE.md  README.md  CONTRIBUTING.md  GOVERNANCE.md  SECURITY.md
CODE_OF_CONDUCT.md  CHANGELOG.md  LICENSE  .gitignore
.claude/settings.json
.claude/hooks/{guard-bash,guard-docs,session-start}.sh
.claude/rules/{docs,workflows,scripts}.md
.claude/skills/{new-work,new-rfc,new-adr}/SKILL.md
.claude/agents/reviewer.md
.githooks/{commit-msg,pre-commit,pre-push,never-publish}
.github/{CODEOWNERS,labels.yml,dependabot.yml,pull_request_template.md}
.github/ISSUE_TEMPLATE/{bug,change,tracking,config}.yml
.github/workflows/{ci,pr,labels,scorecard}.yml
bin/{check,setup,new,init}  bin/lib/{docs,classify}.sh
docs/adr/{0001..0005}-*.md  docs/rfcs/README.md  docs/templates/{intent,spec,plan,rfc,adr}.md
docs/work/0001-oss-template/{research,intent,spec,plan}.md
tests/run-all.sh  tests/lib/{assert,fixture}.sh  tests/fixtures/{runner,hooks}/**
tests/test_*.sh   (one per row below that names one)
```

## Tasks

| # | Task (one commit) | Test written first | ACs |
|---|---|---|---|
| T1 | `tests/run-all.sh`, `tests/lib/assert.sh`, runner fixtures | `test_run_all.sh`: fails on the failing fixture and on a tracked suite missing from the tree; passes on the passing one | AC27, AC43 |
| T2 | `bin/lib/docs.sh` (C1) | `test_docs_lib.sh`: each C1 state, a bad state, the accepted intent's line; deciders "Matthew Van Dusen." and "J. Smith."; markers bare, in a code span, in a fence | AC2, AC5–AC7 |
| T3 | `tests/lib/fixture.sh`: minimal valid repository in a temp dir; mutations that change nothing fail the suite | `test_fixture.sh`: the fixture has every file C1–C4 need; a no-op mutation is reported | AC43 |
| T4 | `bin/check` dispatcher: C4 modes, `--skip`, `--list`, exit codes, range resolution | `test_check_cli.sh`: 0/1/2 cases, unknown check, outside a repo, empty and all-zero `BASE` | AC38 |
| T5 | `bin/lib/classify.sh`; `commits`; `commit-msg` mode (comment lines and scissors stripped; UTF-8 locale pinned) | `test_check_commits.sh`: every AC8 and AC9 case as real commits (root, amended root, two-parent, amended merge, `git revert`, `Reapply` via `git commit -m`) | AC8, AC9 |
| T6 | `pr` mode | `test_check_pr.sh`: titles from AC8/AC9; body with tool credit; body with a person's `Co-authored-by:` | AC28 |
| T7 | `never-publish`, `.githooks/never-publish`, `.gitignore` | `test_check_never_publish.sh`: staged `.scuba/x`, pushed match, missing list, comment-only list, deletion passes, every entry in `.gitignore` | AC32 |
| T8 | `secrets` | `test_check_secrets.sh`: each pattern family, built at runtime, in a range and in the index; a clean diff passes | AC33 |
| T9 | `scripts` | `test_check_scripts.sh`: mode `100644` script, syntax error, `shellcheck` finding, sourced lib not mode-checked, `never-publish` ignored, invalid `settings.json`, missing hook script | AC15, AC37 |
| T10 | `workflows` | `test_check_workflows.sh`: tag ref, SHA without comment, no top-level permissions, `pull_request_target`; `permissions: {}` and `./` actions pass | AC30 |
| T11 | `.githooks/commit-msg`, `.githooks/pre-commit` | `test_githooks.sh`: bad subject refused; `git revert`, `git merge`, root `Initial commit`, amended root all commit; staged `.scuba/x` refused | AC9, AC31 |
| T12 | `.githooks/pre-push` | `test_githooks.sh`: fixup refused; new branch checks `--not --remotes`; ref deletion skipped; `docs` runs with no remote ref | AC31 |
| T13 | `bin/setup` | `test_setup.sh`: `core.hooksPath` set; versions and each tool's installed/missing printed; second run changes nothing | AC34 |
| T14 | `.claude/hooks/guard-bash.sh` | `test_claude_hooks.sh`: every AC17 refusal and pass as JSON in `tests/fixtures/hooks/`; `jq` hidden from `PATH` exits 2; garbage input exits 2 | AC16, AC17 |
| T15 | `.claude/hooks/guard-docs.sh` | ADR body edit (2); status-line-only supersede (0); `Write` moving a spec to `accepted` (2); `MultiEdit` whose second edit adds a `**Decider:**` (2); non-doc edit (0) | AC16, AC18 |
| T16 | `GOVERNANCE.md` | `test_docs_lib.sh`: decider lookup against the real file finds `Matthew Van Dusen` | AC40 |
| T17 | `docs` and `docs --report` | `test_check_docs.sh`: AC2–AC7 cases, incl. plan with no spec, edited accepted ADR, ADR rename, duplicate ADR number, dangling `superseded by`, RFC `0000-` with `PR_NUMBER`, RFC `accepted` without decider, RFC bad status; exact report lines | AC2–AC7 |
| T18 | `.claude/hooks/session-start.sh` | prints the report for an in-flight fixture folder; nothing otherwise; exits 0 when `bin/check` fails | AC19 |
| T19 | `.claude/settings.json` | `test_claude_hooks.sh` asserts permissions, matchers, `onFailure`; `scripts` passes | AC15 |
| T20 | `docs/templates/*`, `bin/new` | `test_new.sh`: every AC35 command; missing or marked predecessor, existing target, bad slug refused; template length, status line, prompts | AC35 |
| T21 | ADRs 0001–0005, `docs/rfcs/README.md` | `docs` passes; `test_new.sh` asserts each ADR has the four sections and is `proposed` | AC6, AC7 |
| T22 | Issue forms, `config.yml` | `test_github.sh`: keys, `required: true`, `blank_issues_enabled: false`, absolute `https` contact links | AC22 |
| T23 | `pull_request_template.md` | `test_github.sh`: file equals `## Summary` block + upstream text pinned in the test | AC23 |
| T24 | `CODEOWNERS`, `labels.yml`, `workflows/labels.yml` | exact label set; workflow has checkout, `contents: read`, `issues: write`, deletion on, no path filter | AC24, AC25 |
| T25 | `dependabot.yml` | prefix `chore`, no scope, no groups, label; `bin/check pr` passes the longest real title | AC26 |
| T26 | `workflows/ci.yml` | `test_github.sh`: `fetch-depth: 0`, `env:` values, range call, macOS `--skip scripts`, runner self-test; `workflows` passes | AC27 |
| T27 | `workflows/pr.yml` | event types; `bin/check pr` with `env:` title and body | AC28 |
| T28 | `workflows/scorecard.yml` (pins re-resolved with `gh api`) | private-repository condition; `workflows` passes | AC29 |
| T29 | `claims` | `test_check_claims.sh`: the AC13 pair; ADR and `docs/work/` out of scope; zero exceptions on the tree | AC13 |
| T30 | `CONTRIBUTING.md` | `claims` passes; `test_github.sh` asserts the § What is enforced rows equal `bin/check --list` | AC1, AC39 |
| T31 | `SECURITY.md`, `CODE_OF_CONDUCT.md` | `claims` passes; no email address | AC41 |
| T32 | `README.md` rewrite, `CHANGELOG.md` | `claims` passes; `template-only` markers balanced | AC41 |
| T33 | `trace` | `test_check_trace.sh`: rule file with no source, unresolved `source:`, unresolved anchor, unlinked "never" line; "never" in a code span passes | AC12 |
| T34 | `AGENTS.md` | `trace` passes; three gates present | AC1, AC11 |
| T35 | `agents`, `CLAUDE.md` | `test_check_agents.sh`: `CLAUDE.md` with extra content, 101-line `AGENTS.md`, unquoted glob, CSV `paths`, unknown key, skill name ≠ directory, 1,025-character description, subagent with an unknown key | AC10, AC14, AC20, AC21 |
| T36 | `.claude/rules/*.md` | `agents` and `trace` pass | AC14 |
| T37 | Skills `new-work`, `new-rfc`, `new-adr` | `agents` and `trace` pass | AC20 |
| T38 | `.claude/agents/reviewer.md` | `agents` and `trace` pass | AC21 |
| T39 | `bin/init` | `test_init.sh`: bad name, dirty tree, `config.yml` rewrite with and without `origin`, no other file rewritten, Deciders placeholder, blocks stripped, deletions staged, nothing committed, itself gone, `bin/check` passes after | AC36 |
| T40 | `tests/test_generation.sh` | root `Initial commit` from `git archive HEAD` passes `bin/check --range "" HEAD` and `tests/run-all.sh` (recursion guard); passes again after `bin/init demo`; email allowlist | AC41, AC42, AC43 |

## Gate steps before the build PR is ready (no commits)

- **G1** On the installed Claude Code (2.1.221): `.claude/settings.json` loads with `onFailure` present, and each hook fires under `claude -p` on one refused and one allowed call. Record the version. If `onFailure` is rejected rather than ignored, drop it and say so in the PR.
- **G2** A person runs `/memory` and confirms each rule loads only for its paths.
- **G3** The reviewer subagent's dry run on the build PR, output pasted into the PR.
- **G4** Simulated generation (AC42): two throwaway repositories, public and private; root commit `Initial commit` pushed as `main`; run conclusions and URLs in the PR; repositories deleted. Creating and deleting them needs the chief of staff's go-ahead.

## ADRs the build creates (T21, all `proposed`)

| ADR | Decision |
|---|---|
| 0001 | Record decisions as ADRs; once decided, only the status line changes; a reversal is a new ADR |
| 0002 | `AGENTS.md` is the single agent file; `CLAUDE.md` is `@AGENTS.md` |
| 0003 | A capability goes through intent, spec and plan in a work folder, each decided by a named person |
| 0004 | Agent files only link to, summarize or operationalize human docs; `trace` checks it |
| 0005 | Subjects git or GitHub writes pass one classifier; tool credit, not human co-authorship, is banned |

`bin/init` deletes them with this folder, so they may link here relatively; `CONTRIBUTING.md` links them by URL to the template.

## Risks

- **R1, most likely to need rework: the wording-based checks (`trace`, `claims`).** False positives push authors to reword. If T29–T34 need more than one round of tuning, narrow the vocabulary rather than add exceptions; there is no escape hatch.
- **R2 Claude Code drift.** Hooks are tested against the documented input on 2.1.221; current is 2.1.296 or later. A format change makes hooks fail closed, blocking every Bash call until fixed: loud by design. Re-verification is a launch item.
- **R3 All-skipped run conclusion** (Scorecard on a private repository) is undocumented. G4 observes it; if it is not `success` or `skipped`, add an always-running step that prints why analysis was skipped.
- **R4 Number races.** Two open PRs can take the same work-folder or ADR number; the second to merge turns `main` red. Mitigation: require branches to be up to date; renumber.
- **R5 Secret patterns matching the template's own text.** T40 scans the whole root commit; reword, don't exempt.
- **R6 Upstream PR template drift.** T23 pins upstream's text in the test; an upstream change needs a matching change here.

## Rollout (the decider's steps; listed, not executed)

1. Accept or amend this spec and plan; decide ADRs 0001–0005.
2. Set the code of conduct contact; create the `maintainers` team with write access.
3. Post `Ack at <head SHA>` on the build PR; merge with rebase or a merge commit to keep one task per commit, quoting the ack.
4. Mark `oss-template` as a template repository; run the labels workflow (`gh workflow run labels.yml`).
5. Organization or repository settings: turn off "Allow GitHub Actions to create and approve pull requests"; ruleset on the default branch requiring a pull request, checks `check (ubuntu-latest)`, `check (macos-latest)`, `pr-text`, and blocking force push and deletion; a required review only where two or more deciders are listed.
6. Turn on private vulnerability reporting for new public repositories.
7. Re-verify hooks on current Claude Code; then M1 on a real generation of each visibility and M3 (AC42, AC44). Launch after both pass.
8. After launch: M5 key written before the reader starts; M6 and M7 counts scheduled.

**Upstream follow-ups** (issues in `ai-native-sdlc`, not done here): the `## Summary` section; the generated-subject exemption; tool credit versus human `Co-authored-by:`; approval as an `Ack at <SHA>` comment rather than the merge; the `CLAUDE.md` import shim for Claude Code before 2.1.277; issue forms; dropping the imperative-mood check; deciders listed in `GOVERNANCE.md` and named in a status line; SHA-pinned actions; the caveats on the Kubernetes template figure (research source 1).
