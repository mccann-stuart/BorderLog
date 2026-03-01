# Task Plan

- [x] Identify the exact Sendable warning site in CountryPolygonLoader and decide on the safest fix
- [x] Apply the minimal code change to remove the main-actor isolated static access from the background closure
- [x] Verify with Xcode diagnostics and document results below

## Review

- Moved the alpha3->alpha2 mapping to a file-scope constant and marked GeoJSON model structs as nonisolated to keep decoding on a background queue.
- XcodeRefreshCodeIssuesInFile: no issues in Learn/Shared/CountryPolygonLoader.swift.

---

# Task Plan (Schengen Dashboard Visibility Toggle)

- [x] Add a persisted `@AppStorage` key in `SettingsView.swift` and replace static Schengen configuration row with a toggle.
- [x] Add the same `@AppStorage` key in `DashboardView.swift` and gate `SchengenSummarySection` rendering.
- [x] Verify compilation/tests for the Learn scheme and document evidence.
- [x] Record completed review notes for behavior, persistence, and regression scope.

## Review (Schengen Dashboard Visibility Toggle)

- Added `showSchengenDashboardSection` as a persisted `@AppStorage` boolean in both `SettingsView.swift` and `DashboardView.swift` with default `true`.
- Replaced the static "Schengen Zone / Built-in" configuration row with a toggle and clarified footer copy that it controls Dashboard card visibility.
- Gated Dashboard rendering so only `SchengenSummarySection` is hidden when toggle is off; map, inference progress, and visited countries sections remain unchanged.
- Verification:
  - `xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' build` → **BUILD SUCCEEDED**.
  - `xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LearnTests/SchengenLedgerCalculatorTests test` → **TEST SUCCEEDED**.

---

# Task Plan (Data-Layer Coverage + Performance Audit)

- [x] Inventory LearnTests coverage touching persistence/ingestion paths.
- [x] Trace persistence/ingestion production code paths and map them to existing tests.
- [x] Identify untested or weakly-tested scenarios most likely to hide regressions.
- [x] Identify performance pitfalls in persistence/ingestion paths and whether tests catch them.
- [x] Document prioritized findings with file references in final report.

## Review (Data-Layer Coverage + Performance Audit)

- Verified with targeted run:
  - `xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LearnTests/LedgerRecomputeServiceTests -only-testing:LearnTests/LedgerRecomputeErrorTests -only-testing:LearnTests/LedgerRangeTests -only-testing:LearnTests/DataManagerTests -only-testing:LearnTests/PhotoSignalIngestorDateRangeTests -only-testing:LearnTests/LocationConcurrencyTests test`
  - Result: **TEST FAILED** due `DataManagerTests.testResetAllDataRemovesData` throwing `NSFetchRequest could not locate an NSEntityDescription for entity name 'LocationSample'`.
- Coverage snapshot (from generated xcresult/xccov on this run):
  - `Shared/PhotoSignalIngestor.swift`: `0%`
  - `Shared/CalendarSignalIngestor.swift`: `0%`
  - `Shared/LocationSampleService.swift`: `4%`
  - `Shared/LedgerRecomputeService.swift`: `15.71%`
  - `Shared/LedgerDataFetching.swift`: `8.33%`
  - `Shared/CountryResolver.swift`: `0%`
  - `Shared/AirportCodeResolver.swift`: `0%`
  - `Shared/GeocodeThrottleStore.swift`: `0%`
  - `Shared/CloudKitDataResetService.swift`: `0%`

---

# Task Plan (iOS Data Layer Defect Audit)

- [x] Identify scope files under `Shared/*.swift`, `Learn/DataManager.swift`, ingestors, recompute services, and `ModelContainerProvider.swift`.
- [x] Audit for high-confidence crash, data-loss, and data-corruption defects with concrete code references.
- [x] Produce a severity-ranked findings list with `file:line` references and concise rationale.
- [x] Add review notes summarizing audit method and confidence filters.

## Review (iOS Data Layer Defect Audit)

- Audited the requested scope with line-level review, focusing on persistence semantics (`save`, migration fallback, destructive cleanup) and cross-context consistency (`ModelContext` visibility across actors).
- Only retained high-confidence defects that can directly cause crash/data loss/corruption under realistic runtime conditions.
- Findings prepared with severity ranking and concrete `file:line` references in the response.

---

# Task Plan (Data Layer Hardening Implementation)

- [x] Update `DataManager` reset/seed behavior and fix `DataManagerTests` schema + assertions.
- [x] Convert ingestion APIs to throwing (`PhotoSignalIngestor`, `CalendarSignalIngestor`, `LocationSampleService`) and remove silent save failures.
- [x] Update ingestion call sites (`SettingsView`, widget provider) to handle throwing APIs and surface errors.
- [x] Harden `ModelContainerProvider` recovery to non-destructive defaults with quarantine-based recovery and remove forced `try!`.
- [x] Optimize ingestion hotspots (calendar stale lookup index + photo preloaded hash dedupe set).
- [x] Add/expand tests for fetcher boundaries, calendar parsing core, photo dedupe/save behavior, and recovery helpers.
- [x] Run full `LearnTests` suite and targeted regressions; record results and residual risk.

## Review (Data Layer Hardening Implementation)

- Implemented full reset/seed hardening in `DataManager` and `DataManagerTests`: reset now deletes `CalendarSignal` and `CountryConfig`, save is explicit before recompute kickoff, and reset/seed tests now use the full schema and assert all relevant entities are cleared.
- Converted ingestion persistence APIs to fail-fast throwing flows:
  - `PhotoSignalIngestor.ingest(mode:)` and `CalendarSignalIngestor.ingest(mode:)` are now `async throws -> Int`.
  - `LocationSampleService.captureAndStore(...)` and `captureAndStoreBurst(...)` are now `async throws -> LocationSample?`.
  - Removed silent `try? save` semantics and replaced with explicit throwing behavior.
