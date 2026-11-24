# Contributing

How a change to this workspace is made and lands. [GOVERNANCE.md](GOVERNANCE.md) says who decides.

## How a change lands

Every change goes through a pull request into `main`. A pull request merges once a decider listed in [GOVERNANCE.md § Deciders](GOVERNANCE.md#deciders) has acked its current head ([§ Approval](GOVERNANCE.md#approval)) and its CI passes, and it lands by rebase, since `main` keeps a linear history. A change bigger than one pull request is planned in a work folder under `docs/work/` and delivered in slices, one pull request each.

## Commits

Subjects take the form `type(scope): subject`, types `feat`, `fix`, `docs`, `refactor`, `test` and `chore`, at most 72 characters. Commits and pull requests carry no tool credit. These are not enforced until the workspace's `commits` and `pr` checks land.

## Tests

Write the failing test first and see it fail for the reason you expect. The workspace's suites live in `tests/` and the product's in `foundation/tests/`; each runs with its `run-all.sh`. Every suite builds its own fixtures in a temporary directory. Beyond the code under test, a suite reads from the workspace only the committed test libraries and fixtures in `tests/` and `foundation/tests/`, and git's list of the suites beside it, to check that none is missing.

## Checks

`bin/check` runs the workspace's own checks, the files in `bin/checks/`. Each reads files through the product's tree reader in `foundation/bin/lib/` and calls the product's libraries there for the product's rules, given explicit parameters; `disclosure`, for one, takes the `AGENTS.md` budget from `foundation/bin/lib/agents.sh` and adds the stage-folder rules only the workspace has. The workspace never runs a product check on its own tree, since `bin/check` looks only in `bin/checks/`.

## Git hooks

Run `bin/setup` once per clone: it points git at `.githooks/`, whose `commit-msg`, `pre-commit` and `pre-push` hooks call `bin/check`. `pre-push` judges each pushed ref's commits and tree with the checks committed at your `HEAD`: never with uncommitted edits to them, and never by running code from the ref being pushed. A ref that changes the checks themselves is judged here by today's checks, and in CI by its own. With no commit checked out (an orphan branch before its first commit), `pre-push` has no checks to take and refuses the push. `git commit --no-verify` and `git push --no-verify` skip the hooks; `.github/workflows/ci.yml` runs the same checks on every pull request and push to `main`, and `main`'s ruleset requires both of its legs to pass before a pull request merges.

## Agent guards

`.claude/settings.json` denies agents these reads:

- `Read(**/.env)`
- `Read(**/.env.*)`

Claude Code applies the list; the workspace has no command guard of its own.

## What is enforced

| Enforcer | What it stops | When |
|---|---|---|
| `.githooks/commit-msg`, `.githooks/pre-commit`, `.githooks/pre-push` | whatever `bin/check` refuses | at commit and at push, after `bin/setup` |
| `bin/check disclosure` | `CLAUDE.md` other than `@AGENTS.md`; `AGENTS.md` over 80 lines or `CONTEXT.md` over 60; a stage folder, routing table or contract out of shape; an Inputs section that is not one `| Source | File/Location | Section/Scope | Why |` table whose rows each name one file in backticks in File/Location and hold no other code span, or a row that names a directory, a glob, a path that does not resolve, a file in a later stage, an output of the same or a later stage, or an earlier stage's output its Outputs do not list; a file in `references/` its Inputs do not name | in `bin/check`, so in the hooks |
| `.claude/settings.json` (Claude Code) | Claude Code reading a `.env` or `.env.*` file at or under its working directory by name | in Claude Code |
| `.github/workflows/ci.yml`, required by `main`'s ruleset | merging a pull request that fails `bin/check --range`, either suite or the runners' self-test | on every pull request and push to `main`, on Ubuntu (bash 5) and macOS (bash 3.2) |

## What is not enforced

- The git hooks, under `--no-verify` or before `bin/setup` runs; CI still runs their checks.
- CI, for an organization admin: `main`'s ruleset lets one bypass it and merge a pull request whose checks have not passed.
- Commit subjects and tool credit, until the `commits` and `pr` checks land.
- `git` and `gh` commands an agent types in the workspace: there is a deny list, not a command guard.
- The `.env` deny list, against a read that does not name the file (`grep -r`, `git show`, `git diff`, a script), a file outside the working directory, and `.envrc`.
- An agent in a stage loading only the files its Inputs name ([AGENTS.md](AGENTS.md#running-the-workflow)): `disclosure` checks what Inputs name, not what an agent reads.
- `shellcheck`: CI installs it, but no step runs it until the workspace's `scripts` check lands.
- Who made a reserved decision; [GOVERNANCE.md](GOVERNANCE.md#reserved-decisions) lists them.
