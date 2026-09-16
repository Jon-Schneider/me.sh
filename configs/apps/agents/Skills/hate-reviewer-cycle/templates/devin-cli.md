# Devin CLI adapter

Use this adapter when Devin is a requested reviewer reached through the `devin` CLI.

Run from the repository root. Use print mode for non-interactive review and pass the user's requested model with `--model` when one was named:

```text
devin --print "RENDERED_REVIEW_REQUEST" [--model MODEL]
```

Keep the default `auto` permission mode (read-only approval). Do not pass `accept-edits`, `smart`, or `dangerous` merely to make review easier. If print mode fails in an untrusted directory, pass `--respect-workspace-trust false` rather than weakening tool permissions.

For follow-up rounds, resume the same conversation so the reviewer keeps its context:

```text
devin --resume SESSION_ID --print "RENDERED_FOLLOW_UP_REQUEST"
```

Obtain `SESSION_ID` by running `devin list` in the repository after the first round, or use `--continue` to resume the most recent conversation when the roster guarantees no other `devin` session interleaves between rounds. Prefer the explicit session id when one is recoverable.

If resume fails, start a fresh print-mode session with the same model and include the short fix summary. A worker subagent may run the CLI to isolate command noise, but it is not another reviewer.
