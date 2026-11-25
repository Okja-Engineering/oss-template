# 01-ask

Draft a run's answers, have the operator confirm them, and record them with `bin/ask` ([docs/workflow.md](../../docs/workflow.md#01-ask-the-answers)).

## Inputs

| Source | File/Location | Section/Scope | Why |
|---|---|---|---|
| the workspace | `../../shared/answers.tsv` | the fields of scope run | each field's type, default and question |

## Process

1. Draft the run fields from the ask: `NAME`, the repository's name, and each other run field the schema lists, from its question and type. Leave a field with a default to it unless the ask says otherwise.
2. Run `bin/ask run NAME FIELD=value…`. It writes `output/NAME/answers.env`, or refuses with the reason ([docs/workflow.md](../../docs/workflow.md#01-ask-the-answers)); fix the value and run it again.
3. Show the operator the answers file.

## Checkpoints

- The operator confirms the answers: run `bin/ask confirm NAME --by "<operator>"`. Or the operator gives edits.
- For edits, run `bin/ask run NAME --redo FIELD=value…`. If it refuses because the target `render.md` names is present, it prints that path: ask the operator "remove <that path>", and only with their yes run `bin/ask run NAME --redo --remove "<that path>" FIELD=value…`; without it, stop and leave the target alone ([docs/workflow.md](../../docs/workflow.md#redoing-a-run)). Then the operator confirms again.

## Audit

- `DESCRIPTION`, once the schema holds it, is one line meeting the writing bar of the upstream AI-native SDLC process: write it the way you would say it.

## Outputs

- `answers.env`, the answers, one FIELD=value a line
- `confirmed.md`, who confirmed them, when, and the answers file's blob id
