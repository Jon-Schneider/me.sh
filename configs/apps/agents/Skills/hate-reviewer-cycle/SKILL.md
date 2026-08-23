---
name: hate-reviewer-cycle
description: Coordinate an ordered, user-selected roster of AI reviewers in adversarial code-review loops, fixing valid findings between reviewers until each converges. Use when the user asks for a hate-review cycle, hate-review loop, or sequential hostile reviews. Reviewer identities, order, and optional models are required user inputs; ask for them if omitted. Supports native subagents and external agents reached through Codex, Claude Code, Pi, apps, or connectors.
---

# Modular Hate Reviewer Cycle

Run a sequential review gauntlet using the reviewers the user chose. The host agent owns the code changes and orchestration; reviewers inspect and report but do not edit.

The reviewer identities are inputs, not policy. Never silently add, replace, reorder, or hard-code reviewers or models.

## Required input: reviewer roster

Extract an ordered roster from the request. Each entry has:

- reviewer identity and model, when specified
- route: native subagent, Codex CLI, Claude Code CLI, Pi CLI, app/connector, or another available mechanism
- any reviewer-specific constraints from the user

Examples include `Sol subagent, then Claude Opus` and `Claude Opus subagent, then Codex Sol`. Prefer a native subagent when the user says “subagent.” Otherwise use the named agent's available app or CLI from the current host.

If the user invokes the cycle without naming reviewers, ask which reviewers to use and in what order. If a requested reviewer is unavailable, report that fact and ask for a replacement or route; do not substitute another model.

## Load only the needed templates

Read [templates/hate-review-request.md](templates/hate-review-request.md) for every cycle, plus only the adapter templates needed by the roster:

- Native subagent: [templates/native-subagent.md](templates/native-subagent.md)
- Codex CLI: [templates/codex-cli.md](templates/codex-cli.md)
- Claude Code CLI: [templates/claude-code-cli.md](templates/claude-code-cli.md)
- Pi CLI: [templates/pi-cli.md](templates/pi-cli.md)
- App, connector, or other external agent: [templates/external-agent.md](templates/external-agent.md)

These adapters are transport guidance, not a fixed stage list. A reviewer can use any adapter that actually reaches the user-selected agent from the current host.

## Determine the review target

Use a target named by the user. Otherwise inspect the repository and choose:

- uncommitted work only: working tree
- clean tree with branch commits ahead of its base: `<base>..HEAD`
- both: branch diff plus working tree

Discover the base from `refs/remotes/origin/HEAD`, then try `main`, then `master`. If no target can be inferred or there is nothing to review, ask the user what to review.

Keep one stable scope statement throughout the cycle. Include the repository root, target, original request, and relevant project instructions in each review request. Do not broaden the scope between reviewers.

## Run the roster sequentially

For each reviewer in the user's order:

1. Render the common hate-review request and invoke the reviewer through its adapter.
2. Evaluate every finding. Implement valid correctness, regression, edge-case, maintainability, and test fixes. Run proportionate tests.
3. Skip only findings that are incorrect, preference-only, out of scope, or contrary to repository conventions. Record a concise reason for each skip.
4. Ask the same reviewer to re-review the current state. Reuse its conversation or session when supported; otherwise create a fresh invocation with the same reviewer/model and a short summary of the prior findings and fixes.
5. Repeat until the reviewer signs off or the review reaches a clearly documented standoff. Only then move to the next reviewer.

Do not run reviewers in parallel: fixes from an earlier reviewer must be visible to later reviewers. Do not reveal earlier reviewers' findings to a new reviewer unless needed to explain the current scope; independent first passes are more useful.

Aim for convergence in two or three rounds per reviewer. Stop a loop when the reviewer signs off, only conscious non-blocking disagreements remain, or it is repeating without new actionable evidence. Never report a sign-off the reviewer did not give.

Unless the user asks for review-only output, implement valid feedback without per-round confirmation. This does not authorize commits, branch changes, unrelated refactors, or external reviewers the user did not name.

## Wrap up

Report, for each reviewer:

- reviewer identity, model, and route
- rounds completed and whether it signed off
- findings fixed
- findings skipped and why
- any remaining disagreement or blocker

Keep the result in roster order so the user can see how the changes survived the gauntlet.
