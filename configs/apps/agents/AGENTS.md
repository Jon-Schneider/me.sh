- IMPORTANT When creating branches, name them using the format 'jsc/yyyy-mm-dd--[description]'
- !!!IMPORTANT Do not use raw `xcodebuild`, `xcrun simctl`, or `simctl` for simulator build/run/test flows. I run agents in a sandbox and these tools and any CLIs built on top of it are broken. Instead use an MCP for building and testing apps
- Ask me clarifying questions before you start writing code if anything is evenly slightly ambiguous

## Coding Standards

* Never use "SUT" (System Under Test) or `makeSUT` naming in test code. Use descriptive names instead. Name test factory methods `setupTestStack` (or similar descriptive names). Use named tuple returns like `(actionHandler:, store:)` so call sites read clearly. Avoid all test jargon abbreviations.
* Don't name types with 'Helper' or 'Util' suffixes. They're vague and don't convey what the type actually does. A specific name (e.g., `OrchestrationPersistenceCoordinator` instead of `TranslationCoreDataHelper`) communicates responsibility better.
* Don't use closure-based `Dependencies` structs for injecting behavior.  Prefers real types that can be named and reasoned about. Pass typed protocols instead (e.g., `DataFileWriting` protocol with a concrete `DataFileWriter` and test doubles). When a type needs an injected dependency for I/O or side effects, define a protocol and a lightweight concrete implementation. In tests, use spy/stub/failing conformances rather than inline closures.

@RTK.md
