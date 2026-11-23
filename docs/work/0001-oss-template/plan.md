# 0001 oss-template: plan

**Status:** draft. **Decider:** Matthew Van Dusen. **Rests on:** [`spec.md`](spec.md).

## Approach

Build the checks first, then the things they check. One task is one commit, and each task starts with the test that fails without it. Work runs as four packages with disjoint write sets (A–D) after one shared first task (A1), then a serial integration package (E). Packages branch from `feat/initial-template` after A1 lands and merge back into it; E runs on the merged branch, which becomes the build PR.

How this fits what already exists:

- **The repository today** holds `README.md`, `LICENSE` and this folder. `README.md` is rewritten (D5). `LICENSE` is untouched. `intent.md` and `research.md` are untouched; the intent's status line already conforms to contract C1.
- **Taken from upstream, where it is sound:** `tests/run-all.sh` (including its tracked-suite cross-check), `tests/lib/assert.sh`, the throwaway-repository-and-bare-remote pattern of `tests/test_hooks.sh`, the fail-closed `never-publish` list, the built-in secret patterns, "prove the suite can fail", `permissions: contents: read`.
- **Upstream defects fixed at the root, not patched:** one subject classifier used by every enforcement point (upstream had three copies of the regex that disagreed on merges, and all three refuse `Revert "…"`); attribution signatures narrowed; imperative check dropped; actions pinned by SHA.
- **Structure that keeps packages independent:** every rule lives in `bin/check`; git hooks and CI call it; Claude Code hooks share its status-line library (`bin/lib/docs.sh`). Nothing parses a status line, a subject, or frontmatter in a second place.

## File tree

```
AGENTS.md  CLAUDE.md                                   C
README.md  CONTRIBUTING.md  GOVERNANCE.md  SECURITY.md
CODE_OF_CONDUCT.md  CHANGELOG.md                       D
LICENSE                                                (unchanged)
.gitignore                                             A
.claude/settings.json                                  C
.claude/hooks/{guard-bash,guard-docs,session-start}.sh C
.claude/hooks/lib/input.sh                             C
.claude/rules/{docs,workflows,scripts}.md              C
.claude/skills/{new-work,new-rfc,new-adr}/SKILL.md     C
.claude/agents/reviewer.md                             C
.githooks/{commit-msg,pre-commit,pre-push,never-publish}  A
.github/{CODEOWNERS,labels.yml,dependabot.yml,pull_request_template.md}  B
.github/ISSUE_TEMPLATE/{bug,change,tracking,config}.yml                  B
.github/workflows/{ci,pr,labels,scorecard,codeql}.yml                    B
bin/check  bin/setup  bin/lib/**                       A
bin/new  bin/init                                      D
docs/adr/{0001..0005}-*.md                             D
docs/rfcs/README.md                                    D
docs/templates/{intent,spec,plan,rfc,adr}.md           D
docs/work/0001-oss-template/{research,intent,spec,plan}.md  (exists)
tests/run-all.sh  tests/lib/**  tests/fixtures/runner/**    A
tests/test_docs_lib.sh  tests/test_run_all.sh  tests/test_check_*.sh
tests/test_githooks.sh  tests/test_setup.sh                 A
tests/test_github.sh                                   B
tests/test_claude_hooks.sh  tests/fixtures/hooks/**    C
tests/test_new.sh  tests/test_init.sh                  D
tests/test_generation.sh                               E
```

## Shared contracts

Packages build against the spec's contracts, not against each other's code: **C1** status line and decider field; **C2** names and directories; **C3** frontmatter subset; **C4** `bin/check` interface and exit codes; **C5** heading anchors in human docs; **C6** hook input reader. Two more, stated here:

