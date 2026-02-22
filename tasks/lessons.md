# Self-Improvement Lessons

## SwiftData UI Freezing
- **Pattern**: Running heavy SwiftData synchronous fetches (`modelContext.fetch`) inside loops, combined with other tasks (geocoding) on the `@MainActor`.
- **Lesson**: Never run large datastore tasks on the main thread in Swift. Always use a background `ModelContext` (e.g. via `@ModelActor` or by initializing a new `ModelContext` on a background thread) for operations like batch ingestion or ledger recomputation.
