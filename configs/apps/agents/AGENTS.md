- IMPORTANT Never create or switch branches unless I explicitly ask — commit on the current branch even when it is `main`. When I do ask, name branches 'jsc/yyyy-mm-dd--[description]'.
- DO NOT commit work unless told to.
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
