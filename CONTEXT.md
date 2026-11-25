# On entry

Read this first in a session that runs the workflow. It maps a request to where it starts and each stage to its contract; each contract names the files it loads ([docs/workflow.md](docs/workflow.md#stages)).

## Triggers

| Request | Where it starts | Lands in |
|---|---|---|
| create a repository called NAME | stage 01-ask | S2 |
| setup: the operator's defaults | `bin/ask setup` | S2 |
| status: what a run does next | `bin/status` | S4 |

The workspace is pre-launch: setup and stage 01 run, and the rest lands with its slice ([docs/workflow.md](docs/workflow.md#status)).

## Routing

| Stage | Contract |
|---|---|
| `stages/01-ask/` | [contract](stages/01-ask/CONTEXT.md) |
