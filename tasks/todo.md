# UI Performance Optimization Plan

## Analysis
- [x] Analyze `PhotoSignalIngestor.swift`
- [x] Analyze `LedgerRecomputeService.swift`
- [x] Identify root cause: Massive SwiftData fetches, loops, and external operations (like geocoding) running synchronously on the `@MainActor`.

## Implementation
- [x] Refactor `PhotoSignalIngestor` to run off the main thread.
    - Change approach so it no longer requires the main UI `ModelContext`.
    - Provide a mechanism to execute the ingestion workload asynchronously on a background `@ModelActor` or using a separate `ModelContext`.
- [x] Refactor `LedgerRecomputeService` to run off the main thread.
    - Convert from `@MainActor enum` into an `@ModelActor` or background worker.
    - Ensure all heavy computations and DB interactions happen without touching the main thread.
- [x] Update Callers (`DataManager`, UI Views, `LocationSampleService`) to initialize these actors with `ModelContainer` rather than `ModelContext`.
    
## Verification
- [x] Validate no build errors.
- [x] Perform manual testing to verify that photo ingestion doesn't freeze the UI.
- [x] Run test suite.
