# 0001 oss-template: research notes

Checked 2026-11-22. Input to the intent, spec and plan for the GitHub template repository that Okja Engineering open-source projects will start from. Everything here was read from a live source on that date unless it is listed under *Unverified*. GitHub content was read with `gh api`. Docs pages were read with WebFetch, or with curl where the site serves Markdown (`code.claude.com/docs/en/*.md`). Short quotes are attributed. Everything else is paraphrased.

Repo state, for context: `Okja-Engineering/oss-template` is **public** and `is_template=false` (`gh api repos/Okja-Engineering/oss-template`). The org has no `.github` repository (404), so no org-level community-health defaults exist today. The org plan reports `team` (`gh api orgs/Okja-Engineering`).

## Findings that should change the plan

1. **Claude Code now reads `AGENTS.md` natively (v2.1.277 and later), but the Claude Code version tested is older.** On that version a repo with only `AGENTS.md` gives Claude Code no project instructions at all. A one-line `CLAUDE.md` that holds `@AGENTS.md` works on every version and is never read twice (code.claude.com/docs/en/memory.md, sections "AGENTS.md" and "Remove an earlier AGENTS.md workaround").
2. **Claude Code does not read `.agents/skills/`.** The memory doc lists "anything under a `.agents/` directory" as not read, and the skills doc lists only `.claude/skills/`, plugin and managed locations (memory.md L381; skills.md "Choose where skills load"). Okja/skills gets around this with a plugin manifest.
3. **Labels and rulesets do not come with a repo generated from a template.** GitHub's docs say nothing either way. Empirically: `actions/typescript-action` (`is_template=true`) has had an `npm` label since at least 2023-08. None of 13 repos generated from it (via the `template_repository` field, created 2023-01 to 2026-11) has `npm`, `actions` or `dependabot`. They have the account default labels, including `accessibility`, which the template lacks. The template's repo ruleset ("Copilot Code Review") also does not appear on generated repos. Labels need a sync workflow. Branch protection needs org rulesets, which the Team plan supports (docs.github.com/.../creating-rulesets-for-repositories-in-your-organization).
4. **The Kubernetes "~92% ignored" figure is real, but narrower than our docs state it.** See source 1 and *Where sources disagree*.
5. **Okja removed AI-use disclosure on 2026-10-03, while Rust and Kubernetes both require it.** This is a policy call for the user (source 1, source 5).
6. **Contributor Covenant 3.0 is current (announced 2025-07-28), not 2.1.** 3.0 has a `[NOTE` placeholder for the reporting method, so it cannot be adopted purely by reference. A contact has to be filled in.
7. **ai-native-sdlc refuses git's generated revert subjects at push and in CI, not at commit.**
   - These are `Revert "..."`, and `Reapply "..."`, which git writes when reverting a revert.
   - `git revert` does not run the `commit-msg` hook. Reproduced on git 2.50.1 with and without the editor: a `commit-msg` that always exits 1 did not fire, and both commits were created. So `.githooks/commit-msg` never sees either subject.
   - `.githooks/pre-push` refuses it (L93–96, the six-type regex over `git rev-list --no-merges`).
   - The CI `commit-messages` job refuses it (`ci.yml` L135–138, same regex). Both exempt only merges.
   - The only way past the push hook is `git push --no-verify`, which also skips that hook's secret scan. CI still refuses the commit, so in practice the subject has to be reworded.
   - If the template copies these checks as-is, it inherits the refusal of a legitimate input.
8. **A `paths:` frontmatter that doesn't parse makes the rule load globally (fail-open)** (memory.md, "Rule frontmatter reference"). Unquoted `**/*.ts` is invalid YAML (anthropics/claude-code#13905).

---

## Okja's own (conventions come from here; the template applies them and must not duplicate them)

### 1. Okja-Engineering/ai-native-sdlc (main, last push 2026-10-05)
Files read: `README.md`, `AGENTS.md`, `CONTROLS.md`, `STANDARDS.md`, `SOURCES.md`, `.github/ISSUE_TEMPLATE/capability.md`, `.github/pull_request_template.md`, `.github/workflows/ci.yml`, `.githooks/{commit-msg,pre-push,never-publish}`.

Confirmed:
- `AGENTS.md` is the single agent file, and there is deliberately no `CLAUDE.md`. The stated reason is that `CLAUDE.md` shadows `AGENTS.md` (`AGENTS.md` intro). Claude Code docs confirm the shadowing for v2.1.277+ (memory.md table). See finding 1 for the version gap.
- Conventional commits: `type(scope): subject`, types `feat|fix|docs|refactor|test|chore`, subject ≤ 72 characters, imperative, no trailing period (`AGENTS.md` § Commits). Enforced by `.githooks/commit-msg` (regex plus a gerund check) and the CI `commit-messages` job.
- No attribution trailers: no `Co-Authored-By`, no tool or model credit. The hook rejects `co-authored-by:`, "generated with", the robot emoji, `noreply@anthropic.com` and `claude.com/claude-code` (`.githooks/commit-msg`). Merge subjects are exempt from the format rules but not from the trailer ban.
- Short templates. The issue carries intent: background, problem, proposed solution, expected outcome, and a validation method "decided BEFORE the work starts" (`capability.md`). The PR carries evidence: what changed, how it was proved and what wasn't, and what is not in the change (`pull_request_template.md`). Both are Markdown templates, not issue forms.
- Kubernetes claim: `AGENTS.md` § "Why these are short" says 1,146 PRs in release 1.37, a section ~92% ignored (43.4% deleted, 39.5% empty, 9.2% placeholder).
  - **Verified against the primary source:** kubernetes/kubernetes commit `06bf5ee60666`, PR #142175, merged 2026-09-25, "remove 'Additional documentation' section from PR template". The counts are 497 / 453 / 105 of 1,146, plus 64 with a single KEP link, 15 with several KEP links, 5 with KEP plus other, and 7 with other.
  - Caveats the Okja text drops:
    - It is one contributor's analysis, opened with "My subject impression is", not a project audit.
    - The removed section's own comment said it "can be blank" when no release note was needed, so an empty block often meant the section correctly did not apply, not that it was ignored.
  - Okja's own PR #17 said at the time that the figure was "relayed, not verified by me". It can now be cited to #142175.
