# Self-Improvement Lessons

## SwiftData UI Freezing
- **Pattern**: Running heavy SwiftData synchronous fetches (`modelContext.fetch`) inside loops, combined with other tasks (geocoding) on the `@MainActor`.
- **Lesson**: Never run large datastore tasks on the main thread in Swift. Always use a background `ModelContext` (e.g. via `@ModelActor` or by initializing a new `ModelContext` on a background thread) for operations like batch ingestion or ledger recomputation.

## Xcode Duplicate Info.plist Output (Widget)
- **Pattern**: `Multiple commands produce .../BorderLogWidget.appex/Info.plist` on a clean build when the widget’s `Info.plist` is both the target’s Info.plist (`INFOPLIST_FILE`) and auto-added to build resources by a file-system–synchronized group.
- **Lesson**: Ensure the widget `Info.plist` is not included in Copy Bundle Resources. For file-system–synchronized groups, add a build-file exception for `Info.plist` (or remove it from target membership) so only the Info.plist processing phase produces it.
