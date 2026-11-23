# 0001 oss-template: decisions

The decider's rulings during intake, in his words, and every call made for him under ruling 12. The spec and plan cite this file. The rulings come from the chief of staff's intake notes, recorded at the time in chat. Only words about this template are quoted; `[…]` marks an omission.

## The decider's rulings (2026-11-22, CST, in chat)

**Rulings 1–4, 18:28.** "Accept all four", accepting the chief of staff's recommendations on four open points in the intent:
1. Measure 1's "first commit" is the commit exactly as GitHub generates it; the template must pass before `bin/init`.
2. Measure 3 (the agent test) gates launch, not the build PR.
3. Claude Code on the current version must pass measure 3; one other `AGENTS.md`-reading agent is reported, not gating.
4. Measure 5's cold reader is a senior engineer outside Okja, chosen by the decider, not named in the repository, and graded by someone else.

**Rulings 5–9, 18:29.** "Keep it public; accept your other recommendations - I'm a bit torn on AI disclosure. I do think that things written for human consumption should be written by a human for a human […] I think we're allowing AI contributions, though. […] But I would rather stick with the AI native SDLC and not have to divert from it."
5. `oss-template` stays public.
6. No AI-disclosure field, following `ai-native-sdlc`. AI contributions are allowed.
7. Community health files live in each repository, not in an org `.github` repository.
8. Agent-written prose is not banned: an agent drafts, a named person decides.
9. Contributor Covenant 3.0 by reference. The reporting contact is still open.

**Ruling 6, refined, about 18:35** (the chief of staff's paraphrase, with the decider's quoted words): AI-written text is fine if it reads as written by a person for a person; the point is no slop. For the PR template he wants "something like a summary, what's changed, and maybe findings".

**Ruling 10, time not recorded (between 18:29 and 18:34).** "this is just setting so I don't have to recreate all these every single repository that I'm making […] we're gonna run all software like it's open source software, whether it's private or not, and so that is going to have an RFC and ADRs and issue templates […] a PR template […] A README that looks like this, security file that looks like this, a contributing file that looks like this." The template is the foundation for every Okja repository, private or public.

**Ruling 11, 18:34.** "yes, Summary […]": the PR template is a one-line Summary plus `ai-native-sdlc`'s three sections.

**Ruling 12, 18:35.** "I'm leaning on you a lot for some of these decision making. I don't need you to check with me. […] we talked a bunch about what we want to do and why, and I think that you should just build it." The intent is accepted. The review stops after the spec and after the plan are waived, and the chief of staff makes the spec and plan calls. Ruling 12 waives the stops, not the decisions: the spec and plan stay `draft`, and the decider accepts them, or doesn't, when he acks the build PR. Merging the build PR still needs his ack at its head.

**Ruling 14, 19:46 (direction change; amends the accepted intent).** "I was kind of wondering if this repo should not just be an icm /claude repo where we provide exportable sequenced workflow for creating a new repo […] instead of a strict template is a starting point […] structured like process and can be consumed by a ai agent to create a new repo". Asked whether to build the template first and add the ICM workflow next, or switch to ICM now, he answered: "Switch to ICM now".

What it changes:
- The repository becomes an ICM workspace: a sequenced workflow that an agent runs to create a new Okja repository. It is no longer a strict GitHub template.
- The intent is amended (its status line records the amendment). The spec and plan are rewritten.
- The build of the template plan stops.
- Calls 1–43 below were made for the template design. The rewritten spec says which of them still hold.

