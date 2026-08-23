# Codex CLI adapter

Use this adapter when Codex is a requested reviewer reached from another host or when the user explicitly requests the Codex CLI route.

Run from the repository root. Pass the rendered hate-review request as the custom review prompt and select the user's requested model with `--model` when one was named.

Map the target to `--uncommitted`, `--base <branch>`, or `--commit <sha>` as appropriate:

```text
codex exec review [TARGET_FLAG] [--model MODEL] --json --output-last-message OUTPUT_FILE "RENDERED_REVIEW_REQUEST"
```

Capture the JSONL event stream separately from `OUTPUT_FILE`. Obtain the session id from the earliest event containing `id` or `session_id`; the output file contains the review text. Do not interpolate user-provided text into executable shell syntax—pass it as a single argument or through a temporary prompt file.

For follow-up rounds, preserve the session:

```text
codex exec resume SESSION_ID "RENDERED_FOLLOW_UP_REQUEST" --json --output-last-message OUTPUT_FILE
```

If the session id cannot be recovered or resume fails, start a fresh review with the same model and include the fix summary. Do not add `--ephemeral` when session continuity is desired. A worker subagent may own the noisy CLI invocation when the host supports one, but that worker is only a transport and must not become an extra reviewer.
