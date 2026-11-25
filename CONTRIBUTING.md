# Contributing

How a change to this workspace is made and lands. [GOVERNANCE.md](GOVERNANCE.md) says who decides.

## How a change lands

Every change goes through a pull request into `main`. A pull request merges once a decider listed in [GOVERNANCE.md § Deciders](GOVERNANCE.md#deciders) has acked its current head ([§ Approval](GOVERNANCE.md#approval)) and its CI passes, and it lands by rebase, since `main` keeps a linear history. A change bigger than one pull request is planned in a work folder under `docs/work/` and delivered in slices, one pull request each.

## Commits

Subjects take the form `type(scope): subject`, types `feat`, `fix`, `docs`, `refactor`, `test` and `chore`, at most 72 characters. Commits and pull requests carry no tool credit. These are not enforced until the workspace's `commits` and `pr` checks land.

## Tests

Write the failing test first and see it fail for the reason you expect. The workspace's suites live in `tests/` and the product's in `foundation/tests/`; each runs with its `run-all.sh`. Each workspace script sets `set -o pipefail`, which `tests/test_scripts.sh` checks, and runs each write, guard and assert in its own shell, not at the end of a pipeline, where a failure would be lost; that is not enforced (decision 228). Every suite builds its own fixtures in a temporary directory. Beyond the code under test, a suite reads from the workspace only the committed test libraries and fixtures in `tests/` and `foundation/tests/`, and git's list of the suites beside it, to check that none is missing.

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
| `bin/check disclosure` | `CLAUDE.md` other than `@AGENTS.md`; `AGENTS.md` over 80 lines or `CONTEXT.md` over 60; a stage folder, routing table or contract out of shape; a tracked path that is not portable, holding anything but ASCII letters, digits, `.`, `_`, `-`, `/` and space, or a case-only twin of a tracked path or of one of its directories; an Inputs section that is not one table, headed Source, File/Location, Section/Scope and Why, whose rows each name one file in backticks in File/Location and whose other cells are plain text, with no backtick, `<`, `[`, `]`, `@`, `&`, carriage return, `://` or `www.` in any case, or a row that names a directory, a path ending in `/`, a glob, an absolute path, a symbolic link, a submodule, a path with a `.` or `..` outside its leading `../` run or that does not resolve, a file in a later stage, an output of the same or a later stage, or an earlier stage's output its Outputs do not list; a file in `references/` its Inputs do not name | in `bin/check`, so in the hooks |
| `bin/check claims` | a line of the workspace's Markdown, outside `foundation/`, `docs/adr/`, `docs/work/` and `tests/fixtures/`, that holds a rule word (must, required, never, refuse, block, reject, enforce or prevent, in their forms) outside code, yet names no script or hook under `bin/`, `.githooks/`, `.claude/hooks/` or `.github/workflows/` and does not say it is not enforced; a heading is not a sentence, so it is not judged | in `bin/check`, so in the hooks |
| `bin/check setup` | a `setup/questionnaire.md` other than what `bin/ask questionnaire` writes from `shared/answers.tsv`; a `setup/answers.env` that `bin/lib/answers.sh` rejects: a setup field missing or given twice, a field that is unknown or not a setup field, or a value its type, its pattern or the free-text rules refuse | in `bin/check`, so in the hooks |
| `bin/check trace` | a line of `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md` or a contract that holds a rule word, or always, do not, don't or STOP, without linking `docs/workflow.md`, `CONTRIBUTING.md` or `GOVERNANCE.md`; a relative link or anchor in those files that does not resolve; a deny entry in `.claude/settings.json` missing from [§ Agent guards](#agent-guards) | in `bin/check`, so in the hooks |
| `bin/ask setup` | an argument that is not FIELD=value, a field given twice, an unknown field or a run field, a value `bin/lib/answers.sh` rejects, or a `setup/answers.env` holding a field the schema does not list as a setup field; a refusal writes nothing | when it runs |
| `bin/ask run`, `bin/ask confirm` | in `run`, an unknown field; a value its type or pattern refuses, or holding a newline or `{{`; a rule word or an email address in free text; a missing field; a setup field outside `--setup-override`; an existing run without `--redo`, or `--redo` with no run; a present target no `--remove` names; in `confirm`, a run that does not exist or a `--by` that is not one line; a refusal writes nothing | when it runs |
| `bin/render` | answers without a `confirmed.md` naming their blob id, or that the schema at `HEAD` rejects, or naming another run or target; a `TARGET_ROOT` at or under a working tree of the workspace, by `-ef` against `git rev-parse --show-toplevel` and the `git worktree list` entries not bare or prunable, or whose existing ancestor cannot be entered; a rendered run without `--replace`, or `--replace` with no render; a present target that is not an empty directory and that no `--remove` names; in `foundation/` at `HEAD`, a placeholder that is not a render field, a `{{FIELD}}` left after substitution, a template that is executable or a symbolic link, a variant that no value of its field selects, a selecting field with no variant for its value, two sources for one path, or a submodule; a target holding a file it did not write or lacking one it did, an entry named `.git`, a name with a newline or a directory holding no listed file; an index that is not its file list; git older than 2.36; a refusal before the copy writes nothing | when it runs |
| `bin/lib/git.sh`, for `bin/render` | git reading a global or system config, a per-user ignore or attributes file, an attribute source, a replace object, a hook or an fsmonitor, or inheriting a repository, an index, an object format or an identity from its caller | when it runs |
| `bin/lib/discard.sh`, for `bin/ask run --redo --remove` and `bin/render --replace --remove` | removing a path other than the target `render.md` names, one whose last component is not the run's name or is a symbolic link, or one whose parent is not `TARGET_ROOT`, each resolved with `pwd -P`; a removal that leaves anything behind, named | when it runs |
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
