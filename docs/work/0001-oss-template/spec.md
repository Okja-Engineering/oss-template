# 0001 oss-template: spec

**Status:** draft. **Decider:** Matthew Van Dusen. **Rests on:** [`intent.md`](intent.md), [`research.md`](research.md).

What the template does, stated so each line can be checked. Each acceptance criterion (AC) names its proof: a `bin/check` check, a suite under `tests/`, or a person reading. Unmarked ACs gate the build PR; **launch** ACs gate launch. Where the decider's intake rulings (2026-11-22) change behaviour, the change is restated in place.

## Terms

- **Generated repository:** made with "Use this template", private or public. **As generated:** its single root commit `Initial commit`, before `bin/init`.
- **Upstream:** [`Okja-Engineering/ai-native-sdlc`](https://github.com/Okja-Engineering/ai-native-sdlc). The template applies and links it; it restates nothing beyond one-line summaries with a link.
- **Agent files:** `AGENTS.md`, `CLAUDE.md`, `.claude/rules/*.md`, `.claude/agents/*.md`, `.claude/skills/*/SKILL.md`. **Human docs:** `README.md`, `CONTRIBUTING.md`, `GOVERNANCE.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md`.
- **Chain docs:** a work folder's `intent.md`, `spec.md`, `plan.md`; RFCs; ADRs. Each has a status line (C1).
- **Reserved decisions:** accepting a chain doc, an RFC disposition, approving a pull request. Only a decider listed in `GOVERNANCE.md` § Deciders makes them.

## 1. Which change needs what

| Rung | Use it when | Artifacts |
|---|---|---|
| PR only | Nothing anyone must agree first: typo, docs, dependency bump, refactor with unchanged behaviour, test-only | Pull request |
| Issue + PR | One PR; the intent fits in an issue (a bug fix, a small change with no real alternatives) | Issue with intent and validation method, then a PR with evidence |
| Work folder | More than one PR, a user-visible behaviour change, or a design with real alternatives | `docs/work/NNNN-slug/`: intent → spec → plan, a tracking issue, PRs |
| RFC | Changes a contract others depend on, the process itself (`CONTRIBUTING.md`, `GOVERNANCE.md`), or needs input beyond the maintainers | `docs/rfcs/NNNN-slug.md` on its own PR |
| ADR | Records a decision someone will later ask "why" about; any rung can produce one | `docs/adr/NNNN-slug.md` |

Pick the lowest rung that fits; when unsure, go one up. An accepted RFC is implemented through a work folder or an issue that links it.

- **AC1** `CONTRIBUTING.md` § Which change needs what holds this table and rule; `AGENTS.md`'s first gate links it. *Reading; `trace`.*

## 2. Work folders, RFCs, ADRs

**Work folders** `docs/work/NNNN-slug/`, numbered from `0001`. Chain docs start from `docs/templates/` via `bin/new`; other files (`research.md`) are allowed.

- **AC2** Refused by `docs`: a folder without `intent.md`; `spec.md` without `intent.md`; `plan.md` without `spec.md`; `spec.md` while `intent.md` holds an open marker; `plan.md` while `spec.md` holds one; an `accepted` or `done` doc holding one. A marker is the literal `[NEEDS CLARIFICATION:` outside code spans and fences. *`tests/test_check_docs.sh`, incl. fixture "plan with no spec".*
- **AC3** Refused by `docs`: folder names not matching `NNNN-slug` (C2); two folders, ADRs or RFCs sharing a number. *`tests/test_check_docs.sh`.*
- **AC4** `bin/check docs --report` prints, per folder with no `plan.md` or a `plan.md` not `done`, exactly `docs/work/NNNN-slug: <doc> <state>, <n> open markers`, where `<doc>` is the latest chain doc present; nothing when none. *`tests/test_check_docs.sh`.*

**RFCs** `docs/rfcs/NNNN-slug.md`, drafted as `0000-slug.md`, **renamed to the PR's number once the PR is open** (rust-lang/rfcs). Lifecycle (`CONTRIBUTING.md` § RFCs): discussion on the PR; when it settles, the decider posts a summary and proposes a disposition (**merge**, **close**, **postpone**); the **final comment period (FCP)** starts when every listed decider has signed off on the PR, label `S-fcp`, and lasts 7 calendar days; a new substantive objection restarts it. Merge: a decider sets `accepted`, then it merges. Close: unmerged. Postpone: label `S-postponed`, closed, reopenable. An accepted RFC is not substantially changed; a new RFC links the old one.

- **AC5** Refused by `docs`: an RFC added in a PR not named with that PR's number (`PR_NUMBER` set); a status other than `draft` or `accepted DATE`; `accepted` without a listed decider. *`tests/test_check_docs.sh`.*

**ADRs** `docs/adr/NNNN-slug.md`, sequential, numbers never reused. Sections: Context, Decision, Consequences, Alternatives considered. Status `proposed`, then `accepted DATE` or `rejected DATE`; an accepted ADR may become `deprecated DATE` or `superseded by NNNN DATE`. **Once out of `proposed`, only the status line changes**, and only by those two transitions; a reversal is a new ADR (Nygard, 2011).

- **AC6** Against a base revision where an ADR is out of `proposed`, `docs` refuses: a change to any other line; any other status transition; deletion; rename. Passes a status-line-only change to `superseded by 0007 2027-01-03`. *`tests/test_check_docs.sh`, incl. fixture "edited accepted ADR".*
- **AC7** `superseded by NNNN` must name an existing ADR. With an empty base (a root commit), `docs` still validates every status line and names; only the immutability comparison is skipped, and it says so. *`tests/test_check_docs.sh`.*

## 3. Commits

Upstream's convention applies by reference ([§ Commits](https://github.com/Okja-Engineering/ai-native-sdlc/blob/main/AGENTS.md#commits)): `type(scope): subject`, types `feat fix docs refactor test chore`, ≤ 72 characters, no trailing period. Two divergences, both to be raised upstream: subjects that git or GitHub writes are not held to the format (ADR-0005), and the credit ban covers tools, not people (D7). One classifier (`bin/lib/classify.sh`) decides every subject for the commit-msg hook, range mode (pre-push, CI) and PR titles.

| Class | Matches | Result |
|---|---|---|
| conventional | the format above; a trailing ` (#N)` is ignored for length; length counts characters under a pinned UTF-8 locale | pass |
| generated | `Revert "…"`, `Reapply "…"` (optional ` (#N)`); `Merge …`; `Initial commit`; `Squashed commit of the following:`; `Apply suggestions from code review` | pass. Range mode also requires `Merge …` to have two or more parents and `Initial commit` to be a root; any commit with two or more parents passes |
| work-in-progress | `fixup! `, `squash! `, `amend! ` | commit-msg passes; range mode refuses |
| other | anything else | refused |

The commit-msg mode classifies by subject alone, because an amend hides whether the commit is a merge or a root; range mode sees parents. The hook can be laxer than CI, never stricter. Before classifying a message file, `#` comment lines and everything below git's scissors line are removed.

**Tool credit** is refused in every class: `noreply@anthropic.com`; `claude.com/claude-code`; a line starting `Generated with [` or `🤖 Generated with`; a `Co-authored-by:` line naming `claude`, `anthropic`, `copilot`, `codex`, `chatgpt`, `openai`, `cursor`, `devin` or `gemini` (any case). A `Co-authored-by:` naming a person passes; GitHub writes those for applied suggestions and squash merges.

- **AC8** Refused: `Update stuff`; `feat: add x.`; a 73-character conventional subject; `feat(Scope): x`; `revert: x`; `Initial commit` or `Merge branch 'x'` on a one-parent non-root commit in range mode; `fixup! x` in range mode; a body with `Co-Authored-By: Claude <noreply@anthropic.com>`. *`tests/test_check_commits.sh`; fixture "bad commit message".*
- **AC9** Passed, through hook and range mode alike: `Revert "feat: add x"` (made with `git revert`); `Reapply "feat: add x"` (made with `git commit -m`, as old Apple git writes a different subject); `Revert "feat: x (#12)" (#13)`; two-parent `Merge pull request #4 from o/b` and `Merge branch 'main' into work`; root `Initial commit`, including after `--amend`; an amended merge; `chore: bump crazy-max/ghaction-github-labeler from 6.0.0 to 6.1.0`; a 72-character subject plus ` (#123)`; a 72-character subject with non-ASCII letters; `Co-authored-by: A Person <a@example.invalid>`; a body saying "the config is generated with jq". *`tests/test_check_commits.sh`, `tests/test_githooks.sh`.*

## 4. Agent configuration

- **AC10** `CLAUDE.md` is exactly the line `@AGENTS.md` (Claude Code before 2.1.277 reads no `AGENTS.md` without it; later versions deduplicate the import). `AGENTS.md` is at most 100 lines. *`agents`; fixture "CLAUDE.md with extra content".*
- **AC11** `AGENTS.md` holds: what the repository is; commands; three ordered gates keyed to a moment (rust-lang/rust's shape) — **before any edit** (pick the rung; stop at an open marker in the doc you'd build on), **before implementation** (a failing test observed first), **before push** (`bin/check` passes; PR template; no tool credit); reserved decisions. *Reading; `trace`.*
- **AC12** **Rule tracing** (ADR-0004; no exceptions, no agent-only escape). In agent files, every line outside frontmatter, fences and code spans containing a rule word (`must`, `never`, `always`, `do not`, `don't`, `required`, `STOP`; whole word, any case) carries a link to a human doc or an upstream document, and each relative link and `#anchor` resolves. Each `.claude/rules/` file declares `source:` (C3) and each source resolves. `trace` prints rule lines found and linked; zero unlinked on the tree. *`tests/test_check_trace.sh`: fixtures "rule file with no source", an unresolved `source:`, an unlinked "never" line; must pass: "never" in a code span.*
- **AC13** **Claim tracing.** In human docs, a line saying something is `enforced`, `enforces`, `refuses`, `refused` or `checked by` names an existing path under `bin/`, `.githooks/`, `.claude/hooks/` or `.github/workflows/`, or says `unenforced` or `not enforced`. ADRs and `docs/work/` are out of scope: they are records, and an accepted ADR cannot be edited when a script is renamed. Zero exceptions on the tree. *`tests/test_check_claims.sh`: "Force pushes to main are refused." alone fails; naming `.claude/hooks/guard-bash.sh` passes.*
- **AC14** `.claude/rules/`: `docs.md` (`docs/**`), `workflows.md` (`.github/workflows/**`), `scripts.md` (`bin/**`, `.githooks/**`, `.claude/hooks/**`, `tests/**`). Frontmatter per C3; unquoted globs, a comma-separated `paths`, unknown keys refused. A rule that fails to parse loads in every session (research finding 8), so no control lives in a rule. *`agents`.*
- **AC15** `.claude/settings.json`: allow `Bash(bin/check:*)`, `Bash(bin/new:*)`, `Bash(tests/run-all.sh:*)`, `Bash(git status:*)`, `Bash(git diff:*)`, `Bash(git log:*)`; deny `Read(**/.env)`, `Read(**/.env.*)`; hook commands `"$CLAUDE_PROJECT_DIR"/.claude/hooks/<name>.sh` with `"onFailure": "block"`. *`scripts` (valid JSON via `jq`; every hook script exists and is executable).*
- **AC16** **Hooks fail closed.** Each hook needs `jq`; a missing `jq`, unreadable input, or any non-zero exit on a non-allow path exits 2 (an `EXIT` trap maps non-zero to 2). A hook blocks only by exiting 2. *`tests/test_claude_hooks.sh`, piping JSON samples, with `jq` hidden from `PATH`.*
- **AC17** `guard-bash.sh` (PreToolUse `Bash`) exits 2 for: any push to the default branch (`main`, `master`, or `origin/HEAD`'s target), explicit (`git push origin main`, `HEAD:main`, `+main`) or implied (no refspec while it is checked out); deleting it remotely; `--no-verify`, or `-n` in a `git commit` short-flag cluster; `git -c core.hooksPath=…`, `git config --unset core.hooksPath`, or setting it to anything but `.githooks`; `gh pr review` with `--approve` or `-a`; `gh pr merge --admin`. Passes: `git push --force-with-lease origin feat/x`, `git config core.hooksPath .githooks`, `gh pr merge 12 --rebase`. Each refusal names its human-doc source. *`tests/test_claude_hooks.sh`.*
- **AC18** `guard-docs.sh` (PreToolUse `Edit|Write|MultiEdit`) computes the file as it would be after the call (all edits of a `MultiEdit`; a `Write`'s content) and compares it with the file as it is, using `bin/lib/docs.sh` (C1). Exit 2 when the call moves a status out of `draft` or `proposed`, adds or changes a `**Decider:**` field, or changes a non-status line of an ADR out of `proposed`. *`tests/test_claude_hooks.sh`.*
- **AC19** `session-start.sh` (SessionStart `startup|resume|clear|compact`) prints `bin/check docs --report`, or nothing; it never blocks. *`tests/test_claude_hooks.sh`.*
- **AC20** Skills `new-work`, `new-rfc`, `new-adr` in `.claude/skills/` (Claude Code does not read `.agents/skills/`): `name` equals the directory, `description` ≤ 1,024 characters; each runs `bin/new`, fills the prompts, and stops for a decider. *`agents` (fixture: 1,025-character description); `trace`.*
- **AC21** Subagent `.claude/agents/reviewer.md` (`name`, `description`, `tools: Read, Grep, Glob, Bash`; `agents` checks only these keys): given a commit range and a work folder or issue, maps each AC or validation item to evidence in the diff, reports covered, missing or contradicted, flags code that diverges from its spec without a spec change, and states the SHA reviewed and files read out of files changed. Advisory; never approves (upstream `STANDARDS.md` §3). *`agents`; one dry run on the build PR.*

## 5. `.github/`

- **AC22** Issue forms `bug.yml` (what happened, reproduce, expected, validation method), `change.yml` (title is the problem; background, problem, proposed solution, expected outcome, validation method), `tracking.yml` (work folder link, steps; `C-tracking`); validation method `required: true`. Required fields hold only in the web form and only in public repositories; private ones rely on the prompt text. `config.yml`: `blank_issues_enabled: false`, contact links as absolute `https://github.com/Okja-Engineering/oss-template/…` URLs to `SECURITY.md` and `CONTRIBUTING.md`. *`tests/test_github.sh`.*
- **AC23** `pull_request_template.md` is `## Summary` with a one-line prompt, then upstream's `.github/pull_request_template.md` verbatim, comments included. No AI-disclosure field (rulings 6, 11). *`tests/test_github.sh` compares against a copy of upstream's text pinned in the test.*
- **AC24** `CODEOWNERS` is `* @Okja-Engineering/maintainers`. `labels.yml` holds exactly `C-bug`, `C-feature`, `C-docs`, `C-tracking`, `C-rfc`, `C-dependencies`, `S-needs-triage`, `S-fcp`, `S-postponed`; `CONTRIBUTING.md` reserves `A-`, `P-`, `T-` for repositories to add. *`tests/test_github.sh`.*
- **AC25** `workflows/labels.yml`: push to `main` (no path filter, so it runs on the as-generated commit; templates don't copy labels, research finding 3) and `workflow_dispatch`; checkout; job permissions `contents: read`, `issues: write`; deletes labels not in the file. *`tests/test_github.sh`.*
- **AC26** `dependabot.yml`: `github-actions`, weekly, prefix `chore`, no scope, no groups, label `C-dependencies`. *`tests/test_github.sh`.*
- **AC27** `workflows/ci.yml` (push to `main`, `pull_request`): checkout `fetch-depth: 0`; `BASE`/`HEAD` from `pull_request.base.sha`/`head.sha` or push `before`/`after`, and `PR_NUMBER`, all via `env:`; `ubuntu-latest` runs `bin/check --range "$BASE" "$HEAD"`, `tests/run-all.sh`, and proves the runner fails on `tests/fixtures/runner/failing`; `macos-latest` (bash 3.2) does the same with `--skip scripts`, as its runners lack `shellcheck`. *`tests/test_github.sh`.*
- **AC28** `workflows/pr.yml` (`pull_request` opened, edited, synchronize, reopened) runs `bin/check pr`: the title through the classifier, the body for tool credit. Separate from `ci.yml` so an `edited` run cannot replace a failed `ci.yml` result on the same SHA. *`tests/test_check_pr.sh`, `tests/test_github.sh`.*
- **AC29** `workflows/scorecard.yml`, from scorecard-action's `examples/scorecard.yml` on `main` (results published), runs only when `github.event.repository.private` is false (its code-scanning upload fails on private repositories without paid Code Security). No CodeQL is shipped, so Scorecard's SAST check scores low; `README.md` says so. *`tests/test_github.sh`.*
- **AC30** Every workflow: top-level `permissions:` of `contents: read` or `{}`, write only per job; no `pull_request_target` or `workflow_run`; every third-party `uses:` pinned to a 40-hex SHA followed by `# vX.Y.Z`. *`workflows`: fixtures tag ref, SHA without comment, no top-level permissions; `permissions: {}` passes.*

## 6. Git hooks and scripts

Git hooks wrap `bin/check`, so each rule runs the same way everywhere. `--no-verify` skips them and they run only after `bin/setup`; CI is the gate.

- **AC31** `commit-msg` runs `bin/check commit-msg "$1"`; `pre-commit` runs `bin/check --staged`; `pre-push` runs `bin/check --range` per ref: ref deletions skipped, a new branch checks commits `--not --remotes`, and no ref skips `docs`. *`tests/test_githooks.sh` (throwaway repo and bare remote).*
- **AC32** `.githooks/never-publish` lists `.scuba/*`, `CLAUDE.local.md`, `.claude/settings.local.json`, each also in `.gitignore`. `never-publish` refuses a tracked, staged or pushed match; a missing or comment-only list is a refusal; deleting a match passes. *`tests/test_check_never_publish.sh` (including `.gitignore` parity).*
- **AC33** `secrets` scans added lines (range, or index) for upstream's built-in patterns: AWS key ids, GitHub tokens, `sk-ant-`/`sk-proj-` keys, private-key headers, Slack tokens, and `key|secret|password|token` assigned a 20-plus-character value; it runs `gitleaks` too when installed. GitHub secret scanning is not relied on (paid for private repositories). *`tests/test_check_secrets.sh`, keys built at runtime.*
- **AC34** `bin/setup` sets `core.hooksPath` to `.githooks` and prints the bash and git versions and, for each of `jq`, `shellcheck`, `gitleaks`, `gh`, installed or missing. Running it twice changes nothing. *`tests/test_setup.sh`.*
- **AC35** `bin/new work SLUG` creates `docs/work/NNNN-SLUG/intent.md`; `bin/new spec NNNN` and `bin/new plan NNNN` refuse while the previous doc is missing or marked, then create it; `bin/new rfc SLUG` creates `docs/rfcs/0000-SLUG.md`; `bin/new adr SLUG` creates the next `docs/adr/NNNN-SLUG.md`, `proposed`. Existing targets and bad slugs are refused. Each template is under 40 lines, opens with a `draft` or `proposed` status line, and gives each section a one-line comment prompt. *`tests/test_new.sh`.*
- **AC36** `bin/init NAME` (`[a-z0-9][a-z0-9._-]*`; clean tree) sets the `README.md` title and description; rewrites `Okja-Engineering/oss-template` to `OWNER/NAME` (owner from `origin`, else `Okja-Engineering`) in `.github/ISSUE_TEMPLATE/config.yml` only, since every other mention points at the template on purpose; replaces the § Deciders list with a placeholder line for the new repository's decider; removes `template-only` comment blocks; deletes `docs/work/0001-oss-template/`, the template's ADRs 0001–0005, `tests/test_init.sh`, `tests/test_generation.sh` and itself; stages with `git add -A`; commits nothing. *`tests/test_init.sh`.*
- **AC37** **Scripts** are the executable files in `bin/` (not `bin/lib/`), `.githooks/` (not `never-publish`), `.claude/hooks/`, and `tests/*.sh`. `scripts` refuses a script not `100755`, any script or sourced library (`bin/lib/*.sh`, `tests/lib/*.sh`) failing `bash -n` or `shellcheck` (required when `CI=true`, otherwise skipped with a notice), and an invalid `.claude/settings.json`. Everything runs on bash 3.2 and 5 with git and POSIX tools; `jq` is needed by hooks and `scripts`. *`tests/test_check_scripts.sh`.*
- **AC38** `bin/check` (C4) prints `ok` or `FAIL` per check with what it examined; exits 0 when all pass, 1 on any refusal, 2 when it cannot run (outside a git repository, unknown check or option, a required tool missing); `--list` prints each check and a one-line description. *`tests/test_check_cli.sh`.*

## 7. Human docs

- **AC39** `CONTRIBUTING.md`: § Which change needs what; § Commits (summary, upstream link, the two divergences); § Issues and pull requests (one line linking upstream's [writing bar](https://github.com/Okja-Engineering/ai-native-sdlc/blob/main/AGENTS.md#write-it-the-way-you-would-say-it)); § Work folders; § RFCs; § ADRs (links the template's ADRs by URL); § Tests; § Labels; § What is enforced (§ 8's table, naming scripts); § What is not enforced (§ 8's list). *Reading; `claims`.*
- **AC40** `GOVERNANCE.md`: roles (maintainers in `CODEOWNERS`; deciders); reserved decisions; **approval** is a listed decider's PR comment `Ack at <head SHA>` on the PR's current head, and whoever merges quotes it in the merge commit; agents draft and may evaluate, never approve or accept, and carry no tool credit; a required-review ruleset applies only when two or more deciders are listed; § Deciders lists `Matthew Van Dusen`. *Reading; `docs` reads § Deciders.*
- **AC41** `SECURITY.md`: in a public repository, report through the Security tab's "Report a vulnerability" (private vulnerability reporting); in a private one, message a maintainer in `CODEOWNERS` directly, not an issue; acknowledgment target 7 days; latest `main` supported. `CODE_OF_CONDUCT.md` adopts Contributor Covenant 3.0 by reference, says maintainers enforce it per `GOVERNANCE.md`, and states in § Reporting that the contact is not yet set and that this blocks launch. `README.md` (model shape: what it is, status, getting started, contributing, security, licence; a `template-only` block on using the template) and `CHANGELOG.md` (Keep a Changelog 1.1.0, `## [Unreleased]`) complete the set. No personal email address anywhere; no employer or client mention. *Reading; `tests/test_generation.sh` refuses addresses outside `example.invalid`, `users.noreply.github.com` and § 3's signatures.*

## 8. What `bin/check` enforces, and what it does not

| Check | Refuses | ACs |
|---|---|---|
| `commits` | subjects outside the classifier; tool credit | AC8, AC9 |
| `secrets` | built-in patterns in added lines | AC33 |
| `never-publish` | matches of `.githooks/never-publish`; a missing or empty list | AC32 |
| `docs` | work-folder order and markers, names, numbers, status lines, deciders, ADR immutability, RFC numbering | AC2–AC7 |
| `agents` | `CLAUDE.md` not exact; `AGENTS.md` over 100 lines; frontmatter outside C3 | AC10, AC14, AC20, AC21 |
| `trace` | unlinked rule lines and unresolved links or sources in agent files | AC12 |
| `claims` | enforcement lines in human docs naming no script | AC13 |
| `workflows` | AC30 | AC30 |
| `scripts` | AC37 | AC15, AC37 |
| `pr` (alone) | PR title outside the classifier; tool credit in the body | AC28 |

**Not enforced**, and listed so in `CONTRIBUTING.md`: (1) that a person, not an agent, wrote an `accepted` status or a decider's name (only the listing is checked; `guard-docs.sh` stops the obvious agent path); (2) that an `Ack at <SHA>` comment preceded the merge, or is quoted in it; (3) that a doc was accepted before the next was started; (4) that the spec changed in the same PR as diverging code (the reviewer reports it); (5) test-first order; (6) the rung chosen; (7) PR description truth and section fill (measured, AC44); (8) FCP length, sign-off and disposition; (9) imperative mood; (10) whether linked human text says what an agent line claims; (11) that `.claude/rules/` load only for their paths (a person checks with `/memory`); (12) Claude Code hooks outside Claude Code, before workspace trust, or around a shell; (13) git hooks under `--no-verify` or before `bin/setup`; (14) secrets beyond the built-in patterns without `gitleaks`; (15) branch protection and required checks (settings, not files); (16) issue-form required fields outside public web forms; (17) script injection in workflows (`env:` is the convention); (18) absolute links; (19) the code of conduct and the security response target.

## 9. Measures

- **AC42 (M1)** Build: `tests/test_generation.sh` makes a root commit `Initial commit` from `git archive HEAD` and runs `bin/check --range "" HEAD` and `tests/run-all.sh` (with a guard so it doesn't run itself); after `bin/init demo`, both pass again. The same root commit pushed as `main` to a new public and a new private repository: no run on that SHA, Dependabot's included, concludes `failure`, `cancelled`, `timed_out`, `startup_failure` or `action_required`, and a run that executed `bin/check` concludes `success`; if nothing runs, it fails. A run whose jobs were all skipped is not a failure. **Launch:** the same rule on a real "Use this template" generation of each visibility.
- **AC43 (M2, M4)** Every check and hook has a suite that plants a violation and sees it refused, and feeds legitimate unusual input and sees it pass; the brief's fixtures are among them. Suites build fixtures with `tests/lib/fixture.sh`; none reads the real `docs/work/0001-oss-template/`, so `bin/init`'s deletions break nothing. *`tests/run-all.sh`.*
- **AC44 (M3 launch; M5–M7 after launch)** M3: in a clean environment (intent, measure 3) on a generated repository seeded with a small shell program, three tasks (doc fix, bug fix, capability), three runs each on current Claude Code and one each on one other `AGENTS.md` reader (reported). The rubric, written first, follows § 1, AC2, AC11 and the reserved decisions; pass is all nine Claude Code runs meeting every line. Hooks are re-verified on current Claude Code first (installed: 2.1.221). M5: five questions (artifact per change, who decides, enforced, not enforced, AI-assisted contributions), key written first; pass is four or more correct and none wrong, graded by someone other than reader and author. M6: report at 3 and 6 months. M7: over the first 20 outside PRs or 6 months, a PR fails if Summary, What changed, or How it was proved is deleted, empty or a placeholder; more than 25% failing fails; under 20, report only.

## Contracts

**C1 Status line.** Within a chain doc's first 5 lines: `**Status:** ` + state + free text. Work docs `draft` | `accepted DATE` | `done DATE` (`plan.md`); RFCs `draft` | `accepted DATE`; ADRs `proposed` | `accepted DATE` | `rejected DATE` | `deprecated DATE` | `superseded by NNNN DATE`; DATE is `YYYY-MM-DD`. Every state but `draft` and `proposed` needs `**Decider:** NAME` on the same line; NAME runs to the next ` **` or line end, less one trailing period, and must equal a § Deciders bullet in `GOVERNANCE.md` (text up to ` (`). One parser, `bin/lib/docs.sh`, serves `bin/check`, `bin/new` and the hooks.

**C2 Names.** `docs/work/NNNN-slug/`, `docs/adr/NNNN-slug.md`, `docs/rfcs/NNNN-slug.md`; slug `[a-z0-9]+(-[a-z0-9]+)*`; a `README.md` in those directories is ignored; templates live in `docs/templates/`.

**C3 Frontmatter subset** (bash can validate it; Claude Code's YAML parser accepts it). `key: value` (plain `[A-Za-z0-9][A-Za-z0-9 ,._/()'-]*`, or double-quoted with no inner quote) or `key:` then `  - "item"` lines. Keys: rules `paths` (list only), `source` (one quoted value or a list); skills `name`, `description`; subagents `name`, `description`, `tools`. `source` values are a human-doc path with optional `#anchor`, always double-quoted.

**C4 `bin/check`.** `bin/check [CHECK…]`: tree checks, plus `commits` over `@{upstream}..HEAD` and `docs` against the merge base when an upstream exists. `bin/check --range BASE HEAD [--skip CHECK] [CHECK…]`: tree checks plus `commits`, `secrets`, `never-publish` over `BASE..HEAD` and `docs` against `BASE`; an empty or all-zero `BASE` means every commit reachable from `HEAD`. `bin/check --staged`: tree checks; `secrets`, `never-publish` on the index; `docs` against `HEAD`. Also `commit-msg FILE`, `pr` (`PR_TITLE`, `PR_BODY`), `docs --report`, `--list`. Reads `PR_NUMBER` and `CI`.

## Decisions

- **D1** `CLAUDE.md` is `@AGENTS.md` (ADR-0002). Rejected: none, as upstream (2.1.221 reads nothing); a symlink (Windows checkout; Claude Code won't edit through it).
- **D2** Skills in `.claude/skills/` only. Rejected: `.agents/skills/` plus a plugin manifest.
- **D3** Generated subjects pass through one classifier (ADR-0005, upstream divergence). Rejected: a `revert` type (git doesn't write it); rewording (refuses text nobody wrote).
- **D4** Imperative mood unchecked: upstream's verb list refuses nouns (`fix: updates endpoint returns 500`).
- **D5** One status-line format; deciders listed in `GOVERNANCE.md`. Rejected: YAML frontmatter (the intent already uses the line); free-text names (pass "Claude" or "the team").
- **D6** Work-folder order enforced by existence and markers, not acceptance; an agent typing `accepted` proves nothing.
- **D7** Credit ban covers tools, not people (upstream divergence): GitHub writes human `Co-authored-by:` lines.
- **D8** Numbering: work folders and ADRs sequential; RFCs take their PR number. Rejected: issue numbers (this folder predates any issue).
- **D9** Issue forms, not upstream's Markdown templates: required fields, where GitHub honours them.
- **D10** PR template is upstream's verbatim plus `## Summary` (ruling 11), the line a PR-only change needs.
- **D11** Approval is a decider's `Ack at <SHA>` comment, not the merge click (upstream divergence); a review ruleset needs two or more deciders, because GitHub refuses self-approval. Agents never approve; merging is not denied.
- **D12** Scorecard only, public repositories only. Rejected: CodeQL (stack-specific; its upload also fails on private repositories).
- **D13** Labels: only those a process step uses, via `crazy-max/ghaction-github-labeler` (released 2026-03; EndBug/label-sync last released 2024-02). Rejected: path filter (uncertain on a root commit).
- **D14** Three git hooks; `pre-push` (beyond the brief) because a push is where a leak becomes public.
- **D15** Hooks require `jq` and fail closed. Rejected: a bash JSON reader (more code to trust); failing open (exit 127 is non-blocking).
- **D16** Security: private vulnerability reporting in public repositories (it exists only there), maintainers directly in private ones; no address invented.
- **D17** `bin/init` deletes the template's own records, rewrites one file's URLs, and stages without committing.
- **D18** The macOS leg runs everywhere: the decider works on macOS, whose `/bin/bash` is 3.2. Cost: macOS minutes on private repositories.
- **D19** No byte budget beyond `AGENTS.md` ≤ 100 lines and `CLAUDE.md` exact. Not shipped: `.mailmap`, `.git-blame-ignore-revs`, `REUSE.toml`, an org `.github` repository (ruling 7).

## Reserved for the decider (launch items; none blocks the build)

1. The code of conduct reporting contact. 2. The `maintainers` team for `CODEOWNERS` (none exists). 3. Hooks re-verified on current Claude Code. 4. The rollout settings in `plan.md`.
