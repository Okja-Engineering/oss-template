# 02-render

Render a confirmed run's answers into its target with `bin/render` ([docs/workflow.md](../../docs/workflow.md#02-render-the-target)).

## Inputs

| Source | File/Location | Section/Scope | Why |
|---|---|---|---|
| stage 01 | `../01-ask/output/<name>/answers.env` | the TARGET line | the target the render writes |
| stage 01 | `../01-ask/output/<name>/confirmed.md` | the whole file | whether the operator confirmed the answers |

## Process

1. Check that the run is confirmed: its `confirmed.md` is present. If not, go back to stage 01.
2. Run `bin/render NAME`. It renders `foundation/` at the workspace's committed `HEAD` into the target and writes `output/NAME/render.md`, or refuses with the reason ([docs/workflow.md](../../docs/workflow.md#02-render-the-target)). An answer it refuses goes back to stage 01 with `bin/ask run NAME --redo`; a fault in the foundation is fixed in the workspace and committed, then render runs again.
3. Show the operator the target and `render.md`.

## Checkpoints

- To render a rendered run again, after the workspace's `HEAD` moves or at the operator's ask, run `bin/render NAME --replace`. If it refuses because the target is present, also for a first render whose target a killed render left, it prints that path: ask the operator "remove <that path>", and only with their yes run `bin/render NAME --replace --remove "<that path>"`; without it, stop and leave the target alone ([docs/workflow.md](../../docs/workflow.md#replacing-a-render)).

## Outputs

- `render.md`, the target, the workspace SHA, the answers file's blob id, the fingerprint and the file list
