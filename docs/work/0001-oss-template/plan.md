# 0001 oss-template: plan

**Status:** draft. **Decider:** Matthew Van Dusen. **Rests on:** [`spec.md`](spec.md), [`decisions.md`](decisions.md).

## Approach

**Sliced delivery** (ruling 16, call 67). Ten slices, S1–S10, each a pull request into `feat/initial-template`, ship-gated and merged in order with a merge commit; then the gate steps (S11) and one pull request into `main`, merged with a merge commit after the decider's ack at its head. Each slice is shippable alone, so the decider may instead take them into `main` one by one; nothing below changes.

**Pipeline first, content second.** S1–S4 build the workflow end to end on a small foundation. S5–S10 fill the foundation, and from S3 on every commit is exercised end to end: `foundation` re-renders the workspace (AC16) and `tests/test_verify.sh` renders both fixture answers and runs each produced repository's own `bin/check` and suites (AC27). A foundation file that breaks a produced repository fails the commit that adds it. Measure 2 (AC28) is served by every row's planted and passing cases; measure 3 (AC29) is a launch step under Rollout.

**Every commit is green** (decision 43): `bin/check` and `tests/run-all.sh` pass with `PATH=/usr/bin:/bin:/usr/sbin:/sbin` and with the normal `PATH` and `REQUIRE_SHELLCHECK=1`. One task is one commit; its named test is written first and seen failing. Commits are conventional and carry no tool credit; neither do pull request bodies. The spec and plan stay `draft` until the decider acts on the pull request into `main` (decision 19).

**Carried from the template plan.** "TT n" is task n of `git show b368d09:docs/work/0001-oss-template/plan.md`, carried with its first test, amended as each row says. Its ordering rules hold: human text states a rule before its enforcer exists and says "not enforced" until then; a task adding a required file adds its `bin/lib/layout.txt` entries first. New rules: a new tracked file is classified in `shared/manifest.txt` in the commit that adds it; a templated file lands as `foundation/PATH.tmpl` together with its rendered root copy.

**Refactors authorized** (so no task bolts on):
- TT4's dispatcher becomes discovery over `bin/checks/` (AC18). Every check task (TT5, TT8–TT15, TT19, TT36) adds a file there, never a branch in `bin/check`.
- Every check reads files through `bin/lib/tree.sh` (AC19); TT9, TT12, TT13 and TT17 judge git objects, not the checkout. `bin/render` uses the same reader.
- `trace`'s link resolution moves into `bin/lib/links.sh`, shared with `links` (AC23).
- TT40, TT41 and every `template-only` step are gone. TT6, TT7, TT26, TT28, TT33, TT34 and TT35 write templates where AC17 lists them.

