# oss-template

A workspace an agent runs to create a new Okja repository. You answer a short questionnaire, the agent works through four stages, and you decide at each checkpoint. Every repository it produces, private or public, starts from the same self-checking foundation.

## Status

Pre-launch. The workspace is being built in ten slices, and until the last one merges and the live check passes, `main` may hold an incomplete foundation. [docs/workflow.md](docs/workflow.md#status) says what can run today.

## How it works

A run goes through four stages, each a folder under `stages/` with a short contract an agent follows: ask (the answers), render (the files), verify (the checks, then the first commit) and publish (the repository on GitHub). Scripts do every write; the agent drafts answers, presents each checkpoint and explains failures; you make the calls. [docs/workflow.md](docs/workflow.md) describes each stage and checkpoint.

## Getting started

```
bin/setup                     # point git at .githooks/, once per clone
bin/check                     # run the workspace's checks
bin/check --list              # list them
tests/run-all.sh              # run the workspace's suites
foundation/tests/run-all.sh   # run the product's suites
```

You need bash 3.2 or later, git and the usual POSIX tools. `shellcheck` is optional on your machine.

## Layout

- `foundation/` is the product: every file a produced repository gets, scripts and checks included. Nothing outside it reaches a produced repository.
- `bin/`, `tests/` and `.githooks/` are the workspace's own scripts, suites and git hooks. They reuse the product's libraries in `foundation/bin/lib/` and `foundation/tests/lib/`.
- `docs/workflow.md` explains the workflow; `docs/work/` holds the work folders that plan the workspace.

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) explains how a change lands, and [GOVERNANCE.md](GOVERNANCE.md) who decides.

## Licence

Apache-2.0; see [LICENSE](LICENSE).
