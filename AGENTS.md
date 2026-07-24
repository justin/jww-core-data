# Repository Guidelines

## Project Structure & Module Organization

`JWW Core Data` is a Swift Package Manager library for shared Core Data infrastructure. Production code lives in `Sources/JWWCoreData/`, including persistent-container subclasses, managed-object protocols, and framework extensions. Tests live in `Tests/JWWCoreDataTests/`. Keep test-only helpers in `Tests/JWWCoreDataTests/Test Helpers/` and model fixtures in `Tests/JWWCoreDataTests/Resources/`. Package products, supported Apple platforms, and the `JWWCore` dependency are declared in `Package.swift`.

## Build, Test, and Development Commands

- Use `BuildProject` to compile, not shell commands`
- `Run tests with `RunAllTests` or `RunSomeTests`
- Test results available via Xcode's test navigator
- `Use `DocumentationSearch` to find Apple API docs
- WWDC session transcripts are searchable

CI also builds the package for macOS, iOS, tvOS, and watchOS with Xcode 26. Before submitting platform-sensitive changes, verify them with Xcode or an appropriate destination in addition to running host tests.

## Coding Style & Naming Conventions

Use four-space indentation and follow the formatting already present in nearby Swift files. Name types in `UpperCamelCase` and methods, properties, and test functions in `lowerCamelCase`. Extensions should use the `Type+Purpose.swift` pattern, such as `NSManagedObjectContext+Extensions.swift`. Add documentation comments to public APIs and comments only for non-obvious intent. SwiftLint warns at 150-character lines and enforces opt-in rules including file headers, attributes, and `fatalError` messages.

## Testing Guidelines
Add tests for every behavior change and regression fix. Use Swift Testing
(`import Testing`, `@Test`, `#expect`, and `#require`) for all unit tests. Do not
add tests using XCTest. Name test functions to describe the observable
behavior. There is no declared coverage threshold, but new public helpers
should cover success cases and relevant edge cases.

## Commit & Pull Request Guidelines

Recent commits use short, capitalized, imperative summaries such as `Update existing code to Swift 6`; keep the subject under 50 characters and omit trailing punctuation. Keep each commit focused. Pull requests should explain the motivation, summarize behavior changes, link relevant issues, and report `swift test` and SwiftLint results. Include platform-specific validation when Core Data, concurrency, or availability behavior changes; screenshots are unnecessary unless a consuming app’s UI is affected.
