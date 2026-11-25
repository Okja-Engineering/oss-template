# Workflow

The human account of the workflow as planned: the stages, their checkpoints and the target. The rules for approval, publishing and redoing a run are added here with the slices that build them. The agent files link here for each workflow rule they state; the design is in [the spec](work/0001-oss-template/spec.md).

## Status

The workspace is pre-launch until its last slice (S10) merges and the live measure 1 check (G4) passes, as [the plan](work/0001-oss-template/plan.md) sets out. Until then `main` may hold an incomplete foundation, and a repository produced from it is not yet the finished product. Today setup and stages 01 and 02 run; each later stage lands with the slice that builds it.

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

`bin/ask run NAME FIELD=value…` writes the run's answers file, `stages/01-ask/output/NAME/answers.env`: every setup field from `setup/answers.env`, the run fields given or their defaults, and `TARGET`, which is exactly `TARGET_ROOT` with its `~` expanded, then `/NAME`; one `FIELD=value` a line, sorted, with LF endings. A setup field given after `--setup-override` replaces its setup value for this run only, recorded in the run's `setup.override.env`, and `setup/answers.env` stays as it was.

`bin/ask run` refuses, writing nothing: an unknown field; a value its type or pattern refuses, or one holding a newline or `{{`; a rule word or an email address in free text; a missing field; a setup field given outside `--setup-override`; an existing run without `--redo`; and a present target that no `--remove` names.

The operator confirms the answers at stage 01's checkpoint, and `bin/ask confirm NAME --by "<operator>"` records who, when and the answers file's blob id in the run's `confirmed.md`. It refuses a `TARGET` that is no longer `TARGET_ROOT`, `~` expanded under the current `HOME`, then `/NAME`, as one edited by hand or written under another `HOME`, and `bin/render` refuses it too; the answers change with `bin/ask run NAME --redo`. Who confirmed, and whether the operator saw the answers first, is not enforced.

## Redoing a run

Edits to a run go through `bin/ask run NAME --redo` with the fields that change, which also clears the run's 03 and 02 outputs and then its confirmation. As `bin/ask setup` keeps the setup answers it is not given, a redo keeps every run answer and every setup override not given again: a field given replaces its value, and an override changes only by giving it again with `--setup-override`, where giving the setup value makes it harmless. A kept answer the schema now refuses is refused, naming the field to give again. When the target that the run's `render.md` names, or, with no `render.md`, the run's `TARGET`, is present, the operator first says yes to "remove <that target>", in those words, and only then does the agent add `--remove "<that target>"`; without the yes the target is left alone. Whether the operator said yes is not enforced.

The shared discard, `bin/lib/discard.sh`, removes exactly the path `--remove` names, and only when it is an absolute path equal byte for byte to the target `render.md` names, or, with no `render.md`, to the run's `TARGET`, that target is the run's `TARGET`, and its last component is `NAME` and not a symbolic link; otherwise `bin/ask` refuses and removes nothing. It first gives the owner read, write and search permission on each directory in the target, then removes it with `rm`, and `bin/ask` refuses, naming the path, if anything remains. A published or attempted run is not to be redone; until S4 builds publishing, that is not enforced.

## 02-render: the target

`bin/render NAME` renders a confirmed run into its target, the answers file's `TARGET`. It reads its arguments, the answers file the run's `confirmed.md` names by blob id, and the schema and `foundation/` at the workspace's committed `HEAD`, and nothing else, so two renders of one answers file at one commit give the same files. A verbatim file is copied byte for byte with its mode. In a template, `PATH.tmpl`, each `{{FIELD}}` takes the render field's value, and a line that is exactly `- {{FIELD}}` is repeated for each item of a `list` field. A variant, `PATH.VALUE`, is used for `PATH` when `VALUE` is the value of the `select` field that selects `PATH`.

`bin/render` refuses, writing nothing: answers that `confirmed.md` does not name, or that the schema at `HEAD` rejects; a `TARGET` that is no longer `TARGET_ROOT`, `~` expanded under the current `HOME`, then `/NAME`; a `TARGET_ROOT` at or under any working tree of the workspace, compared as directories, not as strings; a target that is present and not an empty directory, with or without a `render.md` naming it, as one a killed render leaves, which it names with the route `bin/render NAME --replace --remove "<that target>"`; and, in the foundation, a placeholder that is not a render field, a placeholder left after substitution, an executable template, a variant that no value of its field selects, or a selecting field with no variant for its value. It renders into a private directory first.

The write is one transaction. `bin/render` makes `TARGET_ROOT`, and any directory above it that is missing, which stay as empty directories if the render then fails. It copies the render into a staging directory it makes beside the target, walks it without git, refusing unless it holds exactly the files it wrote and no entry named `.git`, and builds its git tree id, the fingerprint, in a private repository under the hermetic git of `bin/lib/git.sh`, never in the target. Then it removes an empty target, renames the staging directory to the target, and writes the run's `stages/02-render/output/NAME/render.md`, through a temporary file: the target, the workspace SHA, the answers file's blob id, the fingerprint and the file list. A failure or an interrupt removes only what that run made, so the target is left as it was, or is whole with its `render.md`; a render killed outright can leave its staging directory, `TARGET_ROOT/.NAME.render.<pid>`, which nothing reads.

## Replacing a render

A rendered run renders again only with `bin/render NAME --replace`, after the workspace's `HEAD` moves or at the operator's ask. When the target is present, the operator first says yes to "remove <that target>", in those words, and only then does the agent add `--remove "<that target>"`: `bin/render` removes it through the shared discard, as a redo does, clears the run's 03 outputs, so the next verify is a first run, and removes the old `render.md`, all before it writes, so a failure after that leaves the run unrendered. A target with no `render.md`, which a killed render leaves, is removed the same way. Whether the operator said yes is not enforced. A published or attempted run is not to be replaced; until S4 builds publishing, that is not enforced.

## The target

A run renders into `<TARGET_ROOT>/<NAME>`, outside the workspace, and the target is never edited by hand; this is not enforced until `bin/verify` lands in S3.
