---
name: use-pi-agents
description: Delegate bounded coding, investigation, or review tasks to Pi CLI agents, including parallel work and persistent follow-up sessions. Use when the user asks to use, call, ask, or delegate to Pi agents; do not use merely because an ordinary task could be delegated.
---

# Use Pi Agents

Use Pi as an external worker while remaining responsible for scope, integration, and verification. Run Pi from the repository root so it sees the correct project context and instructions.

## Delegate cleanly

- Give each agent one independent, bounded task with the desired outcome, owned files, constraints, and verification expected.
- Preserve the user's requested provider, model, and thinking level exactly. If none is requested, use Pi's configured default. Never silently substitute another model.
- Parallelize only workstreams that will not edit the same files. Give every Pi agent its own session ID; never reuse one session across different tasks.
- For reviews, keep Pi read-only with `--tools read,grep,find,ls`. Add `bash` only when inspection or tests require it, and explicitly prohibit edits and mutating commands.
- For implementation, enable only the tools the task needs. Tell Pi not to commit, create branches, or broaden the task unless the user explicitly authorized that action.

A good initial prompt states the task, scope, relevant user request, constraints, and what the agent must return. Prefer letting Pi inspect the repository over pasting large diffs or files into the prompt.

## Start a persistent session

Create and retain a unique UUID for each delegated task, then run:

```bash
pi --print --session-id "$SESSION_ID" \
  [--provider PROVIDER] [--model MODEL] [--thinking LEVEL] \
  [--tools TOOL_LIST] \
  "TASK_PROMPT"
```

Record the session ID beside the agent's task. Do not use `--no-session`: persistence is what allows the agent to review fixes, answer questions, or continue incomplete work without losing context.

## Continue or resend to the same agent

Use the same session for every follow-up on that task:

```bash
pi --print --session "$SESSION_ID" "FOLLOW_UP_PROMPT"
```

Send new information, failures, requested corrections, or a concise summary of changes since the last turn. Do not restart with the original prompt when a follow-up will do. For review loops, ask the same session to re-review after fixes so it can distinguish resolved findings from remaining ones.

If resume fails, retry once with the full session ID. If the session is unavailable, create a new persistent session using the same provider/model and include a compact handoff containing the original task, prior result, work completed, and unresolved questions.

## Integrate the result

Inspect Pi's output and any workspace changes; do not treat completion claims or review findings as authoritative. Resolve overlaps deliberately, run appropriate verification, and report which agents were used, what they contributed, and any feedback or failures that remain.
