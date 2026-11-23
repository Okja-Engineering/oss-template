# 0001 oss-template: plan

**Status:** draft. **Decider:** Matthew Van Dusen. **Rests on:** [`spec.md`](spec.md), [`decisions.md`](decisions.md).

## Approach

**Slices into `main`** (ruling 16, decision 69). Ten slices, S1–S10, each a pull request into `main`, ship-gated, then merged after the decider's ack at its head, in order; no bulk pull request. S1 branches from `feat/initial-template`, so it carries this folder, and lands by merge commit, so the folder's history is kept unrewritten; the workspace's `commits` check later records that merge as its baseline (decision 92). S1's PR body lists what the decider accepts with its ack: the intent as amended under ruling 14, measure 1's amended gates (decisions 106, 113), and this spec and plan, or what to change (decision 19). Each later slice branches from `main`.

**Pipeline first, content second.** S1–S4 build the workflow end to end on a small foundation. S5–S10 fill `foundation/`. From S3 on, every commit is exercised end to end: CI's `m1` job renders and verifies a fixture answers file per leg, running the produced repository's own `bin/check` and suites (AC29), and `m5` compares fingerprints across legs (AC28). A foundation file that breaks a produced repository fails the commit that adds it, and measure 1 gates each slice PR from S3, the first that can run it (decision 113).

**Every commit is green** (decision 43), checked with `PATH=/usr/bin:/bin:/usr/sbin:/sbin` (bash 3.2, no `shellcheck`) and with the normal `PATH` and `REQUIRE_SHELLCHECK=1`, running each of these from the commit that adds it: `foundation/tests/run-all.sh` (1.1), `tests/run-all.sh` (1.1), the workspace's `bin/check` (1.7), `tests/m1.sh` (3.3). `m1.sh` judges `HEAD`, so the builder runs it after committing and amends before pushing. One task is one commit; its named test is written first and seen failing for the reason the row gives, and a row that adds a refusal writes its fixture case first (AC30). A commit of human prose has no test of its own: the row names the check that reads it. Commits are conventional and carry no tool credit; neither do pull request bodies.

**Carried from the template plan.** "TT n" is task n of `git show b368d09:docs/work/0001-oss-template/plan.md`, carried with its first test, under `foundation/`, amended as each row says. Its ordering rules hold: human text states a rule before its enforcer exists and says "not enforced" until then; a task adding a required product file adds its `foundation/bin/lib/layout.txt` entries first. Each enforcer commit adds its row to the `CONTRIBUTING.md` § What is enforced it serves: `foundation/CONTRIBUTING.md` (from 5.4) for product checks, the workspace's for its checks and scripts. **A field joins `shared/answers.tsv` with its first use** (decisions 107, 117), and is a render field once a template holds its placeholder or it selects a variant: `NAME`, `OWNER`, `TARGET_ROOT` at 2.2; `COMMIT_IDENTITY` at 3.1; `DESCRIPTION`, `VISIBILITY`, `LICENSE`, `COPYRIGHT_HOLDER` at 3.3, where `NAME` becomes a render field; `WORKSPACE_URL` at 4.2, a render field at 5.4; `DECIDERS` at 5.3; `COC_CONTACT` at 9.5; `OWNER` a render field at 10.2; `CODEOWNERS` at 10.4. Every commit that changes a field or its render column writes `shared/answers.tsv` and `setup/**`, regenerating `setup/questionnaire.md` (setup fields only) and filling `setup/answers.env`; from 3.4, when a template is the first use, its first test is the workspace's `foundation` refusing the then-unused render field.

