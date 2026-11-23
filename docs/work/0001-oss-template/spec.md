# 0001 oss-template: spec

**Status:** draft. **Decider:** Matthew Van Dusen. **Rests on:** [`intent.md`](intent.md), [`decisions.md`](decisions.md), [`research.md`](research.md).

What the workspace does, stated so each line can be checked. Each acceptance criterion (AC) names its proof: a `bin/check` check, a suite under `tests/`, a CI job, or a person reading. Unmarked ACs gate the slice that the plan assigns them to; **launch** ACs gate launch. "Ruling N", "decision N" and "call N" cite [`decisions.md`](decisions.md). "Measure N" is the intent's numbering. "TAC N" cites AC N of the superseded template spec (`git show b368d09:docs/work/0001-oss-template/spec.md`), whose foundation ACs this spec carries by reference (§ 4); TAC44's M5, M6 and M7 are measures 6, 7 and 8 here.

## Terms

- **Workspace:** this repository. **Run:** one pass through the stages for one repository name. **Produced repository:** what a run makes. **Target:** the directory a run renders into, `<TARGET_ROOT>/<NAME>`, outside the workspace. **Operator:** the person working through a run's checkpoints.
- **Foundation:** `foundation/`, the complete product tree (call 68). A file there is **verbatim**, a **template** (`PATH.tmpl`) or a **variant** (`PATH.VALUE`, chosen by the field that selects `PATH`; call 78). Nothing outside `foundation/` reaches a produced repository.
- **Answers file:** a run's `stages/01-ask/output/<name>/answers.env`, one `FIELD=value` per line, read as data and never sourced. **Render fields** reach the produced tree; the others steer scripts only.
- **Fingerprint:** the git tree id of a rendered tree, file modes included (call 53).
- **Share** (ruling 15): a step is **deterministic** (a script), **orchestration** (the contract's order and checkpoints) or **judgment** (the agent).
- **Reserved decisions:** TAC's, plus approving a publish plan (a decider in the workspace's `GOVERNANCE.md`, call 70) and changing any § Deciders (decision 45).

## 1. Shape and disclosure

```
AGENTS.md  CLAUDE.md     L0, always on: running and changing the workspace. CLAUDE.md is `@AGENTS.md`
CONTEXT.md               L1, on entry: triggers (create, setup, status), stage routing; points at each contract, repeats no Inputs
README.md  CONTRIBUTING.md  GOVERNANCE.md  LICENSE   the workspace's human docs; GOVERNANCE § Deciders approves publishing
docs/workflow.md         the human source for every workflow rule: checkpoints, approval, the target, --redo and --replace
docs/adr/  docs/work/    the workspace's decisions (ADRs 0001-0006) and work folders
setup/                   questionnaire.md (generated from the schema); answers.env (setup fields)
shared/answers.tsv       the field schema
stages/NN-slug/          01-ask 02-render 03-verify 04-publish: CONTEXT.md, output/.gitignore, references/ when it holds files
bin/                     ask render verify publish status setup; check (runs foundation/bin/check); checks/{stages,setup}; lib/answers.sh
tests/                   the workspace's suites (fixtures only); m1.sh; answers/{public,private}.env
.github/  .claude/settings.json   the workspace's CI; the product's Claude Code hooks, run from foundation/
foundation/              the product tree
```

| Loaded | Files | Budget (call 64) |
|---|---|---|
| Always | `CLAUDE.md`, which imports `AGENTS.md` | `CLAUDE.md` exactly `@AGENTS.md`; `AGENTS.md` ≤ 80 lines |
| On entry | `CONTEXT.md` | ≤ 60 lines |
| Per stage | that stage's `CONTEXT.md`, then only the files its Inputs name | ≤ 80 lines per contract |
| By scripts only | `foundation/`, `setup/answers.env` | none |

Produced repositories follow the same pattern: a short `AGENTS.md` (AC1), rules scoped by path (TAC14), skills and the reviewer loaded on demand (TAC20, TAC21). The workspace's `AGENTS.md` says that agent files under `foundation/` describe produced repositories, not this one.

