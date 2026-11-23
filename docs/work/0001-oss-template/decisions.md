# 0001 oss-template: decisions

The decider's rulings during intake, in his words, and every call made for him under ruling 12. The spec and plan cite this file. The rulings come from the chief of staff's intake notes, recorded at the time in chat. Only words about this template are quoted; `[…]` marks an omission.

## The decider's rulings (2026-11-22, in chat)

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

**Ruling 12, 18:35.** "I'm leaning on you a lot for some of these decision making. I don't need you to check with me. […] we talked a bunch about what we want to do and why, and I think that you should just build it." The chief of staff's reading, not the decider's words: the intent is accepted; the review stops after the spec and after the plan are waived, and the chief of staff makes the spec and plan calls. Ruling 12 waives the stops, not the decisions: the spec and plan stay `draft`, and the decider accepts them, or doesn't, when he acks the first pull request into `main` (decision 69). Merging each pull request into `main` still needs his ack at its head.

**Ruling 13, 19:43.** "Yes, go ahead", answering "For the final check, may I create then delete two throwaway repos in Okja-Engineering?" One public and one private throwaway repository may be created in `Okja-Engineering` for the final measure 1 check, and exactly those two deleted afterwards.

**Ruling 14, 19:46 (direction change; amends the accepted intent).** "I was kind of wondering if this repo should not just be an icm /claude repo where we provide exportable sequenced workflow for creating a new repo […] instead of a strict template is a starting point […] structured like process and can be consumed by a ai agent to create a new repo". Asked whether to build the template first and add the ICM workflow next, or switch to ICM now, he answered: "Switch to ICM now".

What it changes:
- The repository becomes an ICM workspace: a sequenced workflow that an agent runs to create a new Okja repository. It is no longer a strict GitHub template.
- The intent is amended (its status line records the amendment). The spec and plan are rewritten.
- The build of the template plan stops.
- Decisions 1–43 below were made for the template design. The rewritten spec says which of them still hold.

