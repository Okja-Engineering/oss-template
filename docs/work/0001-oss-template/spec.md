# 0001 oss-template: spec

**Status:** draft. **Decider:** Matthew Van Dusen. **Rests on:** [`intent.md`](intent.md), [`decisions.md`](decisions.md), [`research.md`](research.md).

What the workspace does, stated so each line can be checked. Each acceptance criterion (AC) names its proof: a `bin/check` check, a suite under `tests/`, or a person reading. Unmarked ACs gate the pull request into `main`; **launch** ACs gate launch. "Ruling N", "decision N" and "call N" cite [`decisions.md`](decisions.md). "TAC N" cites AC N of the superseded template spec (`git show b368d09:docs/work/0001-oss-template/spec.md`), whose foundation ACs this spec carries by reference (§ 4).

## Terms

- **Workspace:** this repository. **Run:** one pass through the stages for one repository name. **Produced repository:** what a run makes. **Target:** the directory a run renders into, `<TARGET_ROOT>/<NAME>`, outside the workspace. **Operator:** the person deciding at a run's checkpoints.
- **Answers file:** a run's `stages/01-ask/output/<name>/answers.env`, one `FIELD=value` per line, read as data and never sourced. **Render fields** reach the produced tree; `TARGET_ROOT`, `TARGET` and `VISIBILITY` steer scripts only.
- **Foundation:** the produced repository's files, the `product` entries of `shared/manifest.txt`. A **template** is `foundation/<path>.tmpl`; every other product file is **verbatim**, shipped from the workspace's own `<path>` (calls 51, 52).
- **Fingerprint:** the git tree id of a rendered tree, file modes included (call 53).
- **Share** (ruling 15): a step is **deterministic** (a script), **orchestration** (the contract's order and checkpoints) or **judgment** (the agent).
- **Reserved decisions:** TAC's, plus approving a run's publish plan and changing `GOVERNANCE.md` § Deciders (decision 45).

## 1. Shape and disclosure

```
AGENTS.md  CLAUDE.md     L0, always on. Rendered foundation files, as in any produced repository. AGENTS.md's
                         "what this repository is" line is the workspace's description: "to create a repository, read CONTEXT.md"
CONTEXT.md               L1, on entry: purpose, folder map, task routing, what each stage loads
setup/                   questionnaire.md (once per workspace); answers.env (setup fields); self.env (this repository's run fields)
shared/                  answers.tsv (the field schema); manifest.txt (every tracked file: product or workspace)
foundation/              templates only (*.tmpl); placeholders in docs and config, never in scripts
stages/NN-slug/          01-ask 02-render 03-verify 04-publish: CONTEXT.md, references/, output/ (tracked: only its .gitignore)
bin/ tests/ .claude/ .githooks/ .github/ docs/   the workspace's own Okja foundation (the verbatim product files), plus the
                         workspace-only bin/{ask,render,verify,publish}, bin/lib/answers.sh, bin/checks/{stages,foundation}, their suites, docs/work/, the ADRs in docs/adr/
```

| Loaded | Files | Budget (call 64) |
|---|---|---|
| Always | `CLAUDE.md`, which imports `AGENTS.md` | `CLAUDE.md` exactly `@AGENTS.md`; `AGENTS.md` ≤ 80 lines |
| On entry | `CONTEXT.md` | ≤ 60 lines |
| Per stage | that stage's `CONTEXT.md`, then only the files its Inputs name | ≤ 80 lines per contract |
| By scripts only | `foundation/`, `shared/manifest.txt`, `setup/self.env` | none |

Produced repositories follow the same pattern: a short `AGENTS.md` (AC1), rules scoped by path (TAC14), skills and the reviewer loaded on demand (TAC20, TAC21).

- **AC1** `CLAUDE.md` is exactly `@AGENTS.md` and `AGENTS.md` is at most 80 lines, in the workspace and every produced repository (TAC10, its 100 lowered by ruling 16). *`agents`.*
- **AC2** `stages` refuses: `CONTEXT.md` over 60 lines, or a routing table that does not name each `stages/NN-slug/` exactly once; a stage folder not matching `NN-[a-z]+(-[a-z]+)*` or lacking `CONTEXT.md`, `references/` or `output/.gitignore`; an `output/.gitignore` other than `*` and `!.gitignore`; any other tracked file under `output/`; a contract over 80 lines, or without `## Inputs`, `## Process` and `## Outputs`, with optional `## Checkpoints` and `## Audit` between the last two, in that order. *`tests/test_check_stages.sh`: one planted case each.*
- **AC3** **Inputs discipline** (ruling 16). Each Inputs row names one file in backticks, relative to its stage folder, that resolves to a tracked file or is `../NN-slug/output/<name>/FILE` listed in an earlier stage's Outputs. `stages` refuses a directory, a glob, an unresolved path, an input from the same or a later stage, and a file in `references/` that its stage's Inputs do not name. *`test_check_stages.sh`.*
- **AC4** Measure 4 in the workspace: `claims` (TAC13) covers `CONTEXT.md`, the contracts and `setup/questionnaire.md`. Templates are judged once rendered (AC16, AC27). *`claims`.*

## 2. The stages

Scripts do every write (call 56). ICM keeps process out of code, and so does this: order and checkpoints stay in the contracts, and only the transforms are scripts, because prose cannot meet measure 5. A run's state is its output files: in a new session, the latest stage holding `output/<name>/` names the next.

| Stage | Deterministic (script) | Orchestration (contract) | Judgment (agent) |
|---|---|---|---|
| 01-ask | `bin/ask run` validates and writes the answers | checkpoint: the operator confirms the answers | drafts `NAME`, `DESCRIPTION`, `VISIBILITY` from the ask |
| 02-render | `bin/render` writes the target and `render.md` | none, except before `--replace` | none |
| 03-verify | `bin/verify` commits and checks | stop on failure; no checkpoint on pass | diagnoses a failure, proposes a foundation change |
| 04-publish | `bin/publish --plan`, `--apply`, `--watch` | checkpoint: the operator approves the plan line | presents the plan; diagnoses a failed run |

**01-ask.** Inputs: `../../shared/answers.tsv`. Process: draft the run fields from the ask; run `bin/ask run NAME FIELD=value…`; show the file. Checkpoint: the operator confirms, or gives edits, which re-run `bin/ask`. Nothing outside `output/` exists yet. Outputs: `output/<name>/answers.env`.
**02-render.** Inputs: `../01-ask/output/<name>/answers.env`. Process: `bin/render NAME`. Outputs: `output/<name>/render.md`.
**03-verify.** Inputs: `../02-render/output/<name>/render.md`. Process: `bin/verify NAME`. On failure, stop and diagnose: the fix is a change to the workspace, merged like any other, then a rerun from 02 with `--replace`. The target is never edited by hand; `bin/verify` refuses one that differs from its render. Outputs: `output/<name>/verify.md`.
**04-publish.** Inputs: `../03-verify/output/<name>/verify.md`. Process: `bin/publish NAME --plan`; checkpoint; `bin/publish NAME --apply "<plan line>"`; `bin/publish NAME --watch`. A run may stop after 03 with a verified local repository. Outputs: `output/<name>/publish.md`.

- **AC5** `shared/answers.tsv` has columns `field scope render pattern default question`, scope `setup` or `run`. Setup fields: `OWNER`, `DECIDERS` (`;`-separated names), `CODEOWNERS`, `COC_CONTACT`, `WORKSPACE_URL`, `TARGET_ROOT`. Run fields: `NAME` (`[a-z0-9][a-z0-9._-]*`), `DESCRIPTION` (one line), `VISIBILITY` (`public` or `private`). Every field but `TARGET_ROOT` and `VISIBILITY` is a render field. One parser, `bin/lib/answers.sh`, serves `bin/ask`, `bin/render` and `foundation`. *`tests/test_answers.sh`, incl. a value `$(touch x)` that creates nothing.*
- **AC6** `bin/ask setup FIELD=value…` rewrites `setup/answers.env`. `bin/ask run NAME FIELD=value…` writes the answers file: every setup field, every run field (its default when not given), and `TARGET` (`TARGET_ROOT` with a leading `~` expanded, then `/NAME`), sorted by field, LF endings. Refused, writing nothing: an unknown field; a value failing its pattern or holding a newline or `{{`; a missing required field; a setup field given to `run`; an existing `output/NAME/` without `--replace`; a non-empty `TARGET`. *`tests/test_ask.sh`.*
- **AC7** `bin/render NAME [--source HEAD|index|worktree] [--replace]` reads each product path from the workspace at the source (default `HEAD`, call 54) through `bin/lib/tree.sh`, the reader every check uses (AC19). A template has each `{{FIELD}}` replaced by its value, and a line that is exactly `- {{FIELD}}` repeated per list item (call 60); a verbatim file is copied byte for byte; modes come from the source. It writes the target only when absent or empty; `--replace` first empties a target only when `render.md` names it and no `publish.md` exists. Refused: a placeholder that is not a render field; a `{{[A-Z_]+}}` left after substitution; an executable template; a product path with no source. `render.md` records the target, workspace SHA, source, the answers file's blob id and the fingerprint. *`tests/test_render.sh`.*
- **AC8** **Determinism (measure 5).** `bin/render` reads no clock, network, randomness or environment beyond its arguments, the answers file and the workspace. Two renders of one answers file at one workspace commit have the same fingerprint with `TZ`, `LC_ALL`, `HOME`, the working directory and `umask` varied between them. The fingerprint equals the target's tree id and is computed without creating `.git` in the target. No field is run-specific (call 65). *`test_render.sh`.*
- **AC9** **Field effects.** Changing one render field in a fixture answers file changes exactly the product paths whose templates hold its placeholder (`git diff-tree` of the two fingerprints); changing `TARGET` or `VISIBILITY` changes nothing. *`test_render.sh`, every field, both fixtures.*
- **AC10** `bin/verify NAME` refuses unless the target's fingerprint equals `render.md`'s; then, in the target, runs `git init -b main`, `bin/setup`, a root commit `Initial commit`, `bin/check --range "" HEAD` and `tests/run-all.sh`, and the email audit (AC11); requires `HEAD^{tree}` to equal the fingerprint; and records each command, exit code and the `HEAD` SHA in `verify.md`. Exit 0 only when all pass. A rerun on a verified target checks again without committing. *`tests/test_verify.sh`: a file edited after render refused; a planted failing check fails and is recorded; a rerun adds no commit.*
- **AC11** **Email audit** (call 63; decision 47): `bin/verify` fails on an address in the rendered files other than at `example.invalid` or `users.noreply.github.com`, TAC § 3's tool signatures, or a render field's value; `git@github.com:` is not an address. *`test_verify.sh`: planted address refused; each allowed form passes.*
- **AC12** `bin/publish NAME --plan` prints the one line `create OWNER/NAME VISIBILITY; push SHA to main`, after checking that `verify.md` passed, the target's `HEAD` is its SHA with the fingerprint as tree, and `render.md`'s workspace SHA is an ancestor of the workspace's remote default branch as last fetched. Otherwise it refuses. *`tests/test_publish.sh`, with a stub `gh` and a fixture remote.*
- **AC13** `bin/publish NAME --apply "LINE"` refuses unless `LINE` equals the current plan, then runs these steps, each reading state first so a rerun resumes without repeating one (call 59): create the repository with its visibility and description (an existing one passes only when empty or holding `main` at SHA); turn off rebase merging (decision 11); on a public repository, turn on private vulnerability reporting (decision 39); add `origin`; push SHA to `main`, never forced; open, once, the first issue `Produced by <WORKSPACE_URL> at <workspace SHA>` listing the render fields and the fingerprint (measure 7). Each step's result goes in `publish.md`. *`test_publish.sh`: a changed plan; a failure injected after each step, then a rerun; an occupied repository.*
- **AC14** `bin/publish NAME --watch` applies measure 1's rule to the workflow runs on SHA (decisions 31, 32): it waits until all complete, up to 30 minutes, and fails on a run concluding `failure`, `cancelled`, `timed_out`, `startup_failure` or `action_required`, on no run, or when no `check` job concluded `success`; `skipped` is not a failure. Run URLs and conclusions go in `publish.md`. *`test_publish.sh`, one case per conclusion; live in gate G4.*

## 3. The foundation and the workspace's own checks

The workspace is itself an Okja repository: it runs every shipped check plus its own `stages` and `foundation`, its CI is the shipped `ci.yml`, and its suites run in `tests/run-all.sh`. Changing the foundation is a workspace change under its own `CONTRIBUTING.md`: edit the template or the verbatim file, and the rendered root copy of a template, in one pull request.

- **AC15** `foundation` refuses: a tracked file matching no line, or more than one, of `shared/manifest.txt` (`product PATH`, exact; `workspace GLOB`); a product path with no source, the source being `foundation/PATH.tmpl` when it exists and `PATH` otherwise; a file in `foundation/` that is not the `.tmpl` of a product path; an executable template. *`tests/test_check_foundation.sh`.*
- **AC16** **Self-render.** `foundation` renders `setup/answers.env` merged with `setup/self.env` from the source its mode judges (range: `HEAD`; staged: the index; tree: the working tree) and refuses each product path whose render differs from the workspace's file. Verbatim files match by construction, so this judges templates. Run on both CI legs against committed files, it is also measure 5's proof across platforms (call 62). *`test_check_foundation.sh`: planted drift in a fixture workspace.*
- **AC17** The templated product files are exactly: `AGENTS.md` (`{{DESCRIPTION}}` as what the repository is), `README.md` (`# {{NAME}}`, then `{{DESCRIPTION}}`), `GOVERNANCE.md` (§ Deciders `- {{DECIDERS}}`), `CODE_OF_CONDUCT.md` (`{{COC_CONTACT}}`), `.github/CODEOWNERS` (`* {{CODEOWNERS}}`), `.github/ISSUE_TEMPLATE/config.yml` (`https://github.com/{{OWNER}}/{{NAME}}/…`), `docs/adr/README.md` (`{{WORKSPACE_URL}}`). *`foundation`; reading.*

## 4. Foundation content, carried from the template spec

TAC1–TAC35, TAC37–TAC41, TAC43 and contracts C1–C4 hold for the foundation, reading "generated repository" as produced repository and "as generated" as the root commit `bin/verify` makes. Everything about `bin/init`, `template-only` blocks and `tests/generation.sh` is removed: TAC36 and TAC42 are dropped, TAC27 loses its generation step, and TAC41's fixed README opening and template block give way to AC17. With these amendments:

- **AC18** **Checks are files** (call 57). Each check is an executable `bin/checks/<name>` whose second line is `# <description>` and third `# modes: <modes>`. `bin/check` runs those whose modes include the current one, with `CHECK_MODE`, `CHECK_BASE`, `CHECK_HEAD` and `DOCS_BASE` set, keeping TAC38's output and exit codes. *`tests/test_check_cli.sh`: fixture checks passing, failing (exit 1), unable to run (exit 2), and filtered by mode.*
- **AC19** **Judged tree** (decision 44). Checks read files only through `bin/lib/tree.sh`: from `HEAD`'s objects in range mode, the index in staged mode, the working tree in tree mode. CI checks out the head SHA with `fetch-depth: 0`; pre-push judges each pushed ref's tree. *`tests/test_tree_lib.sh`; `test_check_cli.sh`: an uncommitted edit ignored in range mode; `test_check_docs.sh`: an RFC merged to `main` after branching does not fail the branch.*
- **AC20** **Docs base** (decision 50; amends C4). With an empty or all-zero BASE, the checked commits are those reachable from `HEAD` and from no remote ref, and the docs base is the parent of the oldest; when that is a root commit there is none. *`test_check_cli.sh`.*
- **AC21** **Deciders at the docs base** (decision 45; amends TAC7). Each status-line or `**Decider:**` change on a chain doc names a decider listed at the docs base, or in the tree when there is none; `guard-docs.sh` refuses an agent edit inside § Deciders. *`test_check_docs.sh`: a decider added and used in one range refused; `tests/test_claude_hooks.sh`.*
- **AC22** `guard-docs.sh` simulates `replace_all` for `Edit` and each `MultiEdit` edit (decision 46). *`test_claude_hooks.sh`, fixture `# 0007 draft-handling`.*
- **AC23** `links` refuses a relative link or `#anchor` that does not resolve, in tracked Markdown outside `docs/adr/`, `docs/work/` and `CHANGELOG.md` (decision 47). One resolver, `bin/lib/links.sh`, serves `links` and `trace` (TAC12). *`tests/test_check_links.sh`: missing file, missing anchor; a link in a code span passes.*
- **AC24** **Bash versions** (decision 48): a suite that tests bash behaviour runs under `/bin/bash` and under the first `bash` on `PATH` when their major versions differ, and skips a missing one with a notice. *`tests/lib/bashes.sh`; both CI legs.*
- **AC25** **PR template pin.** `.github/pull_request_template.md` is `## Summary`, one prompt line, a blank line, then upstream's file verbatim from line 4. `bin/lib/layout.txt` pins it as `PATH<TAB>blob@4:<sha>`, the blob id of lines 4 to the end (TAC23, TAC39). `pr` requires no heading: Summary, What changed and How it was proved are required by `CONTRIBUTING.md` and counted by measure 8. *`tests/test_check_layout.sh`.*
- **AC26** **ADRs** (call 58; amends decision 17). The ADRs the template plan wrote (0001–0005) are the workspace's own files. A produced repository ships `docs/adr/README.md` linking them, and `CONTRIBUTING.md` § ADRs links that file rather than listing them (TAC40); it numbers its own from 0001. *`foundation`; `docs`; `layout`.*

## 5. What is enforced, and what is not

| Enforcer | Refuses | ACs |
|---|---|---|
| `stages` | budgets; contract shape; Inputs that are globs, directories, unresolved or not earlier; unnamed references | AC2, AC3 |
| `foundation` | unclassified files; product paths without one source; stray or executable templates; self-render drift | AC15, AC16 |
| `agents`, `links` | AC1 and TAC's `agents` cases; unresolved links | AC1, AC23 |
| `bin/ask`, `bin/render` | the cases AC6 and AC7 list | AC6–AC9 |
| `bin/verify` | a target unlike its render; any failing check, suite or address | AC10, AC11 |
| `bin/publish` | an unverified or unmerged run; a stale plan line; an occupied repository; a failed run | AC12–AC14 |
| TAC § 8's checks | as listed there, with AC18–AC25 | TAC |

**Not enforced:** (1) that the agent stops at a checkpoint, or that a person rather than the agent approved one: `--apply` proves only that the line matched the current plan (call 59); (2) that an agent loads only its stage's Inputs: `stages` checks the contracts, not the agent; (3) that drafted answers reflect the ask; (4) `gh` commands an agent types instead of `bin/publish` (a typed push to `main` is refused by `.claude/hooks/guard-bash.sh`, TAC17); (5) a local run from an unmerged workspace commit (only `bin/publish` refuses one); (6) the conduct contact being real; (7) TAC § 8's 22 items, for the foundation; (8) a hook killed by a signal exits 143, which blocks only on a Claude Code release honouring `onFailure`.

## 6. Measures

- **AC27 (measure 1)** Build: `test_verify.sh` renders `tests/answers/public.env` and `tests/answers/private.env` and verifies both, on both CI legs. GitHub half: gate G4 (plan) publishes one of each to a throwaway repository (ruling 13) and `--watch` passes. **Launch:** an agent's real run of each visibility passes `bin/verify` and `--watch`.
- **AC28 (measure 2)** TAC43 holds. Every refusal AC2–AC16 lists has a planted case, and the suites pass unusual legitimate input: answers with non-ASCII letters, `&`, `\` and `=`.
- **AC29 (measure 3, launch)** In a clean environment (intent, measure 3), an agent given only the workspace and "create a repository called X" completes 01 to 04, stopping at both checkpoints and taking no reserved decision; the produced-repository half is TAC44's. The decider writes the rubric before the first run and keeps it outside the workspace (call 66).
- **Measure 4:** AC4 here; TAC13 in each produced repository, run by `bin/verify`. **Measure 5:** AC8, AC9, AC16. **Measures 6–8:** TAC44's cold reader, use and PR-template counts hold; measure 7 counts the first issue AC13 opens.

## 7. Earlier decisions

Decisions 1–8, 10–12, 14–16, 19–28, 30 and 32–43 hold, reading "generated" as produced and "the build PR" as the pull request into `main`. Amended: 13 (by 45, AC21), 17 (by 58), 29 (the generation script becomes `test_verify.sh`, a suite reading fixture answers), 31 (by 50), 41 (the team is the `CODEOWNERS` answer; Okja's value is unchanged). Superseded: 9 (by 64), 18 (render replaces `bin/init`).

## Reserved for the decider (launch items; none blocks the build)

1. The conduct contact: the `COC_CONTACT` setup answer reads "not yet set; this blocks launch" until he sets it. 2. The `maintainers` team. 3. Hooks re-verified on the current Claude Code release. 4. The rollout settings in `plan.md`. 5. The measure 3 rubric. 6. The repository's name. 7. Whether private produced repositories keep the Apache-2.0 `LICENSE` every produced repository gets, as under the template.
