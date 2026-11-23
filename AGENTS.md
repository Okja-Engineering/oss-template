# oss-template workspace

This repository is a workspace: an agent runs it to create a new Okja repository, and a person decides at each checkpoint. It is pre-launch, and no stage runs yet ([docs/workflow.md](docs/workflow.md#status)).

## Running the workflow

Start from [CONTEXT.md](CONTEXT.md), which routes a request to its stage. In a stage, load its `CONTEXT.md` and only the files its Inputs name. Scripts do every write; you draft answers, present each checkpoint and explain failures ([docs/workflow.md](docs/workflow.md#stages)).

## Changing the workspace

- `foundation/` is the product, everything a produced repository gets; the rest is the workspace ([README.md](README.md#layout)).
- Write the failing test first and see it fail ([CONTRIBUTING.md](CONTRIBUTING.md#tests)).
- Before you push, run `bin/check`, `tests/run-all.sh` and `foundation/tests/run-all.sh` ([CONTRIBUTING.md](CONTRIBUTING.md#checks)).
- Commit subjects and tool credit: [CONTRIBUTING.md](CONTRIBUTING.md#commits).

## Reserved decisions

Do not take a reserved decision: accepting a document, approving a pull request or a publish plan, or changing the deciders. A listed decider makes them ([GOVERNANCE.md](GOVERNANCE.md#reserved-decisions)).
