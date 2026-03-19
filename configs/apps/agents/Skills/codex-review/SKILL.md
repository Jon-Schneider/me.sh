---
name: review-from-codex
description: Request a code review from OpenAI Codex CLI and iterate on the feedback until both agents agree the code is good. Use this skill when the user asks for a "codex review", wants a second opinion from Codex, wants to get feedback on their changes from another AI agent, or wants an iterative review loop. Trigger on phrases like "get a review from codex", "ask codex to review", "codex review", "second opinion", "review from codex", or "have codex look at this".
---

# Review from Codex

Use the `codex exec review` CLI to get a code review from Codex, then implement the feedback yourself, and re-request review — looping until both you and Codex agree the code is good.

Note: use `codex exec review` (not bare `codex review`) because `exec review` supports `-o` and `--json` flags needed for headless operation.

## Step 1: Determine what to review

Figure out what the user wants reviewed based on context:

- **Uncommitted changes** (staged, unstaged, untracked): use `--uncommitted`
- **Current branch vs a base branch**: use `--base <branch>`
- **A specific commit**: use `--commit <SHA>`

If the user doesn't specify, check what's available:

1. Run `git status` and `git diff --stat` to see if there are uncommitted changes
2. Discover the default branch: `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'` — fall back to checking for `main`, then `master`, then ask the user if neither exists
3. Run `git log --oneline <default-branch>..HEAD` to see if the current branch has commits ahead
4. If there are uncommitted changes only (no branch commits), review with `--uncommitted`
5. If the branch is ahead of the default branch with no uncommitted changes, review with `--base <default-branch>`
6. If both exist, run `--uncommitted` to capture untracked/unstaged work (which `--base` may miss), then also run `--base <default-branch>` for the full branch diff — Codex will deduplicate in the session context

## Step 2: Call Codex via a subagent

To keep the main context clean, delegate `codex` CLI calls to a **haiku subagent**. The subagent runs the command, parses out the session ID and review text, and returns only those two things — keeping all progress noise out of your context.

Always spawn the subagent from the repo root directory so Codex targets the correct repository.

### Initial review — subagent prompt

Spawn a haiku subagent with this prompt (fill in the flags and repo path):

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
1. The --json flag sends JSONL events to stdout. The session ID is a UUID in the first JSONL event's "id" or "session_id" field. If multiple UUIDs appear, use the one from the earliest event.
2. Read $OUTFILE for the review text (this is the final assistant message).

Return your response in this exact format:

SESSION_ID: <the-uuid>
REVIEW:
<the review content>

If you cannot find a session ID in the JSONL output, return SESSION_ID: unknown and include the review content anyway.
```

### Follow-up reviews — subagent prompt

For subsequent rounds, resume the existing session. If the session ID from the previous round was `unknown`, skip resume and run a fresh `codex exec review` instead, including context about prior feedback in the prompt argument.

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

Return your response in this exact format:

SESSION_ID: <session-id>
REVIEW:
<the review content>
```

### If session resume fails

If resume returns an error, fall back to a fresh `codex exec review` call. Include context about what changed since the last review in the prompt argument.

## Step 3: Implement the feedback

Read and understand the review feedback. Then implement the suggested changes yourself using your own tools — edit files, run tests, whatever is needed. Use your judgment: not every suggestion needs to be followed. If a suggestion doesn't make sense or conflicts with the project's conventions (check CLAUDE.md / AGENTS.md), skip it and note why.

Briefly tell the user what you changed and what you skipped (and why).

## Step 4: Re-request review

After implementing changes, use the subagent pattern from Step 2 (follow-up variant) to ask Codex to re-review via the same session.

## Step 5: Loop until consensus

Repeat steps 3-4 until one of these conditions is met:

- **Codex approves**: the review comes back clean with no actionable feedback
- **You and Codex agree**: you've addressed all valid points and any remaining suggestions are matters of preference or style that you've consciously decided to skip
- **Diminishing returns**: the feedback is going in circles or nitpicking — use your judgment to call it done

Aim for convergence in 2-3 rounds. If it takes more than that, summarize the remaining disagreements for the user and let them decide.

When the loop completes, give the user a brief summary: what Codex flagged, what you changed, and what (if anything) you disagreed on.

## Troubleshooting

- If there are no changes to review, let the user know and ask what they'd like reviewed instead
- For deliberate one-shot reviews where you don't need session continuity, you can add `--ephemeral` to avoid persisting session files — but this means follow-up rounds must start fresh
