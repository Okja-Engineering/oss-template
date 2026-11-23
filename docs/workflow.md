# Workflow

The human source for every workflow rule in this workspace: the stages and their checkpoints, approval, publishing, the target, and redoing a run. The agent files link here for each rule they state; the design is in [the spec](work/0001-oss-template/spec.md).

## Status

The workspace is pre-launch until its last slice (S10) merges and the live measure 1 check (G4) passes, as [the plan](work/0001-oss-template/plan.md) sets out. Until then `main` may hold an incomplete foundation, and a repository produced from it is not yet the finished product. Today no stage can run: each lands with the slice that builds it.

## Stages

A run creates one repository. It goes through four stages in order, each a folder under `stages/` whose contract an agent follows:

| Stage | What happens | Checkpoint | Lands in |
|---|---|---|---|
| 01-ask | the agent drafts the answers; `bin/ask` writes them | the operator confirms the answers | S2 |
| 02-render | `bin/render` writes the produced files into the target | only before replacing a render | S2 |
| 03-verify | `bin/verify` runs the produced repository's checks, then makes its first commit | only when a target must be removed | S3 |
| 04-publish | `bin/publish` creates the repository on GitHub and pushes it | a listed decider approves the plan line | S4 |

Scripts do every write. The agent drafts, presents each checkpoint and explains failures; the operator and the deciders make the calls. None of the stages exists yet, so these checkpoints are not enforced.

## The target

A run renders into `<TARGET_ROOT>/<NAME>`, outside the workspace, and the target is never edited by hand; this is not enforced until `bin/verify` lands in S3.
