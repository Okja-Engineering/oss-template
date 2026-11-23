# 0001 oss-template: plan

**Status:** draft. **Decider:** Matthew Van Dusen. **Rests on:** [`spec.md`](spec.md), [`decisions.md`](decisions.md).

## Approach

**Slices into `main`** (ruling 16, call 69). Ten slices, S1–S10, each a pull request into `main`, ship-gated, then merged after the decider's ack at its head, in order; no bulk pull request. S1 branches from `feat/initial-template`, so it carries this folder; with S1's ack the decider accepts the amended intent, and this spec and plan, or says what to change (decision 19, call 76). Each later slice branches from `main`.

**Pipeline first, content second.** S1–S4 build the workflow end to end on a small foundation. S5–S10 fill `foundation/`. From S3 on, every commit is exercised end to end: CI's `m1` job renders and verifies a fixture answers file per leg, running the produced repository's own `bin/check` and suites (AC28), and `m5` compares fingerprints across legs (AC27). A foundation file that breaks a produced repository fails the commit that adds it.

**Every commit is green** (decision 43): `bin/check`, `foundation/tests/run-all.sh` and `foundation/tests/run-all.sh tests` pass with `PATH=/usr/bin:/bin:/usr/sbin:/sbin` (bash 3.2, no `shellcheck`) and with the normal `PATH` and `REQUIRE_SHELLCHECK=1`. From S3, `tests/m1.sh` passes too; it judges `HEAD`, so the builder runs it after committing and amends before pushing. One task is one commit; its named test is written first and seen failing for the reason the row gives. A commit of human prose has no test of its own: the row names the check that will read it and the commit from which it does. Commits are conventional and carry no tool credit; neither do pull request bodies.

**Carried from the template plan.** "TT n" is task n of `git show b368d09:docs/work/0001-oss-template/plan.md`, carried with its first test, under `foundation/`, amended as each row says. Its ordering rules hold: human text states a rule before its enforcer exists and says "not enforced" until then; a task adding a required product file adds its `foundation/bin/lib/layout.txt` entries first. Each enforcer commit also adds its row to the `CONTRIBUTING.md` § What is enforced it serves (the product's from 5.4; the workspace's for its own checks and scripts), and, when the check fits the workspace, its name to the workspace's `bin/check` list (AC5).

**Refactors authorized** (so no task bolts on):
- TT4's dispatcher becomes discovery over `bin/checks/`, beside itself and in the repository (AC5, AC19). Every check task adds a file there, never a branch in `bin/check`.
- Every check reads files through `bin/lib/tree.sh` (AC20); TT9, TT12, TT13 and TT17 judge git objects, not the checkout. `bin/render` reads `HEAD` through the same library.
- Product scripts locate their libraries by their own path, and `tests/run-all.sh` takes a directory, so the workspace runs them in place (AC5).
- `trace` gains `CONTEXT.md` as an agent file and keeps link resolution (AC4); there is no `links` check.
- TT40, TT41 and every `template-only` step are gone. TT6, TT7, TT26, TT28, TT33, TT34 and TT35 write the templates AC18 lists.

