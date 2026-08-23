# External agent adapter

Use this adapter for an app, connector, API-backed agent, or other user-selected reviewer without a more specific template.

1. Open a conversation with the exact reviewer the user named and send the rendered hate-review request.
2. Prefer giving the reviewer read-only access to the repository. If it cannot inspect local files, send only the scoped diff and surrounding code needed for the review. Do not send unrelated files, credentials, secrets, or repository content outside the requested scope.
3. Preserve the same conversation for follow-up rounds when the app supports it. Otherwise send the follow-up request plus a concise summary of prior findings and fixes in a new conversation.
4. Keep app/tool metadata out of the findings, but preserve the reviewer's wording, severity, and sign-off status.

The user's choice of an external reviewer authorizes using that reviewer for the scoped review; it does not authorize publishing the code elsewhere or adding other services. If the app cannot receive enough context safely or cannot be reached, report the blocker and ask for a different route.
