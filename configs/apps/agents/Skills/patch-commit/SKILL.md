---
name: patch-commit
description: Commit only your own changes using reviewed patches and a locked transaction that serializes staging and commits in a shared worktree. Use whenever you are about to stage or commit in a repository that may contain changes from other agents, parallel sessions, or the user working concurrently — which is the default assumption.
---

# Patch Commit

When invoked by the user treat this as an instruction to commit your changes. Describing or discussing the skill is not an instruction to commit.

The worktree is shared. Commit only changes you can attribute to your own work. Never create or switch branches unless the user asks.

## Workflow

1. **Survey without touching the index.** Inspect `git status --short` and the relevant diffs. Leave unfamiliar changes alone. If anything is already staged, report it; do not unstage someone else's work.

2. **Prepare an exact patch outside the lock.** Work from the repository root. Capture the full base commit ID before generating the patch, and use a unique temporary file:

   ```bash
   patch_commit_base=$(git rev-parse HEAD)
   patch_commit_patch=$(mktemp "${TMPDIR:-/tmp}/patch-commit.XXXXXX")
   git diff --binary --full-index --no-ext-diff --no-textconv "$patch_commit_base" -- path/to/file.ext > "$patch_commit_patch"
   ```

   Narrow the patch to only your changes when a file contains others' edits. For a new file you fully authored, append `git diff --no-index --binary -- /dev/null path/to/new-file.ext` to the patch; exit status 1 means a diff was produced. Do not use `git add -N` to prepare new files, because it mutates the shared index. Never reuse a fixed temporary filename.

3. **Review the entire patch.** Every included change must be yours. The transaction commits these frozen bytes, even if someone subsequently edits the worktree. Include deletions, mode changes, and binary changes only when they belong to your work.

4. **Run the locked transaction.** Resolve `scripts/commit_patch.py` relative to the actual directory containing this skill; do not assume a particular agent's installation path:

   ```bash
   python3 /absolute/path/to/patch-commit/scripts/commit_patch.py \
     --patch "$patch_commit_patch" \
     --base "$patch_commit_base" \
     --message "your message"
   ```

   Use `--message-file` instead of `--message` for a message prepared in a file. `--repo` defaults to the current directory, including subdirectories. `--timeout` sets the lock wait in seconds (default: 300).

   Launch the transaction once. Lock waiting happens inside the Python process and uses no model tokens. If the execution tool yields a running process, use its completion notification or wait facility; do not repeatedly inspect Git, retry the command, or narrate each wait. Keep the process running until it completes or times out.

5. **Report the result and remove your temporary files.** If rejected, inspect the stated reason. Rebuild and review stale patches against the new HEAD before retrying. Do not bypass the wrapper or clear staged changes to force a retry.

## Transaction behavior

The script holds a per-worktree advisory lock across validation, staging, hooks, commit, and failure cleanup. It resolves Git's metadata directory, so invocations through different subdirectories or skill installations share the same lock. Never delete its lock file; the operating system releases the lock when its holders exit.

Earlier commits to unrelated files are allowed. If a patch's files changed since its captured base, the script requires fresh review. It refuses pre-existing staged changes, alternate indexes, and active merge/rebase/cherry-pick/revert operations. It requires an existing HEAD commit.

The script validates the patch in a temporary index, applies it to the shared index, and checks the entire staged tree against the expected result. Existing commit hooks still run; guards reject hooks that change the staged tree before the commit. On failure, the script reverses its own patch only if HEAD and the staged tree still match the transaction's snapshots. Otherwise it leaves the index alone and reports that cleanup requires inspection. Cancellation waits for the active Git command to finish before cleanup and lock release.

All agents staging or committing in this worktree must use the wrapper. The lock does not coordinate concurrent edits or Git commands that bypass it. Ordering is serial but not guaranteed FIFO. Hooks that launch background index writers are outside the transaction.

## Guardrails

- Never stage or commit directly outside the transaction, including `git add -p`, `git apply --cached`, or whole-file `git add`.
- Never run `git add .`, `git add -A`, `git add <dir>`, `git commit -a`, or `git stash` over the whole tree.
- Never discard, revert, or restore changes you did not make, including another actor's staged changes.
- If attribution is uncertain, leave the change out and mention it.
- Prefer small, attributable commits.
