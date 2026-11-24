# Governance

Who decides what in this workspace. A produced repository will have its own `GOVERNANCE.md`, from the foundation; this one governs only the workspace.

## Roles

- **Deciders**, listed in [§ Deciders](#deciders), make the reserved decisions.
- **Contributors** propose changes through pull requests.
- **Agents** draft changes, run the stages and may evaluate work. They take no reserved decision and carry no tool credit; both are not enforced yet.

## Reserved decisions

Only a listed decider makes these:

- accepting a chain document (a work folder's intent, spec or plan, an RFC or an ADR), or changing its status line or `**Decider:**` field;
- approving a pull request into `main`;
- approving a publish plan, naming themselves as the approver;
- changing [§ Deciders](#deciders).

These are not enforced yet: the checks that hold the listed names land in later slices, and who actually made a decision is not enforced at all.

## Approval

A decider approves a pull request by commenting `Ack at <head SHA>` on its current head. A new push needs a new ack. Before merging, whoever merges quotes that comment on the pull request, which then lands by rebase, since `main` keeps a linear history. With one decider listed there is no required-review ruleset, since GitHub refuses self-approval; with two or more, a ruleset requires a decider's review. That the comment came from the decider is not enforced.

## Deciders

- Matthew Van Dusen