- **Check names** are exactly those in spec § 10. `CONTRIBUTING.md` § What is enforced (D) and `bin/check --list` (A) use the same names.
- **Fixtures.** `tests/lib/fixture.sh` (A1) builds a minimal valid repository in a temp directory (agent files, human docs with C5 headings, `GOVERNANCE.md` § Deciders, one work folder, `.githooks/never-publish`, a copy of `bin/`). Every check suite mutates one thing in it. A mutation that changes nothing fails the suite (upstream's `mutate.sh` lesson). Secret-shaped strings are assembled at runtime, never committed.

## Packages

### A1 — shared first task (serial, before everything)

Write set: `tests/run-all.sh`, `tests/lib/assert.sh`, `tests/lib/fixture.sh`, `tests/fixtures/runner/**`, `tests/test_run_all.sh`, `tests/test_docs_lib.sh`, `bin/lib/docs.sh`.

- **A1** Test harness and status-line library. *Tests first:* `test_run_all.sh` (runner exits non-zero on the failing fixture and on a missing tracked suite); `test_docs_lib.sh` (`doc_state` on the accepted intent, each C1 state, a bad state; `doc_decider` on "Matthew Van Dusen." and "J. Smith."; `doc_markers` counting a bare marker and ignoring one in a code span or fence). *Serves:* C1, AC5, AC65.

### Package A — `bin/check`, git hooks, setup

Write set: `bin/check`, `bin/setup`, `bin/lib/**`, `.githooks/**`, `.gitignore`, `tests/test_check_*.sh`, `tests/test_githooks.sh`, `tests/test_setup.sh`, `tests/lib/**`. Depends on: A1.

| Task | Test written first | ACs |
|---|---|---|
| A2 `bin/check` dispatcher: C4 modes, `--list`, exit codes 0/1/2, range resolution (empty or zero base = all of `HEAD`) | `test_check_cli.sh` | C4 |
| A3 Subject classifier (`bin/lib/classify.sh`); `commits`; `commit-msg` and `pr` modes | `test_check_commits.sh`, `test_check_pr.sh`: every subject in AC17–AC19 and both bodies in AC18, as real commits (root, two-parent, `git revert`, revert of a revert) | AC17–AC20, AC44 |
| A4 `work` and `work --report` | `test_check_work.sh`: plan with no spec; spec while intent has a marker; accepted doc with a marker; duplicate number; bad folder name; undeclared decider; report lines and empty report | AC4–AC8 |
| A5 `adr` and `rfc` | `test_check_adr.sh`: edited accepted ADR (fail), status-line-only supersede (pass), deletion, bad transition, dangling `superseded by`, root base; `test_check_rfc.sh`: `0000-` with `PR_NUMBER`, wrong number, right number | AC10, AC11, AC13–AC15 |
| A6 `agents`, `trace`, `claims` | `test_check_agents.sh`: `CLAUDE.md` with extra content, 101-line `AGENTS.md`, budget overflow, unquoted glob, CSV `paths`, unknown key, skill name ≠ directory; `test_check_trace.sh`: rule file with no source, unlinked "never" line, "never" in a code span (pass), agent-only line (counted); `test_check_claims.sh`: the AC26 pair | AC21, AC22, AC24–AC28, AC67 |
| A7 `links`, `workflows`, `scripts` | `test_check_links.sh`, `test_check_workflows.sh` (tag ref, SHA without version comment, no top-level permissions, `pull_request_target`), `test_check_scripts.sh` (mode `100644`, syntax error, settings naming a missing hook) | AC30, AC46, AC54 |
| A8 `secrets`, `never-publish`, `.githooks/never-publish`, `.gitignore` | `test_check_secrets.sh` (runtime-built key in range and in index), `test_check_never_publish.sh` (`.scuba/x` staged, missing list, comment-only list, deletion allowed) | AC48 |
| A9 `.githooks/{commit-msg,pre-commit,pre-push}`, `bin/setup` | `test_githooks.sh`: throwaway repo and bare remote; `git revert`, `git merge`, root `Initial commit` all pass the hooks; bad subject refused at commit; fixup pushed refused; `.scuba/` commit refused. `test_setup.sh`: run twice, same config | AC18, AC47, AC49 |

### Package B — `.github/`

Write set: `.github/**`, `tests/test_github.sh`. Depends on: A1 (assert library). Uses the C4 interface in workflows; A need not be merged to write them.

| Task | Test written first | ACs |
|---|---|---|
| B1 Issue forms and `config.yml` | `test_github.sh`: each form has `name`, `description`, `body`; validation method `required: true`; `blank_issues_enabled: false`; contact links | AC37 |
| B2 PR template and `CODEOWNERS` | headings and their order exactly as AC38; no "AI" heading; `CODEOWNERS` line | AC38, AC39 |
| B3 `labels.yml`, `workflows/labels.yml`, `dependabot.yml` | every label name matches `^[CASP]-`; the AC40 set; one color per prefix; labels workflow has no `paths:`; Dependabot prefix, scope, group, label | AC40–AC42 |
| B4 `workflows/ci.yml`, `workflows/pr.yml` | jobs, matrix, `bin/check --range`, runner self-test, `env:` for event values, `pr.yml` event types | AC43, AC44 |
| B5 `workflows/scorecard.yml`, `workflows/codeql.yml` | private-repository job condition; `languages: actions`; `bin/check workflows` passes on `.github/workflows/` once A7 is merged (skipped with a notice before) | AC45, AC46 |

B re-resolves every pin with `gh api` at build time (research § Action pins lists the 2026-11-22 values and the codeql `releases/latest` trap).

### Package C — `.claude/`, `AGENTS.md`, `CLAUDE.md`

Write set: `.claude/**`, `AGENTS.md`, `CLAUDE.md`, `tests/test_claude_hooks.sh`, `tests/fixtures/hooks/**`. Depends on: A1 (`bin/lib/docs.sh`, assert library); A4 for C4's `work --report` output; A6 to validate its files; D's headings (C5) for links to resolve. C writes against the contracts and goes green at integration where it can't sooner.

| Task | Test written first | ACs |
|---|---|---|
| C1 `.claude/hooks/lib/input.sh` | `test_claude_hooks.sh`: fields with escaped quotes, backslashes, `\n`, Unicode; pretty-printed input; missing field; garbage input exits 2 through a caller | C6, AC34 |
| C2 `guard-bash.sh` | every refusal and pass in AC32 as JSON samples in `tests/fixtures/hooks/`; current branch set in a temp repo | AC32 |
| C3 `guard-docs.sh` | edit body of accepted ADR (2); status-line-only edit (0); `Write` to accepted ADR (2); setting `accepted` on a draft spec (2); edit to a non-doc file (0) | AC31 |
| C4 `session-start.sh` | prints the report for an in-flight fixture folder; prints nothing when none; never exits 2 | AC33 |
| C5 `.claude/settings.json` | `bin/check scripts` passes; permissions and hook matchers as AC30 (asserted in `test_claude_hooks.sh`) | AC30 |
| C6 `AGENTS.md`, `CLAUDE.md` | `bin/check agents trace` fail on their absence, then pass | AC2, AC21–AC23 |
| C7 `.claude/rules/*.md` | `bin/check agents trace`; `/memory` check recorded in the PR by a person | AC25, AC28, AC29 |
| C8 Skills `new-work`, `new-rfc`, `new-adr` | `bin/check agents trace` | AC35 |
| C9 `.claude/agents/reviewer.md` | `bin/check agents trace`; one dry run against this PR's diff and spec, output pasted in the PR | AC36 |

### Package D — human docs, ADRs, templates, `bin/new`, `bin/init`

Write set: `README.md`, `CONTRIBUTING.md`, `GOVERNANCE.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md`, `docs/adr/**`, `docs/rfcs/**`, `docs/templates/**`, `bin/new`, `bin/init`, `tests/test_new.sh`, `tests/test_init.sh`. Depends on: A1 (`bin/lib/docs.sh`, assert library). Its enforcement claims name scripts from A and C; `claims` goes green at integration.

| Task | Test written first | ACs |
|---|---|---|
| D1 `docs/templates/*`, `bin/new` | `test_new.sh`: each AC50 command; refusal on a missing or marked predecessor, existing target, bad slug; template length, status line and prompts | AC50, AC51 |
| D2 `CONTRIBUTING.md` | `bin/check links claims` on the C5 anchors; the § 10 check names and not-enforced list present | AC1, AC3, AC9, AC12, AC20, AC56 |
| D3 `GOVERNANCE.md` | `test_docs_lib.sh`'s decider lookup against the real file | AC57 |
| D4 `SECURITY.md`, `CODE_OF_CONDUCT.md` | `bin/check links`; no `@` address | AC58, AC59 |
| D5 `README.md` rewrite, `CHANGELOG.md` | `bin/check links`; template-only markers balanced | AC55, AC60 |
| D6 ADRs 0001–0005, `docs/rfcs/README.md` | `bin/check adr`; each `proposed`; no relative link into `docs/work/0001-oss-template/` and no `Okja-Engineering/oss-template` slug (both are removed or rewritten by `bin/init`; ADRs cite the template by absolute URL instead) | AC14, AC16 |
| D7 `bin/init` | `test_init.sh`: bad name, dirty tree, slug rewrite with and without an `origin` remote, blocks stripped, deletions staged, nothing committed, itself gone | AC52 |

### Package E — integration (serial, after A–D merge)

Write set: `tests/test_generation.sh`, plus any file for cross-package fixes (one fix per commit, in the owning package's terms).

| Task | Test written first | ACs |
|---|---|---|
| E1 `tests/test_generation.sh` | root commit from `git archive HEAD` passes `bin/check --range "" HEAD` and `tests/run-all.sh`; after `bin/init demo` both pass again; email allowlist | AC53, AC61, AC63 |
| E2 Whole tree green | `bin/check` and `tests/run-all.sh` on bash 3.2 (`/bin/bash` on macOS) and bash 5; `trace` and `claims` at zero exceptions; hooks smoke-tested once under `claude -p` on the installed version | AC65, AC67 |
| E3 Simulated generation | two throwaway repositories (public, private), root commit `Initial commit` pushed as `main`; run conclusions and URLs recorded in the build PR; repositories deleted. Creating and deleting them needs the chief of staff's go-ahead | AC62 |

## ADRs the build creates

All `proposed`; written in D6. They cite this folder by absolute URL to the template repository.

| ADR | Decision |
|---|---|
| 0001 | Record decisions as ADRs; once decided, only the status line changes; reversal is a new ADR that supersedes |
| 0002 | `AGENTS.md` is the single agent file; `CLAUDE.md` is `@AGENTS.md` |
| 0003 | A capability goes through intent, spec and plan in a work folder, each decided by a named person |
| 0004 | Agent files only link to, summarize or operationalize human docs; `bin/check trace` checks it |
| 0005 | Subjects that git or GitHub writes are exempt from the commit format; one classifier everywhere (diverges from upstream) |

## Risks

- **R1, most likely to need rework: the wording-based checks (`trace`, `claims`).** False positives will push authors to reword or reach for `agent-only`. E2 tunes the vocabulary against the real docs; if it needs more than one round, narrow the vocabulary rather than add exceptions.
- **R2 Claude Code drift.** Hooks are tested against the documented input shape on 2.1.221; a format change makes them fail closed, which blocks every Bash call until fixed. Loud, not silent, by design. `paths:` behaviour is checked by a person with `/memory` after upgrades.
- **R3 Run conclusion when every job is skipped** (Scorecard and CodeQL on a private repository) is not documented. E3 observes it. If it is anything but `success` or `skipped`, add a one-step job to each that always runs and prints why analysis was skipped.
- **R4 Review rule versus a single decider.** GitHub does not let a person approve their own PR. If the decider authors PRs (directly or through an agent on their account), a ruleset requiring an approving review blocks every merge. The ruleset's review requirement is a rollout decision.
- **R5 Number races.** Two open PRs can take the same work-folder or ADR number; the second to merge turns `main` red. Mitigation: ruleset "require branches to be up to date"; renumber on conflict.
- **R6 Secret patterns matching the template's own text.** E1 scans the whole root commit; reword, don't exempt.
- **R7 macOS minutes** on private generated repositories (D19).
- **R8 Pins go stale.** Dependabot proposes updates as `chore(deps)` PRs, which pass the classifier.

## Rollout

The decider's steps, listed and not executed here:

1. Accept or amend this spec and plan, and decide ADRs 0001–0005.
2. Set the code of conduct reporting contact; create the `maintainers` team with write access (spec § Reserved for the decider).
3. Merge the build PR with rebase or a merge commit, keeping one task per commit (a squash also passes the checks).
4. Mark `oss-template` as a template repository.
5. Run the labels workflow on the template (`gh workflow run labels.yml`); it also runs on the merge push.
6. Organization ruleset for template-generated repositories (by name pattern or custom property): pull request required; required checks `check (ubuntu-latest)`, `check (macos-latest)`, `pr-text`; force push and deletion blocked on the default branch; review requirement per R4.
7. Organization setting: private vulnerability reporting on for new public repositories.
8. Generate one public and one private repository with "Use this template" and record M1 (AC64).
9. Build the M3 kit and run it (AC66). Launch after both pass.
10. After launch: write the M5 answer key before the reader starts, and schedule the M6 and M7 counts (AC68–AC70).

Upstream follow-ups, to raise as issues in `ai-native-sdlc` and not done here: the Summary line in the PR template; the generated-subject exemption (ADR-0005); SHA-pinned actions; narrower attribution signatures; the caveats on the Kubernetes template figure (research source 1).
