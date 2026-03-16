# ACLI Jira Recipes

Verified against local `acli version 1.3.14-stable` help output on 2026-03-16.

## Command Map

Use this table to translate user intent into the correct command quickly.

| User intent | Command |
| --- | --- |
| Get one Jira issue | `acli jira workitem view KEY-123 --json` |
| Get a subset of fields | `acli jira workitem view KEY-123 --fields key,status,summary,assignee --json` |
| Search by JQL | `acli jira workitem search --jql "project = TEAM ORDER BY updated DESC" --json` |
| Count search results | `acli jira workitem search --jql "project = TEAM" --count` |
| Run saved filter by ID | `acli jira workitem search --filter "12345" --json` |
| Resolve filter by name | `acli jira filter search --name "triage" --json` |
| Get filter metadata by ID | `acli jira filter get --id "12345" --json` |
| List my filters | `acli jira filter list --my --json` |
| List favorite filters | `acli jira filter list --favourite --json` |
| Create one issue | `acli jira workitem create --summary "New task" --project TEAM --type Task --json` |
| Bulk create issues | `acli jira workitem create-bulk --from-json issues.json --yes` |
| Edit issue fields | `acli jira workitem edit --key KEY-123 --summary "New summary" --json` |
| Assign issue | `acli jira workitem assign --key KEY-123 --assignee "@me" --json` |
| Remove assignee | `acli jira workitem assign --key KEY-123 --remove-assignee --json` |
| List comments | `acli jira workitem comment list --key KEY-123 --json` |
| Add a comment | `acli jira workitem comment create --key KEY-123 --body "..." --json` |
| Update a specific comment | `acli jira workitem comment update --key KEY-123 --id 10001 --body "..."` |
| List comment visibility groups | `acli jira workitem comment visibility --group` |
| List project roles for comment visibility | `acli jira workitem comment visibility --role --project TEAM` |
| Transition one issue | `acli jira workitem transition --key KEY-123 --status "Done" --json` |
| List link types | `acli jira workitem link type --json` |
| List issue links | `acli jira workitem link list --key KEY-123 --json` |
| Create one link | `acli jira workitem link create --out KEY-123 --in KEY-456 --type "Blocks" --yes` |
| Bulk create links | `acli jira workitem link create --from-json links.json --yes` |

## Authentication

Check auth before Jira work:

```bash
acli jira auth status
```

Browser login:

```bash
acli jira auth login --web
```

Token login:

```bash
echo "$ATLASSIAN_API_TOKEN" | acli jira auth login \
  --site "example.atlassian.net" \
  --email "user@example.com" \
  --token
```

If the user has multiple accounts configured, inspect or switch with `acli jira auth switch`.

## Filter Resolution

Resolve named filters in two steps:

1. Run `acli jira filter search --name "<name>" --json`.
2. Inspect matches for exact name, owner, and scope.
3. If one match clearly fits, run `acli jira workitem search --filter "<resolved-id>" --json`.
4. If multiple matches plausibly fit, ask the user to choose by ID.

Prefer `filter get` when the user supplies an ID and you want to confirm ownership, columns, or other metadata before running the filter.

## Read Patterns

Use narrow field sets for concise output:

- Basic status check:
  `acli jira workitem view KEY-123 --fields key,status,summary,assignee --json`
- Include description and comments:
  `acli jira workitem view KEY-123 --fields key,summary,status,description,comment --json`
- Exclude a field from navigable defaults:
  `acli jira workitem view KEY-123 --fields '*navigable,-comment' --json`

Use bounded searches by default:

```bash
acli jira workitem search --jql "project = TEAM ORDER BY updated DESC" --limit 10 --json
```

Paginate only when the user wants the full set:

```bash
acli jira workitem search --jql "project = TEAM ORDER BY updated DESC" --paginate --json
```

## JQL Starting Points

Adapt these patterns instead of inventing JQL from scratch every time.

- Recently updated project work:
  `project = TEAM ORDER BY updated DESC`
- Open work for the current user:
  `assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC`
- Unassigned work:
  `project = TEAM AND assignee IS EMPTY ORDER BY priority DESC, updated DESC`
