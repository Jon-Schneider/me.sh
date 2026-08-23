# Pi CLI adapter

Use this adapter when a Pi-supported model is a requested reviewer reached from another host, or when the user explicitly requests Pi as the route.

Run from the repository root. Use the exact provider/model selector requested by the user and create a persistent session:

```text
pi --print --session-id SESSION_ID [--provider PROVIDER] [--model MODEL] "RENDERED_REVIEW_REQUEST"
```

For follow-up rounds, reopen that session and send the rendered follow-up request:

```text
pi --print --session SESSION_ID "RENDERED_FOLLOW_UP_REQUEST"
```

Keep the reviewer read-only. If tool selection is needed, allow only the least-capable set that can inspect the repository and run read-only git or test commands. Do not enable editing merely because Pi supports it.

Pi installations may expose other agents through extensions. When the user names one of those agents, use the extension's native route if available while preserving the same review contract, model identity, session continuity, and read-only boundary. If the selector or extension is unavailable, report it instead of choosing another model.

If session resume is unsupported by the installed Pi version, start a fresh session with the same provider/model and include the fix summary.