- Updated callers to handle throwing ingestion/location capture paths while preserving existing UX:
  - `SettingsView` rescan actions now use `do/catch`, `defer` for busy flags, and alert surfaced error messages.
  - Widget timeline provider catches burst-capture errors and continues with the latest persisted sample.
  - Main app bootstrap/background callers updated to handle thrown ingestion/capture errors.
- Hardened container recovery strategy in `ModelContainerProvider`:
  - Removed unconditional App Group cleanup at normal startup.
  - Replaced immediate destructive recreation with quarantine-first recovery.
  - Added explicit heuristics to gate destructive recreation attempts.
  - Replaced in-memory fallback `try!` with deterministic explicit fallback error handling.
- Addressed ingest scalability bottlenecks:
  - Calendar ingest now preloads existing signals into in-memory indexes to avoid per-event full-table operations.
  - Photo ingest now prefetches existing hash set for the ingest window and avoids per-asset existence fetches.
- Added high-risk tests:
  - `RealLedgerDataFetcherTests`
  - `CalendarFlightParsingTests` (new extracted parsing core)
  - `PhotoSignalIngestorCoreTests`
  - `ModelContainerProviderRecoveryTests`
  - Expanded `DataManagerTests` and updated location concurrency tests for throwing signatures.
- Verification:
  - Targeted regression run:
    - `xcodebuild test -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LearnTests/DataManagerTests -only-testing:LearnTests/RealLedgerDataFetcherTests -only-testing:LearnTests/CalendarFlightParsingTests -only-testing:LearnTests/PhotoSignalIngestorCoreTests -only-testing:LearnTests/ModelContainerProviderRecoveryTests -only-testing:LearnTests/LedgerRecomputeServiceTests -only-testing:LearnTests/LedgerRecomputeErrorTests -only-testing:LearnTests/LedgerRangeTests -only-testing:LearnTests/LocationConcurrencyTests -only-testing:LearnTests/PhotoSignalIngestorDateRangeTests`
    - Result: **TEST SUCCEEDED**.
  - Full suite run:
    - `xcodebuild test -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LearnTests`
    - Result: **TEST SUCCEEDED**.
- Residual risk:
  - Existing non-blocking actor-isolation warnings outside this change set remain in ledger recompute-related code paths; no test failures or runtime regressions were observed in this implementation.

---

# Task Plan (PresenceDay Dispute Visibility Audit)

- [x] Scan `ContentView`, `DailyLedgerView`, `PresenceDayRow`, and `PresenceDayDetailView` for existing dispute-related UI.
- [x] Identify smallest UI-only changes that expose `PresenceDay.isDisputed` without schema changes.
- [x] Prepare a 3-change proposal with exact file paths and line blocks.
- [x] Document review notes with rationale and risk.

## Review (PresenceDay Dispute Visibility Audit)

- Confirmed dispute state exists in model (`PresenceDay.isDisputed`) and is currently filterable in `ContentView` and `DailyLedgerView`.
- Found the core visibility gap: list rows and detail summary do not explicitly label disputed days; dispute suggestions are also gated to unknown-country days only.
- Selected three smallest changes that keep existing schema and data flow: row badge, detail dispute status/suggestions visibility, and list-level dispute count exposure in filters.

---

# Task Plan (PresenceInferenceEngine Dispute Threshold Review)

- [x] Inspect current dispute logic in `Shared/PresenceInferenceEngine.swift` and enumerate thresholds/formulas.
- [x] Inspect dispute-related tests in `LearnTests/InferenceEngineTests.swift` and map covered scenarios.
- [x] Propose 2-3 simple, low-risk ways to increase disputed day count with concrete formulas and implementation points.
- [x] Document tradeoffs and recommendation rationale in the final response.

## Review (PresenceInferenceEngine Dispute Threshold Review)

- Current dispute formula is `isDisputed = ((winnerScore - runnerUpScore) / totalScore) <= 0.5` when at least two countries have non-zero score.
- Confidence label thresholds are independent of dispute status (`high >= 6`, `medium >= 3`, else `low`), and unknown days are produced when `winnerScore < 1.0`.
- Test coverage in `InferenceEngineTests` verifies basic dispute/non-dispute behavior for photo-only signal mixes, but does not cover persistence of `isDisputed` through recompute/upsert.
- Verification run:
  - `xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LearnTests/InferenceEngineTests test`
  - Result: **TEST SUCCEEDED**.

---

# Task Plan (Dispute Surfacing: Persistence Fix + Simple Visibility)

- [ ] Fix `PresenceDay.isDisputed` persistence in `Shared/LedgerRecomputeService.swift` for both update and insert upsert paths.
- [ ] Add dispute visibility chip in `Learn/PresenceDayRow.swift` for non-manual disputed days.
- [ ] Add dispute count surface in `Learn/ContentView.swift` and include it in the range summary UI.
- [ ] Add dispute count in `Learn/DailyLedgerView.swift` and update filter label to `Show Disputed (N)`.
- [ ] Add dispute summary callout + unknown-or-disputed suggestion gate in `Learn/PresenceDayDetailView.swift`.
- [ ] Add/extend unit coverage in `LearnTests/LedgerRecomputeServiceTests.swift` for disputed persistence on update and insert.
- [ ] Run targeted tests (`LedgerRecomputeServiceTests`, `InferenceEngineTests`) and full `LearnTests` suite.
- [ ] Record review notes, outcomes, and residual risk.

## Review (Dispute Surfacing: Persistence Fix + Simple Visibility)

- Pending.
