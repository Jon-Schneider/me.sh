---
name: hate-reviewer-cycle
description: Run an adversarial two-stage review loop — first a "hate review" subagent (opus by default, fable on request) that tears the changes apart until it signs off, then an OpenAI Codex pass until it signs off too. Use when the user asks to "hate review until it passes", "run the hate reviewer cycle", "hate then codex", or otherwise wants a hostile review gauntlet before merging. Trigger on phrases like "hate reviewer cycle", "hate review loop", "beat this up then codex it".
---

# Hate Reviewer Cycle

A two-stage adversarial gauntlet for a change. Stage 1 runs a hostile "hate review" subagent that assumes the code is bad and hunts for reasons to reject it, looping until it signs off. Stage 2 hands the survived changes to OpenAI Codex, looping until Codex signs off. You implement the fixes between rounds.

The point is friction: each stage should genuinely try to reject the change. Do not soften the reviewers' output or wave away findings to close the loop faster.

## Defaults (set for this user)

- **Reviewer model**: default the hate-review subagent to **opus**. Use **fable** only if the user explicitly asks (e.g. "hate review with fable", "cheap pass"). If the user says "fable or opus" without choosing, use opus.
- **Fix authority**: when a reviewer flags issues, **implement the valid feedback yourself** without stopping to ask. Skip a finding only when it's a matter of preference or conflicts with project conventions (check CLAUDE.md / AGENTS.md) — and note each skip and why. No per-round confirmation.

## Step 1: Determine what to review

If the user named a target (a commit, a base branch), use it. Otherwise inspect the repo and pick:

- Uncommitted work only (`git status` / `git diff --stat` non-empty, tree not clean) → review the **working tree**.
- Tree clean but branch ahead (`git log --oneline <base>..HEAD` non-empty) → review **`<base>..HEAD`**.
- Both → review the full picture (working tree + branch diff).

Discover `<base>` with `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'` — fall back to `main`, then `master`, then ask. If there's nothing to review, tell the user and ask what they'd like reviewed.

## Step 2 — STAGE 1: Hate review loop

Spawn a subagent (opus by default; fable on request) to do a hostile review. Keep its raw output in the subagent — you receive its findings, not its reasoning noise.

### Hate reviewer subagent prompt

Spawn via the Agent tool with `model: opus` (or `model: fable`) and this prompt (fill in the target):

```
You are a senior engineer doing a code review, and you HATE this implementation.
You are looking for every reason to REJECT it. Be specific and technical, not vague.

Review target: <describe: uncommitted changes / <base>..HEAD / commit <SHA>>.
Run the appropriate git command yourself to see the diff (e.g. `git diff`,
`git diff <base>..HEAD`, or `git show <SHA>`), plus read surrounding code as needed.

Tear it apart. Cover at minimum:
- Correctness bugs and unhandled edge cases
- Missing or weak tests
- Bad naming, unclear structure, wrong abstractions
- Convention violations vs this repo's CLAUDE.md / AGENTS.md
- Anything you'd block the PR on

Return your findings as a prioritized list (blockers first, then nits).
If — and only if — you genuinely cannot find anything worth blocking on,
respond with the single line: SIGN-OFF: no blocking issues.
Do not sign off just to be agreeable. Default to finding problems.
```

### Loop

1. Fix the findings per **Fix authority** above (edit files, add tests, run the build/tests), then briefly tell the user what you changed and skipped.
2. Re-spawn the hate reviewer (same model) on the updated changes. Fresh subagents are fine — carry forward a one-line note of what you addressed so it can check your work.
3. Repeat until the reviewer returns `SIGN-OFF: no blocking issues`, or the remaining findings are all conscious preference-based skips.

Aim for convergence in 2-3 rounds. If it's circling or nitpicking, call it and summarize the standoff for the user.

**Only proceed to Stage 2 once Stage 1 has signed off.**

## Step 3 — STAGE 2: Codex review loop

Now run the Codex loop over the (already hate-reviewed) changes. This mirrors the `codex-review` skill — reuse it directly if available; otherwise follow the outline below.

Use `codex exec review` (not bare `codex review`) — `exec review` supports `-o` and `--json` for headless operation. Delegate the CLI calls to a **haiku subagent** so Codex's progress noise stays out of your context; the subagent returns only the session ID and the review text.

### Initial Codex review — haiku subagent prompt

```
Run these commands and wait for them to complete (use a 300 second timeout):

cd <repo-root>
ERRFILE=$(mktemp "${TMPDIR:-/tmp}/codex-review-err-XXXXXX.txt")
OUTFILE=$(mktemp "${TMPDIR:-/tmp}/codex-review-XXXXXX.txt")
codex exec review [FLAGS] --json -o "$OUTFILE" 2>"$ERRFILE"
EXIT_CODE=$?

If the exit code is non-zero, read $ERRFILE and return:
ERROR: <the stderr content>

Otherwise:
1. The --json flag sends JSONL events to stdout. The session ID is a UUID in the
   first JSONL event's "id" or "session_id" field. If multiple UUIDs appear, use
   the one from the earliest event.
2. Read $OUTFILE for the review text (the final assistant message).

Return in this exact format:

SESSION_ID: <the-uuid>
REVIEW:
<the review content>

If you cannot find a session ID, return SESSION_ID: unknown and include the review anyway.
```

`[FLAGS]` matches the Step 1 target: `--uncommitted` for working-tree changes, `--base <default-branch>` for a branch diff, `--commit <SHA>` for a commit. Spawn from the repo root.

### Follow-up Codex reviews — haiku subagent prompt

Resume the session (if the ID was `unknown`, run a fresh `codex exec review` instead, including a note of what changed):

```
Run these commands and wait for them to complete (use a 300 second timeout):

cd <repo-root>
ERRFILE=$(mktemp "${TMPDIR:-/tmp}/codex-review-err-XXXXXX.txt")
OUTFILE=$(mktemp "${TMPDIR:-/tmp}/codex-review-XXXXXX.txt")
codex exec resume <session-id> "I've addressed your review feedback. Please re-review the current state of the changes." --json -o "$OUTFILE" 2>"$ERRFILE"
EXIT_CODE=$?

If the exit code is non-zero, read $ERRFILE and return:
ERROR: <the stderr content>

Otherwise, read $OUTFILE for the review text.

Return in this exact format:

SESSION_ID: <session-id>
REVIEW:
<the review content>
```

### Loop

Same rhythm as Stage 1: fix per Fix authority, re-request review, repeat until Codex comes back clean or the only open items are conscious preference-based skips. Aim for 2-3 rounds.

## Step 4: Wrap up

Give the user a brief summary of the whole cycle:

- Stage 1 (hate review, <model>): what it flagged, what you fixed, what you skipped, rounds taken.
- Stage 2 (Codex): what it flagged, what you fixed, what you skipped, rounds taken.
- Any remaining disagreements for the user to decide on.

## Troubleshooting

- No changes to review → tell the user, ask what to review.
- Reviewer refuses to sign off over pure nits → after 2-3 rounds, summarize the standoff and let the user call it.
- Codex session resume fails → fall back to a fresh `codex exec review`, including context on what changed.
- For a deliberate one-shot Codex pass with no follow-up, add `--ephemeral` to avoid persisting session files.