**Before S1:** `shellcheck` and `jq` installed locally (installing changes the machine: the chief of staff's go-ahead). Nothing before S11 needs the network; `gh` is stubbed in tests.

## Slices

### S1 Skeleton and check harness (8 commits)

| # | Commit | Test written first | ACs |
|---|---|---|---|
| 1.1 | TT1, plus `tests/lib/bashes.sh` | TT1's; `bashes.sh` runs a probe under each bash present, skipping a missing one with a notice | TAC43, AC24 |
| 1.2 | `bin/lib/tree.sh`: list paths, read blobs and modes from the working tree, the index or a commit | `test_tree_lib.sh`: an uncommitted edit, a staged-only file, an executable bit, per source | AC19 |
| 1.3 | TT4 as discovery: `bin/check` over `bin/checks/`, modes, bases, `--list`, exit codes | `test_check_cli.sh`: AC18's fixture checks; AC20's bases; an uncommitted edit ignored in range mode | TAC38, AC18–AC20 |
| 1.4 | TT18 `bin/setup` | TT18's | TAC34 |
| 1.5 | `bin/checks/agents` (exact `CLAUDE.md`, 80-line `AGENTS.md`); `CLAUDE.md`; a short `AGENTS.md` routing to `CONTEXT.md` | `test_check_agents.sh`: extra content in `CLAUDE.md`; an 81-line `AGENTS.md` | TAC10, AC1 |
| 1.6 | `CONTEXT.md`; `stages/0{1..4}-*/` with prose contracts, `references/`, `output/.gitignore` | read against AC2, AC3 (the check follows) | § 2 |
| 1.7 | `bin/checks/stages` | `test_check_stages.sh`: each AC2 and AC3 case; the real tree passes | AC2, AC3 |
| 1.8 | `.github/workflows/ci.yml`, minimal: `check` on Ubuntu and macOS, head SHA, `fetch-depth: 0`, `bin/check --range`, `tests/run-all.sh`, SHA-pinned actions | PR 1's own CI | AC19 |

**Done when** PR 1's CI passes on both legs and `bin/check --list` shows `agents` and `stages`. **Write set:** `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`, `stages/**`, `bin/{check,setup}`, `bin/lib/tree.sh`, `bin/checks/{agents,stages}`, `tests/{run-all.sh,lib/assert.sh,lib/bashes.sh,fixtures/runner/**,test_*.sh}`, `.github/workflows/ci.yml`.

### S2 Answers and render (7 commits)

| # | Commit | Test written first | ACs |
|---|---|---|---|
| 2.1 | `shared/answers.tsv`, `bin/lib/answers.sh` | `test_answers.sh`: parse; pattern refusals; `=`, `&`, `\`, non-ASCII kept; `$(touch x)` creates nothing | AC5 |
| 2.2 | `bin/ask`, `setup/questionnaire.md`, `setup/answers.env` | `test_ask.sh`: every AC6 case | AC6 |
| 2.3 | `shared/manifest.txt`, `bin/checks/foundation` (classification, sources, templates) | `test_check_foundation.sh`: every AC15 case; the real tree passes | AC15 |
| 2.4 | `bin/render`: substitution, list lines, refusals, `--replace`, `render.md`, fingerprint | `test_render.sh`: every AC7 refusal; fingerprint equals `git write-tree` of the target; no `.git` made | AC7 |
| 2.5 | `tests/answers/{public,private}.env`; purity and field-effect cases | `test_render.sh`: AC8's variations; AC9 for every field | AC8, AC9 |
| 2.6 | `foundation/{AGENTS,README}.md.tmpl`, `setup/self.env`; root `AGENTS.md` and `README.md` become their renders; `foundation` gains self-render | `test_check_foundation.sh`: planted drift in a fixture workspace | AC16, AC17 |
| 2.7 | Contracts 01 and 02 name the real commands | `stages` | § 2 |

**Done when** `bin/ask run demo …` then `bin/render demo` give the same fingerprint twice, and self-render passes on both legs. **Write set:** `setup/**`, `shared/**`, `foundation/**`, `bin/{ask,render}`, `bin/lib/answers.sh`, `bin/checks/foundation`, `tests/{answers/**,test_answers.sh,test_ask.sh,test_render.sh,test_check_foundation.sh}`, `AGENTS.md`, `README.md`, `stages/0{1,2}-*/CONTEXT.md`.

### S3 Verify (4 commits)

| # | Commit | Test written first | ACs |
|---|---|---|---|
| 3.1 | `bin/verify` | `test_verify.sh` on a fixture workspace: render then verify passes; an edit after render refused; a planted failing check recorded; a rerun adds no commit | AC10 |
| 3.2 | The email audit in `bin/verify` | a planted address refused; each allowed form passes | AC11 |
| 3.3 | `test_verify.sh` renders and verifies both fixture answers against the workspace itself | seen failing on a planted product defect | AC27 |
| 3.4 | Contract 03 final | `stages` | § 2 |

**Done when** both fixture renders verify on both legs. **Write set:** `bin/verify`, `tests/test_verify.sh`, `tests/fixtures/workspace/**`, `stages/03-verify/CONTEXT.md`.

### S4 Publish, against a stub (4 commits)

| # | Commit | Test written first | ACs |
|---|---|---|---|
| 4.1 | `bin/publish --plan` | `test_publish.sh` (stub `gh`, fixture remote): unverified run, moved `HEAD`, unmerged workspace SHA refused; the exact line | AC12 |
| 4.2 | `--apply` | a changed plan; a failure injected after each step, then a rerun that repeats nothing; an occupied repository; no forced push | AC13 |
| 4.3 | `--watch` | one case per conclusion, all skipped, no runs, no `check` success | AC14 |
| 4.4 | Contract 04 final; `CONTEXT.md` routing complete | `stages` | § 2 |

**Done when** the stubbed suite passes on both legs. The live run is G4, once, on the complete foundation (ruling 13 covers one pair of throwaway repositories). **Write set:** `bin/publish`, `tests/test_publish.sh`, `tests/fixtures/gh/**`, `stages/04-publish/CONTEXT.md`, `CONTEXT.md`.

### S5–S10 Foundation content (37 commits)

Each row is the TT task named, with its test written first as there, plus the amendment the row adds.

| # | Commit (TT task, amended) | ACs |
|---|---|---|
| 5.1 | TT2 `bin/lib/docs.sh` | TAC2–TAC7 |
| 5.2 | TT3 `tests/lib/fixture.sh` | TAC43 |
| 5.3 | TT5 `layout`, with the `blob@N:` pin form | TAC39, AC25 |
| 5.4 | TT6 `GOVERNANCE.md` as a template (§ Deciders from `DECIDERS`) | TAC40, AC17 |
| 5.5 | TT7 `CONTRIBUTING.md`; the `docs/adr/README.md` template, which § ADRs links | TAC1, TAC40, AC26 |
| 5.6 | TT8 `bin/lib/rules.sh`, `claims`; the test adds a `CONTEXT.md` line and a contract line | TAC13, AC4 |
| 5.7 | TT9 `docs`; the test adds a decider added and used in one range (refused) and an RFC merged to `main` after branching (passes) | TAC2–TAC7, AC19, AC21 |
| 5.8 | TT25 ADRs 0001–0005 as workspace files; `docs/rfcs/README.md` | AC26 |
| 6.1 | TT10 `bin/lib/classify.sh`, `commits`, `commit-msg` mode | TAC8, TAC9 |
| 6.2 | TT11 `pr` mode | TAC28 |
| 6.3 | TT24 `docs/templates/*`, `bin/new`; a produced repository's first ADR is 0001 | TAC35, AC26 |
| 7.1 | TT12 `never-publish`, `.githooks/never-publish`, `.gitignore` | TAC32 |
| 7.2 | TT13 `secrets`, reading added lines through `tree.sh` | TAC33, AC19 |
| 7.3 | TT14 `scripts` | TAC15, TAC37 |
| 7.4 | TT16 `.githooks/commit-msg`, `pre-commit` | TAC9, TAC31 |
| 7.5 | TT17 `pre-push`; the test adds an uncommitted edit that must not change a pushed ref's verdict | TAC31, AC19 |
| 8.1 | `bin/lib/links.sh`, `links` | AC23 |
| 8.2 | TT19 `trace`, resolving through `links.sh` | TAC12 |
| 8.3 | TT20 `guard-bash.sh`, under each bash present | TAC16, TAC17, AC24 |
| 8.4 | TT21 `guard-docs.sh`; the test adds an edit inside § Deciders (refused) and `replace_all` on `# 0007 draft-handling` | TAC18, AC21, AC22 |
| 8.5 | TT22 `session-start.sh` | TAC19 |
| 8.6 | TT23 `.claude/settings.json` | TAC15 |
| 9.1 | TT36, the rest of `agents`: frontmatter, skills, subagent | TAC14, TAC20, TAC21 |
| 9.2 | TT37 `.claude/rules/*.md` | TAC14 |
| 9.3 | TT38 skills `new-work`, `new-rfc`, `new-adr` | TAC20 |
| 9.4 | TT39 `.claude/agents/reviewer.md` | TAC21 |
| 9.5 | TT33 `SECURITY.md`; `CODE_OF_CONDUCT.md` as a template | TAC41, AC17 |
| 9.6 | TT34 the `README.md` template in full; `CHANGELOG.md` | TAC41, AC17 |
| 9.7 | TT35 the `AGENTS.md` template in full: three gates within 80 lines | TAC11, AC1 |
| 10.1 | TT15 `workflows` | TAC30 |
| 10.2 | TT26 issue forms; `config.yml` as a template | TAC22, AC17 |
| 10.3 | TT27 `pull_request_template.md`, pinned from line 4 | TAC23, AC25 |
| 10.4 | TT28 `CODEOWNERS` as a template, `labels.yml`, `workflows/labels.yml` | TAC24, TAC25, AC17 |
| 10.5 | TT29 `dependabot.yml` | TAC26 |
| 10.6 | TT30 `ci.yml` in full: `shellcheck` pin, job names, head SHA, no generation step | TAC27, AC19 |
| 10.7 | TT31 `pr.yml` | TAC28 |
| 10.8 | TT32 `scorecard.yml`, pins re-resolved with `gh api` | TAC29 |

- **S5 Docs process** (5.1–5.8). Done when `docs`, `claims` and `layout` pass on the workspace and both fixture renders. Writes `bin/lib/{docs,rules}.sh`, `bin/lib/layout.txt`, `bin/checks/{layout,claims,docs}`, `tests/lib/fixture.sh`, `GOVERNANCE.md`, `CONTRIBUTING.md`, `docs/{adr,rfcs}/**`, their templates and suites.
- **S6 Commits and new documents** (6.1–6.3). Done when every commit since S1 passes `commits`. Writes `bin/lib/classify.sh`, `bin/checks/{commits,pr}`, `bin/new`, `docs/templates/**`, suites.
- **S7 Hygiene and git hooks** (7.1–7.5). Done when `bin/setup` in a fixture render installs hooks that refuse TT16's and TT17's cases. Writes `.githooks/**`, `.gitignore`, `bin/checks/{never-publish,secrets,scripts}`, suites.
- **S8 Agent guards** (8.1–8.6). Done when every hook test passes under both bashes on both legs. Writes `bin/lib/links.sh`, `bin/checks/{links,trace}`, `.claude/{hooks/**,settings.json}`, `tests/fixtures/hooks/**`, suites.
- **S9 Agent files and human docs** (9.1–9.7). Done when `trace`, `claims` and `agents` pass on the workspace and both renders. Writes `.claude/{rules,skills,agents}/**`, `bin/checks/agents`, `SECURITY.md`, `CHANGELOG.md`, three templates and their rendered root copies.
- **S10 GitHub files** (10.1–10.8). Done when every TAC the spec carries is met in both fixture renders. Writes `.github/**`, `foundation/.github/**`, `bin/checks/workflows`, its suite.

## S11 Gate steps on the final head (no commits unless one finds a defect)

Each records the SHA it ran on and reruns when the head moves; results go in the pull request into `main`.
- **G1–G3** as the template plan's: hooks fire under `claude -p` on the installed Claude Code; a person confirms with `/memory` that rules load only for their paths; the reviewer's dry run on the pull request into `main`.
- **G4** Measure 1 live (AC27): `bin/ask`, `bin/render`, `bin/verify` and `bin/publish` for both fixture answers into two throwaway repositories in `Okja-Engineering`; `--watch` passes; URLs and conclusions recorded; exactly those two deleted (ruling 13). A rerun after the head moves needs a fresh go-ahead.
- **G5** A fresh session given only the workspace and "create a repository called X" runs to the publish checkpoint and stops there: a smoke test of the contracts, not measure 3.

## Risks

- **R1, most likely to need rework: `--watch` against GitHub.** Only G4 exercises it live: first pushes, private repositories (Scorecard skipped), Dependabot runs, timing. If an all-skipped run does not conclude `skipped`, take the template plan's fallback (its R3).
- **R2 Render bytes differing by platform** (awk, locale, `umask`). Self-render on both legs catches it on every pull request; `bin/render` uses `printf` and awk `index`/`substr` only (decision 5).
- **R3 CI time.** The shipped suites run in the workspace and once per fixture render, on two legs. If a leg passes 15 minutes, verify one fixture per leg (public on Ubuntu, private on macOS), recorded as a call.
- **R4 Wording checks** (the template plan's R1) now also read `CONTEXT.md` and the contracts. Reword; add no exceptions.
- **R5 Bolt-on pressure at stage 03**: an agent "fixing" the target. `bin/verify` refuses a target unlike its render; the fix is a foundation change.
- **R6 Size of the final ack**: about 60 commits reach `main` under one ack; each slice's merge commit and ship-gate record are the review units (call 67).
- The template plan's R2 (Claude Code drift), R4 (number races) and R6 (upstream PR template drift) hold.

## Rollout (the decider's steps; listed, not executed)

The template plan's rollout holds, except: step 4 (mark as a template) is dropped; step 6 is done per produced repository by `bin/publish`; step 2's conduct contact is set with `bin/ask setup COC_CONTACT=…`, re-rendering the workspace's own copy in the same pull request; step 7's rubric lives in the measure 3 tracking issue (call 66), and launch runs one real repository of each visibility through all four stages (AC27) and the measure 3 runs (AC29).
