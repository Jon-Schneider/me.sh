- IMPORTANT Never create or switch branches unless I explicitly ask — commit on the current branch even when it is `main`. When I do ask, name branches 'jsc/yyyy-mm-dd--[description]'.
- Ask me clarifying questions before you start writing code if anything is evenly slightly ambiguous
- Always explain the rationale behind non-obvious fixes, not just what changed
- Be concise in all written comments, commit messages, pull request descriptions, and other writing.
- Be direct and to the point. I have 15 years of software engineering experience, and don't need over-explanation.

## Coding Standards

* Code should be readable and self-evident without needing comments. Comments are for non-intuitive explanations of what's going on. The default should be no comments unless necessary. Never write walls of comments in code. A comment must be extremely important to justify being longer than one line. Make comments concise and only to document public interfaces, link to authoritative specifications, or explain surprising implementation details.
* Prefer descriptive names, single responsibility, immutable data, guard clauses, and composition.
* Represent parameter choices with enums, builders, or separate methods.
* Don't use closure-based `Dependencies` structs for injecting behavior.  Prefers real types that can be named and reasoned about. Pass typed protocols instead (e.g., `DataFileWriting` protocol with a concrete `DataFileWriter` and test doubles). When a type needs an injected dependency for I/O or side effects, define a protocol and a lightweight concrete implementation. In tests, use spy/stub/failing conformances rather than inline closures.]
* Never use "SUT" (System Under Test) or `makeSUT` naming in test code. Use descriptive names instead. Name test factory methods `setupTestStack` (or similar descriptive names). Use named tuple returns like `(actionHandler:, store:)` so call sites read clearly. Avoid all test jargon abbreviations.
* Don't name types with 'Helper' or 'Util' suffixes. They're vague and don't convey what the type actually does. A specific name (e.g., `OrchestrationPersistenceCoordinator` instead of `TranslationCoreDataHelper`) communicates responsibility better.

## Testing

* The `axe` CLI tool is available for driving the iOS simulator. Run `axe --help` to see options.

@RTK.md


<!-- headroom:rtk-instructions -->
# RTK (Rust Token Killer) - Token-Optimized Commands

When running shell commands, **always prefix with `rtk`**. This reduces context
usage by 60-90% with zero behavior change. If rtk has no filter for a command,
it passes through unchanged — so it is always safe to use.

## Key Commands
```bash
# Git (59-80% savings)
rtk git status          rtk git diff            rtk git log

# Files & Search (60-75% savings)
rtk ls <path>           rtk read <file>         rtk grep <pattern>
rtk find <pattern>      rtk diff <file>

# Test (90-99% savings) — shows failures only
rtk pytest tests/       rtk cargo test          rtk test <cmd>

# Build & Lint (80-90% savings) — shows errors only
rtk tsc                 rtk lint                rtk cargo build
rtk prettier --check    rtk mypy                rtk ruff check

# Analysis (70-90% savings)
rtk err <cmd>           rtk log <file>          rtk json <file>
rtk summary <cmd>       rtk deps                rtk env

# GitHub (26-87% savings)
rtk gh pr view <n>      rtk gh run list         rtk gh issue list

# Infrastructure (85% savings)
rtk docker ps           rtk kubectl get         rtk docker logs <c>

# Package managers (70-90% savings)
rtk pip list            rtk pnpm install        rtk npm run <script>
```

## Rules
- In command chains, prefix each segment: `rtk git add . && rtk git commit -m "msg"`
- For debugging, use raw command without rtk prefix
- `rtk proxy <cmd>` runs command without filtering but tracks usage
<!-- /headroom:rtk-instructions -->
