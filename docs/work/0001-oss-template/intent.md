# 0001 oss-template: intent

**Status:** accepted 2026-11-22 by the decider; amended 2026-11-22 under ruling 14 by the chief of staff, and measure 1's gates amended 2026-11-22 by the chief of staff; both pending the decider's acceptance with the first slice's ack. **Decider:** Matthew Van Dusen. **Rests on:** [`research.md`](research.md), [`decisions.md`](decisions.md).

## The problem

Okja intends to run every repository, private or public, like open source, yet none has a repeatable, AI-native contribution practice: `ai-native-sdlc` writes one down, but each new repository starts from scratch. The seven earlier public ones, set up by hand, differ:

- Agent instructions: three share a cross-agent file, one has editor rules, three have none.
- One pins CI actions by commit (since 2026-10-12); six use mutable tags, which Scorecard flags.
- One refuses git's revert subject at push and in CI; bypassing its push hook skips its secret scan.

## Terms

- **Workspace:** this repository: a staged workflow an agent runs to create a **produced repository**, with an **operator** deciding at checkpoints.
- **Slice PRs:** the pull requests, one per slice, that build the workspace.
- **Launch:** the dated announcement, after measures 1 and 3 pass on a real run.
- **Reserved decisions:** accepting documents and approving changes. Only a named person makes them.

## Who it serves, and what changes

- **Operators** answer one questionnaire and decide at checkpoints instead of assembling repositories.
- **Maintainers** of every produced repository start from one shared, self-checking foundation.
- **Outside contributors**, where any exist, know up front what a change needs and who decides.
- **Coding agents** find the process written down and are refused where a rule must hold.
- **Assessors** can trace each enforcement claim to its check.

## How we'll know it worked

Each measure states how it fails; the spec sets thresholds and fixtures. Checks, not agents' accounts, carry the guarantees; the workflow ends in deterministic verification.

1. **Produced repositories pass on their first commit.** Judged on the first commit the workflow pushes: `bin/check` exits 0 and every workflow run it triggers concludes without failure, one running `bin/check`; if nothing runs, it fails. *Gates each slice PR* that touches the workflow or the foundation via a scripted fixed-answer run (render, verify and the produced repository's local checks); its GitHub half, the workflow runs, *gates launch*, on fixed answers and then on an agent's real run.
2. **Checks refuse only what they should.** Each check fails on a planted violation and passes, unbypassed, on legitimate unusual input: git's and GitHub's revert and merge subjects, git's reapply subject, and "Initial commit". *Gates the slice PRs.*
3. **Agents follow the process untold.** In a clean environment (no user- or org-level instructions, skills, plugins or memory; linked Okja documents reachable), an agent given only the workspace and "create a repository called X" completes every stage, stopping at each checkpoint and taking no reserved decision. In a produced repository, an agent prompted only with a change produces just what it needs: a PR for a doc fix; for a bug fix, an issue with intent and validation method, a failing test, then a PR with evidence; for a capability, intent, spec and plan, each decided by a person, none begun while a `[NEEDS CLARIFICATION]` is open. A person grades against a prewritten rubric, recording agent, version and configuration; Claude Code (current) must pass, one other cross-agent-file reader is reported; rerun on process changes. *Gates launch.*
4. **Claims and rules trace to a source.** In the workspace's and produced repositories' own files (not linked or work-in-progress documents), rule-stating sentences name their check or say they're unenforced; agent rules link to human text. Pass: zero exceptions; counting checks flag planted bad cases. Limits: matching is by wording; enforcement and agreement go unverified. *Gates the slice PRs.*
5. **Same answers, same foundation.** Two runs with identical questionnaire answers produce identical foundation files, apart from fields the spec lists as run-specific. *Gates the slice PRs.*
6. **A cold reader can answer the basics.** A senior engineer outside Okja, chosen by the decider and unnamed here, answers from a produced repository and its linked documents: which change needs which artifact, who decides, what is enforced, and how AI-assisted contributions are handled. Pass: answers match a prewritten key, graded by someone else. *Reports after launch.*
7. **It is used.** Every Okja repository created after launch records that the workflow produced it or says why not in its first issue; counted at 3 and 6 months. None qualifying is no result. *Reports after launch.*
8. **PR templates get filled in.** From launch, in produced repositories with outside PRs (first 20 or 6 months), count required sections deleted, empty or placeholder; above the spec's threshold fails; under 20, report without conclusion. *Reports after launch.*

## What this deliberately won't do

In v1 it won't restate the Okja process, add stack-specific tooling beyond what the questionnaire selects, retrofit existing repositories, ship as a plugin (exportable means self-contained, runnable by any `AGENTS.md` reader), promise a full Scorecard score at creation (it and some GitHub features differ in private repositories), give agents reserved decisions, add large-project governance, or sync produced repositories.