- "Every claim backed by a gate or labelled unenforced":
  - `CONTROLS.md` is "derived, not designed". `bin/validate-controls.sh` checks control↔gate wiring in four directions.
  - In-band declarations like `<!-- declared-not-enforced: ... -->` label what is not gated.
  - `AGENTS.md`: "A prose promise is not a control."

Take:
- Conventional-commit and trailer rules by reference to `ai-native-sdlc/AGENTS.md` § Commits. Ship the hook plus a CI job, because hooks are bypassable (`AGENTS.md` § CI).
- The issue/PR split and both template bodies nearly verbatim. They are already the shortest defensible shape.
- The `CONTROLS.md` pattern at template scale: one table mapping each convention to the gate that enforces it, or "unenforced".
- The pre-push never-publish list (`.githooks/never-publish`, currently `.scuba/*` and `.devin/eval/*`). Scratch folders are a real leak path for a public repo.
- `permissions: contents: read` at workflow top level (`ci.yml` L13). It already matches Scorecard Token-Permissions.
- The "tests must be able to fail" self-test idea (the `Prove the suite can fail` step in `ci.yml`).

Reject:
- `actions/checkout@v4` by tag (`ci.yml` L26, L102, L172). Scorecard Pinned-Dependencies flags it. The latest is v7 (see *Verified facts*).
- Copying the process machinery (`process/`, `bin/validate-*.sh`, the 15 in-band declaration forms). That is the SDLC repo's subject, not every project's.
- The "Real templates are small" line that says rust-lang/rust's template "renders fourteen lines". It is stale: since 2026-08 the whole 1,231-byte rust template sits inside HTML comments and renders nothing (rust `.github/pull_request_template.md`, commit `0bcefa1ec7`).

### 2. Okja-Engineering/skills (local clone at `ab3e445` = origin/main, 2026-08-04)
Files read: `AGENTS.md`, `README.md`, `.github/workflows/ci.yml`, `ci/check-always-on-budget.js`, `ci/check-frontmatter.js`, `.agents/skills/*/SKILL.md`, `.claude-plugin/plugin.json`.

Take:
- The always-on byte budget (`ci/check-always-on-budget.js`): `AGENTS.md` bytes plus each skill `description` must stay ≤ 3,065 B (2,665 × 1.15). It has a self-test that plants an oversized surface. Bytes, not tokens, because bytes are exact offline. The template should budget `AGENTS.md` + `CLAUDE.md` + any unscoped `.claude/rules/*.md` + skill descriptions.
- The frontmatter check (`ci/check-frontmatter.js`):
  - Parses with real YAML (js-yaml), not regex.
  - `name` matches the directory, ≤ 64 chars, `[a-z0-9-]`. `description` ≤ 1,024 chars.
  - Refuses unknown keys.
  - The same check should cover `.claude/agents/*.md` and `.claude/rules/*.md` `paths:`, because Claude Code silently ignores unknown fields and unparseable YAML (sub-agents.md, skills.md, memory.md).
- "Do not restate these rules in project files" (`AGENTS.md` last line). The template links to Okja/skills and ai-native-sdlc rather than copying them.
- CI asserts git index modes (`120000` symlink, `100755` scripts) because review does not show modes (`ci.yml`). Useful for template hook scripts.

Reject:
- `CLAUDE.md` as a symlink to `AGENTS.md`:
  - Claude Code docs advise the `@AGENTS.md` import instead whenever anyone clones on Windows. Git checks a symlink out there as a one-line text file unless `core.symlinks` is set.
  - Edit/Write refuse to write through a symlink (memory.md "Share one file with other coding tools").
- `.agents/skills/` as the only skill location for Claude Code users. Claude Code does not read it (finding 2). Fine as the cross-tool source if the template also ships a plugin manifest or `.claude/skills` links.
- The "no vendor-specific frontmatter" claim as stated:
  - The allowlist admits `disable-model-invocation`, which Claude Code documents as its own extension.
  - claude.ai upload and the Skills API reject it with a hard error (skills.md "Using skill frontmatter outside Claude Code").
  - Accept the field, but describe it accurately.
- `actions/checkout@v4` and `actions/setup-node@v4` by tag (same Scorecard issue as source 1).

---

## Repository hygiene

### 3. rust-lang/rust (main `ce66487ebb`, 2026-11-22)
Files read: `AGENTS.md`, `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/` (listing, `config.yml`, `tracking_issue.md`), `triagebot.toml`, `.git-blame-ignore-revs`, `.mailmap`, `REUSE.toml`.

