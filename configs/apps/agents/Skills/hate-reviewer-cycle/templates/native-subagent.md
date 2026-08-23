# Native subagent adapter

Use this adapter when the requested reviewer is available through the current host's subagent or agent tool.

1. Create a reviewer agent with the exact model the user requested. Do not use a hard-coded fallback model.
2. Give it the rendered hate-review request, repository root, and access to the requested scope. Explicitly prohibit edits and commits.
3. Keep its task limited to review. The host agent evaluates findings and changes files.
4. Reuse the same agent for follow-ups when the host supports continued turns. Otherwise create a fresh agent with the same model and include the short fix summary from the follow-up template.
5. Return the review verbatim enough to preserve severity and sign-off status; discard tool chatter and hidden reasoning.

If the host cannot provide the exact requested model as a subagent, stop and report the mismatch. A similarly named or newer model is not an automatic substitute.
