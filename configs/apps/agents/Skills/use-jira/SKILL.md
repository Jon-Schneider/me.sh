---
name: use-jira
description: Use Atlassian CLI `acli` with Jira Cloud to inspect, search, create, edit, assign, comment on, transition, and link Jira work items, and to resolve or run Jira filters by name or ID. Use when the user wants Jira issue operations performed from the terminal instead of the browser, especially for reading issue details, searching with JQL, posting or updating comments, changing status or assignee, editing summaries or descriptions, creating new work items, or running saved filters.
---

# Use Jira

Use `acli` for Jira Cloud work. Translate user language like "issue" or "ticket" into `acli jira workitem ...`, because the CLI uses `workitem` as the resource name.

## Workflow

### 1. Verify the environment

- Check that `acli` is installed with `acli -v` or `acli --help`.
- Check authentication with `acli jira auth status` before Jira work.
- If authentication fails, use `acli jira auth login --web` or `acli jira auth login --site "<site>.atlassian.net" --email "<email>" --token`.

### 2. Confirm the exact target

- Resolve the precise issue key, JQL, filter, comment ID, or link direction before mutating anything.
- When the user names a saved filter, resolve it with `acli jira filter search --name "<partial name>" --json`.
- When multiple filters match, stop and ask the user to choose by ID.
- When the user gives a filter ID, validate it with `acli jira filter get --id "<id>" --json` if there is any ambiguity.

### 3. Read before writing

- Inspect current state before comment, transition, assign, edit, create follow-up issues, or link operations.
- Use `acli jira workitem view KEY-123 --json` or focused `--fields` reads for issue context.
- Use `acli jira workitem comment list --key KEY-123 --json` before updating a specific comment or when comment history matters.
- Use `acli jira workitem link list --key KEY-123 --json` and `acli jira workitem link type --json` when link direction or duplication is unclear.
- Preview JQL or filter targets before bulk writes unless the user already provided an explicit, reviewed scope.

### 4. Prefer the smallest safe command

- Prefer single-target commands unless the user explicitly wants bulk behavior.
- Prefer `--json` for reads and for writes when structured confirmation is useful.
- Prefer narrow `--fields` instead of `*all` unless the user truly needs the full payload.
- Use `--paginate` only when the user wants the full result set.
- Avoid `--ignore-errors` unless the user explicitly accepts partial success.
- Avoid `--editor` unless the user asked for an interactive flow.

### 5. Confirm writes explicitly

- Restate the intended write when the request is not already unambiguous.
- Add `--yes` only after the user has clearly asked to execute the change without another prompt.
- Treat status names, visibility settings, and link directions as Jira-project-specific details that may need verification first.

### 6. Report precisely

- Summarize the command intent, which work items or filters were targeted, and what changed.
- Call out unresolved ambiguity, invalid status names, auth problems, missing permissions, or partial failures.

## Task Map

### Inspect or search work items

- Use `acli jira workitem view KEY-123 --json` for one issue.
- Use `acli jira workitem search --jql "<query>" --json` for JQL.
- Use `acli jira workitem search --filter "<id>" --json` for saved filters.
- Use `--count` when the user wants totals instead of issue details.

### Create or edit work items

- Use `acli jira workitem create` for new issues.
- Use `acli jira workitem create-bulk` only for explicit batch creation requests.
- Use `acli jira workitem edit` for summary, description, labels, assignee, or type changes.
- Read the current issue first when editing an existing work item so the delta is clear.

### Assign, transition, comment, or link

- Use `acli jira workitem assign` for assignee changes.
- Use `acli jira workitem transition --status "<Status>"` for workflow moves.
- Use `acli jira workitem comment create` for new comments and `comment update` for specific comment edits.
- Use `acli jira workitem link create` only after confirming direction and link type.

## Output Rules

- Prefer Jira Cloud terms in explanations, but map user wording naturally.
- Keep browser-opening flags like `--web` opt-in only.
- When a named filter matches multiple results, present the best matches with IDs and owners.
- When a write touches multiple issues, report successes and failures separately.

## References

- Read [references/acli-jira-recipes.md](./references/acli-jira-recipes.md) for exact command patterns, filter-resolution flows, create/edit/assign examples, and batch JSON or CSV operations.
- Read [references/jira-adf-cheatsheet.md](./references/jira-adf-cheatsheet.md) when generating Jira comments or descriptions that need paragraphs, lists, or code blocks in Atlassian Document Format.
