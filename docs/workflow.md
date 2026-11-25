# Workflow

The human account of the workflow as planned: the stages, their checkpoints and the target. The rules for approval, publishing and redoing a run are added here with the slices that build them. The agent files link here for each workflow rule they state; the design is in [the spec](work/0001-oss-template/spec.md).

## Status

The workspace is pre-launch until its last slice (S10) merges and the live measure 1 check (G4) passes, as [the plan](work/0001-oss-template/plan.md) sets out. Until then `main` may hold an incomplete foundation, and a repository produced from it is not yet the finished product. Today no stage can run: each lands with the slice that builds it.

## Stages

A run creates one repository. It goes through four stages in order, each a folder under `stages/` whose contract an agent follows:

| Stage | What happens | Checkpoint | Lands in |
|---|---|---|---|
| 01-ask | the agent drafts the answers; `bin/ask` writes them | the operator confirms the answers, and approves removing the target before a redo | S2 |
| 02-render | `bin/render` writes the produced files into the target | only before replacing a render | S2 |
| 03-verify | `bin/verify` runs the produced repository's checks, then makes its first commit | only before a target is removed | S3 |
| 04-publish | `bin/publish` creates the repository on GitHub and pushes it | a listed decider approves the plan line; the operator decides whether to abandon an attempted run | S4 |

In a stage, an agent loads its `CONTEXT.md` and only the files its `## Inputs` table names. Scripts do every write. The agent drafts, presents each checkpoint and explains failures; the operator and the deciders make the calls. None of the stages exists yet, so these checkpoints are not enforced.

## Setup

The operator's defaults, the setup fields of `shared/answers.tsv`, live in `setup/answers.env`. `bin/ask questionnaire` writes `setup/questionnaire.md` from the schema: every setup question at once, each with its field, type and default. The operator answers them, and `bin/ask setup FIELD=value…` records the answers, keeping each field not given and filling a missing one from its default; it refuses a value the validator in `bin/lib/answers.sh` rejects, and then writes nothing. `bin/check setup` refuses a questionnaire the schema would not produce and a setup file the validator rejects.

## The target

A run renders into `<TARGET_ROOT>/<NAME>`, outside the workspace, and the target is never edited by hand; this is not enforced until `bin/verify` lands in S3.
