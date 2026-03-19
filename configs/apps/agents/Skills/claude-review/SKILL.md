---
name: claude-review
description: Request a code review from Claude Code, implement or evaluate the feedback, and iterate until the review converges. Use when the user asks for a "Claude review", wants feedback from Claude Code, asks for a second opinion from Claude, or wants an iterative review loop between Codex and Claude on the same set of changes.
---

# Claude Review

Use Claude Code as a persistent reviewer while you stay responsible for the edits. Keep Claude invocations out of the main context by delegating them to a subagent, and keep the same Claude session alive across rounds so the review can converge instead of restarting from scratch.

The helper script is at `scripts/claude_review.py`. It wraps `claude -p` for the initial call and `claude --resume` for follow-up rounds, and it always returns:

```text
SESSION_ID: <uuid>
REVIEW:
<review text>
```

## Step 1: Determine what to review

Figure out the review scope from the user request and repository state.

- Use `uncommitted` for staged, unstaged, and untracked work.
- Use `base` for branch review against a base branch.
- Use `commit` for a specific commit.
- Use `both` when the branch has commits ahead of the base branch and there are also uncommitted changes.
- Use `files` when the target is not in a git repository or when the user wants Claude to review specific files directly.

If the user does not specify the scope, inspect the repo:

1. Run `git status --short` and `git diff --stat` to see whether there are uncommitted changes.
2. Discover the default branch with `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'`.
3. If that fails, check for `main` and then `master`.
4. Run `git log --oneline <default-branch>..HEAD` to see whether the current branch is ahead.
5. Choose `uncommitted`, `base`, or `both` from that state.

If the directory is not a git repo, skip the git-based scope detection and use `files` with a short `--scope-context` such as `Review only SKILL.md and scripts/claude_review.py in this directory.`

If there is nothing meaningful to review, stop and tell the user.

## Step 2: Call Claude through a subagent

Do not run the Claude CLI directly in the main thread unless there is no subagent option. Spawn a worker subagent so the Claude command output and retries do not pollute the main context.

The subagent owns only the Claude invocation. It should not edit files. It should return either the helper script's stdout verbatim or an `ERROR:` line.

Run the subagent from the repository root.

### Initial review

Tell the subagent to run:

```bash
# Standard install location: ~/.codex/skills/claude-review
# If needed, confirm with: ls ~/.codex/skills/claude-review
SKILL_DIR=/absolute/path/to/this/installed/claude-review/skill
python3 "$SKILL_DIR/scripts/claude_review.py" initial \
  --repo-root <repo-root> \
  --scope <uncommitted|base|both|commit|files> \
  --scope-context '<scope restated in one sentence>' \
  [--base-branch <branch>] \
  [--commit <sha>] \
  [--user-request '<original request>']
```

Notes:

- Let the script generate the session id unless you have a reason to supply one.
- Always provide `--scope-context`, even for git-backed scopes. Reuse the same sentence on resume.
- For `base` and `both`, name the base branch in `--scope-context`. For `commit`, include the commit SHA in `--scope-context`.
- Prefer Claude to inspect the repo itself instead of pasting large diffs into the prompt.
- If the environment needs special Claude CLI flags, pass them via repeated `--claude-arg` values from the subagent command.

### Follow-up review

After you make changes, tell the subagent to run:

```bash
# Standard install location: ~/.codex/skills/claude-review
# If needed, confirm with: ls ~/.codex/skills/claude-review
SKILL_DIR=/absolute/path/to/this/installed/claude-review/skill
python3 "$SKILL_DIR/scripts/claude_review.py" resume \
  --repo-root <repo-root> \
  --session-id <session-id> \
  --scope-context '<same scope sentence used for the initial review>' \
  [--summary '<what changed since the last round>'] \
  [--user-request '<original request>']
```

The `--summary` should be short and factual. Keep `--scope-context` stable across rounds so Claude keeps reviewing the same target.

## Step 3: Implement or reject feedback deliberately

Read Claude's feedback and decide what is actually valid.

- Implement changes that fix real correctness, regression, edge-case, or test gaps.
- Skip suggestions that conflict with project conventions or the user's stated goal.
- If you skip a suggestion, keep a short reason so you can explain the disagreement later.

You are still responsible for judgment. Treat Claude as a reviewer, not the decision-maker.

## Step 4: Re-review in the same Claude session

Reuse the `SESSION_ID` from the first Claude response. The point of the persistent session is to let Claude remember prior findings and focus on what remains.

If `claude --resume` fails, start a fresh initial review and include a short summary of:

- what Claude previously flagged
- what you changed
- what you intentionally did not change

## Step 5: Stop when the review converges

Aim for 2 to 3 rounds.

Stop when one of these is true:

- Claude says the review is clean.
- The remaining disagreement is stylistic or preference-based and you have a clear reason to stop.
- The loop is repeating without producing new actionable issues.

When you finish, report:

- what Claude flagged
- what you changed
- what you intentionally skipped
- whether Claude signed off or where the disagreement remained

## Troubleshooting

- If there are no changes to review, ask the user what scope they want reviewed.
- If Claude tries to leave the requested scope, rerun with a tighter `--user-request` or `--extra-instruction`.
- If you want to validate the wrapper without invoking Claude, run the script with `--dry-run`.