- **AC1** `CLAUDE.md` is exactly `@AGENTS.md` and `AGENTS.md` is at most 80 lines, in the workspace and every produced repository (TAC10, its 100 lowered by ruling 16). *`agents`.*
- **AC2** `stages` refuses: `CONTEXT.md` over 60 lines, or a routing table not naming each `stages/NN-slug/` exactly once; a stage folder not matching `NN-[a-z]+(-[a-z]+)*` or lacking `CONTEXT.md` or `output/.gitignore`; an `output/.gitignore` other than `*` and `!.gitignore`; any other tracked file under `output/`; a contract over 80 lines, or without `## Inputs`, `## Process` and `## Outputs`, with optional `## Checkpoints` and `## Audit` between the last two, in that order. *`tests/test_check_stages.sh`, one fixture case each.*
- **AC3** **Inputs discipline** (ruling 16). Each Inputs row names one file in backticks, relative to its stage folder, that resolves to a tracked file or is `../NN-slug/output/<name>/FILE` listed in an earlier stage's Outputs. `stages` refuses a directory, a glob, an unresolved path, an input from the same or a later stage, and a file in `references/` that its stage's Inputs do not name. *`test_check_stages.sh`.*
- **AC4** **Workspace prose traces** (measure 4). `claims` (TAC13) covers the workspace's Markdown outside `foundation/`, `docs/adr/` and `docs/work/`. `trace` (TAC12) treats every `CONTEXT.md` as an agent file (call 86), so each rule line in `AGENTS.md`, `CONTEXT.md` and the contracts links `docs/workflow.md` or another workspace human doc, and every relative link and anchor in an agent file resolves. *`claims`; `trace`; `tests/test_check_trace.sh` adds a `CONTEXT.md` fixture.*
- **AC5** **Product checks run by invocation** (call 79). Product scripts find their libraries by their own location and judge the repository they run in. `foundation/bin/check` discovers checks beside itself and in the repository's `bin/checks/`, and `--paths PATHSPEC…` limits what tree checks read. The workspace's `bin/check` runs `foundation/bin/check --paths ':!foundation'` with `agents claims trace docs commits secrets never-publish scripts workflows stages setup`; `bin/setup` sets `core.hooksPath` to `foundation/.githooks`, whose hooks call the repository's `bin/check`; `.claude/settings.json` runs `foundation/.claude/hooks/*`, and the workspace's `CONTRIBUTING.md` § Agent guards links the product's. *`tests/test_check_cli.sh`: a repository check discovered, a path excluded; `bin/check --list` in the workspace.*

## 2. The stages

Scripts do every write (call 56). ICM keeps process out of code, and so does this: order and checkpoints stay in the contracts, and only the transforms are scripts, because prose cannot meet measure 5. The target is a handoff outside `output/`, a departure from ICM (call 85).

| Stage | Deterministic (script) | Orchestration (contract) | Judgment (agent) |
|---|---|---|---|
| 01-ask | `bin/ask run`, `bin/ask confirm` | checkpoint: the operator confirms the answers | drafts `NAME`, `DESCRIPTION`, `VISIBILITY`; audits the description |
| 02-render | `bin/render` | a checkpoint only before `--replace` | none |
| 03-verify | `bin/verify` | stop on failure; route to the remedy | diagnoses the failure |
| 04-publish | `bin/publish --plan`, `--apply`, `--watch` | checkpoint: a listed decider approves the plan line | presents the plan; diagnoses a failed run |

**01-ask.** Inputs: `../../shared/answers.tsv`. Process: draft the run fields from the ask; run `bin/ask run NAME FIELD=value…`; show the file. Checkpoint: the operator confirms (`bin/ask confirm NAME --by "<operator>"`) or gives edits (`bin/ask run NAME --redo …`). Audit: `DESCRIPTION` is one line meeting upstream's [writing bar](https://github.com/Okja-Engineering/ai-native-sdlc/blob/main/AGENTS.md#write-it-the-way-you-would-say-it). Outputs: `answers.env`, `confirmed.md`.
**02-render.** Inputs: `../01-ask/output/<name>/confirmed.md`. Process: `bin/render NAME`. Outputs: `render.md`.
**03-verify.** Inputs: `../02-render/output/<name>/render.md`. Process: `bin/verify NAME`. On failure, stop; the remedy follows the failure, as `docs/workflow.md` sets out: a target unlike its render, `bin/render NAME --replace`; a check, suite or audit failing on the foundation, a workspace change merged like any other, then `--replace`; failing on an answer, `bin/ask run NAME --redo`, confirm, render; a missing tool, install it and rerun 03. The target is never edited by hand. Outputs: `verify.md`.
**04-publish.** Inputs: `../03-verify/output/<name>/verify.md`. Process: `bin/publish NAME --plan`; checkpoint; `bin/publish NAME --apply "<line>" --approver "<decider>"`; `bin/publish NAME --watch`. A run may stop after 03 with a verified local repository. Outputs: `publish.md`.

