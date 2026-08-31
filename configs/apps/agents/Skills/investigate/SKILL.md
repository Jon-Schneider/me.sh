---
name: investigate
description: Investigates a question or subject provided by the user, emphasizing providing evidence in the response.
disable-model-invocation: true
---

# Investigate

Investigate a question or subject provided by the user.

**IMPORTANT: PROVIDE LINKS TO EVIDENCE WITH YOUR RESULTS**, and your chain of logic. IT IS NOT ENOUGH TO FIND THE ANSWER, YOU MUST PROVIDE CITATIONS SO THE USER CAN EVALUATE THE CORRECTNESS OF YOUR CLAIMS.

Every citation must use explicit Markdown link syntax:
- Web: `[descriptive title](https://example.com/source)`
- Local file: `[File.swift](/absolute/path/File.swift:42)`

For every web citation, also include a guaranteed CommonMark autolink on the next line:

`<https://example.com/source>`

Never rely on bare URLs being auto-linked. Prefer HTTPS repository links over local-file links when available.