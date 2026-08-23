# Claude Code CLI adapter

Use this adapter when Claude is a requested reviewer reached from Codex, Pi, or another host through Claude Code.

Run from the repository root. Start a persistent print-mode session with the exact model alias or id requested by the user:

```text
claude --session-id SESSION_ID --print --output-format text [--model MODEL] "RENDERED_REVIEW_REQUEST"
```

Generate and retain `SESSION_ID` before the first call. On follow-up rounds:

```text
claude --resume SESSION_ID --print --output-format text "RENDERED_FOLLOW_UP_REQUEST"
```

Do not pass an edit-accepting or permission-bypass mode merely to make review easier. The prompt limits Claude to read-only inspection. If local policy prevents required read-only inspection, report the failure rather than weakening policy silently.

If the `claude-review` skill and its wrapper are installed, they may be used as the transport instead. Pass the hostile instructions from the common template through its extra-instruction mechanism, pass the requested model, and preserve its returned session id. The ordinary review prompt from that skill does not replace this cycle's hate-review request.

If resume fails, start a new session with the same model and include the short fix summary. A worker subagent may run the CLI to isolate command noise, but it is not another reviewer.
