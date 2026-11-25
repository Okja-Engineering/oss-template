# Workflow

The human account of the workflow as planned: the stages, their checkpoints and the target. The rules for approval, publishing and redoing a run are added here with the slices that build them. The agent files link here for each workflow rule they state; the design is in [the spec](work/0001-oss-template/spec.md).

## Status

The workspace is pre-launch until its last slice (S10) merges and the live measure 1 check (G4) passes, as [the plan](work/0001-oss-template/plan.md) sets out. Until then `main` may hold an incomplete foundation, and a repository produced from it is not yet the finished product. Today setup and stage 01 run; each later stage lands with the slice that builds it.

## Stages

A run creates one repository. It goes through four stages in order, each a folder under `stages/` whose contract an agent follows:

| Stage | What happens | Checkpoint | Lands in |
|---|---|---|---|
| 01-ask | the agent drafts the answers; `bin/ask` writes them | the operator confirms the answers, and approves removing the target before a redo | S2 |
| 02-render | `bin/render` writes the produced files into the target | only before replacing a render | S2 |
| 03-verify | `bin/verify` runs the produced repository's checks, then makes its first commit | only before a target is removed | S3 |
| 04-publish | `bin/publish` creates the repository on GitHub and pushes it | a listed decider approves the plan line; the operator decides whether to abandon an attempted run | S4 |

In a stage, an agent loads its `CONTEXT.md` and only the files its `## Inputs` table names. Scripts do every write. The agent drafts, presents each checkpoint and explains failures; the operator and the deciders make the calls. The checkpoints of the stages not yet built are not enforced.

## Setup

The operator's defaults, the setup fields of `shared/answers.tsv`, live in `setup/answers.env`. `bin/ask questionnaire` writes `setup/questionnaire.md` from the schema: every setup question at once, each with its field, type and default. The operator answers them, and `bin/ask setup FIELD=value…` records the answers, keeping each field not given and filling a missing one from its default; it refuses a value the validator in `bin/lib/answers.sh` rejects, and then writes nothing. `bin/check setup` refuses a questionnaire the schema would not produce and a setup file the validator rejects.

## 01-ask: the answers

`bin/ask run NAME FIELD=value…` writes the run's answers file, `stages/01-ask/output/NAME/answers.env`: every setup field from `setup/answers.env`, the run fields given or their defaults, and `TARGET`, which is `TARGET_ROOT` with its `~` expanded, then `/NAME`; one `FIELD=value` a line, sorted, with LF endings. A setup field given after `--setup-override` replaces its setup value for this run only, recorded in the run's `setup.override.env`, and `setup/answers.env` stays as it was.

`bin/ask run` refuses, writing nothing: an unknown field; a value its type or pattern refuses, or one holding a newline or `{{`; a rule word or an email address in free text; a missing field; a setup field given outside `--setup-override`; an existing run without `--redo`; and a present target that no `--remove` names.

The operator confirms the answers at stage 01's checkpoint, and `bin/ask confirm NAME --by "<operator>"` records who, when and the answers file's blob id in the run's `confirmed.md`. Who confirmed, and whether the operator saw the answers first, is not enforced.

## Redoing a run

Edits to a run go through `bin/ask run NAME --redo` with the answers, which also clears the run's confirmation and its 02 and 03 outputs. When the target that the run's `render.md` names is present, the operator first says yes to "remove <that target>", in those words, and only then does the agent add `--remove "<that target>"`; without the yes the target is left alone. Whether the operator said yes is not enforced.

The shared discard, `bin/lib/discard.sh`, removes exactly the path `--remove` names, and only when it equals the target `render.md` names byte for byte, its last component is `NAME` and not a symbolic link, and its parent and `TARGET_ROOT`, each resolved with `pwd -P`, are one directory; otherwise `bin/ask` refuses and removes nothing. It first gives the owner read, write and search permission on each directory in the target, then removes it with `rm`, and `bin/ask` refuses, naming the path, if anything remains. A published or attempted run is not to be redone; until S4 builds publishing, that is not enforced.

## The target

A run renders into `<TARGET_ROOT>/<NAME>`, outside the workspace, and the target is never edited by hand; this is not enforced until `bin/verify` lands in S3.
