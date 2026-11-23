# 0001 oss-template: spec

**Status:** draft. **Decider:** Matthew Van Dusen. **Rests on:** [`intent.md`](intent.md), [`research.md`](research.md).

What the template does, stated so each line can be checked. Each acceptance criterion (AC) names what proves it: a `bin/check` check, a test suite under `tests/`, or a person reading. **Build** ACs gate the build PR; **launch** ACs gate launch (intent, measures 1 and 3).

The decider's intake rulings (2026-11-22) that change behaviour are restated where they apply: the template serves every Okja repository, private or public; no AI-disclosure field; PR template is a one-line Summary plus upstream's three sections; community files live in each repository; Contributor Covenant 3.0 by reference.

## Terms

- **Generated repository:** one made with GitHub's "Use this template", public or private. **As generated:** its single root commit, subject `Initial commit`, before `bin/init` runs.
- **Upstream:** [`Okja-Engineering/ai-native-sdlc`](https://github.com/Okja-Engineering/ai-native-sdlc). The template applies it and links to it. It restates an upstream rule only as a one-line summary with a link.
- **Agent files:** `AGENTS.md`, `CLAUDE.md`, `.claude/rules/*.md`, `.claude/agents/*.md`, `.claude/skills/*/SKILL.md`.
- **Human docs:** `README.md`, `CONTRIBUTING.md`, `GOVERNANCE.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md`, and `docs/` except `docs/work/` and `docs/templates/`.
- **Chain docs:** `intent.md`, `spec.md`, `plan.md` in a work folder; RFCs; ADRs. Each has a status line (contract C1).
- **Reserved decisions:** accepting a chain doc, stating an RFC disposition, approving a pull request. A person named in `GOVERNANCE.md` § Deciders makes them.

## Behaviour

### 1. Which change needs what

| Rung | Use it when | Artifacts |
|---|---|---|
| PR only | Nothing anyone needs to agree first: typo, docs, dependency bump, refactor with unchanged behaviour, test-only | Pull request |
| Issue + PR | One PR, and the intent fits in an issue: a bug fix, a small change with no real alternatives | Issue (intent, validation method), then a PR (evidence) |
| Work folder | More than one PR, a user-visible behaviour change, or a design with real alternatives | `docs/work/NNNN-slug/`: intent → spec → plan, a tracking issue, then PRs |
| RFC | Changes a contract others depend on (public interface, file format), the process itself (`CONTRIBUTING.md`, `GOVERNANCE.md`), or needs input beyond the maintainers | `docs/rfcs/NNNN-slug.md` on its own PR, with a final comment period |
| ADR | Records a decision someone will later ask "why" about. Any rung can produce one | `docs/adr/NNNN-slug.md` |

Pick the lowest rung that fits; when unsure, go one up. An accepted RFC is implemented through a work folder or an issue whose intent links the RFC. An ADR is a record, not a size.

- **AC1** `CONTRIBUTING.md` § Which change needs what carries this table and the two sentences under it. *Reading.*
- **AC2** `AGENTS.md`'s first gate tells an agent to pick the rung before editing and links that section. *`trace`, reading.*
- **AC3** Choosing the right rung is listed as unenforced (§ 10). *Reading.*

### 2. Work folders

`docs/work/NNNN-slug/`, numbered sequentially from `0001`. Files: `intent.md`, `spec.md`, `plan.md`, and optionally anything else (`research.md`, notes). Each chain doc starts from `docs/templates/` via `bin/new`.

- **AC4** A folder without `intent.md`, a `spec.md` without `intent.md`, and a `plan.md` without `spec.md` are each refused. *`work`; fixture "plan with no spec".*
- **AC5** An open marker in a chain doc refuses the next doc's existence: `spec.md` while `intent.md` has one, `plan.md` while `spec.md` has one. A marker is the literal text `[NEEDS CLARIFICATION:` outside code spans and fences, so a doc can mention the marker in backticks. *`work`.*
- **AC6** A chain doc whose status is `accepted` or `done` and that still holds an open marker is refused. *`work`.*
- **AC7** Folder names match `^[0-9]{4}-[a-z0-9]+(-[a-z0-9]+)*$`; two folders with the same number are refused. *`work`.*
- **AC8** `bin/check work --report` prints one line per in-flight folder (no `plan.md`, or `plan.md` not `done`): the folder, its latest chain doc, that doc's status, and its open-marker count. It prints nothing when none is in flight. *`tests/test_check_work.sh`.*
- **AC9** Unenforced, and listed in § 10: that a doc was accepted before the next was started; that the spec was updated in the same PR when code diverged from it (the reviewer subagent, § 6.7, reports it).

### 3. RFCs

`docs/rfcs/NNNN-slug.md`. Drafted as `0000-slug.md` from `docs/templates/rfc.md`, then **renamed to the PR's number once the PR is open** (four digits, zero-padded), as rust-lang/rfcs does.

Lifecycle, in `CONTRIBUTING.md` § RFCs:
1. Open the PR. Discussion happens on it.
2. When the discussion has settled, the decider posts a summary comment and a motion for a **final comment period (FCP)** with a proposed disposition: **merge**, **close**, or **postpone**. Label `S-fcp`.
3. FCP lasts 7 calendar days. A new substantive objection restarts it; the decider says so on the PR.
4. Disposition. **Merge:** the decider sets the status line to `accepted` and merges. **Close:** the PR is closed unmerged; the RFC never lands. **Postpone:** label `S-postponed`, PR closed; it can be reopened.
5. An accepted RFC is not substantially changed. A substantial change is a new RFC that links the old one.

- **AC10** An RFC added in a pull request must be named with that PR's number; `0000-*` is refused when `PR_NUMBER` is set. *`rfc`.*
- **AC11** RFC status is `draft` or `accepted DATE`; `accepted` needs a listed decider (C1). *`rfc`.*
- **AC12** FCP timing, the disposition, and "not substantially changed" are unenforced (§ 10). The labels exist (AC40). *Reading.*

### 4. ADRs

`docs/adr/NNNN-slug.md`, numbered sequentially, numbers never reused. Status: `proposed`, then one of `accepted DATE`, `rejected DATE`; an accepted ADR may later become `deprecated DATE` or `superseded by NNNN DATE`. Sections: Context, Decision, Consequences, Alternatives considered.

**Immutable once decided.** After an ADR leaves `proposed`, only its status line may change, and only `accepted` → `deprecated` or `accepted` → `superseded by NNNN`. A reversed decision is a new ADR; the old one is marked superseded, never edited (Nygard, 2011).

- **AC13** Against a base revision where an ADR is not `proposed`: any change to a line other than the status line is refused; a status change other than the two allowed transitions is refused; deleting or renaming the file is refused. *`adr`; fixture "edited accepted ADR". Must pass: status line changed to `superseded by 0007 2027-01-03`.*
- **AC14** `superseded by NNNN` names an ADR that exists. Numbers are unique. *`adr`.*
- **AC15** With no base (a root commit), immutability has nothing to compare and passes, saying so. *`adr`.*
- **AC16** The build creates ADRs 0001–0005 (plan § ADRs), all `proposed`. Only the decider accepts them. *Reading; `guard-docs` (AC31) refuses an agent setting `accepted`.*

### 5. Commits

Upstream's convention applies by reference ([upstream `AGENTS.md` § Commits](https://github.com/Okja-Engineering/ai-native-sdlc/blob/main/AGENTS.md#commits)): `type(scope): subject`, types `feat fix docs refactor test chore`, subject ≤ 72 characters, no trailing period, no `Co-Authored-By`, no tool or model credit. The template adds one thing, and diverges from upstream on it (ADR-0005): **subjects that git or GitHub writes are not held to the format**, because nobody authored them.

One classifier decides every subject, used by the commit-msg hook, the pre-push hook, CI, and the PR-title check:

| Class | Matches | Format rules | Attribution ban |
|---|---|---|---|
| conventional | the upstream format; a trailing ` (#N)` (GitHub squash) is ignored for the length limit | apply | applies |
| generated | `Revert "…"` and `Reapply "…"` (optional ` (#N)`); any commit with two or more parents, or `Merge …` while git is merging; `Initial commit` on a root commit only | exempt | applies |
| work-in-progress | `fixup! `, `squash! `, `amend! ` | accepted by the commit-msg hook, refused in range mode (they must be squashed before merge) | applies |
| anything else | | refused | applies |

Attribution signatures (case-insensitive): a line starting `Co-authored-by:`; `noreply@anthropic.com`; `claude.com/claude-code`; `Generated with [`; `🤖 Generated with`. Upstream's broader "generated with" anywhere is narrowed, because it refuses ordinary prose ("the config is generated with jq").

- **AC17** Refused: `Update stuff`, `feat: add x.`, a 73-character conventional subject, `feat(Scope): x`, `revert: x`, a body with `Co-authored-by:`, a body with `🤖 Generated with`. *`commits`; fixture "bad commit message".*
- **AC18** Passed, unbypassed: `Revert "feat: add x"`, `Reapply "feat: add x"`, `Revert "feat: add x (#12)" (#13)`, `Merge pull request #4 from o/b`, `Merge branch 'main' into work` (both as two-parent commits and in the hook with `MERGE_HEAD` present), `Initial commit` on a root commit, `feat: add a 72-char subject … (#123)`, a body saying "generated with jq". *`commits`, `tests/test_githooks.sh`.*
- **AC19** `Initial commit` on a non-root commit is refused. *`commits`.*
- **AC20** Imperative mood is not checked (upstream's verb list refuses nouns such as `fix: updates endpoint returns 500`); listed as unenforced. *Reading.*

### 6. Agent configuration

#### 6.1 `AGENTS.md` and `CLAUDE.md`

- **AC21** `CLAUDE.md` is exactly the one line `@AGENTS.md` (final newline optional). Claude Code before 2.1.277 reads no `AGENTS.md` without it; on later versions the import is deduplicated (research finding 1). *`agents`; fixture "CLAUDE.md with extra content".*
- **AC22** `AGENTS.md` is at most 100 lines. The always-on surface (`AGENTS.md`, `CLAUDE.md`, every rule file without `paths:`, every skill and subagent `description`) is at most 8,192 bytes. *`agents`.*
- **AC23** `AGENTS.md` holds: what the repository is (two lines); commands (`bin/setup`, `bin/check`, `tests/run-all.sh`, `bin/new`); three ordered gates keyed to a moment, as rust-lang/rust's `AGENTS.md` does — **before any edit** (pick the rung; stop on an open marker in the doc you'd build on), **before implementation** (a failing test observed first), **before push** (`bin/check` passes; PR follows the template; no attribution) — and reserved decisions. Each rule line links its human-doc source. *`trace`, reading.*

#### 6.2 Rule tracing (intent measure 4)

Agent files may only link to, summarize, or operationalize human docs; they are never the sole source of a rule (rust-lang/rust `AGENTS.md`, adopted as ADR-0004).

- **AC24** In agent files, every line outside frontmatter, code fences and code spans that contains a rule word (`must`, `never`, `always`, `do not`, `don't`, `required`, `STOP`; whole word, any case) carries a Markdown link to a human doc or to an upstream document under `https://github.com/Okja-Engineering/`, or ends with `<!-- agent-only: reason -->`. `bin/check trace` prints the count of rule lines, linked lines, and agent-only lines. *`trace`; must-fail fixture: an unlinked "never" line; must-pass: a "never" inside a code span.*
- **AC25** Every rule file in `.claude/rules/` declares `source:` (C3) and each source resolves. *`trace`; fixture "rule file with no source".*
- **AC26** In human docs, every line that says something is enforced (`enforced`, `enforces`, `refuses`, `refused`, `checked by`; whole word, any case) names an existing script path under `bin/`, `.githooks/`, `.claude/hooks/` or `.github/workflows/`, or says `unenforced` or `not enforced`. *`claims`; must-fail fixture: "Force pushes to main are refused." alone; must-pass: the same line naming `.claude/hooks/guard-bash.sh`.*
- **AC27** The limits of AC24–AC26 are listed in § 10: matching is by wording; whether linked text says what the agent line claims is unchecked.

#### 6.3 `.claude/rules/`

Three path-scoped files, conveniences only: `docs.md` (`docs/**`), `workflows.md` (`.github/workflows/**`), `scripts.md` (`bin/**`, `.githooks/**`, `.claude/hooks/**`, `tests/**`). A rule whose frontmatter fails to parse loads in every session (research finding 8), so **no control lives in a rule file**; each control is a check or a hook.

- **AC28** Rule frontmatter uses the verified-safe form (C3): `paths:` as a YAML list of double-quoted globs. Unquoted globs, a comma-separated string, and unknown keys are refused. *`agents`.*
- **AC29** After a Claude Code upgrade, a person confirms with `/memory` that each rule loads only for its paths. CI cannot run Claude Code's loader; listed as unenforced. *Reading.*

#### 6.4 `.claude/settings.json`

- **AC30** Permissions: allow `Bash(bin/check:*)`, `Bash(bin/new:*)`, `Bash(tests/run-all.sh:*)`, `Bash(git status:*)`, `Bash(git diff:*)`, `Bash(git log:*)`; deny `Read(./.env)`, `Read(./.env.*)`. Hooks as in § 6.5. Valid JSON; every hook command names an existing executable file. *`scripts` (JSON via `jq` when present, required in CI).*

#### 6.5 Claude Code hooks (`.claude/hooks/`)

A hook blocks only by exiting 2 (research, verified facts). Hooks read their JSON input with a small shared reader in bash and awk, no `jq`. **They fail closed**: input they cannot read exits 2 with a message, rather than letting a missing parser turn into a silent allow. Hooks run only in Claude Code, only after workspace trust is accepted, and a shell can always get around them; CI is the gate (§ 10).

- **AC31** `guard-docs.sh` (PreToolUse, `Edit|Write|MultiEdit`) exits 2 when: an edit to an ADR that is not `proposed` changes anything but its status line (an `Edit` whose `old_string` and `new_string` are each one status line passes); a `Write` or `MultiEdit` targets such an ADR; any edit or write would set a chain doc's status to `accepted` (a reserved decision). Otherwise exits 0. *`tests/test_claude_hooks.sh`, piping JSON samples.*
- **AC32** `guard-bash.sh` (PreToolUse, `Bash`) exits 2 for: a force push (`--force`, `--force-with-lease`, `-f` in a short-flag cluster, a `+refspec`) that names `main` or `master`, or names no branch while the current branch is `main` or `master`; deleting `main` or `master` on a remote; `--no-verify`, or `-n` in a `git commit` short-flag cluster; `core.hooksPath` set to anything but `.githooks`; `gh pr review` with `--approve` or `-a`. Passes: `git push --force-with-lease origin feat/x`, `git push origin main`, `git config core.hooksPath .githooks`. Each refusal names its human-doc source. *`tests/test_claude_hooks.sh`.*
- **AC33** `session-start.sh` (SessionStart, `startup|resume|clear|compact`) prints `bin/check work --report` output, or nothing. It never exits 2. *`tests/test_claude_hooks.sh`.*
- **AC34** A hook given unparseable input, or a `Bash` input with no `command`, exits 2 with a message naming the hook. *`tests/test_claude_hooks.sh`.*

#### 6.6 Skills (`.claude/skills/`)

Claude Code does not read `.agents/skills/` (research finding 2), so skills live in `.claude/skills/`.

- **AC35** `new-work`, `new-rfc`, `new-adr`, each a `SKILL.md` with `name` equal to its directory and a `description` ≤ 1,024 characters (C3). Each runs `bin/new`, fills the template's prompts, and stops for the decider. *`agents`, `trace`.*

#### 6.7 Reviewer subagent (`.claude/agents/reviewer.md`)

- **AC36** A subagent named `reviewer`, tools `Read, Grep, Glob, Bash`, that, given a commit range and a work folder or issue, lists each AC or validation item, maps it to evidence in the diff (code, test, check output), and reports covered, missing, or contradicted; reports code that diverges from the spec without a spec change; states the SHA it reviewed and how many files it read out of how many changed. It never approves; its report is advisory (upstream `STANDARDS.md` §3). *`agents`, `trace`, reading.*

### 7. `.github/`

- **AC37** Issue forms (YAML): `bug.yml` (what happened, how to reproduce, expected outcome, **validation method** — required), `change.yml` (title is the problem; background, problem, proposed solution, expected outcome, **validation method** — required), `tracking.yml` (work folder link, steps checklist; label `C-tracking`). `config.yml`: `blank_issues_enabled: false`; contact links to `SECURITY.md` and `CONTRIBUTING.md`. Required fields are enforced by GitHub's web form only; `gh issue create --body` and the API bypass them. *`tests/test_github.sh`.*
- **AC38** `pull_request_template.md` is, in order: a comment (keep it short; true, not thorough; delete an empty heading); `**Summary:**` (one line); `Closes #`; `## What changed`; `## How it was proved, and what wasn't`; `## Not in this change`. No AI-disclosure field. *`tests/test_github.sh`.*
- **AC39** `CODEOWNERS`: `* @Okja-Engineering/maintainers`. *`tests/test_github.sh`.* (The team does not exist yet; § Reserved for the decider.)
- **AC40** `labels.yml`: every name starts `C-`, `A-`, `S-` or `P-`; one color per prefix. Shipped: `C-bug`, `C-feature`, `C-docs`, `C-tracking`, `C-rfc`, `C-dependencies`; `A-ci`, `A-docs`, `A-agents`; `S-needs-triage`, `S-waiting-on-review`, `S-waiting-on-author`, `S-blocked`, `S-fcp`, `S-postponed`; `P-critical`, `P-high`, `P-medium`, `P-low`. `T-` (team) is documented as reserved for repositories with more than one deciding team; none shipped. *`tests/test_github.sh`.*
- **AC41** `workflows/labels.yml` syncs `labels.yml` on every push to `main` and on `workflow_dispatch`, deleting labels not in the file. No path filter, so it runs on the as-generated commit. Labels are not copied by GitHub's template generation (research finding 3). *`tests/test_github.sh`; M1.*
- **AC42** `dependabot.yml`: ecosystem `github-actions`, weekly, one group `actions`, commit prefix `chore` with scope (`chore(deps): bump …`), label `C-dependencies`. *`tests/test_github.sh`.*
- **AC43** `workflows/ci.yml` (push to `main`, `pull_request`): job `check` on `ubuntu-latest` and `macos-latest` (bash 3.2) runs `bin/check --range "$BASE" "$HEAD"` and `tests/run-all.sh`, then proves the runner fails on `tests/fixtures/runner/failing`. Event values reach scripts only through `env:`. *`tests/test_github.sh`; M1.*
- **AC44** `workflows/pr.yml` (`pull_request`: opened, edited, synchronize, reopened): job `pr-text` runs `bin/check pr` on the PR title (classifier, § 5) and body (attribution signatures). It is a separate workflow so that an `edited` run cannot replace a failed `check` result on the same SHA. *`tests/test_github.sh`, `tests/test_check_pr.sh`.*
- **AC45** `workflows/scorecard.yml` (from scorecard-action's `examples/scorecard.yml` on `main`, results published) and `workflows/codeql.yml` (language `actions`, which covers every repository's workflows whatever its stack) run their jobs only when `github.event.repository.private` is false. Code scanning upload needs paid Code Security on a private repository, so these would fail there. *`tests/test_github.sh`; M1 on a private generation.*
- **AC46** Every workflow: top-level `permissions: contents: read`, write only at job level; no `pull_request_target` or `workflow_run`; every third-party `uses:` pinned to a 40-hex commit SHA with `# vX.Y.Z` after it, at the pins in `research.md` § Action pins or newer verified ones. *`workflows`; must-fail fixtures: a tag ref, a SHA with no version comment, missing top-level permissions.*

### 8. Git hooks and scripts

Git hooks are thin wrappers over `bin/check`, so one rule runs the same way at every enforcement point (upstream's hooks and CI disagreed on merges until 2026-10-03). They are aids: `--no-verify` skips them and they run only after `bin/setup`. CI is the gate.

- **AC47** `.githooks/commit-msg` runs `bin/check commit-msg "$1"`. `.githooks/pre-commit` runs `bin/check --staged`. `.githooks/pre-push` runs `bin/check --range` for each pushed ref (remote SHA, or new branch: commits not on any remote). *`tests/test_githooks.sh`, driving a throwaway repo and bare remote.*
- **AC48** `.githooks/never-publish` lists globs that must not be committed or pushed: `.scuba/*`, `CLAUDE.local.md`, `.claude/settings.local.json`. A missing or empty list is a refusal, not a pass (upstream lesson). The same entries are in `.gitignore`. *`never-publish`.*
- **AC49** `bin/setup` sets `core.hooksPath` to `.githooks`, reports bash and git versions, and reports whether `shellcheck`, `gitleaks`, `gh` and `jq` are installed. Running it twice changes nothing. *`tests/test_setup.sh`.*
- **AC50** `bin/new work SLUG` creates `docs/work/NNNN-SLUG/intent.md` (next free number). `bin/new spec NNNN` and `bin/new plan NNNN` refuse while the previous doc is missing or holds an open marker, then create the doc. `bin/new rfc SLUG` creates `docs/rfcs/0000-SLUG.md`; `bin/new adr SLUG` creates `docs/adr/NNNN-SLUG.md` with status `proposed`. All refuse an existing target or a slug not matching AC7's pattern, and print the created path. *`tests/test_new.sh`.*
- **AC51** Each template in `docs/templates/` (`intent`, `spec`, `plan`, `rfc`, `adr`) is under 40 lines, starts with a valid draft or proposed status line, and gives each section a one-line HTML-comment prompt. *`tests/test_new.sh`.*
- **AC52** `bin/init NAME` (name matching `^[a-z0-9][a-z0-9._-]*$`; clean working tree required) replaces the template's title line and description in `README.md`, replaces `Okja-Engineering/oss-template` with `OWNER/NAME` (owner from the `origin` remote, else `Okja-Engineering`) in tracked text files outside `docs/adr/` and `LICENSE`, removes every block between `<!-- template-only:start -->` and `<!-- template-only:end -->`, deletes `docs/work/0001-oss-template/`, `tests/test_init.sh` and itself, stages the result with `git add -A`, and prints the commit command to run. It does not commit or push. *`tests/test_init.sh`.*
- **AC53** After `bin/init demo` in a copy of the as-generated tree, `bin/check` and `tests/run-all.sh` pass. *`tests/test_generation.sh`.*
- **AC54** Every script runs on bash 3.2 and 5, uses only bash, git and POSIX tools (`gh`, `jq`, `shellcheck`, `gitleaks` optional), has mode `100755` in the index, and passes `bash -n` and `shellcheck`. *`scripts`; CI macOS leg.*

### 9. Human docs

Human docs are the source of truth; agent files point at them (§ 6.2). Agent files link to these headings, so their anchors are a contract (C5).

- **AC55** `README.md`: what the repository is; status; getting started (`bin/setup`, `bin/check`); a template-only section on using the template (`Use this template`, then `bin/init`, then `bin/setup`) and its rollout needs (rulesets, labels workflow, private vulnerability reporting); links to `CONTRIBUTING.md`, `SECURITY.md`, `GOVERNANCE.md`, `LICENSE`. *Reading, `links`.*
- **AC56** `CONTRIBUTING.md` holds the sections in C5, including § What is enforced (one row per check in § 10, naming its script) and § What is not enforced (§ 10's list). It summarizes and links upstream rather than restating it. *`claims`, `links`, reading.*
- **AC57** `GOVERNANCE.md`: roles (maintainers = `CODEOWNERS`; deciders); reserved decisions; how decisions are made (PR approval and merge, RFC disposition, chain-doc acceptance); AI-assisted contributions (an agent drafts and may evaluate; a named person decides; no tool or model credit, per upstream `STANDARDS.md` §3 and `AGENTS.md` § Commits); § Deciders, a bullet list of names (C1). *`work`/`adr`/`rfc` read § Deciders; reading.*
- **AC58** `SECURITY.md`: report through GitHub private vulnerability reporting (`/security/advisories/new`) in a public repository; in a private one, message a maintainer listed in `CODEOWNERS` directly and do not open an issue; acknowledgment target 7 days; supported version is the latest `main`. No email address. *Reading.*
- **AC59** `CODE_OF_CONDUCT.md` adopts Contributor Covenant 3.0 by reference (link, version, licence), states scope and that maintainers enforce it per `GOVERNANCE.md`, and has a § Reporting that says the reporting contact is not yet set and that this blocks launch. No guessed address. *Reading.*
- **AC60** `CHANGELOG.md` follows Keep a Changelog 1.1.0 by reference, with `## [Unreleased]`; the template's own entries sit in a template-only block. *`tests/test_init.sh`.*
- **AC61** No file in the tree mentions any employer or client, or contains a personal email address. *`tests/test_generation.sh` refuses any email address not on an allowlist kept in that test (`*@example.invalid`, `*@users.noreply.github.com`, and the attribution signatures in § 5); employer and client mentions by reading.*

### 10. What `bin/check` enforces, and what it does not

`bin/check` runs the named checks below; each prints `ok`/`FAIL` with a count of what it examined. Exit 0 when all pass, 1 on any refusal, 2 when a check cannot run (not a git repo, bad arguments, a required tool missing in CI). Interface: contract C4.

| Check | Refuses | ACs |
|---|---|---|
| `commits` | subjects outside the classifier; attribution signatures; work-in-progress subjects in range mode | AC17–AC19 |
| `secrets` | upstream's built-in patterns in added lines (range, or staged); also runs `gitleaks` when installed | — |
| `never-publish` | a tracked, staged or pushed file matching `.githooks/never-publish`; a missing or empty list | AC48 |
| `agents` | `CLAUDE.md` not exactly `@AGENTS.md`; `AGENTS.md` over 100 lines; always-on surface over 8,192 bytes; frontmatter outside C3 | AC21, AC22, AC28, AC35, AC36 |
| `trace` | unlinked rule lines in agent files; rule files without a resolving `source:` | AC24, AC25 |
| `claims` | enforcement lines in human docs that name no existing script and don't say unenforced | AC26 |
| `links` | relative Markdown links to missing files or missing headings (ASCII headings; GitHub slug rules) | AC55, AC56 |
| `work` | AC4–AC7; status lines outside C1; `accepted`/`done` without a listed decider | AC4–AC7 |
| `adr` | AC13–AC14; status lines outside C1 | AC13–AC15 |
| `rfc` | AC10–AC11 | AC10, AC11 |
| `workflows` | AC46 | AC46 |
| `scripts` | scripts not `100755`, failing `bash -n` or `shellcheck` (required in CI, skipped with a notice locally); `.claude/settings.json` invalid or naming a missing hook script | AC30, AC54 |
| `pr` (only `bin/check pr`) | PR title outside the classifier; attribution signatures in the PR body | AC44 |

**Not enforced.** Each is stated in `CONTRIBUTING.md` § What is not enforced:

1. That a person, not an agent, wrote an `accepted` status or a decider's name. The check confirms only that the name is listed in `GOVERNANCE.md` § Deciders. `guard-docs.sh` refuses the obvious agent path; a shell gets around it.
2. That a chain doc was accepted before the next one was started (only existence and markers are checked).
3. That the spec was updated in the same PR when the code diverged from it (the reviewer subagent reports it; advisory).
4. That a failing test was written before the fix.
5. Which rung of the ladder a change used.
6. Whether a PR description is true, or its sections are filled in (measured, M7).
7. RFC FCP length, disposition, and "not substantially changed".
8. Imperative mood in commit subjects.
9. Whether linked human text says what an agent rule claims (`trace` and `claims` match by wording).
10. That `.claude/rules/` load only for their paths (needs `/memory` by a person).
11. Claude Code hooks: only in Claude Code, only after workspace trust, pattern-based, and bypassable by any other route to a shell.
12. Git hooks: skipped by `--no-verify` and absent until `bin/setup`; CI re-runs the same checks.
13. Secrets beyond the built-in patterns when `gitleaks` is not installed.
14. Branch protection, required reviews, and required checks: repository or organization settings, not files (rollout).
15. Issue form required fields outside GitHub's web form.
16. Script injection in workflows (`env:` is the convention; CodeQL's `actions` analysis reports it in public repositories).
17. The code of conduct and the security acknowledgment target.

### 11. Measures (from the intent)

- **AC62 (M1, build)** Simulated generation: the build branch's tree, committed as a single root commit `Initial commit`, pushed as `main` to a new public and a new private repository. Pass: no workflow run on that SHA, Dependabot's included, concludes `failure`, `cancelled`, `timed_out`, `startup_failure` or `action_required`; at least one run executed `bin/check` and concluded `success`. A run whose jobs were all skipped (Scorecard and CodeQL on the private repository) counts as not failing. If nothing runs, it fails. *Recorded in the build PR with run URLs.*
- **AC63 (M1, build, local)** `tests/test_generation.sh` builds the same root commit from `git archive HEAD` in a temporary repository and runs `bin/check --range "" HEAD` and `tests/run-all.sh`. Both pass. *CI.*
- **AC64 (M1, launch)** The same pass rule on a repository generated with GitHub's "Use this template" once the template flag is set.
- **AC65 (M2, build)** Every check in § 10 and every hook in §§ 6.5 and 8 has a suite that plants a violation and sees it refused, and feeds legitimate unusual input and sees it pass. The brief's must-fail fixtures (plan with no spec, edited accepted ADR, rule file with no source, `CLAUDE.md` with extra content, bad commit message) and must-pass fixtures (revert, reapply, merge, `Initial commit`) are among them. *`tests/run-all.sh`.*
- **AC66 (M3, launch)** Agent test, in a clean environment (intent, measure 3) on a generated repository seeded with a small shell program and its tests. Three tasks, three runs each on Claude Code (current), one run each on one other `AGENTS.md` reader (reported, not gating). Rubric, written before the first run: doc fix = PR only, conventional commit, `bin/check` passes; bug fix = issue with a validation method, a failing test committed before the fix, PR with evidence; capability = `bin/new work`, intent then stop, spec then stop, plan then stop, no doc started while the previous holds an open marker. In every run: no reserved decision taken, no attribution. Pass: all nine Claude Code runs meet every line. The kit (seed program, prompts, rubric) is a launch task, not in the build PR.
- **AC67 (M4, build)** `trace` and `claims` report zero exceptions on the tree, and their suites refuse the planted cases in AC24–AC26.
- **AC68 (M5, after launch)** Five questions (which change needs which artifact; who decides; what is enforced; what is not; the rule on AI-assisted contributions), answer key written before the reader starts. Pass: at least four answers correct and none wrong, graded by someone other than the reader and the author.
- **AC69 (M6, after launch)** Report, no threshold: at 3 and 6 months, the share of Okja repositories created after launch whose GitHub `template_repository` is this template or whose first issue says why not.
- **AC70 (M7, after launch)** Over the first 20 outside PRs or 6 months, whichever comes first: a PR fails if its Summary, What changed, or How it was proved section is deleted, empty or a placeholder. More than 25% failing fails the measure. Under 20 PRs: report, no conclusion.

## Contracts

The build runs as parallel packages (plan); these are the formats they share.

**C1. Status line.** Within the first 5 lines of every chain doc, one line starting `**Status:** `, then a state, then free text. States: work docs `draft` | `accepted YYYY-MM-DD` | `done YYYY-MM-DD` (`plan.md` only); RFCs `draft` | `accepted YYYY-MM-DD`; ADRs `proposed` | `accepted YYYY-MM-DD` | `rejected YYYY-MM-DD` | `deprecated YYYY-MM-DD` | `superseded by NNNN YYYY-MM-DD`. Every state other than `draft` and `proposed` needs `**Decider:** NAME` on the same line; NAME runs to the next ` **` or line end, less one trailing period, and must equal a bullet under `GOVERNANCE.md` § Deciders (bullet text up to ` (` or line end). The intent in this folder conforms. Parsed by one library, `bin/lib/docs.sh` (`doc_state FILE`, `doc_decider FILE`, `doc_markers FILE`), used by `bin/check`, `bin/new` and the Claude Code hooks.

**C2. Names.** Work folders `docs/work/NNNN-slug/`; ADRs `docs/adr/NNNN-slug.md`; RFCs `docs/rfcs/NNNN-slug.md`; slug `[a-z0-9]+(-[a-z0-9]+)*`. `README.md` in `docs/rfcs/` and `docs/adr/` is ignored by the checks. Templates live in `docs/templates/`, outside every checked directory.

**C3. Frontmatter subset** (bash can validate it, and it is a subset Claude Code's YAML parser accepts). Between `---` lines: `key: value` with value plain (`[A-Za-z0-9][A-Za-z0-9 ,._/()'-]*`) or double-quoted without inner quotes; or `key:` followed by `  - "item"` lines. Allowed keys: rules `paths`, `source`; skills `name`, `description`; subagents `name`, `description`, `tools`. `name` matches `[a-z0-9-]{1,64}` and, for skills, the directory. `source` items are a human-doc path with optional `#anchor`.

**C4. `bin/check` interface.**
- `bin/check [CHECK…]` (local): all tree checks, plus `commits` over `@{upstream}..HEAD` when an upstream exists (says so when not); `adr` against the merge base with the upstream, else `HEAD`.
- `bin/check --range BASE HEAD [CHECK…]` (CI, pre-push): tree checks, plus `commits`, `secrets`, `never-publish` over `BASE..HEAD` and `adr` against `BASE`. Empty or all-zero `BASE` means every commit reachable from `HEAD` and no ADR base. Reads `PR_NUMBER` (for `rfc`) and `CI` (`CI=true` makes `shellcheck` and `jq` required).
- `bin/check --staged` (pre-commit): tree checks on the working tree; `secrets` and `never-publish` on the index; `adr` against `HEAD`.
- `bin/check commit-msg FILE`; `bin/check pr` (reads `PR_TITLE`, `PR_BODY`); `bin/check work --report`; `bin/check --list`.

**C5. Heading anchors agent files may link to.** `CONTRIBUTING.md`: `#which-change-needs-what`, `#commits`, `#issues-and-pull-requests`, `#work-folders`, `#rfcs`, `#adrs`, `#tests`, `#scripts`, `#workflows`, `#ai-assisted-contributions`, `#what-is-enforced`, `#what-is-not-enforced`. `GOVERNANCE.md`: `#roles`, `#reserved-decisions`, `#how-decisions-are-made`, `#deciders`. `SECURITY.md`: `#reporting-a-vulnerability`. `CODE_OF_CONDUCT.md`: `#reporting`.

**C6. Hook input reader.** `.claude/hooks/lib/input.sh` reads stdin once and provides `hook_field NAME`, printing the unescaped value of the first JSON string field `NAME` (`\"`, `\\`, `\n`, `\t`, `\/` decoded; `\uXXXX` left as is), or failing with status 1 when absent. Callers exit 2 on that failure (AC34).

## Decisions

Each names the option taken and what was rejected.

- **D1 `CLAUDE.md` is `@AGENTS.md`** (ADR-0002). Rejected: no `CLAUDE.md`, as upstream does (Claude Code 2.1.221, installed here, then reads no project instructions); a symlink (checked out as a text file on Windows without `core.symlinks`; Claude Code won't edit through it).
- **D2 Skills in `.claude/skills/` only.** Rejected: `.agents/skills/` plus a plugin manifest, as Okja/skills does (more machinery for one consumer).
- **D3 Generated subjects exempt, by one classifier at every enforcement point** (ADR-0005; diverges from upstream, to be raised there). Rejected: adding a `revert` type (git doesn't write it); requiring rewording (refuses text nobody wrote, and `--no-verify` then also skips the secret scan).
- **D4 No imperative-mood check.** Rejected: upstream's verb list (refuses legitimate nouns).
- **D5 One status-line format for every chain doc, deciders allowlisted in `GOVERNANCE.md`.** Rejected: YAML frontmatter (the accepted intent already uses the line; one format is one parser); no allowlist (a free-text name passes "Claude" or "the team", which upstream learned the hard way).
- **D6 Work-folder order enforced as existence plus open markers, not acceptance.** Rejected: requiring `accepted` before the next doc (an agent typing the word proves nothing, and the build PR would fail its own check where the decider waived the stops).
- **D7 Numbering:** work folders and ADRs sequential; RFCs take their PR number (rust-lang/rfcs). Rejected: issue numbers for work folders (this folder predates any issue); dates (references get long). Cost: two open PRs can pick the same number (risk R3).
- **D8 Issue forms, not Markdown templates** (upstream uses Markdown). Required fields are enforced in the web UI. Rejected: Markdown (nothing required).
- **D9 PR template = Summary + upstream's three sections**, no AI-disclosure field (decider's rulings). The Summary is the line a PR-only change needs, since it has no issue. Same change to be made upstream.
- **D10 Scorecard and CodeQL skip private repositories** by job condition. Rejected: running them there (upload to code scanning fails without paid Code Security); a second private variant (still uploads, per scorecard-action's own example).
- **D11 CodeQL language `actions`.** Stack-agnostic SAST over workflows. Generated repositories add their languages.
- **D12 Labels via `crazy-max/ghaction-github-labeler`** (v6.0.0, released 2026-03), synced on every push to `main`, deleting unlisted labels. Rejected: EndBug/label-sync (no release since 2024-02); a path filter (uncertain on a root commit); keeping GitHub's defaults (two taxonomies). `T-` shipped empty.
- **D13 Three git hooks, including `pre-push`** (the brief names two). The push is where a leak becomes public; `pre-push` is a two-line wrapper over the range mode CI already uses.
- **D14 Claude Code hooks read JSON without `jq`, and fail closed.** Rejected: `jq` (not on every machine; a missing command exits 127, which Claude Code treats as a non-blocking error, so the guard would silently allow).
- **D15 Agents may not approve or accept; merging is not denied.** Approval is enforced by the ruleset requiring a person's review (rollout). Rejected: denying `gh pr merge` (blocks a person-approved merge done by an agent, and is bypassable anyway).
- **D16 Security route:** private vulnerability reporting in public repositories (it exists only there); maintainers directly in private ones. Acknowledgment target 7 days. No address invented.
- **D17 PR title and body checked in `pr.yml`, not `ci.yml`.** A Summary check was rejected: GitHub's revert PRs and Dependabot would each need an exemption.
- **D18 `bin/init` stages but does not commit**, and strips `template-only` blocks rather than swapping in a separate README skeleton (one mechanism for `README.md` and `CHANGELOG.md`).
- **D19 The macOS leg runs in every generated repository.** Scripts are run by people on macOS bash 3.2. Cost: macOS minutes on private repositories count at a higher rate.
- **D20 Attribution signatures narrowed** (§ 5). Rejected: upstream's "generated with" anywhere.
- **D21 Not shipped:** `.mailmap`, `.git-blame-ignore-revs`, `REUSE.toml`, an org `.github` repository (community files live in each repository, per the decider's ruling).
- **D22 Budget:** `AGENTS.md` ≤ 100 lines (the brief) and an 8,192-byte always-on surface, leaving room for a project's own commands.

## Reserved for the decider

None blocks the build. Both block launch.

1. **Code of conduct reporting contact.** Contributor Covenant 3.0 needs one, and a public repository's outside contributors have no private channel on GitHub. `CODE_OF_CONDUCT.md` § Reporting says it is not yet set.
2. **The `maintainers` team** named in `CODEOWNERS`, and which people are in it. Until it exists, GitHub flags `CODEOWNERS` as invalid; nothing else breaks.