- Text search:
  `project = TEAM AND text ~ "search phrase" ORDER BY updated DESC`
- Issues in a status:
  `project = TEAM AND status = "In Progress" ORDER BY updated DESC`
- Work updated in the last week:
  `updated >= -7d ORDER BY updated DESC`

Prefer `NOT status = "Done"` or `statusCategory != Done` to brittle workflow-specific negative checks.

## Create Patterns

Create a single issue:

```bash
acli jira workitem create \
  --summary "Investigate intermittent login failures" \
  --project TEAM \
  --type Bug \
  --description "Reported by support after the 2026-03-15 deploy." \
  --assignee "@me" \
  --label incident \
  --json
```

Generate a JSON template before bulk creation:

```bash
acli jira workitem create-bulk --generate-json
```

Then create in bulk:

```bash
acli jira workitem create-bulk --from-json issues.json --yes
```

Use `--from-json` or `--description-file` when summaries or descriptions are generated content, especially if they need ADF.

## Edit and Assign Patterns

Edit a focused set of fields on one issue:

```bash
acli jira workitem edit \
  --key KEY-123 \
  --summary "Clarify rollout checklist ownership" \
  --description-file description.json \
  --labels rollout,docs \
  --json
```

Edit by JQL or filter only after previewing the target set:

```bash
acli jira workitem edit \
  --jql 'project = TEAM AND labels = stale' \
  --remove-labels stale \
  --yes \
  --json
```

Assign or clear assignees:

```bash
acli jira workitem assign --key KEY-123 --assignee "@me" --json
acli jira workitem assign --filter 10001 --assignee "default" --yes --json
acli jira workitem assign --key KEY-123 --remove-assignee --json
```

## Comment Patterns

Use inline bodies for short comments:

```bash
acli jira workitem comment create \
  --key KEY-123 \
  --body "Investigated the failure. Root cause is the expired staging token." \
  --json
```

Use a file for long or structured comments:

```bash
acli jira workitem comment create \
  --key KEY-123 \
  --body-file comment.json \
  --json
```

Update a specific existing comment:

```bash
acli jira workitem comment update \
  --key KEY-123 \
  --id 10001 \
  --body-file comment.txt
```

Set restricted visibility when the user asks for it:

```bash
acli jira workitem comment update \
  --key KEY-123 \
  --id 10001 \
  --body "Internal note" \
  --visibility-role "Administrators" \
  --notify
```

Avoid `--editor` unless the user explicitly wants an interactive editor session.

## Transition Patterns

Transition a single issue:

```bash
acli jira workitem transition --key KEY-123 --status "In Progress" --json
```

Transition a reviewed batch:

```bash
acli jira workitem transition \
  --jql 'project = TEAM AND labels = release-blocker' \
  --status "To Do" \
  --yes \
  --json
```

Status names are workflow-specific. Read the current issue first and report the attempted target status if the transition fails.

## Link Patterns

Inspect link types before linking when direction matters:

```bash
acli jira workitem link type --json
```

Create a single link:

```bash
acli jira workitem link create \
  --out KEY-123 \
  --in KEY-456 \
  --type "Blocks" \
  --yes
```

Generate a JSON template for bulk linking:

```bash
acli jira workitem link create --generate-json
```

Sample JSON shape for bulk linking:

```json
[
  {
    "inwardIssue": "PROJ-456",
    "outwardIssue": "PROJ-123",
    "type": "Blocks"
  },
  {
    "inwardIssue": "PROJ-789",
    "outwardIssue": "PROJ-123",
    "type": "Relates"
  }
]
```

Read existing links first when duplicate or inverse links are possible.

## Common Flags

| Flag | Meaning |
| --- | --- |
| `--json` | Prefer for structured parsing and concise summaries |
| `--fields` | Limit returned fields on views and searches |
| `--limit` | Cap search results intentionally |
| `--paginate` | Fetch the complete result set |
| `--count` | Return only totals |
| `--yes` | Skip confirmation prompts after explicit user approval |
| `--ignore-errors` | Continue after per-item failures in batch operations |
| `--web` | Open Jira in a browser instead of returning CLI output |