Take:
- **Ordered gates in `AGENTS.md`:**
  - "Before any edit": 1 external repositories, 2 prohibited text, 3 a named reviewer.
  - "Before implementation": 1 testing (a failing test observed, its command allowed to exit, no `--bless`), 2 soundness classification.
  - "Before pushing": the user confirms understanding, testing, and personal review of the full diff ("Agent review does not count"), and the user authors the LLM disclosure.
  - Shape to copy: gates numbered and keyed to a moment, each with a STOP/PAUSE outcome.
- **Agent-file rule** (`AGENTS.md` § Prohibited text, L96–103): agent files "may only link to, summarize, or conservatively operationalize" human-facing docs. They must not create obligations for humans. If no human source exists, PAUSE and ask the user to write one first. An agent file must never be "the sole source of a rule".
  - **Making it mechanically checkable (proposal):**
    - (a) Every imperative line in `AGENTS.md`, `CLAUDE.md`, `.claude/rules/*.md`, `.claude/agents/*.md` and `SKILL.md` bodies must carry a link into a human-facing doc (`CONTRIBUTING.md`, `docs/`, an Okja repo). "Imperative" means it matches a closed list such as must, never, do not, always, required, STOP or PAUSE.
    - (b) CI resolves each link and its `#anchor` to an existing heading.
    - (c) A line that is deliberately agent-only carries an in-band `<!-- agent-only: reason -->` declaration and is counted.
    - Whether the linked text actually says what the line claims stays unenforced and is labelled so. This mirrors `CONTROLS.md` "What is not controlled", item 0.
- No `Co-Authored-By` (`AGENTS.md` § Before pushing). It agrees with Okja.
- `config.yml` routing (`blank_issues_enabled: true`, `contact_links` to the forum, internals and the Clippy repo). Route questions away from the tracker.
- Tracking-issue template (`tracking_issue.md`): label `C-tracking-issue`, a steps checklist, and the rule that it is "not meant for large scale discussion". Use it for epics.
- Label prefixes (meanings from forge.rust-lang.org/release/issue-triaging.html):
  - Prefixes: `T-` team, `C-` category, `A-` area, `S-` status, `P-` priority, `I-` issue kind, `E-` participation call.
  - In `triagebot.toml` `[relabel] allow-unauthenticated`, `P-*` is absent, so priority is maintainer-only.
  - `S-waiting-on-review` is auto-added on new PRs and `needs-triage` on new issues.
  - Take the prefix scheme, keep the set small (C-, A-, S-, P-), and keep P- maintainer-set.
- `.git-blame-ignore-revs` with a header comment giving the `git config blame.ignorerevsfile` line (and GitHub honours the file by default; *Unverified*).
- `.mailmap` (754 lines in rust). Ship an empty one with the header comment.

Reject:
- `triagebot` itself (a bot service). Use a label-sync action plus manual labels.
- `REUSE.toml` for v1:
  - rust uses it for blanket per-path licence annotation in a multi-licence tree.
  - A single-licence template does not need it.
  - It also lists a `CLAUDE.md` that does not exist in the tree (tree listing shows only `AGENTS.md`), which shows how these files drift.
- `homu-ignore` markers (bors-specific).
- The rust gates' content (soundness, external repos, prohibited text). Only the shape transfers.

### 4. rust-lang/rfcs (`README.md`, `0000-template.md`)
Take:
- An explicit "when you need an RFC" list and a "does not need one" list (README § When you need to follow this process). The template's ADR/design-doc folder needs the same two lists.
- FCP with a stated disposition (merge, close or postpone).
  - Sign-off from all subteam members before FCP. FCP runs 10 calendar days.
  - A *summary comment* before the FCP motion on long threads.
  - Map this to a disposition field plus a named decider (ai-native-sdlc `DECIDERS.md`), not to a team vote.
- Numbering. Copy `0000-template.md` to `text/0000-name.md`, then rename to the PR number **once the PR is open**, not on merge (README § What the process is). Accepted RFCs are not substantially changed. A substantial change is a new RFC plus a note on the original.
- Postponed: closed with a `postponed` label and re-openable. Use "close" when the answer is "never".
- Template sections: Summary, Motivation, Guide-level, Reference-level, Drawbacks, Rationale and alternatives, Prior art, Unresolved questions, Future possibilities.
  - Take Motivation, Drawbacks, Rationale and alternatives, and Unresolved questions.
  - Fold guide- and reference-level explanation into one section.

Reject:
- Separate RFC repo and sub-team triage meetings (scale mismatch).
- "Do not squash or rebase commits after they are visible on the PR" (README). It conflicts with a squash-merge, conventional-subject main. Apply it to design-doc PRs only if at all.

