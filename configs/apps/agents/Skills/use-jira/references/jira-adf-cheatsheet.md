# Jira ADF Cheatsheet

Use this file when comments or descriptions need reliable Jira Cloud formatting. `acli` accepts plain text, but paragraphs, lists, and code blocks are more predictable when you pass Atlassian Document Format (ADF) JSON.

## Rules of Thumb

- Use plain text for one short paragraph.
- Use ADF for multiple paragraphs, bullet lists, code blocks, or generated content that must preserve formatting.
- Prefer `--body-file` or `--description-file` for ADF so shell quoting does not corrupt JSON.
- Treat headings and rich text marks as unstable unless you have verified the target Jira instance accepts them.

## Minimal Paragraph

```json
{
  "version": 1,
  "type": "doc",
  "content": [
    {
      "type": "paragraph",
      "content": [
        {
          "type": "text",
          "text": "Investigated the alert and confirmed the impact is limited to staging."
        }
      ]
    }
  ]
}
```

## Two Paragraphs

```json
{
  "version": 1,
  "type": "doc",
  "content": [
    {
      "type": "paragraph",
      "content": [
        {
          "type": "text",
          "text": "Root cause is an expired OAuth client secret."
        }
      ]
    },
    {
      "type": "paragraph",
      "content": [
        {
          "type": "text",
          "text": "Rotation is scheduled for today and rollback is not required."
        }
      ]
    }
  ]
}
```

## Bullet List

```json
{
  "version": 1,
  "type": "doc",
  "content": [
    {
      "type": "bulletList",
      "content": [
        {
          "type": "listItem",
          "content": [
            {
              "type": "paragraph",
              "content": [
                {
                  "type": "text",
                  "text": "Reproduced in staging"
                }
              ]
            }
          ]
        },
        {
          "type": "listItem",
          "content": [
            {
              "type": "paragraph",
              "content": [
                {
                  "type": "text",
                  "text": "Added request logging"
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

## Code Block

```json
{
  "version": 1,
  "type": "doc",
  "content": [
    {
      "type": "codeBlock",
      "attrs": {
        "language": "bash"
      },
      "content": [
        {
          "type": "text",
          "text": "curl -I https://example.internal/healthz\njq '.status' response.json"
        }
      ]
    }
  ]
}
```

## Mixed Example

```json
{
  "version": 1,
  "type": "doc",
  "content": [
    {
      "type": "paragraph",
      "content": [
        {
          "type": "text",
          "text": "Deployment plan for the fix:"
        }
      ]
    },
    {
      "type": "bulletList",
      "content": [
        {
          "type": "listItem",
          "content": [
            {
              "type": "paragraph",
              "content": [
                {
                  "type": "text",
                  "text": "Roll out to staging"
                }
              ]
            }
          ]
        },
        {
          "type": "listItem",
          "content": [
            {
              "type": "paragraph",
              "content": [
                {
                  "type": "text",
                  "text": "Monitor error rate for 30 minutes"
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "type": "codeBlock",
      "attrs": {
        "language": "bash"
      },
      "content": [
        {
          "type": "text",
          "text": "kubectl rollout restart deploy/web\nkubectl rollout status deploy/web"
        }
      ]
    }
  ]
}
```

## Usage Patterns

Comment create:

```bash
acli jira workitem comment create --key KEY-123 --body-file comment.json --json
```

Comment update:

```bash
acli jira workitem comment update --key KEY-123 --id 10001 --body-adf comment.json
```

Issue create or edit:

```bash
acli jira workitem create --summary "New task" --project TEAM --type Task --description-file description.json --json
acli jira workitem edit --key KEY-123 --description-file description.json --json
```
