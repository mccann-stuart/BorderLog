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

- [ ] Update `DataManager` reset/seed behavior and fix `DataManagerTests` schema + assertions.
- [ ] Convert ingestion APIs to throwing (`PhotoSignalIngestor`, `CalendarSignalIngestor`, `LocationSampleService`) and remove silent save failures.
- [ ] Update ingestion call sites (`SettingsView`, widget provider) to handle throwing APIs and surface errors.
- [ ] Harden `ModelContainerProvider` recovery to non-destructive defaults with quarantine-based recovery and remove forced `try!`.
- [ ] Optimize ingestion hotspots (calendar stale lookup index + photo preloaded hash dedupe set).
- [ ] Add/expand tests for fetcher boundaries, calendar parsing core, photo dedupe/save behavior, and recovery helpers.
- [ ] Run full `LearnTests` suite and targeted regressions; record results and residual risk.

## Review (Data Layer Hardening Implementation)

- Pending.