### 5. Rust LLM policy (forge.rust-lang.org/policies/llm-usage.html, WebFetch)
Take:
- Disclosure for every conditionally allowed use, an `llm-assisted` label, and lying about LLM use as a conduct violation.
- A pre-arranged named reviewer for LLM-created PRs.
- "held to a higher standard than human-created PRs" on tests. If no suite exists, write one or close the PR.
- LLM review is advisory only. It is never sufficient to merge or reject. This matches ai-native-sdlc `STANDARDS.md` §3.
- Agent files must not be the only place where something is documented (the page's ❌ list).

Reject:
- The ban on LLM-originated PR descriptions, issue bodies and docs as an Okja default. Okja's process has agents draft PR bodies. If an Okja project adopts it, say so per project.
- The personal-use exemption machinery (specific to rust's contributor scale).
- Note: the policy is dated by its announcement post (2026-08-05). It applies to the compiler, libs, types, rustdoc and bootstrap teams only.

### 6. Kubernetes KEPs (github.com/kubernetes/enhancements/tree/master/keps)
Files read: `keps/README.md`, `keps/NNNN-kep-template/{README.md,kep.yaml}`, `api/proposal.go`, `hack/` listing.

Take:
- Typed metadata validated in CI:
  - `hack/verify-kep-metadata.sh` validates against the Go struct in `api/proposal.go`.
  - Required: `title`, `kep-number`, `authors`, `owning-sig`, `approvers`, `status`.
  - Status enum: provisional | implementable | implemented | deferred | rejected | withdrawn | replaced.
  - Two-way links: `replaces` and `superseded-by`.
- `hack/verify-toc-vs-template.sh`: check that a doc's sections match its template. Cheap and mechanical.
- Number = tracking issue number (keps/README "What is the number..."). It needs no rename step, unlike the RFC PR-number rename.
- "Merge early and iterate." A merged KEP is not an approved KEP (template header comment).
- Graduation criteria (alpha/beta/GA), reduced to "what must be true to call this done".

Reject:
- The production-readiness questionnaire, SIG ownership and milestones (bureaucracy at this scale).
- Correction to the mandate: KEP metadata lives in a **separate `kep.yaml`**, not frontmatter. MADR (source 9) is the frontmatter precedent.

### 7. OpenSSF Scorecard checks (github.com/ossf/scorecard/blob/main/docs/checks.md, last changed `1b19105b0a` 2026-11-18)
What the template can satisfy in files alone:
- **Token-Permissions:** top-level read-only, write only at job level.
- **Pinned-Dependencies:**
  - Pin by full SHA.
  - New: a `uses:` tag counts as pinned if it is backed by a published *immutable release*. Of the actions below, only codeql-action's releases are `immutable=true`.
- **Dependency-Update-Tool:** a Dependabot or Renovate config file.
- **Security-Policy:** `SECURITY.md`. Scoring: email/URL 6, free text 3, vuln/disclosure terms plus a timeline number 1.
- **SAST:** a workflow using `github/codeql-action`.
- **Dangerous-Workflow:** no `pull_request_target`/`workflow_run` with a PR checkout.
- **Binary-Artifacts:** no binaries.
- **License:** a `LICENSE` file.

What needs settings or history:
- **Branch-Protection:** settings or rulesets, not copied (finding 3). Some fields need an admin token.
- **Code-Review, CI-Tests, SAST (PR-app branch), Contributors:** read from the last ~30 PRs/commits.
- **Maintained:** only scores after a repo is 90 days old, so every new repo starts low.
- **Signed-Releases, Packaging, SBOM:** a release process.
- **Webhooks:** settings.
- **CII-Best-Practices:** external registration.
- **Fuzzing:** language-specific.

Take:
- The file-satisfiable set as template defaults.
- `ossf/scorecard-action`'s `examples/scorecard.yml` (public) and `scorecard-private.yml`. Per the v2.6.0 release notes they pin every action by SHA. Copy from `main`, not from the tag.

Reject:
- Chasing a 10/10 on a fresh repo. Maintained and history-based checks cannot pass at birth. State that in the template README rather than read it as failure.

### 8. GitHub community health files (docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file, plus template-repo and issue-form pages)
Take:
- The org `.github` repo (must be **public**) can supply defaults for `CODE_OF_CONDUCT`, `CONTRIBUTING`, `SECURITY`, `SUPPORT`, `FUNDING.yml`, issue/PR templates + `config.yml`, discussion forms, `ACCESSIBILITY.md` and `VULNERABILITY_REPORT.yml`.
  - Lookup order is `.github/`, then root, then `docs/`.
  - A per-repo file overrides the default.
  - `ISSUE_TEMPLATE` overrides **per folder**, not per file.
  - A default **cannot be `LICENSE`**.
  - Defaults are not in clones or git history.
- Template mechanics (docs.github.com/.../creating-a-template-repository and .../creating-a-repository-from-a-template): only files are copied, from the default branch (optionally all branches), as a single commit with unrelated history, and no Git LFS. The docs are silent on labels and rulesets, so finding 3 is from observation.
- Issue forms (docs.github.com/.../syntax-for-issue-forms):
  - Required: `name`, `description`, `body`.
  - Optional: `title`, `labels`, `assignees`, `projects`, `type`.
  - Body elements: markdown, input, textarea, dropdown, checkboxes (the docs' example also uses `upload`).
  - Still "public preview".
  - Labels in a template are not applied if they do not exist in the repo.
- `config.yml` (docs.github.com/.../configuring-issue-templates-for-your-repository):
  - Keys: `blank_issues_enabled`, `contact_links` (name, url, about).
  - With blank issues disabled, Write+ users still see a "Maintainers only" blank option.
  - Templates take effect only on the default branch.

Decision input, not a choice:
- Put community files in an org `.github` repo, so one edit updates every repo but nothing appears in a clone.
- Or put them in the template, so they are visible and versioned per repo but drift after generation.
- The issue-template folder-override rule makes the two hard to mix.

### 9. ADRs (adr.github.io, adr.github.io/madr/)
Take:
- MADR 4.0.0 (2024-09-17, `gh api repos/adr/madr/releases/latest`):
  - YAML frontmatter: `status`, `date`, `decision-makers`, `consulted`, `informed`.
  - Status examples: proposed, rejected, accepted, deprecated, "superseded by ADR-0123".
  - Files `NNNN-title-with-dashes.md` in `docs/decisions/`.
  - MADR's own ADR-0008 chose YAML frontmatter for status.
- Immutability is from Nygard's 2011 post (linked from adr.github.io): keep a reversed decision and mark it superseded. "Numbers will not be reused."

Reject:
- Citing adr.github.io for immutability. The site does not state it (its pages carry no "immutable" or "superseded" text). The rule is Nygard's, and MADR only implies it through the status value.
- The full MADR template (Decision Drivers, Pros and Cons per option). Okja's ai-native-sdlc already has options and decision records with a named decider.

### 10. Conventional Commits, Keep a Changelog, Contributor Covenant
- Conventional Commits **1.0.0 is current** (conventionalcommits.org/en/v1.0.0, licence CC BY 3.0).
  - Only `feat` and `fix` are mandated. Other types are allowed.
  - Breaking changes use `!` or a `BREAKING CHANGE:` footer (uppercase; `BREAKING-CHANGE` is a synonym).
  - Types are case-insensitive for implementors.
  - Take by reference. Okja's six-type lowercase subset is a stricter local rule, and it rejects `revert`, `perf`, `ci` and `build`.
- Keep a Changelog **1.1.0** is the spec version shown (keepachangelog.com/en/1.1.0; the site's own changelog runs to 1.1.2).
  - Sections: Added, Changed, Deprecated, Removed, Fixed, Security.
  - An `Unreleased` section at the top and ISO dates.
  - It advises against using git logs as changelogs.
  - Take by reference.
- Contributor Covenant **3.0 is the latest** (contributor-covenant.org/version/3/0/code_of_conduct, CC BY-SA 4.0).
  - Announced 2025-07-28 (ethicalsource.dev/blog/contributor-covenant-3). GitHub tags stop at 2.1 (2021-08-04).
  - Sections: Our Pledge, Encouraged Behaviors, Restricted Behaviors, Reporting an Issue, Addressing and Repairing Harm, Scope, Attribution.
  - Adopters must fill the reporting `[NOTE` placeholder.
  - Recommend 3.0 with an Okja contact. It goes in the org `.github` repo if source 8 lands that way.

---

## AI-native SDLC

### 11. Claude Code best practices (code.claude.com/docs/en/best-practices.md)
Take:
- Split deterministic from non-deterministic. `CLAUDE.md`, prompts and skills are advisory, while hooks, deny rules and managed settings always apply. A rule that must hold every time goes into a hook or deny rule.
- Keep `CLAUDE.md` short. Include only what Claude cannot work out from the code: exact test, typecheck and lint commands, and gotchas.
- A `Stop` hook that exits 2 enforces "checks pass before finishing". Eight consecutive blocks with no tool call between them end the turn anyway.
- Keep the enforced set small: "If you ever find yourself at forty of them, most are probably preferences."

Reject:
- Nothing outright. The "delete hooks for preferences" advice is reconciled with Okja's gate rule under *Where sources disagree*.

### 12. Effective context engineering (anthropic.com/engineering/effective-context-engineering-for-ai-agents, 2025-09-29)
Take:
- Context is a finite budget with diminishing returns. This supports the byte budget in source 2.
- Instructions at the "right altitude". Start minimal and add what testing shows is missing.
- Just-in-time retrieval: `CLAUDE.md` up front, everything else fetched by search.
- A structured notes file outside the context window (our `.scuba/` scratch).

Reject:
- Nothing. It is guidance, not a spec.

### 13. Building effective agents (anthropic.com/engineering/building-effective-agents, 2024-12-19)
Take:
- Simplest thing first.
- Prompt chaining with programmatic gates between steps. This matches the rust ordered gates and spec-kit's Constitution Check.
- Poka-yoke tool design, for example absolute paths.

Reject:
- Orchestrator and framework patterns as template content. They belong to a project, not to a template.

### 14. How Anthropic teams use Claude Code (claude.com/blog/how-anthropic-teams-use-claude-code, 2025-07-24)
Take:
- Teams rely on `CLAUDE.md` files for orientation.
- Synchronous supervision with TDD for security-sensitive work, versus autonomous loops for prototypes. Choose supervision by risk.

Reject:
- The quantitative figures ("3x", "80% reduction", "saved them 20 minutes"). They are self-reported with no method, and Okja's no-speed-claims rule excludes them anyway.
- The fetched page does not contain the checkpoint or "slot machine" practice often attributed to it (*Unverified*).

### 15. Scaling agentic coding (resources.anthropic.com PDF, 13 pp., text extracted locally; file metadata ~2025-09)
Take:
- Commit `CLAUDE.md` to the root of `main` and review changes to it like docs.
- Include `CLAUDE.md` in onboarding.
- Use managed settings for org policy.

Reject:
- "Policy-as-code" in `CLAUDE.md` (Security chapter). Best practices (source 11) says `CLAUDE.md` is non-deterministic, so it is not a control.
- Branch-specific `CLAUDE.md`: drift for little gain.
- The ROI metrics: sprint throughput, time-to-completion, lines of code accepted, suggestion accept rate. They are activity and speed measures that ai-native-sdlc `STANDARDS.md` §6 and `AGENTS.md` reject.

### 16. Claude Code docs: memory, settings, permissions, hooks, hooks-guide, skills, subagents (code.claude.com/docs/en/*.md via llms.txt)
Take: everything under *Verified facts* below.

Reject:
- Relying on `.claude/rules/` `paths:` for anything that must load. There are open bugs:
  - #96361: not triggered when Write creates a new file.
  - #88565 and #90450: auto mode's Bash-first editing never triggers rule injection.
  - #90523: project-level symlinked rules are never loaded.
  - #16299: an `@import` inside a path-scoped rule loads at session start.
  - Use path-scoped rules for convenience only, never for a control.

### 17. github/spec-kit (v1.4.3, 2026-11-19, MIT)
Take (ideas only):
- A constitution with a "Constitution Check" gate in the plan template. It is evaluated before research and again after design, with a "Complexity Tracking" table that is filled only to justify a violation (`templates/plan-template.md`).
- `[NEEDS CLARIFICATION: ...]` inline markers in spec and plan (`templates/spec-template.md`, `plan-template.md`). They are greppable, so CI can refuse a spec that still has them.
- Mandatory "Success Criteria / Measurable Outcomes" (`spec-template.md`). This is the same idea as Okja's validation method.

Reject:
- The `specify` CLI and its slash commands (the mandate says so).
- Note the current flow is constitution → specify → plan → tasks → implement → **converge** (README § Spec-Driven Development). `clarify` (≤ 5 questions) and `analyze` are optional (`templates/commands/`). The mandate's sequence is the older one.
- Spec-kit's example success criteria include speed targets ("under 2 minutes"). They conflict with Okja's writing rule.

### 18. agents.md
Take:
- Plain Markdown with no required fields.
- Suggested sections: overview, build and test commands, code style, testing, security, PR guidelines.
- Stewarded by the Agentic AI Foundation under the Linux Foundation.

Reject:
- Its nesting rule, "The closest AGENTS.md to the edited file wins", as a description of Claude Code. Claude Code loads every `AGENTS.md` from the working directory upward, plus subdirectory ones on Read (memory.md "When Claude Code reads AGENTS.md").
- Note that agents.md does not list Claude Code among supporting tools, although Claude Code supports it.

---

## Verified facts

| Fact | Result | Source |
|---|---|---|
| `.claude/rules/` `paths:` syntax | Docs accept "a YAML list or a comma-separated string". The docs' examples use a quoted YAML list. Only `paths` is read and other fields are ignored. YAML that doesn't parse means frontmatter is ignored and the rule **loads unconditionally**. Patterns are relative to the dir containing `.claude/`, and `*.md` matches at any depth. | memory.md "Path-specific rules", "Rule frontmatter reference" |
| `paths:` parser history | **YAML list broken, then fixed:** #26868 (multi-entry list honoured only one path) closed completed 2026-04-09, with the reporter confirming the fix in 2.1.97. #33581 closed as its duplicate. **Conflicting earlier reports:** #17204 (quoted and list forms fail, unquoted CSV works) closed not_planned on 2026-05-16, with a commenter on 2026-06-03 saying still broken. #16038 (only list works) closed completed. #19377 (both forms work) closed not_planned. #13905 (unquoted globs are invalid YAML) closed completed. **Still open:** #16299 (scoped rules load globally; a 2026-10-15 comment on 2.1.300 says the body is deferred but `@imports` inside load at start). **Safe form:** a quoted YAML list (`paths:` then `  - "src/**/*.ts"`) on ≥ 2.1.97. Never unquoted globs. Each rule needs a manual `/memory` or `/context all` check after a CC upgrade, because CI cannot run the Claude Code loader. | anthropics/claude-code issues as cited |
| Hook exit codes | 0 = success, and stdout JSON is parsed. **2 = blocking** (stderr is the reason; on PreToolUse the call stays blocked even if the JSON says allow). **1 or any other = non-blocking error**, and the action proceeds. The docs warn to use exit 2, not 1, for policy. A missing script path is also non-blocking unless `"onFailure": "block"` is set (≥ v2.1.295). | hooks.md "Exit code output", "Other exit codes", "Block the action when a hook fails" |
| PreToolUse stdin | Common fields: `session_id`, `prompt_id`, `transcript_path`, `cwd`, `scratchpad_dir`, `permission_mode`, `hook_event_name`. Event fields: `tool_name`, `tool_input`, `tool_use_id`. Bash `tool_input`: `command`, `description`, `timeout`, `run_in_background`. Write: `file_path`, `content`. Edit: `file_path`, `old_string`, `new_string`, `replace_all`. | hooks.md "Common input fields", "PreToolUse input" |
| PreToolUse JSON alternative | `hookSpecificOutput.permissionDecision`: `allow`, `deny`, `ask` or `defer` (defer only with `-p`), plus `permissionDecisionReason`, `updatedInput` and `additionalContext`. Precedence across hooks is deny > defer > ask > allow. Deny and ask rules still apply over a hook's allow. Top-level `decision: approve/block` is deprecated for this event. | hooks.md "PreToolUse decision control"; permissions.md "Precedence among rules, hooks, and mods" |
| SessionStart output | Matchers are `startup`, `resume`, `clear`, `compact` and `fork`. Plain stdout is added to context. JSON `hookSpecificOutput.additionalContext`, `sessionTitle`, `watchPaths`, `reloadSkills` and `initialUserMessage` (`-p` only). Only `command` and `mcp_tool` types are allowed. A SessionStart hook that prints `AGENTS.md` now duplicates it and should be removed. | hooks.md "SessionStart"; memory.md "Remove an earlier AGENTS.md workaround" |
| `@` imports | `@AGENTS.md` alone in `CLAUDE.md` works, and it is the docs' own example. Relative paths resolve from the **importing file**. Recursion is at most **four hops**. Imports inside code spans and fences are skipped. Paths with spaces need backslash escapes, and quoted paths are not imported. External imports need a one-time approval. Imports do not reduce context cost. | memory.md "Import additional files" |
| Native `AGENTS.md` | Read natively from **v2.1.277**, by default only when there is no `CLAUDE.md`, `.claude/CLAUDE.md` or `CLAUDE.local.md` in the cwd or above. **A personal `CLAUDE.local.md` silently stops `AGENTS.md` loading.** Not read: `AGENTS.local.md`, `AGENTS.override.md`, `.agents/`. `InstructionsLoaded` hooks don't fire for a natively read `AGENTS.md`. **The Claude Code version tested is older.** | memory.md "AGENTS.md" |
| Permission rule syntax | `Tool` or `Tool(specifier)`. Evaluated deny → ask → allow, first match wins, and specificity does not reorder. A deny anywhere beats an allow anywhere. In `Bash(...)`, `*` matches any text including spaces; `Bash(ls *)` also matches bare `ls`, and `:*` is an equivalent trailing form. Compound commands split on `&&`, `\|\|`, `;`, `\|`, `&` and newline, and every part must be allowed. Bash rules are not a security boundary (`/usr/bin/curl` and `sh -c` bypass them), so use the sandbox or a hook. | permissions.md "Permission rule syntax", "Bash" |
| Project hooks and trust | Interactive: hooks from **every** settings file are held until the workspace trust dialog is accepted. **`claude -p` or SDK: treated as trusted, so a repo's `.claude/settings.json` hooks run.** `permissions.allow` waits for trust, while `deny` and `ask` apply immediately. Project subagent frontmatter hooks need explicit trust even under `-p`. | hooks.md "Workspace trust"; permissions.md "What runs before you trust a folder" |
| Skills | Location `.claude/skills/<name>/SKILL.md` (project), `~/.claude/skills/`, plugin, managed; **not** `.agents/skills/`. Fields: `name`, `description`, `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `disallowed-tools`, `model`, `effort`, `context`, `agent`, `background`, `hooks`, `paths`, `shell`, `metadata`, `license`, `compatibility`. The description plus `when_to_use` is truncated at 1,536 chars. Unknown fields are silently ignored. Portable subset: `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`. | skills.md "Choose where skills load", "Frontmatter reference" |
| Subagents | `.claude/agents/*.md`, scanned recursively. Required: `name` (≤ 256, no `:`) and `description`. Optional: `tools`, `disallowedTools`, `model`, `permissionMode`, `maxTurns`, `autoCompactWindow`, `skills`, `mcpServers`, `hooks`, `memory`, `background`, `omitClaudeMd`, `effort`, `isolation` (`worktree`), `color`, `initialPrompt`, `experimental.cacheTtl`. camelCase. Unparseable YAML **skips the file**. Unknown fields are ignored (named in `--debug` from v2.1.296). | sub-agents.md "Frontmatter reference" |
| Template copies labels? | **No** (observed, 13 generated repos; docs silent) | finding 3 |
| Template copies rulesets or branch protection? | **No** (observed on 3 generated repos; docs silent) | finding 3 |
| CI runs on a template-generated root commit? | **Yes** (observed; docs silent). The root commit has subject "Initial commit", 0 parents, and is pushed with an all-zero `before`. `push` workflows run on it 12–15 s after creation. Dependabot `dynamic` runs also fire on the same SHA, so "every run triggered by the first commit" includes them when the repo ships a Dependabot config. Upstream's own "Lint Codebase" workflow failed on the root commit in all 5 repos below. No Okja repo has been generated from a template. | Observed on 10 of 10 repos generated from `actions/typescript-action` between 2026-10 and 2026-11. These 5 were re-checked on 2026-11-22 with `gh api repos/<r>/actions/runs?head_sha=<root>`: `Shamnadpta/typescript-action`, `GranataJ/typescript-action`, `makeitstrict/typescript-action`, `jestin-16/typescript-action`, `nrikez/typescript-action` |
| Org rulesets | Available on Team and Enterprise. They can target repos by `fnmatch` name or custom property ("dynamic list"). Okja org plan = `team`. | docs.github.com/.../creating-rulesets-for-repositories-in-your-organization; `gh api orgs/Okja-Engineering` |

### Action pins (checked 2026-11-22: `gh api repos/<r>/releases`, then `git/ref/tags/<tag>`, dereferencing annotated tags)

| Action | Tag | Commit SHA | Released | Immutable release |
|---|---|---|---|---|
| actions/checkout | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` | 2026-07-20 | no |
| ossf/scorecard-action | v2.6.0 | `23f22cd43608bae7a1f1fa2603d7314dee9538a5` | 2026-11-19 | no |
| github/codeql-action (incl. `/upload-sarif`) | v4.39.4 | `1bd86f2fdb4b86187fa4059f16f31a3202acc9ea` | 2026-11-20 | yes |
| EndBug/label-sync | v2.3.3 | `52074158190acb45f3077f9099fea818aa43f97a` | 2024-02-13 | no |
| crazy-max/ghaction-github-labeler | v6.0.0 | `548a7c3603594ec17c819e1239f281a3b801ab4d` | 2026-03-01 | no |

Traps found while resolving these:
- `releases/latest` for codeql-action returns `codeql-bundle-v2.27.5`, a CLI bundle, not an action version. Use the newest `v4.*` tag.
- checkout v7.0.0 added a block on checking out a fork PR under `pull_request_target`/`workflow_run`.
- EndBug/label-sync has had no release since 2024-02, although the repo was pushed 2026-11-22. ghaction-github-labeler is the more recently released of the two.

---

## Where sources disagree

1. **`CLAUDE.md` alongside `AGENTS.md`.**
   - ai-native-sdlc: none, and rely on shadowing (`AGENTS.md` intro).
   - Okja/skills: a symlink (`README.md`, CI asserts it).
   - Claude Code docs: none is needed on ≥ 2.1.277; use `@AGENTS.md` for older versions, Windows, or when a `CLAUDE.local.md` exists (memory.md).
   - **The import is the only option that works in every case listed**, and it is deduplicated.
2. **`AGENTS.md` nesting.** agents.md: closest file wins. Claude Code: every one from the cwd upward is loaded.
3. **Pinning.** Both Okja repos use `@v4` tags. Scorecard wants a SHA or an immutable-release tag.
4. **How much to enforce.**
   - ai-native-sdlc: every convention has a gate or is labelled unenforced.
   - Claude Code best practices: delete hooks for preferences and keep the set small.
   - Reconcilable: label preferences "unenforced" in the conventions table rather than hooking them.
5. **Where policy lives.**
   - Scaling PDF: security policy in `CLAUDE.md`.
   - Best practices and ai-native-sdlc: `CLAUDE.md` is advisory, and a prose promise is not a control.
6. **Measurement.**
   - Scaling PDF and the Anthropic-teams blog: throughput, time-to-completion, lines accepted.
   - ai-native-sdlc `STANDARDS.md` §6 and `AGENTS.md`: no speed claims; measure outcomes.
   - spec-kit's example success criteria are time-based too.
7. **AI disclosure.**
   - Rust: required, with an `llm-assisted` label, and concealment is a conduct violation (forge policy).
   - Kubernetes: a YES/NO + how field since 2026-08-12 (kubernetes PR #141199).
   - Okja ai-native-sdlc: **removed** its "AI use" PR section on 2026-10-03 (commit `79ca5d069c`). The reasons: nothing consumed it, it had adoption evidence only, and it contradicted the trailer ban.
   - The commit `eb080e1` message still describes the rule as present.
8. **Who writes PR and issue prose.** Rust bans LLM-originated PR descriptions, issue bodies and docs (`AGENTS.md` § Prohibited text). Kubernetes and Okja do not.
9. **Proposal numbering.**
   - RFC: rename to the PR number once the PR is open (rfcs README). The mandate said "on merge".
   - KEP: the tracking issue number.
   - MADR and Nygard: a sequential number, never reused.
10. **Proposal metadata.** KEP: a sidecar `kep.yaml`. MADR: YAML frontmatter. rust RFC: a Markdown bullet header.
11. **History on proposal PRs.** RFC: never squash or rebase once visible. Okja: one logical change per commit, with conventional subjects. A squash-merge flow cannot satisfy both.
12. **Commit types.** Conventional Commits allows any type and is case-insensitive. Okja allows six lowercase types and blocks `revert` (finding 7).
13. **Code of conduct version.** The mandate assumed 2.1. 3.0 is current.
14. **spec-kit flow.** The mandate lists specify → clarify → plan. The current README puts converge last and makes clarify optional.
15. **The Kubernetes figure.**
    - ai-native-sdlc: "a template section that about 92% of contributors ignored".
    - Primary source: a single contributor's count of a section that was allowed to be blank.
    - Use it as "most PRs left it empty or absent", not as abandonment.
16. **Skill portability.** Okja/skills says `SKILL.md` carries no vendor-specific keys, but admits `disable-model-invocation`, which Claude Code documents as a Claude Code extension.
17. **`paths:` syntax.** Docs: list or CSV both work. The issue history has each form failing in some version, and the closed issues conflict with each other.

## Unverified

- **Scaling PDF publication date.** There is no date in the extracted text. "~2025-09" is from the file's InDesign metadata, as reported by WebFetch. The text was extracted with a local stdlib script and ligatures were lost ("identied"). Quotes from it were not used.
- **The "slot machine" or checkpoint practice** sometimes attributed to the Anthropic-teams post. It is not in the fetched page, so it may be in the original PDF version, which I did not fetch.
- **Whether org rulesets apply automatically to newly created repos.** The docs say "dynamic list" but do not state it.
- **Whether GitHub's `blank_issues_enabled` default is `true`.** The docs page does not state a default. rust sets it explicitly.
- **That GitHub's blame view honours `.git-blame-ignore-revs` automatically.** From memory; not fetched.
- **The label and ruleset non-copy result is observational,** from one template's generated repos (13 for labels, 3 for rulesets). No GitHub doc states it.
- **The `paths:` safe form** is from docs plus one reporter's confirmation (#26868). I did not reproduce it: the `/memory` check needs an interactive session, which this research did not run. The Claude Code version tested is ≥ 2.1.97 but older than native `AGENTS.md` support.
- **The Contributor Covenant 3.0 FAQ on linking versus copying.** The FAQ page was not fetched.
- **Rust LLM policy ratification details** come from the WebFetch summary of the policy page. The 2026-08-05 date is from the linked blog URL, not fetched separately.
- **The Keep a Changelog version** (1.1.0 shown as current, against the site changelog reaching 1.1.2) was not reconciled further.
