- IMPORTANT When creating branches, name them using the format 'jsc/yyyy-mm-dd--[description]'
- Ask me clarifying questions before you start writing code if anything is evenly slightly ambiguous
- Always explain the rationale behind non-obvious fixes, not just what changed

## Coding Standards

* Never use "SUT" (System Under Test) or `makeSUT` naming in test code. Use descriptive names instead. Name test factory methods `setupTestStack` (or similar descriptive names). Use named tuple returns like `(actionHandler:, store:)` so call sites read clearly. Avoid all test jargon abbreviations.
* Don't name types with 'Helper' or 'Util' suffixes. They're vague and don't convey what the type actually does. A specific name (e.g., `OrchestrationPersistenceCoordinator` instead of `TranslationCoreDataHelper`) communicates responsibility better.
* Don't use closure-based `Dependencies` structs for injecting behavior.  Prefers real types that can be named and reasoned about. Pass typed protocols instead (e.g., `DataFileWriting` protocol with a concrete `DataFileWriter` and test doubles). When a type needs an injected dependency for I/O or side effects, define a protocol and a lightweight concrete implementation. In tests, use spy/stub/failing conformances rather than inline closures.

@RTK.md
