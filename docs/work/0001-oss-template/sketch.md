# Sketch: an ICM workspace that creates an Okja repository

For reaction, not a spec. 2026-11-22. Rests on the amended intent (ruling 14). The old template spec's content becomes `foundation/`.

```
AGENTS.md          L0. Okja's AGENTS.md rendered for this repo; its "This repository" section says "to create a repo, read CONTEXT.md"
CLAUDE.md          exactly `@AGENTS.md` (decision 1 stands; no second router)
CONTEXT.md         L1. ICM's router content lives here: folder map, stage routing, what to load per stage
setup/questionnaire.md  once per workspace: owner, deciders, CoC contact, licence holder, target root -> setup/answers.env
foundation/        L3. The produced repo's tree verbatim, {{PLACEHOLDERS}} in docs/config only (never scripts); manifest.txt
shared/            L3. answers schema, run-specific field list, M3 rubric, upstream pins (PR template blob)
bin/ .githooks/ .github/ docs/ tests/   this repo's own Okja foundation (rendered), plus bin/render, bin/verify, bin/publish
stages/01-ask  02-render  03-verify  04-publish   each: CONTEXT.md, references/, output/<repo-name>/ (gitignored)
```

## Stages
**01-ask.** Reads the one-line ask, `setup/answers.env`, the schema. Writes `output/<name>/answers.env` (name, description, visibility, year; derived fields filled, not asked).
Checkpoint: the operator confirms or edits the answers; nothing is created before this. Audit: `bin/render --check-answers` passes; target dir absent or empty.

**02-render.** Reads answers + `foundation/`. Writes the tree to `<target root>/<name>/` and `output/<name>/render.sha256`.
Checkpoint: none (a script, no choices). Audit: a second render to a temp dir is byte-identical; no `{{` left; every manifest path present with its mode.

**03-verify.** Reads the target, `render.sha256`. Writes `git init -b main`, `bin/setup`, root commit `Initial commit`; `output/<name>/verify.md` (commands, exit codes, SHA).
Checkpoint: none on pass. On fail, stop: the fix is a workspace PR to `foundation/`, then re-run 02. The target is never hand-edited.
Audit: HEAD's tree matches `render.sha256` (catches hand-patching); `bin/check --range "" HEAD` and `tests/run-all.sh` exit 0.

**04-publish.** Reads `verify.md`, answers. Writes the GitHub repo, a push of the verified SHA, settings a template couldn't set (rebase merge off; private vulnerability reporting on public), a first issue recording workspace SHA + answers (M7), `publish.md`.
Checkpoint: the person approves "create OWNER/NAME, VISIBILITY, push SHA X". A run may stop after 03 with a verified local repo.
Audit: pushed SHA = verified SHA; `bin/publish --watch` applies M1's run rules on that SHA (decisions 31, 32).

## Where determinism comes from
- **Scripted:** render (a pure function of `foundation/` + answers: no clock, no network; the year is an answer), verify, publish's `gh` calls and run watch. These carry M1 and M5.
- **Agent judgment:** drafting answers from the ask, presenting checkpoints, diagnosing a failure and proposing a `foundation/` fix. No judgment writes a produced file, so same answers give same files by construction.
- **Proof, in the workspace's CI:** fixed answers (`tests/answers/{public,private}.env`) render twice and diff empty; one changed answer moves only listed run-specific fields; both verify (M1 and M5 build-PR gates).
- **ICM tension, stated:** ICM says don't write process into code. Sequence and checkpoints stay in markdown; only the transforms are scripts, because prose can't hit M5.
- **Subtracted from the old spec:** `bin/init`, `template-only` blocks, `tests/generation.sh`, the delete-the-work-folder logic. Render replaces all four; the old ACs move nearly whole into `foundation/`.

## Where it lands, and dogfooding
- The target is `<target root>/<name>/` (default `~/Development/<owner>/`), outside the workspace, never nested. `output/` holds reports and pointers, not the repo.
- GitHub creation is stage 04, behind its own checkpoint.
- The workspace is itself an Okja repo: its root foundation files equal `bin/render` of `foundation/` with `setup/self.answers.env`; a `self-render` check in its `bin/check` fails on drift. AGENTS.md's routing line comes from the "This repository" section every produced repo already fills (old AC11), so it's no special case.

## Forks (recommended default first)
1. **Scripts plus agent** vs agent-only. Agent-only can't meet M5, and the intent already gates the build PR on a scripted run. The live sub-question: publish as `bin/publish` (default) or agent-typed `gh` commands.
2. **One run per repo** vs a standing operator session. State lives only in `stages/*/output/<name>/`, so any new session resumes from files; a looping session adds nothing.
3. **Retrofit later** vs a stage now. It's an intent non-goal; v1 refuses a non-empty target. A later stage can diff a render against an existing tree using the same hash manifest.
4. **No agent "adapt" stage in v1** (stack, prose) vs one now. Anything an agent writes into the produced repo breaks M5 unless the field is listed as run-specific.

## Risks
- **Most likely to break:** the M1 run watch on private repos and first pushes (skipped runs, no docs base). It's carried over, but now runs live in 04 rather than in a one-off build check.
- **Self-render** makes every foundation change touch two places in one PR. That's deliberate but noisy, and the workspace's `layout`/`claims` checks must know `foundation/` is a template, not this repo's own docs.
- **Bolt-on pressure:** an agent "just fixing" the target when verify fails. 03's hash audit makes that detectable, not merely discouraged.
- **Intent wording:** "questionnaire answers" is two files here (setup plus per-run), so the spec must define M5 over both. `oss-template` no longer fits as a name; renaming is the decider's call.