**Before S1:** `shellcheck` and `jq` installed locally (installing changes the machine: the chief of staff's go-ahead). Tests need no network (`gh` is stubbed); CI needs GitHub; 10.8 re-resolves pins with `gh api`; G4 creates repositories.

## S1 Skeleton and check harness (9 commits)

| # | Commit | Test written first, and why it fails | ACs |
|---|---|---|---|
| 1.1 | TT1 under `foundation/tests/`, `run-all.sh` taking a directory | TT1's, plus a fixture directory argument: no runner yet | TAC43 |
| 1.2 | TT3 `foundation/tests/lib/fixture.sh` | TT3's: no library yet | TAC43 |
| 1.3 | `foundation/bin/lib/tree.sh`: paths, blobs and modes from the working tree, the index or a commit | `test_tree_lib.sh`: an uncommitted edit, a staged-only file, an executable bit, per source | AC20 |
| 1.4 | TT4 as discovery: `foundation/bin/check`, modes, bases, `--paths`, `--list`, exit codes, `LC_ALL=C` | `test_check_cli.sh`: AC19's fixture checks; AC21's bases, incl. a first push and an unborn branch; a repository check discovered; a path excluded; an uncommitted edit ignored in range mode | TAC38, AC5, AC19–AC21 |
| 1.5 | TT18 `foundation/bin/setup`; the workspace's `bin/setup` | TT18's; `tests/test_setup.sh`: a fixture workspace's `core.hooksPath` is `foundation/.githooks`, twice | TAC34, AC5 |
| 1.6 | `foundation/bin/checks/agents`; the workspace's `bin/check` (list: `agents`), `AGENTS.md`, `CLAUDE.md` | `test_check_agents.sh`: extra content in `CLAUDE.md`; an 81-line `AGENTS.md` | TAC10, AC1, AC5 |
| 1.7 | The workspace's `README.md`, `CONTRIBUTING.md`, `GOVERNANCE.md` (§ Deciders), `docs/workflow.md` | prose: read by `claims` from 5.5, `docs` from 5.6, `trace` from 8.1 | AC4 |
| 1.8 | `bin/checks/stages`; `CONTEXT.md` with its triggers and an empty routing table; list adds `stages` | `test_check_stages.sh`: AC2 and AC3 fixture cases; no check yet | AC2, AC3 |
| 1.9 | `.github/workflows/ci.yml`: both legs, head SHA, `fetch-depth: 0`, the three commands above, SHA-pinned actions | its runner self-test (TAC27): the job fails unless `run-all.sh` fails the failing fixture | AC27 |

**Done when** S1's CI passes on both legs and the workspace's `bin/check --list` shows `agents` and `stages`. **Write set:** `foundation/{bin/check,bin/setup,bin/lib/tree.sh,bin/checks/agents,tests/**}`, `bin/{check,setup,checks/stages}`, `tests/{test_setup.sh,test_check_stages.sh}`, `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`, `README.md`, `CONTRIBUTING.md`, `GOVERNANCE.md`, `docs/workflow.md`, `.github/workflows/ci.yml`, and this folder from `feat/initial-template`.

## S2 Ask, render, status (5 commits)

| # | Commit | Test written first, and why it fails | ACs |
|---|---|---|---|
| 2.1 | `foundation/bin/lib/rules.sh` (TT8's word list), `shared/answers.tsv`, `bin/lib/answers.sh` | `test_answers.sh`: parse; pattern and rule-word refusals; non-ASCII, `&`, `\`, `=` kept; `$(touch x)` creates nothing | AC6, AC29 |
| 2.2 | `bin/ask setup` and `questionnaire`; `setup/answers.env`, `setup/questionnaire.md`; `bin/checks/setup`; list adds `setup` | `test_ask.sh` (setup cases); `test_check_setup.sh`: a stale questionnaire, a missing field | AC7, AC8 |
| 2.3 | `bin/ask run`, `confirm`, `--redo`; contract 01 (its Input, `answers.tsv`, now exists); routing row | `test_ask.sh`: every AC7 run case | AC7 |
| 2.4 | `bin/render`; contract 02; routing row | `test_render.sh` on a fixture workspace: every AC9 refusal; AC10's variations; AC11 per field; fingerprint equals `git write-tree`; no `.git` made | AC9–AC11 |
| 2.5 | `bin/status`; the `status` trigger | `test_status.sh`: one case per AC14 state | AC14 |

**Done when** `bin/ask run`, `confirm`, then `bin/render` on a fixture workspace give the same fingerprint twice. **Write set:** `foundation/bin/lib/rules.sh`, `shared/**`, `setup/**`, `bin/{ask,render,status,lib/answers.sh,checks/setup}`, `stages/0{1,2}-*/**`, `CONTEXT.md`, `CONTRIBUTING.md`, their suites.

## S3 Verify and measure 1, locally (3 commits)

| # | Commit | Test written first, and why it fails | ACs |
|---|---|---|---|
| 3.1 | `bin/verify`, `--check`, the commit identity; contract 03 with its remedies; routing row | `test_verify.sh` on a fixture workspace: an edit after render refused; a planted failing check recorded; `--check` adds no commit | AC12 |
| 3.2 | The email audit | a planted address refused; each allowed form passes | AC13 |
| 3.3 | `tests/m1.sh`, `tests/answers/{public,private}.env`, CI jobs `m1` and `m5`; then the first product files: `foundation/{CLAUDE.md,AGENTS.md.tmpl,README.md.tmpl,LICENSE.apache-2.0,LICENSE.none.tmpl}` | `m1.sh`, run before the product files: the produced repository's `agents` fails on the missing `CLAUDE.md` | AC18, AC27, AC28 |

**Done when** `m1` passes on both legs and `m5` agrees. **Write set:** `bin/verify`, `tests/{m1.sh,answers/**,test_verify.sh,fixtures/workspace/**}`, `foundation/{CLAUDE.md,AGENTS.md.tmpl,README.md.tmpl,LICENSE.*}`, `stages/03-verify/**`, `CONTEXT.md`, `.github/workflows/ci.yml`.

## S4 Publish, against a stub (3 commits)

| # | Commit | Test written first, and why it fails | ACs |
|---|---|---|---|
| 4.1 | `bin/publish --plan`, `--ref` | `test_publish.sh` (stub `gh`, fixture remote): dirty workspace, other-commit render, unreachable SHA, failing `--check`; the exact line | AC15 |
| 4.2 | `--apply --approver` | a changed plan; an unlisted approver; a failure injected after each step, then a rerun that repeats nothing; an occupied repository | AC16 |
| 4.3 | `--watch`; contract 04; routing complete | one case per conclusion; no first run in 5 minutes; a late run within the settle window | AC17 |

**Done when** the stubbed suite passes on both legs; the live run is G4. **Write set:** `bin/publish`, `tests/{test_publish.sh,fixtures/gh/**}`, `stages/04-publish/**`, `CONTEXT.md`, `CONTRIBUTING.md`.

## S5–S10 Foundation content (35 commits)

Each row is the TT task named, under `foundation/`, with its first test as there, plus what the row adds.

| # | Commit (TT task, amended) | ACs |
|---|---|---|
| 5.1 | TT2 `bin/lib/docs.sh` | TAC2–TAC7 |
| 5.2 | TT5 `layout`; `layout.txt` holds product paths and answer-independent lines; the `minus:` pin form | TAC39, AC24 |
| 5.3 | TT6 `GOVERNANCE.md.tmpl` | TAC40, AC18 |
| 5.4 | TT7 `CONTRIBUTING.md`; `docs/adr/README.md.tmpl`, which § ADRs links | TAC1, TAC40, AC25 |
| 5.5 | TT8 `claims`; the test adds a workspace `CONTEXT.md` line; list adds `claims`; workspace prose passes | TAC13, AC4 |
| 5.6 | TT9 `docs`; the test adds a decider added and used in one range (refused) and an RFC merged to `main` after branching (passes); list adds `docs` | TAC2–TAC7, AC20, AC22 |
| 5.7 | ADRs 0001–0005 (TT25) and 0006 (the ICM workspace) as workspace files, `proposed`; `foundation/docs/rfcs/README.md` | AC25 |
| 6.1 | TT10 `classify.sh`, `commits`, `commit-msg` mode; list adds `commits` | TAC8, TAC9 |
| 6.2 | TT11 `pr` mode; the workspace's `pr.yml` | TAC28, AC27 |
| 6.3 | TT24 `docs/templates/*`, `bin/new`; a produced repository's first ADR is 0001 | TAC35, AC25 |
| 7.1 | TT12 `never-publish`, `.githooks/never-publish`, `.gitignore` (product and workspace); list adds it | TAC32 |
| 7.2 | TT13 `secrets`, reading added lines through `tree.sh`; list adds it | TAC33, AC20 |
| 7.3 | TT14 `scripts`, refusing a script without `LC_ALL=C`; list adds it | TAC15, TAC37, AC26 |
| 7.4 | TT16 `.githooks/commit-msg`, `pre-commit`, calling the repository's `bin/check` | TAC9, TAC31, AC5 |
| 7.5 | TT17 `pre-push`; the test adds an uncommitted edit that must not change a pushed ref's verdict | TAC31, AC20 |
| 8.1 | TT19 `trace`: `CONTEXT.md` as an agent file, links resolved; list adds it; the workspace's agent files source to `docs/workflow.md` | TAC12, AC4 |
| 8.2 | TT20 `guard-bash.sh` | TAC16, TAC17 |
| 8.3 | TT21 `guard-docs.sh`; the test adds an edit inside § Deciders (refused) and `replace_all` on `# 0007 draft-handling` | TAC18, AC22, AC23 |
| 8.4 | TT22 `session-start.sh` | TAC19 |
| 8.5 | TT23 `.claude/settings.json`; the workspace's, running `foundation/.claude/hooks/*`; its § Agent guards | TAC15, AC5 |
| 9.1 | TT36, the rest of `agents`: frontmatter, skills, subagent | TAC14, TAC20, TAC21 |
| 9.2 | TT37 `.claude/rules/*.md` | TAC14 |
| 9.3 | TT38 skills `new-work`, `new-rfc`, `new-adr` | TAC20 |
| 9.4 | TT39 `.claude/agents/reviewer.md` | TAC21 |
| 9.5 | TT33 `SECURITY.md`; `CODE_OF_CONDUCT.md.tmpl` | TAC41, AC18 |
| 9.6 | TT34 `README.md.tmpl` in full; `CHANGELOG.md` | TAC41, AC18 |
| 9.7 | TT35 `AGENTS.md.tmpl` in full: three gates within 80 lines | TAC11, AC1 |
| 10.1 | TT15 `workflows`; list adds it; the workspace's workflows pass | TAC30 |
| 10.2 | TT26 issue forms; `config.yml.tmpl` | TAC22, AC18 |
| 10.3 | TT27 `pull_request_template.md`, Summary before `## What changed`, upstream blob pinned | TAC23, AC24 |
| 10.4 | TT28 `CODEOWNERS.tmpl`, `labels.yml`, `workflows/labels.yml` | TAC24, TAC25, AC18 |
| 10.5 | TT29 `dependabot.yml` | TAC26 |
| 10.6 | TT30 the product's `ci.yml`: `shellcheck` pin, job names, head SHA, `CHECK_REF`, no generation step | TAC27, AC20, AC21 |
| 10.7 | TT31 the product's `pr.yml` | TAC28 |
| 10.8 | TT32 `scorecard.yml`, pins re-resolved with `gh api` | TAC29 |

- **S5 Docs process** (5.1–5.7, 7 commits). Done when `docs`, `claims` and `layout` pass on the workspace and in `m1`. Writes `foundation/{bin/lib/docs.sh,bin/lib/layout.txt,bin/checks/{layout,claims,docs},GOVERNANCE.md.tmpl,CONTRIBUTING.md,docs/**}`, `docs/adr/**`, the workspace's `bin/check` and `CONTRIBUTING.md`, suites.
- **S6 Commits and new documents** (6.1–6.3, 3). Done when every commit since S1 passes `commits`. Writes `foundation/{bin/lib/classify.sh,bin/checks/{commits,pr},bin/new,docs/templates/**}`, `.github/workflows/pr.yml`, suites.
- **S7 Hygiene and git hooks** (7.1–7.5, 5). Done when the workspace's commits run through `foundation/.githooks` and a fixture render's hooks refuse TT16's and TT17's cases. Writes `foundation/{.githooks/**,.gitignore,bin/checks/{never-publish,secrets,scripts}}`, `.gitignore`, suites.
- **S8 Agent guards** (8.1–8.5, 5). Gate **G1** before the ack. Done when every hook test passes on both legs. Writes `foundation/{bin/checks/trace,.claude/hooks/**,.claude/settings.json}`, `.claude/settings.json`, the workspace's agent files, `docs/workflow.md`, suites.
- **S9 Agent files and human docs** (9.1–9.7, 7). Gates **G2**, **G3**. Done when `trace`, `claims` and `agents` pass in `m1`. Writes `foundation/{.claude/{rules,skills,agents}/**,SECURITY.md,CHANGELOG.md,*.md.tmpl}`, suites.
- **S10 GitHub files** (10.1–10.8, 8). Gate **G4**. Done when every TAC the spec carries is met in `m1` and G4 passes. Writes `foundation/.github/**`, `foundation/bin/checks/workflows`, suites.

## Gates (no commits unless one finds a defect)

Each records the SHA it ran on and reruns when the head moves; results go in the slice's pull request.
- **G1** (S8) Hooks fire under `claude -p` on the installed Claude Code, in the workspace and in a fixture render; `onFailure` handled as the template plan's G1 says.
- **G2** (S9) A person confirms with `/memory`, in a fixture render, that rules load only for their paths. **G3** (S9) The reviewer subagent's dry run on S9's pull request.
- **G4** (S10) Measure 1 live (AC28): both fixtures through all four stages into two throwaway repositories in `Okja-Engineering`, `--ref` naming S10's branch; `--watch` passes; URLs and conclusions recorded; exactly those two deleted (ruling 13). A rerun after the head moves needs a fresh go-ahead.

## Risks

- **R1, most likely to need rework: `--watch` against GitHub.** Only G4 exercises it live: first pushes, private repositories (Scorecard skipped), Dependabot runs, timing. If an all-skipped run does not conclude `skipped`, take the template plan's fallback (its R3).
- **R2 Product scripts run in two places.** In the workspace they judge workspace paths through `--paths`; in a produced repository, its whole tree. A script that assumes the product layout breaks the workspace's `bin/check` first, which is where it should break.
- **R3 Render bytes differing by platform** (awk, locale, `umask`). `m5` catches it on every pull request; `bin/render` uses `printf` and awk `index`/`substr` only (decision 5), under `LC_ALL=C`.
- **R4 Nested agent files under `foundation/`** load when an agent reads product files there (not enforced, item 11). The workspace's `AGENTS.md` names them as the product's.
- **R5 Wording checks** (the template plan's R1) now also read the workspace's prose. Reword; add no exceptions.
- **R6 Bolt-on pressure at stage 03**: an agent "fixing" the target. `bin/verify` refuses a target unlike its render; `docs/workflow.md` routes each failure to its remedy.
- **R7 Ten acks.** Each slice waits on the decider's ack, so the build moves at his pace; the next slice may be built on its branch while one waits.
- The template plan's R2 (Claude Code drift), R4 (number races) and R6 (upstream PR template drift) hold.

## Rollout (the decider's steps; listed, not executed)

The template plan's rollout holds, except: acks go slice by slice (step 3); step 4 (mark as a template) is dropped; step 6 is done per produced repository by `bin/publish`; the conduct contact is set with `bin/ask setup COC_CONTACT=…` (step 2); the licence policy (call 74) is confirmed or changed; an issue in `ai-native-sdlc` proposes the Summary section (ruling 11), and when upstream adopts it, AC24's pin moves to the new blob; the rubric lives in the measure 3 tracking issue (call 66); launch runs one real repository of each visibility through all four stages (AC28) and the measure 3 runs (AC30).
