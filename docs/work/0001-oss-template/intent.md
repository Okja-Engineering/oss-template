# 0001 oss-template: intent

**Status:** accepted 2026-11-22 by the decider. **Decider:** Matthew Van Dusen. **Rests on:** [`research.md`](research.md).

## The problem

Okja intends to run every repository, private or public, like open source, yet none has a repeatable, AI-native contribution practice: `ai-native-sdlc` (2026-09-23) writes it down, but each new repository still starts from scratch. The seven earlier public ones, set up by hand, differ:

- **Instructions for agents working in the repository:** three share one cross-agent file, one has editor rules, three have none.
- **CI actions:** one pins by commit (since 2026-10-12); six use mutable tags, which Scorecard flags.
- **Reverts:** one refuses git's revert subject at push and in CI. Bypassing its push hook skips its secret scan.

## Terms

- **The repository** (as agents and readers see it): its files plus the Okja documents they link to.
- **Build PR:** the pull request building the template.
- **Launch:** the dated announcement, after measure 3 and a real-generation measure 1 pass.
- **Reserved decisions:** accepting documents and approving changes; a named person's only.

## Who it serves, and what changes

- **Maintainers** of every new Okja repository start from one shared, self-checking foundation.
- **Outside contributors**, where a repository has them, know up front what a change needs and who decides.
- **Coding agents** find the process in the repository and are refused where a rule must hold.
- **Assessors** can trace each enforcement claim to its check.

## How we'll know it worked

Each measure states how it fails; the spec sets thresholds and fixtures.

1. **New repositories pass on their first commit.** Judged exactly as GitHub generates it, before any init or rename. Pass: every workflow run it triggers succeeds, one running `bin/check`; if nothing runs, it fails. *Gates the build PR* on a simulated GitHub generation (root commit "Initial commit", new repository), and *launch* on a real one.
2. **Checks refuse only what they should.** Each check fails on a planted violation and passes, unbypassed, on legitimate unusual input: git's and GitHub's revert and merge subjects, git's reapply subject, and "Initial commit". *Gates the build PR.*
3. **Agents follow the process untold.**
   - **Setup:** a clean environment (no user- or org-level instructions, skills, plugins or memory; linked Okja documents reachable), a generated repository seeded with a small program, and a prompt naming only the change.
   - **Doc fix:** only a PR.
   - **Bug fix:** an issue with intent and validation method, a failing test before the fix, then a PR with evidence.
   - **Capability:** intent, spec and plan, each followed by a person's decision; none starts while a `[NEEDS CLARIFICATION]` is open.
   - **Always:** reserved decisions stay with a named person.

   A person grades runs against a prewritten rubric, recording agent, version and configuration. Claude Code (current) must pass; one other cross-agent-file reader is reported, not gating. Rerun on process changes. *Gates launch.*
4. **Claims and rules trace to a source.** In the repository's own files (excluding linked and work-in-progress documents), rule-stating sentences name their check or say they're unenforced; agent-instruction rules link to human-facing text. Pass: zero exceptions; counting checks flag planted bad cases. Limits: matching is by wording; enforcement and linked-text agreement go unverified. *Gates the build PR.*
5. **A cold reader can answer the basics.** A senior engineer outside Okja, chosen by the decider and unnamed here, answers from the repository: which change needs which artifact, who decides, what is and isn't enforced, and the rule on AI-assisted contributions (an agent may evaluate, not approve; no tool or model credit). Pass: answers match a prewritten key, graded by someone else. *Reports after launch.*
6. **It is used.** Every Okja repository created after launch, private or public, came from the template (per GitHub) or says why not in its first issue. Counted at 3 and 6 months. None qualifying is no result. *Reports after launch.*
7. **PR templates get filled in.** In generated repositories with outside PRs, from launch, over the first 20 or 6 months (whichever first), count required sections deleted, empty or placeholder; above the spec's threshold fails. Okja's public repositories have had none; under 20, report without conclusion. *Reports after launch.*

## What this deliberately won't do

It won't restate the Okja process, choose a stack, promise a full Scorecard score at creation (it and some GitHub features differ in private repositories), give agents reserved decisions, retrofit existing repositories, add large-project governance, or sync generated repositories.
