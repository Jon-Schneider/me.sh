---
name: patch-commit
description: Commit only your own changes by staging individual hunks via patch, never `git add .` or `git add -A`. Use whenever you are about to stage or commit in a repository that may contain changes from other agents, parallel sessions, or the user working concurrently — which is the default assumption.
---

# Patch Commit

You are almost never the only actor making changes in the active repository. Other
agents, parallel sessions, background tooling, and the user may all be editing files
at the same time. The working tree you see is shared. Treat every uncommitted change
as suspect until you have confirmed *you* are the one who made it.

## Core rule

Commit **only the changes you made**, and stage them by patch. Never blindly stage
the whole working tree.

- ❌ `git add .`
- ❌ `git add -A`
- ❌ `git add <dir>` (sweeps everything under it)
- ❌ `git commit -a` / `git commit -am`
- ✅ `git add -p` (interactively select hunks) — but you cannot drive the interactive
  prompt, so use the non-interactive equivalents below
- ✅ `git add <specific file you authored>` for files you know you created/edited in full
- ✅ `git apply --cached <patch>` to stage an exact, known diff

## Workflow

1. **Survey before touching the index.**

   ```bash
   git status --short
   git diff --stat
   ```

   Identify which files and hunks correspond to the work *you* did this session. If
   anything is unfamiliar, assume it belongs to someone else and leave it alone.

2. **Stage your changes precisely.**

   For files you fully authored or edited, stage them by exact path:

   ```bash
   git add path/to/file-you-changed.ext
   ```

   When a file contains a mix of your changes and someone else's, do **not** add the
   whole file. Build a patch of only your hunks and stage that:

   ```bash
   # Inspect hunks for a single file
   git diff -- path/to/shared-file.ext

   # Stage an exact, self-authored diff non-interactively
   git diff -- path/to/shared-file.ext > /tmp/my-change.patch
   # (edit the patch down to only your hunks if needed, then:)
   git apply --cached /tmp/my-change.patch
   ```

3. **Verify the staged set is exactly yours before committing.**

   ```bash
   git diff --cached
   ```

   Read the entire staged diff. If it contains a single line you did not write,
   unstage it (`git restore --staged <path>`) and narrow your selection. Do not
   proceed until the staged diff matches your work and nothing else.

4. **Commit only what is staged.** Never pass `-a` to `git commit`.

   ```bash
   git commit -m "your message"
   ```

## Guardrails

- Never run `git add .`, `git add -A`, `git add <dir>`, `git commit -a`, or
  `git stash` over the whole tree — these capture other actors' work.
- Never discard, revert, or `git checkout`/`git restore` files you did not change.
- If you cannot confidently attribute a change to yourself, leave it unstaged and
  mention it rather than committing it.
- Prefer many small, attributable commits over one sweeping commit.
