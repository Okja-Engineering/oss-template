# Contributing

This workspace follows Okja's [AI-native SDLC](https://github.com/Okja-Engineering/ai-native-sdlc) and adds what this file says. [GOVERNANCE.md](GOVERNANCE.md) says who decides.

## How a change lands

Every change goes through a pull request into `main`. A pull request merges once a decider listed in [GOVERNANCE.md § Deciders](GOVERNANCE.md#deciders) has acked its current head ([§ Approval](GOVERNANCE.md#approval)) and its CI passes. A change bigger than one pull request is planned in a work folder under `docs/work/` and delivered in slices, one pull request each.

## Commits

Subjects follow upstream's [convention](https://github.com/Okja-Engineering/ai-native-sdlc/blob/main/AGENTS.md#commits): `type(scope): subject`, types `feat`, `fix`, `docs`, `refactor`, `test` and `chore`, at most 72 characters. Commits and pull requests carry no tool credit. These are not enforced until the workspace's `commits` and `pr` checks land.

## Tests

Write the failing test first and see it fail for the reason you expect. The workspace's suites live in `tests/` and the product's in `foundation/tests/`; each runs with its `run-all.sh`. Every suite builds its own fixtures in a temporary directory and reads nothing else from the workspace.

## Checks

`bin/check` runs the workspace's own checks, the files in `bin/checks/`. Each is a thin caller of the product's libraries in `foundation/bin/lib/`, given explicit parameters; the workspace never runs a product check on its own tree, since `bin/check` looks only in `bin/checks/`.

## Git hooks

Run `bin/setup` once per clone: it points git at `.githooks/`, whose `commit-msg`, `pre-commit` and `pre-push` hooks call `bin/check`. `pre-push` judges each pushed ref's own commits and tree, not your working tree. `git commit --no-verify` and `git push --no-verify` skip the hooks.

## Agent guards

`.claude/settings.json` denies agents these reads:

- `Read(**/.env)`
- `Read(**/.env.*)`

Claude Code applies the list; the workspace has no command guard of its own.

## What is enforced

| Enforcer | What it stops | When |
|---|---|---|
| `.githooks/commit-msg`, `.githooks/pre-commit`, `.githooks/pre-push` | whatever `bin/check` refuses | at commit and at push, after `bin/setup` |
| `bin/check disclosure` | `CLAUDE.md` other than `@AGENTS.md`; `AGENTS.md` over 80 lines or `CONTEXT.md` over 60; a stage folder, routing table or contract out of shape; an Inputs row that is not one earlier, existing file; an unnamed reference | in `bin/check`, so in the hooks |
| `.claude/settings.json` (Claude Code) | an agent reading a `.env` file | in Claude Code |

## What is not enforced

- The git hooks, under `--no-verify` or before `bin/setup` runs.
- Commit subjects and tool credit, until the `commits` and `pr` checks land.
- `git` and `gh` commands an agent types in the workspace: there is a deny list, not a command guard.
- Who made a reserved decision; [GOVERNANCE.md](GOVERNANCE.md#reserved-decisions) lists them.
