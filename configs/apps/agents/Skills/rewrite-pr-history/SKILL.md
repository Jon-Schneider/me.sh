---
name: rewrite-pr-history
description: Rewrite a feature branch into a clean, reviewable commit stack without changing the final file contents. Use when asked to prepare a PR by resetting existing commits and recomposing the same net changes into small, sequential commits that are easy to review one commit at a time.
---

# Rewrite PR History

Preserve the exact net file changes while replacing the branch's commit history with smaller, reviewable commits.

## Guardrails

- Do not modify file contents during this workflow.
- Do not run formatters, linters, code generators, or refactors during this workflow.
- Use only Git history and staging operations.
- Abort if there are pre-existing unstaged/staged changes that are unrelated to the rewrite request.

## Rewrite Workflow

1. Capture branch context and safety snapshot.

```bash
current_branch=$(git branch --show-current)
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)

if [ -n "$upstream" ]; then
  base_commit=$(git merge-base HEAD "$upstream")
else
  base_commit=$(git merge-base HEAD origin/main)
fi

original_head=$(git rev-parse HEAD)
original_tree=$(git rev-parse HEAD^{tree})
backup_tag="backup/rewrite-$(date +%Y%m%d-%H%M%S)"

git tag "$backup_tag" "$original_head"
```

2. Reset commit history while preserving the working tree contents.

```bash
git reset --soft "$base_commit"
git reset
```

3. Rebuild history as small, sequential commits.

- Plan a commit sequence by concern (for example: API contract, service logic, UI wiring, tests).
- Stage only the patch for the next review unit.
- Commit that patch with a focused message.
- Repeat until no changes remain.

```bash
# Repeat this cycle until done:
# Stage files for the next review unit (method left to the agent)
git diff --cached --stat
git commit -m "<area>: <small, reviewable step>"
```

4. Verify that the final file tree is unchanged from the pre-rewrite state.

```bash
git diff --cached --quiet
git diff --quiet
final_tree=$(git rev-parse HEAD^{tree})
[ "$final_tree" = "$original_tree" ]
```

5. Compare old vs new commit stacks for sanity.

```bash
git range-diff "$base_commit...$backup_tag" "$base_commit...HEAD"
```

## Recovery

If the rewrite goes wrong, restore the pre-rewrite branch state exactly:

```bash
git reset --hard "$backup_tag"
```

After a successful rewrite and validation, delete the backup tag:

```bash
git tag -d "$backup_tag"
```

## Reporting Back

When finished, report:

- The detected base commit and branch.
- Number of new commits created.
- Confirmation that `final_tree == original_tree`.
- Any caveats (for example, intentionally non-compiling intermediate commits).