**Ruling 15, 20:17 (approves the workflow sketch's shape).** "Yeah, I'd go with anything that's like agentic. I mean, that air quoted agentic workflow is that it's 60% deterministic, 30% orchestration, and 10% judgment." The design follows that split: scripts do the deterministic work, stage contracts orchestrate, and the agent's judgment is the small remainder.

**Launch item, the decider's call: the name.** `oss-template` no longer describes the repository, since it is not a template and its output need not be open source. Renaming it is the decider's call, and nothing in the workspace depends on the current name.

### Calls made under rulings 12 and 14 for the amended intent

These were made by the chief of staff's drafting agent, as delegated ("I don't need you to check with me"). None is the decider's.
- **v1 is stack-agnostic.** The only tooling is what the questionnaire selects; stack adaptation is a later stage.
- **No retrofitting of existing repositories in v1.** A later stage may add it.
- **"Exportable" means self-contained.** The workspace runs when any `AGENTS.md`-reading agent is pointed at it. There is no plugin or marketplace packaging in v1.
- **Guarantees are deterministic.** The workflow ends in a verification stage. Identical questionnaire answers must produce identical foundation files (new measure 5).
- **Measure 1 is gated two ways.** The build PR is gated by a scripted run with fixed answers, no agent involved. Launch is gated by an agent's real run.
- **Measure 7 changes its record.** It counts a produced repository's own record that the workflow made it, replacing GitHub's template record, which an ICM-produced repository does not have.

## Calls made under ruling 12

Each call below was made by the chief of staff (an agent), or drafted by an agent it dispatched and taken by the chief of staff at a review gate, delegated under ruling 12. None is the decider's. Each gives the option taken and what was rejected.

### Agent configuration
1. `CLAUDE.md` is the single line `@AGENTS.md` (ADR-0002). Rejected: no `CLAUDE.md`, as upstream does (Claude Code 2.1.221, installed here, then reads no project instructions); a symlink (checked out as text on Windows; Claude Code won't edit through it).
2. Skills live in `.claude/skills/` only. Rejected: `.agents/skills/` plus a plugin manifest (Claude Code doesn't read `.agents/`).
3. Agent-rule sources are human docs in this repository, which may link upstream. There is no agent-only escape. Hook refusal messages and `.claude/settings.json` deny entries trace to human text too.
4. Hooks require `jq` and fail closed: a PreToolUse hook exits 0 only when it has set an explicit allow flag, and exits 2 on every other path. Rejected: a bash JSON reader (more code to trust); an `EXIT` trap mapping non-zero to 2 (run under macOS `/bin/bash` 3.2 with `set -u`, a script that aborted on an unset variable exited 0 through that trap, which Claude Code reads as allow); failing open (a missing command exits 127, which Claude Code treats as non-blocking).
5. `guard-docs.sh` simulates edits with awk `index`/`substr` on values passed through `ENVIRON`. Rejected: `${v/…/…}`, which treats `&` and patterns differently across bash versions.
6. Every status change is reserved for a decider. Agents create chain docs only as `draft` or `proposed`, may edit bodies, and never change a status line or `**Decider:**` field. Superseding an ADR needs the new ADR accepted first.
7. `guard-bash.sh` is a denylist. Upstream's `AGENTS.md` says denylists fail open; this diverges from that, and the limit is listed as unenforced.
8. Approval record integrity: `guard-bash.sh` refuses `gh` writes containing `Ack at`, and `gh api` writes to reviews or merges. Unenforced, and stated: an agent holding the decider's token can post as him by another route, and an agent can edit `.claude/hooks/` or `.claude/settings.json` to disable the guards. With a ruleset, `CODEOWNERS` routes such edits to review.
9. No byte budget beyond `AGENTS.md` ≤ 100 lines and `CLAUDE.md` exact.

### Process and records
10. Approval is a listed decider's PR comment `Ack at <head SHA>` on the PR's current head, quoted in the squash or merge commit body by whoever merges. A required-review ruleset applies only when two or more deciders are listed, because GitHub refuses self-approval. Agents never approve; an agent may merge after an ack. Diverges from upstream, where the merge is the approval.
11. Merges into `main` are squash or merge commits; rebase merging is disabled, so the merge carries the quoted ack.
12. One status-line format for every chain doc, with a `**Decider:**` field on every one (on a draft: who will decide), and deciders listed in `GOVERNANCE.md` § Deciders. Rejected: YAML frontmatter (the accepted intent already uses the line); upstream's `DECIDERS.md` table with a `decided_by:` field (two places to keep in step); free-text names (they pass "Claude" or "the team").
13. A decider is checked when the decision is made: a status line entering a decided state in the checked range must name a listed decider. Inherited ADRs stay valid after `bin/init` replaces § Deciders. Rejected: validating every decided doc on every run (breaks every inherited ADR after init); keeping the template's deciders in generated repositories.
14. Work-folder order is enforced by existence and open markers, not by acceptance: an agent typing `accepted` proves nothing.
15. Numbering: work folders and ADRs sequential; RFCs take their PR number (rust-lang/rfcs). Generated repositories number their own ADRs from 0006. Rejected: issue numbers for work folders (this folder predates any issue).
16. RFC final comment period: a summary and a proposed disposition (merge, close, postpone); it starts when every listed decider has signed off and lasts 7 calendar days.
17. The template's ADRs stay in generated repositories as inherited, binding decisions. `bin/init` deletes only `docs/work/0001-oss-template/`, the generation script, its own test and itself. Rejected: deleting them (a generated repository would follow decisions it has no record of).
18. `bin/init` rewrites the template's URL only in `.github/ISSUE_TEMPLATE/config.yml`; every other mention points at the template on purpose. It replaces § Deciders with a placeholder; filling it is exempt from the RFC rung. It stages and does not commit.
19. The spec and plan stay `draft` until the decider acts on the build PR.

### Commits and pull requests
20. One subject classifier serves every enforcement point. Subjects git or GitHub writes pass: `Revert "…"`, `Reapply "…"`, merges, root `Initial commit`, `Squashed commit of the following:`, `Apply suggestions from code review` (ADR-0005). Rejected: a `revert` type (git doesn't write it); rewording (refuses text nobody wrote). Diverges from upstream.
21. The commit-msg hook classifies by subject alone, since an amend hides whether the commit is a merge or a root. Range mode checks parents. The hook may be laxer than CI, never stricter.
22. The credit ban covers tools, not people: GitHub writes human `Co-authored-by:` lines for applied suggestions and squash merges. It is a denylist of known tool names and addresses, so a new tool's name passes; listed as unenforced. Diverges from upstream.
23. Breaking-change `!` is allowed (Conventional Commits 1.0.0).
24. Imperative mood is not checked: upstream's verb list refuses nouns (`fix: updates endpoint returns 500`).
25. Issue forms, not upstream's Markdown templates. Required fields hold only in the web form of a public repository.
26. The PR template is upstream's file verbatim after a `## Summary` section (rulings 6, 11). The Summary is the line a PR-only change needs, since it has no issue. Summary, What changed, and How it was proved are required by `CONTRIBUTING.md` and not checked (measure 7 counts them).
27. PR title and body are checked in `pr.yml`, apart from `ci.yml`, so an `edited` run cannot replace a failed `ci.yml` result on the same SHA.
28. Dependabot: prefix `chore`, no scope, no groups, so its subjects pass the classifier at ≤ 72 characters.

### CI and checks
29. Every test reads fixtures. Assertions about the real tree belong to `bin/check` (`layout` holds them), and the generation simulation is a script CI runs, not a suite.
30. Measure 4 covers every rule-stating sentence in tracked Markdown outside `docs/adr/`, `docs/work/` and `CHANGELOG.md`. Rule words: must, must not, required, never, refuse(s/d), block(s/ed), reject(s/ed), enforce(s/d), prevent(s/ed). Each such sentence names a check or says it is unenforced. Matching is by wording.
31. `docs` compares against `git merge-base BASE HEAD`, and `secrets` scans what that merge base adds. A new ref with no remote base compares against the remote default branch's merge base. Only a repository's first push has nothing to compare.
32. Measure 1 counts a run concluding `skipped` as not failed (Scorecard skips every job on a private repository). Rejected: requiring every run to conclude `success`, which would fail every private generation when nothing is broken.
33. Scorecard only, and only on public repositories. No CodeQL ships, so Scorecard's SAST check scores low, and `README.md` says so. Rejected: CodeQL (stack-specific; its upload also fails on private repositories without paid Code Security).
34. `shellcheck` v0.11.0 is installed on the Ubuntu leg from its GitHub release, verified by sha256, with `REQUIRE_SHELLCHECK=1`. Elsewhere its cases are skipped with a notice.
35. The macOS leg runs in every generated repository: the decider works on macOS, whose `/bin/bash` is 3.2. Cost: macOS minutes on private repositories.
36. Three git hooks, including `pre-push` (beyond the brief), because a push is where a leak becomes public.
37. `secrets` uses upstream's built-in patterns plus `gitleaks` when installed. GitHub secret scanning is not relied on (paid for private repositories).
38. Labels: only those a process step applies. A repository's own `A-`/`P-`/`T-` labels must be added to `labels.yml`, because the sync deletes unlisted labels. Rejected: EndBug/label-sync (no release since 2024-02); a path filter (uncertain on a root commit).

### Security, conduct, scope
39. Security reports: private vulnerability reporting in public repositories, where it exists; a maintainer directly in private ones. No address is invented. Acknowledgment target: 7 days.
40. Contributor Covenant 3.0 by reference. The reporting contact is the decider's (a launch item).
41. `CODEOWNERS` names `@Okja-Engineering/maintainers`. No such team exists; creating it is the decider's (a launch item).
42. Not shipped: `.mailmap`, `.git-blame-ignore-revs`, `REUSE.toml`.
43. A serial build, one task per commit, each commit green on bash 3.2 without `shellcheck` and with the normal `PATH` and `REQUIRE_SHELLCHECK=1`.