- **AC6** `shared/answers.tsv` has columns `field scope render selects pattern default question`. Setup fields, with defaults (`OWNER` standing for its value): `OWNER` (`Okja-Engineering`), `DECIDERS` (`;`-separated names), `CODEOWNERS` (`@OWNER/maintainers`), `COC_CONTACT` (`not yet set, so launch waits on it`), `WORKSPACE_URL` (`https://github.com/Okja-Engineering/oss-template`), `COPYRIGHT_HOLDER` (`OWNER`), `COMMIT_IDENTITY` (`OWNER <OWNER@users.noreply.github.com>`), `TARGET_ROOT` (`~/Development/OWNER`). Run fields: `NAME` (`[a-z0-9][a-z0-9._-]*`), `DESCRIPTION` (one line), `VISIBILITY` (`public` or `private`), `LICENSE` (`apache-2.0` or `none`, selecting `LICENSE`; default `apache-2.0` when public, `none` when private; call 74). Render fields: all but `COMMIT_IDENTITY`, `TARGET_ROOT`, `VISIBILITY`. Each has a pattern. One parser, `bin/lib/answers.sh`, serves every script. *`tests/test_answers.sh`, incl. `$(touch x)` creating nothing and values with non-ASCII letters, `&`, `\` and `=` kept.*
- **AC7** `bin/ask setup FIELD=value…` rewrites `setup/answers.env`; `bin/ask questionnaire` writes `setup/questionnaire.md` from the schema, as ICM's rules ask: one flat numbered list, every question at once, each with its field, type and default. `bin/ask run NAME FIELD=value… [--redo]` writes the answers file (setup fields, run fields with their defaults, and `TARGET`, `~` expanded), sorted, LF endings; `--redo` first removes an unpublished run's target and later outputs. `bin/ask confirm NAME --by WHO` writes `confirmed.md` with who, when and the answers file's blob id. Refused, writing nothing: an unknown field; a value failing its pattern or holding a newline, `{{`, or a rule word from `foundation/bin/lib/rules.sh` (call 73); a missing field; a setup field given to `run`; an existing run without `--redo`, or `--redo` on a published one; a non-empty target. *`tests/test_ask.sh`.*
- **AC8** `setup` refuses a `setup/questionnaire.md` that differs from `bin/ask questionnaire`'s output, and a `setup/answers.env` missing a setup field or failing a pattern. *`tests/test_check_setup.sh`.*
- **AC9** `bin/render NAME [--replace]` refuses answers without a `confirmed.md` naming their blob id, then reads `foundation/` at the workspace's committed `HEAD` (call 71) through `foundation/bin/lib/tree.sh`. A verbatim file is copied byte for byte; a template has each `{{FIELD}}` replaced by its value, and a line that is exactly `- {{FIELD}}` repeated per list item; a variant is used for `PATH` when its `VALUE` equals the selecting field's; modes come from the tree. It writes the target only when absent or empty; `--replace` first empties an unpublished target that `render.md` names. Refused: a placeholder that is not a render field; a `{{[A-Z_]+}}` left after substitution; an executable template; a variant whose field selects nothing, or a selecting field with no variant for its value. `render.md` records the target, workspace SHA, answers blob id and fingerprint. *`tests/test_render.sh` on a fixture workspace.*
- **AC10** **Determinism (measure 5).** `bin/render` reads no clock, network, randomness or environment beyond its arguments, the answers file and the workspace's `HEAD`. Two renders of one answers file at one commit have the same fingerprint with `TZ`, `LC_ALL`, `HOME`, the working directory and `umask` varied. The fingerprint equals the target's tree id and is computed without creating `.git` there. No field is run-specific. *`test_render.sh`; across platforms, AC27's `m5` job.*
- **AC11** **Field effects.** Changing one render field changes exactly the product paths whose templates hold its placeholder, or that it selects; changing a non-render field changes nothing. *`test_render.sh`, every field.*
- **AC12** `bin/verify NAME` refuses unless the target's fingerprint equals `render.md`'s; then, in the target, runs `git init -b main`, `bin/setup`, a root commit `Initial commit` authored and committed as `COMMIT_IDENTITY` (call 82), `bin/check --range "" HEAD`, `tests/run-all.sh` and the email audit (AC13); requires `HEAD^{tree}` to equal the fingerprint; and records each command, exit code and the `HEAD` SHA in `verify.md`. `bin/verify NAME --check` repeats every check on a verified target without committing. *`tests/test_verify.sh` on a fixture workspace: a file edited after render refused; a planted failing check recorded; `--check` adds no commit.*
- **AC13** **Email audit** (call 63): `bin/verify` fails on an address in the rendered files other than at `example.invalid` or `users.noreply.github.com`, TAC § 3's tool signatures, or a render field's value; `git@github.com:` is not an address. *`test_verify.sh`.*
- **AC14** **Resume.** `bin/status [NAME]` prints, per run, its next step: 01 is complete when `confirmed.md` matches the answers; 02 when `render.md` names that answers blob; 03 when `verify.md` records a pass on that render; 04 when `publish.md` records a passing watch. After a failed 03 it prints that failure's remedy, never 04. *`tests/test_status.sh`, one case per state.*
- **AC15** `bin/publish NAME --plan [--ref REF]` refuses a dirty workspace, a render from a commit other than `HEAD`, a workspace SHA not reachable from REF (default: the remote default branch as last fetched; call 72), and a target failing `bin/verify --check`. It prints one line naming every outward action: create `OWNER/NAME` as VISIBILITY with its description; turn off rebase merging (decision 11); on a public repository, turn on private vulnerability reporting (decision 39); push SHA to `main`; open the first issue. *`tests/test_publish.sh`, with a stub `gh` and a fixture remote.*
- **AC16** `bin/publish NAME --apply "LINE" --approver "NAME"` refuses unless LINE equals the current plan and NAME is listed in the workspace's `GOVERNANCE.md` § Deciders (call 70). Each step reads state first, so a rerun resumes without repeating one: an existing repository passes only when empty or holding `main` at SHA; the push is never forced; the first issue, `Produced by <WORKSPACE_URL> at <workspace SHA>`, lists the render fields and the fingerprint (measure 7) and opens once. `publish.md` records the approver, the time, the line, and each step. *`test_publish.sh`: a changed plan; an unlisted approver; a failure injected after each step, then a rerun; an occupied repository.*
- **AC17** `bin/publish NAME --watch` applies measure 1's rule to the workflow runs on SHA (decisions 31, 32): it waits up to 5 minutes for a first run, then until every run is complete and none has started for 2 minutes, up to 30 minutes in all; it fails on a run concluding `failure`, `cancelled`, `timed_out`, `startup_failure` or `action_required`, on no run, or when no `check` job concluded `success`; `skipped` is not a failure. Run URLs and conclusions go in `publish.md`. *`test_publish.sh`, one case per conclusion and timing; live in gate G4.*

## 3. The foundation

- **AC18** The templates are exactly: `AGENTS.md` (what the repository is, from `DESCRIPTION`), `README.md` (`# {{NAME}}`, then `{{DESCRIPTION}}`), `GOVERNANCE.md` (§ Deciders, `- {{DECIDERS}}`), `CODE_OF_CONDUCT.md` (`{{COC_CONTACT}}`), `.github/CODEOWNERS` (`* {{CODEOWNERS}}`), `.github/ISSUE_TEMPLATE/config.yml` (`https://github.com/{{OWNER}}/{{NAME}}/…`), `docs/adr/README.md` (`{{WORKSPACE_URL}}`). The variants are `LICENSE.apache-2.0` (the Apache-2.0 text) and `LICENSE.none.tmpl` (`Copyright {{COPYRIGHT_HOLDER}}. All rights reserved.`). `foundation/bin/lib/layout.txt` names only product paths and lines no answer changes. *`test_render.sh`; `tests/m1.sh`; reading.*

## 4. Foundation content, carried from the template spec

TAC1–TAC35, TAC37–TAC41, TAC43 and contracts C1–C4 hold for the foundation, reading "generated repository" as produced repository and "as generated" as the root commit `bin/verify` makes. Everything about `bin/init`, `template-only` blocks and `tests/generation.sh` is removed: TAC36 and TAC42 are dropped, TAC27 loses its generation step, and TAC41's fixed README opening and template block give way to AC18. With these amendments:

- **AC19** **Checks are files** (call 57). Each check is an executable `bin/checks/<name>` whose second line is `# <description>` and third `# modes: <modes>`; `bin/check` runs those whose modes include the current one, with `CHECK_MODE`, `CHECK_BASE`, `CHECK_HEAD`, `CHECK_REF` and `DOCS_BASE` set, keeping TAC38's output and exit codes. *`test_check_cli.sh`: fixture checks passing, failing (exit 1), unable to run (exit 2), filtered by mode.*
- **AC20** **Judged tree** (decision 44). Checks read files only through `bin/lib/tree.sh`: from `HEAD`'s objects in range mode, the index in staged mode, the working tree in tree mode. CI checks out the head SHA with `fetch-depth: 0`; pre-push judges each pushed ref's tree. *`tests/test_tree_lib.sh`; `test_check_cli.sh`: an uncommitted edit ignored in range mode; `test_check_docs.sh`: an RFC merged to `main` after branching does not fail the branch.*
- **AC21** **Docs base** (decision 50; amends C4). With an empty or all-zero BASE, the checked commits are those reachable from `HEAD` and from no remote ref other than `CHECK_REF` (CI sets it to the pushed branch, so a repository's first push checks its root commit), and the docs base is the parent of the oldest; a root commit means none. Staged mode with no `HEAD` (the root commit being made) has no docs base. *`test_check_cli.sh`: a first push where `origin/main` equals `HEAD`; a commit on an unborn branch.*
- **AC22** **Deciders at the docs base** (decision 45; amends TAC7). Each status-line or `**Decider:**` change on a chain doc names a decider listed at the docs base, or in the tree when there is none; `guard-docs.sh` refuses an agent edit inside § Deciders. *`test_check_docs.sh`: a decider added and used in one range refused; `tests/test_claude_hooks.sh`.*
- **AC23** `guard-docs.sh` simulates `replace_all` for `Edit` and each `MultiEdit` edit (decision 46). *`test_claude_hooks.sh`, fixture `# 0007 draft-handling`.*
- **AC24** **PR template** (call 75; amends TAC23). `.github/pull_request_template.md` is upstream's file with a Summary section inserted before its `## What changed` line: `## Summary`, a blank line, a one-line comment prompt, a blank line. Removing the lines from `## Summary` up to `## What changed` gives a blob id of `c349e2c7a5bd35d293eea22e3937033b90a51879`; `layout.txt` pins it as `PATH<TAB>blob:<sha><TAB>minus:## Summary`. Once upstream carries the section, the entry pins upstream's new blob without `minus:`. `pr` requires no heading; Summary, What changed and How it was proved are required by `CONTRIBUTING.md` and counted by measure 8. *`tests/test_check_layout.sh`.*
- **AC25** **ADRs** (call 58; amends decision 17). ADRs 0001–0005 (the template plan's) and 0006 (the ICM workspace) are workspace files. A produced repository ships `docs/adr/README.md` linking them, its `CONTRIBUTING.md` § ADRs links that file (TAC40), and it numbers its own ADRs from 0001. *`docs`; `layout`.*
- **AC26** Every script exports `LC_ALL=C` before any pattern match (call 88). *`scripts` (TAC37) refuses a script without it; `test_check_scripts.sh`.*

## 5. The workspace's CI, and what is enforced

- **AC27** `.github/workflows/ci.yml` (the workspace's) runs, on Ubuntu (bash 5) and macOS (bash 3.2): `bin/check --range`, `foundation/tests/run-all.sh`, and `foundation/tests/run-all.sh tests` for the workspace's suites; job `m1` runs `tests/m1.sh` with `public.env` on Ubuntu and `private.env` on macOS; job `m5` renders both on both legs and fails unless each fixture's fingerprints agree (call 84). `pr.yml` runs `bin/check pr`. *Their runs on every slice.*

| Enforcer | Refuses | ACs |
|---|---|---|
| `stages`, `setup` | budgets; contract shape; bad Inputs; unnamed references; a stale questionnaire or setup file | AC2, AC3, AC8 |
| `agents`, `claims`, `trace` | as TAC, plus `CONTEXT.md` as an agent file | AC1, AC4 |
| `bin/ask`, `bin/render` | AC7's and AC9's cases | AC7, AC9–AC11 |
| `bin/verify` | a target unlike its render; any failing check, suite or address | AC12, AC13 |
| `bin/publish` | a dirty, moved or unreachable workspace; an unverified target; a stale line; an unlisted approver; an occupied repository; a failed run | AC15–AC17 |
| TAC § 8's checks | as listed there, with AC19–AC26 | TAC |

**Not enforced:** (1) who confirmed the answers, and whether the operator showed them first; (2) that the named approver approved: an agent can pass the decider's name (call 70); (3) that an agent loads only its stage's Inputs: `stages` checks the contracts, not the agent; (4) that the answers reflect the ask and the description meets the writing bar (stage 01's audit is the agent's); (5) `gh` commands an agent types instead of `bin/publish` (a typed push to `main` is refused by `foundation/.claude/hooks/guard-bash.sh`, TAC17); (6) a local run from an unmerged commit (only `bin/publish` refuses one); (7) the conduct contact being real; (8) relative links outside agent files (call 77); (9) TAC § 8's 22 items, for the foundation; (10) a hook killed by a signal exits 143, which blocks only on a Claude Code release honouring `onFailure`; (11) agent files under `foundation/` loading when an agent reads product files there.

## 6. Measures

- **AC28 (measure 1)** Build: `tests/m1.sh` makes a temporary worktree at `HEAD`, runs `bin/ask setup`, `run` and `confirm` with a fixture's values, then `bin/render` and `bin/verify`; it passes for both fixtures (AC27; call 83). GitHub half: gate G4 publishes each to a throwaway repository (ruling 13) with `--ref` naming the pull request's branch, and `--watch` passes. **Launch:** an agent's real run of each visibility passes `bin/verify` and `--watch`.
- **AC29 (measure 2)** TAC43 holds, and every refusal AC2–AC17 lists has a fixture case in the suite named.
- **AC30 (measure 3, launch)** In a clean environment (intent, measure 3), an agent given only the workspace and "create a repository called X" completes 01 to 04, stopping at both checkpoints and taking no reserved decision; the produced-repository half is TAC44's. The decider writes the rubric before the first run and keeps it outside the workspace (call 66).
- **Measure 4:** AC4; TAC13 in each produced repository, run by `bin/verify`. **Measure 5:** AC10, AC11, AC27's `m5`. **Measures 6–8:** TAC44's (its M5–M7); measure 7 counts the first issue AC16 opens.

## 7. Earlier decisions

Decisions 1–8, 10–12, 14, 16, 19–28, 30, 32–46, 49 and 50 hold, reading "generated" as produced and "the build PR" as the slices' pull requests into `main`. Amended: 13 (by 45), 15 (ADR numbering, by 58), 29 (generation becomes `tests/m1.sh`, call 83), 31 (by 50), 41 (the team is the `CODEOWNERS` answer), 47 and 48 (by 77). Superseded: 9 (by 64), 17 (by 58), 18 (render replaces `bin/init`). Calls 51, 62, 65 and 67 are superseded by the first workspace review (calls 68–77).

## Reserved for the decider (launch items; none blocks the build)

1. The conduct contact (`COC_CONTACT`). 2. The `maintainers` team. 3. Hooks re-verified on the current Claude Code release. 4. The rollout settings in `plan.md`. 5. The measure 3 rubric. 6. The repository's name. 7. The licence policy: call 74's default holds until he decides.