**Refactors authorized** (so no task bolts on):
- Shared code becomes libraries with explicit parameters (decisions 95, 102): TT1's runner, TT4's dispatcher, and the logic of TT8 (word lists), TT9 (`docs.sh`, given the `GOVERNANCE.md` path, roots and base), TT10 (classifier), TT12 (`never-publish` matching), TT13 (secret patterns), TT14 (script rules) and TT15 (workflow rules). Product checks and the workspace's checks are thin callers; no product check ever runs on the workspace (decision 89).
- Every check reads files through `bin/lib/tree.sh`, which drops the path prefixes its caller names (AC21); TT9, TT12, TT13 and TT17 judge git objects, not the checkout. `bin/render` reads `HEAD` through it.
- `trace` gains `CONTEXT.md` as an agent file and resolves links through `bin/lib/links.sh`; there is no `links` check.
- Skills and the reviewer subagent are stored as `.tmpl` (decision 91). TT40, TT41 and every `template-only` step are gone. TT6, TT7, TT26, TT28, TT33–TT35, TT38 and TT39 write the templates AC19 lists.

**Before S1:** git 2.31 or later (AC10 needs `GIT_CONFIG_COUNT`; S1 needs nothing new), `shellcheck` and `jq` installed locally (installing changes the machine: the chief of staff's go-ahead). Tests need no network (`gh` is stubbed); CI needs GitHub; 10.8 re-resolves pins with `gh api`; G4 creates repositories.

## S1 Skeleton and check harness (10 commits)

| # | Commit | Test written first, and why it fails | ACs |
|---|---|---|---|
| 1.1 | TT1 as `foundation/tests/lib/runner.sh` with `foundation/tests/run-all.sh`; the workspace's `tests/run-all.sh` | TT1's, plus each runner given its directory: no runner yet | TAC43, AC20 |
| 1.2 | TT3 `foundation/tests/lib/fixture.sh` | TT3's: no library yet | TAC43 |
| 1.3 | `foundation/bin/lib/tree.sh`: paths, blobs and modes from the working tree, the index or a commit, minus excluded prefixes | `test_tree_lib.sh`: an uncommitted edit, a staged-only file, an executable bit, an excluded prefix, per source | AC21 |
| 1.4 | TT4 as `foundation/bin/lib/dispatch.sh` and `foundation/bin/check`: modes, bases, `--list`, exit codes, `LC_ALL=C` | `test_check_cli.sh`: AC20's fixture checks; AC22's first push and unborn branch; an uncommitted edit ignored in range mode | TAC38, AC20–AC22, AC30 |
| 1.5 | TT18 `foundation/bin/setup` | TT18's | TAC34 |
| 1.6 | `foundation/bin/checks/agents` (exact `CLAUDE.md`, 80-line `AGENTS.md`) | `test_check_agents.sh`: extra content in `CLAUDE.md`; an 81-line `AGENTS.md` | TAC10, AC1, AC30 |
| 1.7 | The workspace's `bin/check`, `bin/setup`, `.githooks/{commit-msg,pre-commit,pre-push}` | `tests/test_check_cli.sh`: each AC5 argument form; `test_githooks.sh`: each hook with its arguments, `pre-push` per new, updated and deleted ref; `test_setup.sh`: `core.hooksPath` is `.githooks`, twice | AC5, AC30 |
| 1.8 | The workspace's `README.md`, `CONTRIBUTING.md` (§ Agent guards naming `Read(**/.env)` and `Read(**/.env.*)`; § What is enforced), `GOVERNANCE.md` (§ Deciders), `docs/workflow.md` (the workspace is pre-launch until S10 merges and G4 passes; until then `main` may hold an incomplete foundation), `.claude/settings.json` | prose: read by the workspace's `claims` and `trace` from 2.1 | AC4 |
| 1.9 | The workspace's `bin/checks/disclosure`; `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md` (triggers, empty routing table) | `test_check_disclosure.sh`: every AC1–AC3 fixture case; no check yet | AC1–AC3, AC30 |
| 1.10 | `.github/workflows/ci.yml`: both legs; Ubuntu installs `shellcheck` v0.11.0 by pinned SHA-256 with `REQUIRE_SHELLCHECK=1`; head SHA, `fetch-depth: 0`; top-level `permissions: contents: read`; actions pinned by SHA with version comments (TAC30's form, judged from 10.1) | its runner self-test (TAC27): the job fails unless the runner fails the failing fixture | AC28 |

**Done when** S1's CI passes on both legs and `bin/check --list` shows `disclosure`. **Write set:** `foundation/{bin/check,bin/setup,bin/lib/{tree,dispatch}.sh,bin/checks/agents,tests/**}`, `bin/{check,setup,checks/disclosure}`, `.githooks/**`, `tests/{run-all.sh,test_check_cli.sh,test_githooks.sh,test_setup.sh,test_check_disclosure.sh,fixtures/**}`, `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`, `README.md`, `CONTRIBUTING.md`, `GOVERNANCE.md`, `docs/workflow.md`, `.claude/settings.json`, `.github/workflows/ci.yml`, and this folder from `feat/initial-template`.

## S2 Ask and render (5 commits)

| # | Commit | Test written first, and why it fails | ACs |
|---|---|---|---|
| 2.1 | `foundation/bin/lib/{rules,links}.sh`; the workspace's `claims` and `trace` | `test_check_claims.sh`, `test_check_trace.sh` on fixtures: an unsourced rule line in a `CONTEXT.md`, an unresolved anchor, an unlisted deny entry; `tests/fixtures/` ignored | AC4, AC30 |
| 2.2 | `shared/answers.tsv` with its `type` column and the fields S2 uses (`NAME`, `OWNER`, `TARGET_ROOT`); `bin/lib/answers.sh` | `test_answers.sh` on a fixture schema: parse; each type and pattern; an email refused in a `text` and a `list` field only; a 101-character `name` and a 351-character `text` refused (GitHub's limits, decision 120); non-ASCII, `&`, `\`, `=` kept; `$(touch x)` creates nothing | AC6, AC7, AC30 |
| 2.3 | `bin/ask setup` and `questionnaire`; `setup/answers.env`, `setup/questionnaire.md`; the workspace's `setup` | `test_ask.sh` (setup cases; a run field kept out of the questionnaire); `test_check_setup.sh`: a stale questionnaire, a value the validator rejects | AC7, AC8, AC30 |
| 2.4 | `bin/ask run`, `--setup-override`, `confirm`, `--redo --remove PATH` for unpublished runs (the attempted and published refusals land at 4.2); the shared discard, `bin/lib/discard.sh`, with `--redo` its first caller (decisions 134, 136, 140); contract 01 with its removal checkpoint, and its routing row | `test_ask.sh`: every AC7 run case but those refusals and the secret one (7.2), incl. a rule word and an email in a fixture `text` field, `--redo` without `--remove`, with another path, through a symbolic link or outside `TARGET_ROOT`, each refused with nothing removed, and an override leaving `setup/answers.env` untouched | AC7, AC9, AC30 |
| 2.5 | `bin/render` over `bin/lib/render.sh`; `--replace --remove PATH`, calling 2.4's discard; hermetic git built positively, its settings carried in `GIT_CONFIG_COUNT`, objects pinned to SHA-1 (decisions 112, 128, 135, 137); contract 02 and its row | `test_render.sh` on a fixture workspace: every AC9 refusal; each of AC10's planted render cases, first seen changing the fingerprint with its setting removed, and the workspace's `.git` gaining no object or ref; AC11's variations; AC12 per field and `select` value; no `.git` in the target | AC9–AC12, AC30 |

**Done when** `bin/ask run`, `confirm`, then `bin/render` on a fixture workspace give the same fingerprint twice. **Write set:** `foundation/bin/lib/{rules,links}.sh`, `shared/**`, `setup/**`, `bin/{ask,render,lib/{answers,render,discard}.sh,checks/{claims,trace,setup}}`, `stages/0{1,2}-*/**`, `CONTEXT.md`, `docs/workflow.md`, the workspace's `CONTRIBUTING.md`, suites.

## S3 Verify and measure 1, locally (4 commits)

| # | Commit | Test written first, and why it fails | ACs |
|---|---|---|---|
| 3.1 | `bin/verify`: `bin/check --staged`, `tests/run-all.sh` and (from 3.2) the email audit before the commit, which `git commit-tree` makes and `update-ref` records, expecting no old value, only after its identity and tree are asserted (decisions 118, 119, 122, 131, 141); reruns and `--check` staged too (decision 138); an unborn `.git` reused after a failure (decision 124); `COMMIT_IDENTITY` joins the schema (noreply or `.invalid`, decision 114); contract 03 with its removal checkpoint and routes; its row | `test_verify.sh` on a fixture workspace, under each of AC10's planted cases, incl. a `post-index-change` hook and `core.fsmonitor` in a reused unborn `.git`, neither run: an edit after render refused; a planted failing check recorded, leaving no ref, then a rerun after the fix passing; a rerun adds no commit; a partial run, an untracked file and an edit after verify each refused; `GIT_AUTHOR_EMAIL` and `GIT_COMMITTER_EMAIL` planted in the environment and from another repository's hook, the identity still `COMMIT_IDENTITY`; a hook planted in the target never run; `test_answers.sh`: a `COMMIT_IDENTITY` at another address, or with a name git would rewrite, refused | AC6, AC10, AC13, AC30 |
| 3.2 | The email audit | a planted address refused; `COC_CONTACT`'s address and each allowed form pass | AC14, AC30 |
| 3.3 | `tests/m1.sh` (fixture setup values through `--setup-override`), `tests/answers/{public,private}.env` (unusual values; a non-ASCII `DESCRIPTION`), CI jobs `m1` and `m5`; then the first product files: `foundation/{CLAUDE.md,AGENTS.md.tmpl,README.md.tmpl,LICENSE.apache-2.0,LICENSE.none.tmpl}`, with the fields they use | `m1.sh` before the product files fails at render (`LICENSE` has no variant), and with the variants alone at verify (`agents`: no `CLAUDE.md`) | AC6, AC19, AC28, AC29 |
| 3.4 | The workspace's `foundation` check, rendering through `bin/lib/render.sh` with the schema, the fixture answers and `foundation/` read at the commit under judgment (decisions 115, 130) | `test_check_foundation.sh` on fixtures: a leftover placeholder, a render field nothing uses, a missing variant, an executable template, a skill stored as `SKILL.md`; in pre-push, a pushed ref other than `HEAD` rendered with that ref's schema, and an uncommitted edit ignored | AC19, AC30 |

**Done when** `m1` passes on both legs and `m5` agrees. **Write set:** `bin/{verify,checks/foundation,lib/render.sh}`, `shared/answers.tsv`, `setup/**`, `tests/{m1.sh,test_answers.sh,answers/**,test_verify.sh,test_check_foundation.sh,fixtures/**}`, `foundation/{CLAUDE.md,AGENTS.md.tmpl,README.md.tmpl,LICENSE.*}`, `stages/03-verify/**`, `CONTEXT.md`, `docs/workflow.md`, `.github/workflows/ci.yml`, the workspace's `CONTRIBUTING.md`.

## S4 Publish, against a stub, and status (5 commits)

| # | Commit | Test written first, and why it fails | ACs |
|---|---|---|---|
| 4.1 | `bin/publish --plan`, unpublished runs only (AC16) | `test_publish.sh` (stub `gh`, fixture remote): dirty workspace, other-commit render, SHA not on the default branch, dirty target, failing `--check`, a root commit authored by another identity; the exact line | AC16, AC30 |
| 4.2 | `--apply --approver [--basis]`: the two regimes and write-ahead records (decisions 110, 111, 120); the mirror, and every push from it with `gh`'s credential helper on the push only and the URL from `gh repo view` (decisions 121, 126, 133); `WORKSPACE_URL` joins the schema (the first issue); the attempted and published states, which `--plan`, `bin/ask --redo` and `bin/render --replace` now honour | AC17's cases: a failure injected after each intent and each done line, then a resume; after a partial publish, a moved `HEAD` and a new target commit ignored, and a visibility changed out of band refused; a hook planted in the target never run; `--redo VISIBILITY=private` after a public repository was created, refused; a pre-existing repository, refused; `--plan` on a published run printing the approved line and the steps left | AC7, AC9, AC16, AC17, AC30 |
| 4.3 | `--abandon` (decisions 127, 141: the UTC name, with a counter) and contract 04's checkpoint for it | AC17's `--abandon` cases: an intent with no remote effect (the run unpublished, `--redo` working again), twice in one second; a created repository and a done line, each refused | AC15, AC17, AC30 |
| 4.4 | `--watch`, a failure completing a published run with failure (decision 129); contract 04 and its row | one case per conclusion; no first run in 5 minutes; a late run within the settle window | AC18, AC30 |
| 4.5 | `bin/status`, now that every format it reads exists; the `status` trigger | `test_status.sh`: one case per AC15 state, incl. `HEAD` moved past a render, an attempted run, a published run without a watch, and one whose watch failed, routed to the produced repository | AC15 |

**Done when** the stubbed suite passes on both legs. **Write set:** `bin/{publish,status,ask,render}` (the published-state refusals), `shared/answers.tsv`, `setup/**`, `tests/{test_publish.sh,test_status.sh,fixtures/gh/**}`, `stages/04-publish/**`, `CONTEXT.md`, `docs/workflow.md`, the workspace's `CONTRIBUTING.md`.

## S5–S10 Foundation content (35 commits)

Each row is the TT task named, under `foundation/`, with its first test as there, plus what the row adds. Every row's write set also holds its suite, its `layout.txt` entries and its `foundation/CONTRIBUTING.md` row; a row that adds a workspace check adds `bin/checks/<name>` and the workspace's `CONTRIBUTING.md` row; a row that adds a field or changes its render column adds `shared/answers.tsv` and `setup/**`.

| # | Commit (TT task, amended) | ACs |
|---|---|---|
| 5.1 | TT2 `bin/lib/docs.sh` | TAC2–TAC7 |
| 5.2 | TT5 `layout`; `layout.txt` holds product paths and answer-independent lines; the `minus:` pin form | TAC39, AC25 |
| 5.3 | TT6 `GOVERNANCE.md.tmpl`; `DECIDERS` joins the schema, and the fixture answers' `DECIDERS` hold non-ASCII letters; first test: `foundation` refuses `DECIDERS` unused | TAC40, AC19 |
| 5.4 | TT7 `CONTRIBUTING.md`; `docs/adr/README.md.tmpl`, which § ADRs links; `WORKSPACE_URL` becomes a render field (first test as 5.3) | TAC1, TAC40, AC26 |
| 5.5 | TT8 `claims`, calling `rules.sh` | TAC13 |
| 5.6 | TT9 rules into `docs.sh` with parameters; the product's `docs` and the workspace's; the test adds a decider added and used in one range (refused) and an RFC merged to `main` after branching (passes) | TAC2–TAC7, AC5, AC21, AC23 |
| 5.7 | ADRs 0001–0005 (TT25) and 0006 (the ICM workspace), `proposed`; `foundation/docs/rfcs/README.md`; prose judged by the workspace's `docs` from 5.6 | AC26 |
| 6.1 | TT10 `classify.sh`, `commits`, `commit-msg` mode; the workspace's `commits`, with S1's merge as baseline | TAC8, TAC9, AC5 |
| 6.2 | TT11 `pr` mode; the workspace's `pr` and `pr.yml` (top-level permissions, actions pinned by SHA with version comments) | TAC28, AC5, AC28 |
| 6.3 | TT24 `docs/templates/*`, `bin/new`; a produced repository's first ADR is 0001 | TAC35, AC26 |
| 7.1 | TT12 `never-publish.sh`, `never-publish`, `.githooks/never-publish`, `.gitignore`; the workspace's `never-publish`, passing its own `.githooks/never-publish` | TAC32, AC5 |
| 7.2 | TT13 `secrets.sh`, `secrets`, reading added lines through `tree.sh`; the workspace's `secrets`; `bin/ask` refusing a value its patterns match (decision 139); the first test adds a token-like `DESCRIPTION` refused by `bin/ask`, and a fixture render holding it refused by verify's `bin/check --staged` before any ref (decision 131) | TAC33, AC5, AC7, AC13, AC21 |
| 7.3 | TT14 `scripts.sh`, `scripts`, refusing a script without `LC_ALL=C`; the workspace's `scripts` | TAC15, TAC37, AC27 |
| 7.4 | TT16 `.githooks/commit-msg`, `pre-commit` | TAC9, TAC31 |
| 7.5 | TT17 `pre-push`; the test adds an uncommitted edit that must not change a pushed ref's verdict | TAC31, AC21 |
| 8.1 | TT19 `trace`: `CONTEXT.md` as an agent file, links through `links.sh` | TAC12 |
| 8.2 | TT20 `guard-bash.sh` | TAC16, TAC17 |
| 8.3 | TT21 `guard-docs.sh`; the test adds an edit inside § Deciders (refused) and `replace_all` on `# 0007 draft-handling` | TAC18, AC23, AC24 |
| 8.4 | TT22 `session-start.sh` | TAC19 |
| 8.5 | TT23 `.claude/settings.json` | TAC15 |
| 9.1 | TT36, the rest of `agents`: frontmatter, skills, subagent, judged on rendered files | TAC14, TAC20, TAC21 |
| 9.2 | TT37 `.claude/rules/*.md` | TAC14 |
| 9.3 | TT38 skills `new-work`, `new-rfc`, `new-adr`, as `SKILL.md.tmpl` | TAC20, AC19 |
| 9.4 | TT39 `.claude/agents/reviewer.md.tmpl` | TAC21, AC19 |
| 9.5 | TT33 `SECURITY.md`; `CODE_OF_CONDUCT.md.tmpl`; `COC_CONTACT` joins the schema (first test as 5.3) | TAC41, AC19 |
| 9.6 | TT34 `README.md.tmpl` in full; `CHANGELOG.md` | TAC41, AC19 |
| 9.7 | TT35 `AGENTS.md.tmpl` in full: three gates within 80 lines | TAC11, AC1 |
| 10.1 | TT15 `workflows.sh`, `workflows`; the workspace's `workflows`, judging its own `.github/` and fixing what it finds there | TAC30, AC5 |
| 10.2 | TT26 issue forms; `config.yml.tmpl`; `OWNER` becomes a render field (first test as 5.3) | TAC22, AC19 |
| 10.3 | TT27 `pull_request_template.md`, Summary before `## What changed`, upstream blob pinned | TAC23, AC25 |
| 10.4 | TT28 `CODEOWNERS.tmpl`, `labels.yml`, `workflows/labels.yml`; `CODEOWNERS` joins the schema (first test as 5.3) | TAC24, TAC25, AC19 |
| 10.5 | TT29 `dependabot.yml` | TAC26 |
| 10.6 | TT30 the product's `ci.yml`: `shellcheck` pin, job names, head SHA, `CHECK_REF`, no generation step | TAC27, AC21, AC22 |
| 10.7 | TT31 the product's `pr.yml` | TAC28 |
| 10.8 | TT32 `scorecard.yml`, pins re-resolved with `gh api` | TAC29 |

- **S5 Docs process** (5.1–5.7, 7 commits). Done when `docs`, `claims` and `layout` pass in `m1` and the workspace's `docs` passes on its own documents. Writes `foundation/{bin/lib/docs.sh,bin/lib/layout.txt,bin/checks/{layout,claims,docs},GOVERNANCE.md.tmpl,CONTRIBUTING.md,docs/**}`, `bin/checks/docs`, `docs/adr/**`, `tests/answers/**`.
- **S6 Commits and new documents** (6.1–6.3, 3). Done when every commit after S1's merge passes the workspace's `commits`. Writes `foundation/{bin/lib/classify.sh,bin/checks/{commits,pr},bin/new,docs/templates/**}`, `bin/checks/{commits,pr}`, `.github/workflows/pr.yml`.
- **S7 Hygiene and git hooks** (7.1–7.5, 5). Done when a fixture render's hooks refuse TT16's and TT17's cases. Writes `foundation/{.githooks/**,.gitignore,bin/lib/{never-publish,secrets,scripts}.sh,bin/checks/{never-publish,secrets,scripts}}`, `bin/checks/{never-publish,secrets,scripts}`, `bin/ask`, `tests/{test_ask.sh,test_verify.sh}`, `.githooks/never-publish`, `.gitignore`.
- **S8 Agent guards** (8.1–8.5, 5). Gate **G1** before the ack. Done when every hook test passes on both legs. Writes `foundation/{bin/checks/trace,.claude/hooks/**,.claude/settings.json}`.
- **S9 Agent files and human docs** (9.1–9.7, 7). Gates **G2**, **G3**. Done when `trace`, `claims` and `agents` pass in `m1`. Writes `foundation/{bin/checks/agents,.claude/{rules,skills,agents}/**,SECURITY.md,CHANGELOG.md,*.md.tmpl}`.
- **S10 GitHub files** (10.1–10.8, 8). Done when every TAC the spec carries is met in `m1`. Writes `foundation/{.github/**,bin/lib/workflows.sh,bin/checks/workflows}`, `bin/checks/workflows`, `.github/**`.

## Gates (no commits unless one finds a defect)

Each records the SHA it ran on and reruns when the head moves; results go in the slice's pull request, or, for G4, the launch tracking issue.
- **G1** (S8) Hooks fire under `claude -p` on the installed Claude Code in a fixture render; `onFailure` handled as the template plan's G1 says.
- **G2** (S9) A person confirms with `/memory`, in a fixture render, that rules load only for their paths, and, in the workspace, that no product skill or subagent loads. **G3** (S9) The reviewer subagent's dry run in the public fixture's render, after a planted capability change is committed there (a work folder and the code it plans), over the range from its root commit to `HEAD`.
- **G4** (after S10 merges; gates launch) Measure 1 live (AC29): from `main`, both fixtures through all four stages, setup values by `--setup-override`, into two throwaway repositories in `Okja-Engineering`, approver the decider with basis "per ruling 13"; `--watch` passes; URLs and conclusions recorded; exactly those two deleted (ruling 13, decision 93). A rerun after `main` moves needs a fresh go-ahead.

## Risks

- **R1, most likely to need rework: `--watch`, a resumed `--apply` and the mirror push against GitHub.** Only G4 exercises them live, and the stub only approximates the remote states AC17 judges; G4 is also the first run of a produced repository's checks in range mode (verify runs them staged): first pushes, private repositories (Scorecard skipped), Dependabot runs, timing. It runs after S10 merges, so a defect it finds is a new slice. If an all-skipped run does not conclude `skipped`, take the template plan's fallback (its R3).
- **R2 Library parameters drift.** A product library changed for a product check can break a workspace caller; the workspace's suites and CI run on every slice, so it breaks there first.
- **R3 Render bytes differing by platform or configuration** (awk, locale, `umask`, git configuration and environment). `m5` and the hostile-configuration tests catch it; `bin/render` uses `printf` and awk `index`/`substr` under `LC_ALL=C` and hermetic git.
- **R4 Wording checks** (the template plan's R1) also read the workspace's prose. Reword; add no exceptions.
- **R5 Bolt-on pressure at stage 03**: an agent "fixing" the target. `bin/verify` refuses a target unlike its render, a dirty one or a partial run, commits only after every check passes, and nothing removes a target without the operator's "remove <path>" at a checkpoint; `docs/workflow.md` routes each failure.
- **R6 Ten acks.** Each slice waits on the decider's ack, so the build moves at his pace; the next slice may be built on its branch while one waits.
- The template plan's R2 (Claude Code drift), R4 (number races) and R6 (upstream PR template drift) hold.

## Rollout (the decider's steps; listed, not executed)

The template plan's rollout holds, except: acks go slice by slice (step 3), S1's covering the amended intent; step 4 (mark as a template) is dropped; step 6 is done per produced repository by `bin/publish`; the conduct contact is set with `bin/ask setup COC_CONTACT=…` (step 2); the licence policy (decision 74) is confirmed or changed; an issue in `ai-native-sdlc` proposes the Summary section (ruling 11), and when upstream adopts it, AC25's pin moves to the new blob; the rubric lives in the measure 3 tracking issue (decision 66); G4 runs; launch runs one real repository of each visibility through all four stages (AC29) and the measure 3 runs (AC31).