**Ruling 15, 20:17 (approves the workflow sketch's shape).** "Yeah, I'd go with anything that's like agentic. I mean, that air quoted agentic workflow is that it's 60% deterministic, 30% orchestration, and 10% judgment." The design follows that split: scripts do the deterministic work, stage contracts orchestrate, and the agent's judgment is the small remainder.

**Ruling 16, 20:17.** "and you stage everything out. Like, it should never be a big bulk, incremental disclosure, progressive disclosure, or whatever."

### Design principles from rulings 15 and 16

The chief of staff's reading of the two rulings, applied by the spec and plan:
- **60% deterministic, 30% orchestration, 10% judgment** (ruling 15). Scripts do every write. Stage contracts hold the sequence and the checkpoints. The agent drafts answers, presents checkpoints and diagnoses failures. The spec says which share each stage step is.
- **Progressive disclosure everywhere** (ruling 16). Always-on files stay small, under checked budgets. Each stage contract names exactly the files it loads, in an Inputs table whose paths resolve, and no contract loads a directory or "everything". References load on demand. Produced repositories follow the same pattern.
- **Delivery is staged too** (ruling 16): small pull requests, each shippable and verifiable on its own, not one bulk change.

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
1. `CLAUDE.md` is the single line `@AGENTS.md` (ADR-0002). Rejected: no `CLAUDE.md`, as upstream does (the Claude Code version tested then reads no project instructions); a symlink (checked out as text on Windows; Claude Code won't edit through it).
2. Skills live in `.claude/skills/` only. Rejected: `.agents/skills/` plus a plugin manifest (Claude Code doesn't read `.agents/`).
3. Agent-rule sources are human docs in this repository, which may link upstream. There is no agent-only escape. Hook refusal messages and `.claude/settings.json` deny entries trace to human text too.
4. Hooks require `jq` and fail closed: a PreToolUse hook exits 0 only when it has set an explicit allow flag, and exits 2 on every other path. Rejected: a bash JSON reader (more code to trust); an `EXIT` trap mapping non-zero to 2 (run under macOS `/bin/bash` 3.2 with `set -u`, a script that aborted on an unset variable exited 0 through that trap, which Claude Code reads as allow); failing open (a missing command exits 127, which Claude Code treats as non-blocking).
5. `guard-docs.sh` simulates edits with awk `index`/`substr` on values passed through `ENVIRON`. Rejected: `${v/…/…}`, which treats `&` and patterns differently across bash versions.
6. Every status change is reserved for a decider. Agents create chain docs only as `draft` or `proposed`, may edit bodies, and never change a status line or `**Decider:**` field. Superseding an ADR needs the new ADR accepted first.
7. `guard-bash.sh` is a denylist. Upstream's `AGENTS.md` says denylists fail open; this diverges from that, and the limit is listed as unenforced.
8. Approval record integrity: `guard-bash.sh` refuses `gh` writes containing `Ack at`, and `gh api` writes to reviews or merges. Unenforced, and stated: an agent holding the decider's token can post as him by another route, and an agent can edit `.claude/hooks/` or `.claude/settings.json` to disable the guards. With a ruleset, `CODEOWNERS` routes such edits to review.
9. No byte budget beyond `AGENTS.md` ≤ 100 lines and `CLAUDE.md` exact. *Superseded by decision 64.*

### Process and records
10. Approval is a listed decider's PR comment `Ack at <head SHA>` on the PR's current head, quoted in the squash or merge commit body by whoever merges. A required-review ruleset applies only when two or more deciders are listed, because GitHub refuses self-approval. Agents never approve; an agent may merge after an ack. Diverges from upstream, where the merge is the approval.
11. Merges into `main` are squash or merge commits; rebase merging is disabled, so the merge carries the quoted ack.
12. One status-line format for every chain doc, with a `**Decider:**` field on every one (on a draft: who will decide), and deciders listed in `GOVERNANCE.md` § Deciders. Rejected: YAML frontmatter (the accepted intent already uses the line); upstream's `DECIDERS.md` table with a `decided_by:` field (two places to keep in step); free-text names (they pass "Claude" or "the team").
13. A decider is checked when the decision is made: a status line entering a decided state in the checked range must name a listed decider. Inherited ADRs stay valid after `bin/init` replaces § Deciders. Rejected: validating every decided doc on every run (breaks every inherited ADR after init); keeping the template's deciders in generated repositories. *Amended by decision 45.*
14. Work-folder order is enforced by existence and open markers, not by acceptance: an agent typing `accepted` proves nothing.
15. Numbering: work folders and ADRs sequential; RFCs take their PR number (rust-lang/rfcs). Generated repositories number their own ADRs from 0006. Rejected: issue numbers for work folders (this folder predates any issue). *Its 0006 start is superseded by decision 58: produced repositories number their own ADRs from 0001.*
16. RFC final comment period: a summary and a proposed disposition (merge, close, postpone); it starts when every listed decider has signed off and lasts 7 calendar days.
17. The template's ADRs stay in generated repositories as inherited, binding decisions. `bin/init` deletes only `docs/work/0001-oss-template/`, the generation script, its own test and itself. Rejected: deleting them (a generated repository would follow decisions it has no record of). *Superseded by decision 58.*
18. `bin/init` rewrites the template's URL only in `.github/ISSUE_TEMPLATE/config.yml`; every other mention points at the template on purpose. It replaces § Deciders with a placeholder; filling it is exempt from the RFC rung. It stages and does not commit. *Superseded: render replaces `bin/init`.*
19. The spec and plan stay `draft` until the decider acts on the build PR.

### Commits and pull requests
20. One subject classifier serves every enforcement point. Subjects git or GitHub writes pass: `Revert "…"`, `Reapply "…"`, merges, root `Initial commit`, `Squashed commit of the following:`, `Apply suggestions from code review` (ADR-0005). Rejected: a `revert` type (git doesn't write it); rewording (refuses text nobody wrote). Diverges from upstream.
21. The commit-msg hook classifies by subject alone, since an amend hides whether the commit is a merge or a root. Range mode checks parents. The hook may be laxer than CI, never stricter.
22. The credit ban covers tools, not people: GitHub writes human `Co-authored-by:` lines for applied suggestions and squash merges. It is a denylist of known tool names and addresses, so a new tool's name passes; listed as unenforced. Diverges from upstream.
23. Breaking-change `!` is allowed (Conventional Commits 1.0.0).
24. Imperative mood is not checked: upstream's verb list refuses nouns (`fix: updates endpoint returns 500`).
25. Issue forms, not upstream's Markdown templates. Required fields hold only in the web form of a public repository.
26. The PR template is upstream's file verbatim after a `## Summary` section (rulings 6, 11). The Summary is the line a PR-only change needs, since it has no issue. Summary, What changed, and How it was proved are required by `CONTRIBUTING.md` and not checked (measure 7 counts them). *Amended by decision 75.*
27. PR title and body are checked in `pr.yml`, apart from `ci.yml`, so an `edited` run cannot replace a failed `ci.yml` result on the same SHA.
28. Dependabot: prefix `chore`, no scope, no groups, so its subjects pass the classifier at ≤ 72 characters.

### CI and checks
29. Every test reads fixtures. Assertions about the real tree belong to `bin/check` (`layout` holds them), and the generation simulation is a script CI runs, not a suite.
30. Measure 4 covers every rule-stating sentence in tracked Markdown outside `docs/adr/`, `docs/work/` and `CHANGELOG.md`. Rule words: must, must not, required, never, refuse(s/d), block(s/ed), reject(s/ed), enforce(s/d), prevent(s/ed). Each such sentence names a check or says it is unenforced. Matching is by wording.
31. `docs` compares against `git merge-base BASE HEAD`, and `secrets` scans what that merge base adds. A new ref with no remote base compares against the remote default branch's merge base. Only a repository's first push has nothing to compare.
32. Measure 1 counts a run concluding `skipped` as not failed (Scorecard skips every job on a private repository). Rejected: requiring every run to conclude `success`, which would fail every private generation when nothing is broken.
33. Scorecard only, and only on public repositories. No CodeQL ships, so Scorecard's SAST check scores low, and `README.md` says so. Rejected: CodeQL (stack-specific; its upload also fails on private repositories without paid Code Security).
34. `shellcheck` v0.11.0 is installed on the Ubuntu leg from its GitHub release, verified by sha256, with `REQUIRE_SHELLCHECK=1`. Elsewhere its cases are skipped with a notice.
35. The macOS leg runs in every generated repository, holding the macOS `/bin/bash` 3.2 floor. Cost: macOS minutes on private repositories.
36. Three git hooks, including `pre-push` (beyond the brief), because a push is where a leak becomes public.
37. `secrets` uses upstream's built-in patterns plus `gitleaks` when installed. GitHub secret scanning is not relied on (paid for private repositories).
38. Labels: only those a process step applies. A repository's own `A-`/`P-`/`T-` labels must be added to `labels.yml`, because the sync deletes unlisted labels. Rejected: EndBug/label-sync (no release since 2024-02); a path filter (uncertain on a root commit).

### Security, conduct, scope
39. Security reports: private vulnerability reporting in public repositories, where it exists; a maintainer directly in private ones. No address is invented. Acknowledgment target: 7 days.
40. Contributor Covenant 3.0 by reference. The reporting contact is the decider's (a launch item).
41. `CODEOWNERS` names `@Okja-Engineering/maintainers`. No such team exists; creating it is the decider's (a launch item).
42. Not shipped: `.mailmap`, `.git-blame-ignore-revs`, `REUSE.toml`.
43. A serial build, one task per commit, each commit green on bash 3.2 without `shellcheck` and with the normal `PATH` and `REQUIRE_SHELLCHECK=1`.

### Calls from the third spec review (chief of staff, delegated under ruling 12)

Made at the third gate on the template spec. They apply to the checks and hooks that become the foundation.

44. Range mode judges exactly `HEAD`'s tree, read through git, never the working tree; CI checks out the head SHA with full history; pre-push judges each pushed ref's tree. Rejected: judging the checkout (an uncommitted edit, or an RFC merged to `main` after branching, changed the verdict).
45. Every status-line or `**Decider:**` change on any chain doc is checked against the deciders listed at the docs base, or in the tree when there is no base. Changing `GOVERNANCE.md` § Deciders is a reserved decision, and `guard-docs.sh` refuses an agent edit to it.
46. `guard-docs.sh` simulates `replace_all` for `Edit` and `MultiEdit`.
47. The email allowlist and the relative-link scan each get planted failing cases, as checks rather than steps of a generation script. *Amended by decision 77: links are resolved by `trace`, in agent files only.*
48. Suites that test bash behaviour run under each bash present and skip a missing one with a notice; CI's Ubuntu leg is bash 5, its macOS leg 3.2. *Amended by decision 77: the two CI legs supply the two bashes.*
49. An RFC is renamed to its PR's number once the PR is open (rust-lang/rfcs practice). This departs from the brief, which said on merge.
50. With an empty base, the docs base is keyed on where the checked commits start, not on resolving the remote default branch.

### Calls for the ICM workspace (architect, delegated under rulings 12 and 14)

Made for the rewritten spec and plan. Each gives the option taken and what was rejected. None is the decider's.

51. **One source per file.** `foundation/` holds only templates; every other file of a produced repository is shipped verbatim from the workspace's own copy, listed in `shared/manifest.txt`. Rejected: the produced tree copied whole under `foundation/` (the sketch's shape): two copies of every script, so each script change is made twice and drift is caught rather than impossible. *Reversed by decisions 68 and 78.*
52. **Templates end in `.tmpl`.** Rejected: plain names under `foundation/`, because agents that read nested `AGENTS.md` files would load an unrendered one, and the workspace's Markdown checks would judge unrendered text; an exclusion list inside the shipped checks (product code knowing workspace paths).
53. **A render is identified by its git tree id** (its fingerprint), which covers modes. Rejected: a sha256 manifest (a second format; `shasum` and `sha256sum` differ by platform).
54. **Render reads the workspace at `HEAD` by default**, through the same tree reader the checks use, so a render is a function of the workspace commit and the answers. Rejected: reading the working tree (uncommitted edits would reach a produced repository unrecorded).
55. **One answers file per run**, setup and run fields merged, read as data and never sourced. Rejected: two input files (measure 5 would be defined over a pair); sourcing it as shell (a value would execute).
56. **One script per stage** (`bin/ask`, `bin/render`, `bin/verify`, `bin/publish`), and scripts do every write (ruling 15). State lives only in each stage's `output/<name>/`, so any session resumes from files. Rejected: agent-typed `git` and `gh` commands (not repeatable, cannot meet measure 5); a standing operator session; a retrofit stage or an agent "adapt" stage in v1 (an intent non-goal; agent-written produced files would break measure 5).
57. **Checks are files**, `bin/checks/<name>`, discovered by `bin/check`. The workspace adds its own checks the same way a produced repository would. Rejected: a second entry point such as `bin/check-workspace` (hooks and CI would miss it); workspace conditions inside the shipped `bin/check`. *Amended by decision 95.*
58. **Produced repositories do not copy the workspace's ADRs.** Their `docs/adr/README.md` links them, and they number their own from 0001. Amends decision 17. Rejected: copying them, since under decision 45 an inherited ADR whose decider is not listed in the produced repository fails its first commit, and exempting the first commit would weaken `docs` everywhere.
59. **Publish is plan, apply, watch.** `--apply` takes the exact plan line the person approved and refuses if the state moved; each step reads state first, so a rerun resumes; nothing is force-pushed. The script's first push of `main` is the one push to a default branch the workflow makes, after the checkpoint. Rejected: requiring a terminal confirmation (an agent could not complete the stage, and it can't be tested); a Claude Code `ask` permission rule (`.claude/settings.json` ships to produced repositories, and the rule holds only in Claude Code). The checkpoint stays orchestration and is listed as not enforced.
60. **Render substitutes and nothing else**: `{{FIELD}}` becomes the field's value, and a line that is exactly `- {{FIELD}}` repeats per item of a list field. Rejected: conditionals (text that differs by visibility stays one text covering both, as `SECURITY.md` already does). *Amended by decision 78 (whole-file variants).*
61. **Stage outputs are ignored by a `.gitignore` inside each `output/`**, so the root `.gitignore` stays a product file. **The target is outside the workspace.** Rejected: a root ignore pattern (a workspace path in every produced repository); a target under `output/` (the running agent would load the produced repository's nested agent files, and searches would see two repositories).
62. **Self-render is the cross-platform proof of measure 5**: the workspace's committed files must equal their render on both CI legs. Rejected: committed fixture fingerprints (they change with every foundation change); a cross-job comparison in `ci.yml` (workspace logic in a shipped workflow). *Superseded by decision 84.*
63. **The email audit is part of `bin/verify`**, judging what a run produces. Rejected: a shipped check, since produced repositories legitimately add addresses (a conduct contact, say). *Amended by decision 109.*
64. **Budgets on always-on files** (supersedes decision 9): `AGENTS.md` at most 80 lines, `CONTEXT.md` at most 60, each stage contract at most 80. Rejected: byte budgets (lines are what ICM and the earlier `AGENTS.md` limit already use).
65. **No year or licence-holder field.** `LICENSE` is the Apache-2.0 text, shipped verbatim, which names neither; so no answer depends on the clock and no field is run-specific. *Superseded by decision 74.*
66. **The measure 3 rubric is kept outside the workspace**, in its tracking issue, because an agent under test could read anything in the workspace.
67. **Delivery is sliced**: each slice is a pull request into `feat/initial-template`, ship-gated and merged in order with a merge commit; one pull request then goes into `main`, merged with a merge commit so each slice and this folder's history stay reachable. Rejected: one bulk pull request (ruling 16). Each slice is shippable alone, so pointing them at `main` one by one, each with the decider's ack, needs no change to the plan; that choice is the decider's. *Superseded by decision 69.*

### Calls from the first workspace review (chief of staff, delegated under ruling 12)

Made at the gate on the first workspace spec and plan. Each gives the option taken and what it replaced.

68. **The workspace is not an instance of its own product.** `foundation/` holds the complete product tree: templates and verbatim files, scripts included, one copy each. The workspace root holds only workspace files, and `docs/workflow.md` is the human source for every workflow rule. Replaces decision 51 and self-render, which the review traced most findings to: the workspace's own documents had to say what every produced repository says.
69. **Slices go into `main` one by one**, each with the decider's ack at its head (ruling 16). `feat/initial-template` carries this folder into the first slice. Supersedes decision 67.
70. **Publishing names a listed decider.** `bin/publish --apply` takes `--approver NAME`, refused unless NAME is listed in the workspace's `GOVERNANCE.md` § Deciders; `publish.md` records the approver, the time and the exact line approved. The approved line lists every outward action. Not enforced: an agent can pass the decider's name.
71. **Only a clean `HEAD` render publishes.** Render reads committed `HEAD` only; `--plan` refuses a dirty workspace or a render from another commit, and re-derives verification rather than trusting `verify.md`.
72. **Ancestry is checked against a recorded ref**, by default the remote default branch; the live measure 1 check names its pull request's branch. *Superseded by decision 93.*
73. **Answers are validated as produced text.** `bin/ask` refuses a value that would trip `claims` or `trace` in the produced repository; `bin/ask --redo` clears an unpublished run; stage 03's remedy depends on the failure; stage 01 audits the description against upstream's writing bar; the questionnaire is generated from the schema.
74. **Licence, pending the decider:** a `LICENSE` answer, `apache-2.0` by default for public repositories and `none` (an all-rights-reserved notice) for private ones; the operator may override per repository. Supersedes decision 65.
75. **The PR template pins upstream's whole blob.** The Summary section sits after upstream's `Closes #` line, and removing it gives upstream's file exactly. Ruling 11's "change it upstream too" is a rollout step; once upstream has the section, the pin moves to its new blob with nothing inserted.
76. The intent's status line wrongly said the decider made the amendment; it now says the chief of staff did, under ruling 14, pending the decider's acceptance, which he gives or withholds with the first slice's ack.
77. **Cut:** the bash-version helper (the CI legs supply bash 3.2 and 5); render's `--source`; the separate `links` check (`trace` resolves links in agent files); the smoke-test gate G5.

### Calls for the revised workspace (architect, delegated under rulings 12 and 14)

78. **No manifest: the product is `foundation/`.** A `.tmpl` file is a template; a file named `PATH.VALUE` is a whole-file variant, chosen by the field the schema says selects `PATH`. Rejected: a manifest (a second list of the folder's contents); conditionals inside a file's text.
79. **The workspace runs product checks by invocation.** Its `bin/check` calls `foundation/bin/check` with the checks that fit a workspace and `--paths ':!foundation'`; `bin/check` discovers checks beside itself and in the repository's `bin/checks/`; product scripts find their libraries by their own location and judge the repository they run in; the workspace's git hooks and Claude Code hooks are the product's, invoked from `foundation/`. Rejected: copies at the root (decision 68); running every product check on the workspace (`layout` and others describe a produced repository). *Superseded by decision 89.*
80. **The workspace has its own `GOVERNANCE.md`**, whose § Deciders lists who approves publishing and decides the workspace's documents. Rejected: the `DECIDERS` answer, which names a produced repository's deciders.
81. **Confirming answers is recorded** (`bin/ask confirm`), and render refuses answers unconfirmed or changed since, so a resumed session can tell checkpoint 1 happened. Not enforced: who confirmed.
82. **The root commit's author is the `COMMIT_IDENTITY` answer.** Rejected: the operator's git identity (absent in CI; differs by machine). *Amended by decision 114.* *Amended by decision 119.*
83. **Measure 1's local half is `tests/m1.sh`**, a script CI runs in a temporary worktree at `HEAD`, not a suite (decision 29): it judges the real foundation. One fixture per CI leg. Its verdict is about `HEAD`, so a builder runs it after committing.
84. **Measure 5 across platforms:** a workspace CI job compares both fixtures' fingerprints from both legs. Supersedes decision 62; the workspace's CI is no longer shipped, so the job is workspace logic in a workspace file.
85. **The target is a handoff outside `output/`**, a departure from ICM, where `output/` is the only handoff surface. Stage outputs name the target and its fingerprint, so the handoff stays checkable.
86. **`trace` treats every `CONTEXT.md` as an agent file.** The workspace's agent-file rules source to `docs/workflow.md`; produced repositories have no `CONTEXT.md` unless they add one. *Amended by decision 89.*
87. **`--redo` and `--replace` clear only unpublished state**, each after a checkpoint: `bin/ask run --redo` for new answers, `bin/render --replace` for a new render of the same answers. *Amended by decision 94.* *Amended by decision 116.* *Amended by decision 123.*
88. **Every script sets `LC_ALL=C`**: under `en_US.UTF-8`, bash 3.2's `[a-z]` matches `B`.

### Decisions from the second workspace review (chief of staff, delegated under ruling 12)

89. **The workspace never runs a product check on its own tree.** Its checks are its own and small, in its `bin/checks/`: `commits`, `scripts`, `trace` (its agent files, sourced to its human docs), `claims` (its prose), `disclosure` (always-on budgets, contract Inputs) and `foundation` (renders the fixtures). They reuse product code only by sourcing `foundation/bin/lib/*.sh` with explicit parameters. Its git hooks are its own and call its `bin/check`; its agent guard is a settings deny list. Paths are filtered inside the tree reader. Supersedes decision 79. *Amended by decision 102.*
90. **Git is pinned wherever a tree is built or committed** (render, fingerprint, verify): no global or system config, `core.fileMode=true`, `commit.gpgsign=false`, no excludes, and an index built from render's own file list, refusing extra or missing files. *Amended by decision 104.*
91. **Product skills and subagents are stored as `.tmpl`**, so neither loads in the workspace, where `bin/new` does not exist. A nested `foundation/CLAUDE.md` is harmless: its `@AGENTS.md` import resolves to nothing, since `AGENTS.md` is a template.
92. **The `commits` baseline.** The docs commits on `feat/initial-template` predate the `commits` check (one subject is 74 characters). S1 lands by merge commit, and the workspace's `commits` check judges only commits not reachable from S1's merge, recorded when the check lands. History is not rewritten.
93. **No `--ref`.** Publishing needs a workspace SHA reachable from the remote default branch, so the live measure 1 run (G4) happens after S10 merges, on `main`, and gates launch, not a slice. Ruling 13 covers creating, publishing to and deleting the two throwaway repositories; the approver recorded is the decider's name, with "per ruling 13" as its basis. Supersedes decision 72.
94. **`--redo` and `--replace` each sit behind their own checkpoint**, in the stage that runs them (01 and 02). Stage 03 routes to those stages and runs neither. *Amended by decision 123.*

### Decisions for the second revision (architect, delegated under rulings 12 and 14)

95. **Shared code is libraries with parameters.** The dispatcher (`foundation/bin/lib/dispatch.sh`, given a checks directory), the suite runner (`foundation/tests/lib/runner.sh`, given a directory), the tree reader (given excluded prefixes), the classifier, the word lists, the link resolver, the status parser, the script rules and the secret patterns are libraries; each product check and the product's `bin/check` and `tests/run-all.sh` are thin callers, and so are the workspace's. Rejected: a wrapper that runs product checks with a path filter (decision 89). Amends decision 57: each dispatcher discovers one directory.
96. **The workspace also runs `secrets` and `setup`**, two small checks of its own beyond decision 89's list: it is public, its hooks would otherwise scan nothing, and `setup` keeps the generated questionnaire and the setup answers in step with the schema. *Amended by decision 102.*
97. **`bin/publish --apply` takes an optional `--basis TEXT`**, recorded in `publish.md` beside the approver (default: "approved at the checkpoint"), so G4 can record "per ruling 13" without a second approver format.
98. **`bin/verify` reruns only on a verified target.** A target with `.git` whose history is not exactly one root commit with the fingerprint as tree is refused, and the remedy is `bin/render --replace`. *Amended by decision 105.* *Amended by decision 124.*
99. **Two more ICM departures, recorded:** `references/` exists only when it holds files (git keeps no empty folder); the generated questionnaire does not list the files each answer affects, because that is derived from the templates and AC12 tests it.
100. **The `foundation` check judges `HEAD` in every mode**, because render reads only committed `HEAD`; in a pre-commit hook it therefore judges the previous commit, and CI and pre-push judge the pushed one. *Amended by decision 115.*

### Decisions from the third workspace review (chief of staff, delegated under ruling 12)

101. **A run is published once `publish.md` records any outward step** (repository created, setting changed, push, issue). From then on `--redo` and `--replace` refuse. A resumed `--apply` refuses unless the repository matches the approved line exactly (owner and name, visibility, description, and either empty or `main` at the verified SHA); a repository this run's `publish.md` did not create is refused. This closes a resume that could push content meant for a private repository into a public one. *Amended by decision 120.*
102. **The workspace also runs `docs`, `workflows`, `pr` and `never-publish`**, as thin callers of parameterised product libraries: `docs.sh` takes the `GOVERNANCE.md` path, the document roots and the base. Their earlier "not enforced" items are removed.
103. **Setup overrides are run-scoped.** `bin/ask run --setup-override FIELD=VALUE` writes `stages/01-ask/output/<name>/setup.override.env`, never the tracked `setup/answers.env`; the fixtures and G4 use it, so the workspace stays clean.
104. **Git is hermetic** for render, the fingerprint and verify: `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM=1`, `core.excludesFile=/dev/null`, every variable `git rev-parse --local-env-vars` names unset, and a private temporary `GIT_INDEX_FILE`. *Amended by decision 112.*
105. **`bin/verify`'s rerun and `--check`, and `bin/publish --plan`, require the target's working tree to be clean and equal to `HEAD`.** *Amended by decision 124.*
106. **Measure 1's gate wording in the intent is amended**: the scripted fixed-answer run gates each slice PR that touches the workflow or the foundation; the GitHub half gates launch (G4). The amendment is the chief of staff's, pending the decider's acceptance with S1's ack, and S1's PR body lists it for him. *Amended by decision 113.*

### Decisions for the third revision (architect, delegated under rulings 12 and 14)

107. **A field joins the schema with its first use**, and the schema gains a `type` column (`name`, `text`, `list`, `select`, `owner`, `login-or-team`, `email-or-url`, `url`, `identity`, `path`) that the validator, the questionnaire and render share. The workspace's `foundation` check refuses a render field that no template uses, so each templated file's first test is that refusal for the field it introduces. A field used only by scripts so far is not yet a render field. *Amended by decision 117.*
108. **Two more ICM departures, recorded:** Layer 0 is `CLAUDE.md` as `@AGENTS.md`, with routing in `CONTEXT.md` and no What-to-Load table (each contract's Inputs is the load list); stage 02, otherwise linear, has a checkpoint before `--replace`.
109. **The email audit allows one answer's address**: `COC_CONTACT`'s, when it is an email. Every other free-text answer refuses an address. Amends decision 63. *Amended by decision 114.*


### Decisions from the fourth workspace review (chief of staff, delegated under ruling 12)

110. **Two publish regimes.** Before the first outward step, `--apply` requires its line to equal the current `--plan`. Once published, a resume is judged only against `publish.md`'s approved line and verified SHA and the remote's actual state (owner and name, visibility, description; `main` absent or at the SHA; settings; the first issue present or not), never the workspace's `HEAD` or the local target. Each remaining step runs only if its precondition holds on the remote; otherwise the run refuses and names the mismatch. Fixes a published run that could not resume. *Amended by decision 120.*
111. **Write-ahead records.** `publish.md` records an intent line before each outward step and a done line after it. A run with any intent line is published; a resume adopts a remote that matches the approved line, and refuses one that does not. *Amended by decision 120.*
112. **Hermetic git is built positively**: every variable `git rev-parse --local-env-vars` names unset, then `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM=1`, `GIT_ATTR_NOSYSTEM=1`, `GIT_NO_REPLACE_OBJECTS=1`, `core.attributesFile=/dev/null`, `core.excludesFile=/dev/null`, `git init --template=`, and the fingerprint built in a private temporary `GIT_DIR`, never the workspace's `.git`. Amends decision 104. *Amended by decision 128.*
113. **Measure 1 gates each slice PR from S3**, the first slice that can run it. The intent's wording is amended to say so; the amendment is the chief of staff's, pending the decider's acceptance with S1's ack. Amends decision 106.
114. **`COMMIT_IDENTITY`'s address is a GitHub noreply address** (`…@users.noreply.github.com`) or ends in `.invalid`. The refusal of email addresses in answers applies to `text` and `list` fields only. Amends decisions 82 and 109.

### Decisions for the fourth revision (architect, delegated under rulings 12 and 14)

115. **The `foundation` check renders the commit under judgment**, through render's library rather than `bin/render`: in range mode the head commit, so pre-push renders each pushed ref and CI the head SHA; in staged and tree modes `HEAD`. It never renders the index or the working tree. `bin/render` itself always renders `HEAD`. Rejected: a `--commit` option on `bin/render` (an operator could render an unmerged commit); judging `HEAD` in pre-push (a pushed ref need not be checked out). Amends decision 100. *Amended by decision 130.*
116. **One discard, for `--redo` and `--replace`:** it removes only the target `render.md` names, and only when that target's files match the recorded fingerprint (and, after verify, its history is the one root commit, clean); anything else is refused and left for the operator. Amends decision 87. *Amended by decisions 118 and 123.*
117. **A field is used when a template holds its placeholder or it selects a variant.** Fields join the schema at first use: `NAME`, `OWNER` and `TARGET_ROOT` in S2; `COMMIT_IDENTITY` with verify; `DESCRIPTION`, `VISIBILITY`, `LICENSE` and `COPYRIGHT_HOLDER` with the first product files; `WORKSPACE_URL` with the first issue. The setup questionnaire lists setup fields only; run fields are asked in stage 01. Amends decision 107.

### Decisions from the fifth workspace review (chief of staff, delegated under ruling 12)

118. **`bin/verify` checks before it commits.** It initialises the target under hermetic git, adds render's file list, runs `bin/check` in tree mode, `tests/run-all.sh` and the email audit, and makes the root commit only if all pass, with no hook running for that one commit (the checks already ran; `verify.md` says so). A failure is recorded in `verify.md` and leaves no commit. A target unlike its render (dirty, partial, or unlike the fingerprint) is removed only after a checkpoint in stage 03 where the operator approves "remove <the path `render.md` names>"; the shared discard then removes exactly that path, and only under `TARGET_ROOT`. Without the yes it is left alone. Fixes a remedy that always refused. Amends decisions 98 and 116.
119. **The root commit's identity is set and asserted.** `bin/verify` unsets every inherited `GIT_AUTHOR_*` and `GIT_COMMITTER_*` variable, sets the name and email of both from `COMMIT_IDENTITY`, and accepts the commit only when its `%an <%ae>` and `%cn <%ce>` each equal `COMMIT_IDENTITY`; `--plan` asserts it again. Fixes a personal address leaking into a published root commit. Amends decision 82.
120. **Published means a step done, or its effect seen on the remote**, not merely an intent line. A run with an intent line but neither is **attempted**: a resume retries it, or the operator abandons it with `bin/publish NAME --abandon`, behind a checkpoint, allowed only while the remote shows no effect. `bin/ask` validates GitHub's limits: `NAME` at most 100 characters of GitHub's allowed set, `DESCRIPTION` at most 350. Amends decisions 101, 110 and 111.
121. **The push comes from a private bare mirror** built from the target's objects: `git push <remote> <SHA>:refs/heads/main`, with hooks off for that push (the checks ran in verify and the SHA is asserted again), never from the target's working tree or with its hooks.

### Decisions for the fifth revision (architect, delegated under rulings 12 and 14)

122. **Verify commits through `git commit-tree`, then `git update-ref`.** It writes the tree, makes the commit object with the identity of decision 119, asserts its author, committer and tree, and only then points `refs/heads/main` at it, so no hook can run and no ref exists until the assertion passes. Rejected: `git commit -c core.hooksPath=/dev/null` (a ref exists before the assertion, and undoing it is another removal).
123. **The discard takes the operator's words.** `bin/ask run NAME --redo --remove PATH` and `bin/render NAME --replace --remove PATH` remove exactly PATH, only when it equals `render.md`'s target byte for byte and resolves, with no symbolic link on the way, under `TARGET_ROOT`; a present target without a matching `--remove` is refused. The checkpoint that yields `--remove` sits in the stage that finds the need: 03 for a failed verify, otherwise 01 or 02. Rejected: keeping decision 116's automatic discard of a matching target beside it (two removal paths, one unapproved). Amends decisions 87, 94, 116 and 118.
124. **A failed verify resumes.** `bin/verify` accepts a target with no `.git`, or with the unborn `.git` it made (no ref, no commit), which it re-adds from render's list; on one root commit with the fingerprint as tree and a clean working tree equal to `HEAD` it reruns the checks without committing; anything else is refused and routed to stage 03's removal checkpoint. Rejected: verify deleting its own `.git` on failure (a removal without a checkpoint). Amends decisions 98 and 105.
125. **The root commit's range-mode checks run in the produced repository's CI** on the first push (AC22), which `--watch` judges; verify judges the tree before the commit exists. Rejected: staged mode before the commit (it judges the same tree and adds a mode to reason about).
126. **The mirror lives at `stages/04-publish/output/<name>/mirror.git`**, made by the first `--apply` before any outward step with `git init --bare --template=` under hermetic git: it fetches the target's `main`, requires it to equal the verified SHA, and asserts the root commit's tree and identity. Every push, first or resumed, comes from it, so the target is never read once published. Rejected: a temporary mirror (gone before a resume, which would need the target again).
127. **`--abandon` returns an attempted run to unpublished**: it refuses a done line or any effect seen on the remote, then renames `publish.md` to `publish.abandoned-<UTC time>.md` and removes the mirror; `--redo` and `--replace` then work again. They refuse an attempted run, naming `--abandon`, so they need no remote query.
128. **Hermetic git also unsets `GIT_ATTR_SOURCE`** and the inherited author, committer and date variables, checks `git add`'s exit status, and refuses a file extra to render's list or missing from it. Each planted case in AC10's tests is first seen changing the result with its setting removed. Amends decision 112.
129. **A failed watch on a published run completes it with failure**: `publish.md` records the conclusions, and `bin/status` routes the fix to the produced repository's own pull request process; the run is never redone.
130. **The `foundation` check reads the schema, the fixture answers and `foundation/` all at the commit under judgment.** Amends decision 115.
