# Task Plan (Data Model + Day Detail Hardening)

- [x] Add schema V6 fields for canonical day identity (`DayOverride.dayKey/dayTimeZoneId`, `Stay.entryDayKey/exitDayKey/dayTimeZoneId`, `CalendarSignal.bucketingTimeZoneId`) and introduce one-time epoch reset gate.
- [x] Add/centralize day identity helpers and update all creation/edit flows to persist canonical day keys/timezones.
- [x] Rework calendar ingest to true upsert semantics, consistent timezone bucketing, and orphan cleanup with impacted day recompute.
- [x] Update inference/recompute to consume canonical day keys, remove `countryCode` fallback pollution, and make day timezone selection deterministic.
- [x] Harden day-detail behavior: key-based override matching, canonical day window for evidence, and timezone-consistent display/Today logic.
- [x] Make presence-day window key retrieval robust against `date` drift.
- [x] Add and update tests for calendar upsert/orphan cleanup, canonical day identity stability, inference determinism, and day-detail override behavior.
- [x] Run targeted and full test suites; capture results and residual risks.

## Review (Data Model + Day Detail Hardening)

- Added canonical day identity persistence across manual models and signals:
  - `DayOverride`: unique `dayKey` + `dayTimeZoneId`.
  - `Stay`: `entryDayKey`, `exitDayKey`, `dayTimeZoneId`.
  - `CalendarSignal`: `bucketingTimeZoneId`.
- Added `DayIdentity` helper to canonicalize write-time day keys/timezones and day-window derivation (`canonicalDay`, `normalizedDate`, `dayWindow`), then wired editor/apply flows to persist canonical fields.
- Upgraded storage schema to V6 and introduced one-time store epoch reset gate in `ModelContainerProvider` (`storeEpochV2=6`) with test coverage for one-time purge semantics.
- Reworked calendar ingestion to real upsert behavior with stale/orphan cleanup and impacted-day recompute tracking, while ensuring `dayKey`, `timeZoneId`, and `bucketingTimeZoneId` are derived from one explicit bucketing timezone.
- Updated recompute/inference pipeline to consume canonical manual day keys, propagate `bucketingTimeZoneId` for calendar evidence, remove `countryCode ?? countryName` fallback pollution, and use deterministic timezone tie-break (`highest score`, then lexicographic timezone id).
- Hardened day detail and row behavior:
  - Override CRUD now matches by `dayKey` instead of brittle `Date ==`.
  - Evidence stay overlap uses canonical day window from `dayKey + day.timeZoneId`.
  - Date display and "Today" logic now use day timezone semantics.
- Hardened day-key range retrieval by switching `fetchPresenceDayKeys(from:to:)` to key-window generation + key lookup, eliminating dependence on drift-prone `PresenceDay.date` range filters.
- Added/updated tests:
  - `CalendarSignalIngestorCoreTests` (upsert moved-day + delete/orphan behavior).
  - Canonical model tests (`DayOverrideTests`, `StayTests`).
  - Validation and determinism tests (`DayOverrideValidationTests`, `InferenceEngineTests`).
  - Fetch safety and epoch reset tests (`RealLedgerDataFetcherTests`, `ModelContainerProviderRecoveryTests`).
- Verification:
  - Targeted run: `xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LearnTests/DayKeyTests -only-testing:LearnTests/StayTests -only-testing:LearnTests/DayOverrideTests -only-testing:LearnTests/DayOverrideValidationTests -only-testing:LearnTests/InferenceEngineTests -only-testing:LearnTests/RealLedgerDataFetcherTests -only-testing:LearnTests/CalendarSignalIngestorCoreTests -only-testing:LearnTests/ModelContainerProviderRecoveryTests -only-testing:LearnTests/LedgerRecomputeServiceTests test` -> **TEST SUCCEEDED**.
  - Full suite: `xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -only-testing:LearnTests test` -> **TEST SUCCEEDED** (`113 tests, 0 failures`).
  - Post-hardening follow-up (canonical timestamp normalization in `DayOverride`/`Stay`):
    - `xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' build` -> **BUILD SUCCEEDED**.
    - `xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,id=9DE9B9B2-671C-4278-8A4A-F3B48E244388' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -only-testing:LearnTests/DayOverrideTests -only-testing:LearnTests/StayTests -only-testing:LearnTests/RealLedgerDataFetcherTests test` -> **TEST SUCCEEDED** (13 tests, 0 failures).
- Residual risk:
  - Existing actor-isolation warnings (outside this scope and pre-existing in project) remain; no behavioral regressions were observed in targeted or full test runs.

---
# Task Plan (Widget Location Authorization Unblock)

- [ ] Add `NSWidgetWantsLocation` to widget extension plist.
- [ ] Centralize location authorization gating in `LocationSampleService` with widget-specific authorization checks.
- [ ] Skip widget capture attempts when widget updates are not authorized and keep timeline fallback behavior.
- [ ] Add targeted tests for authorization gating matrix.
- [ ] Verify with plist extraction, targeted tests, and widget build.
- [ ] Add review notes and evidence.

## Review (Widget Location Authorization Unblock)

- Pending implementation.

---

# Task Plan (Weekly Changelog: Feb 24-Mar 1, 2026)

- [x] Confirm existing Weekly Changelog format in `README.md` and load prior automation memory to avoid duplication.
- [x] Collect repo-backed highlights and merged PR links for Feb 24-Mar 1, 2026 from `git log`.
- [x] Update `README.md` Weekly Changelog with a new week entry using the same simple structure.
- [x] Verify the new entry contains only history-supported items and consistent formatting.
- [x] Add review notes for this run.

## Review (Weekly Changelog: Feb 24-Mar 1, 2026)

- Added a new weekly changelog block at the top of `README.md` for Feb 24-Mar 1, 2026 using the existing `Highlights` + `Key PRs` format.
- Sourced all PR links from merge commits in repo history for that week (`#82`, `#83`, `#84`, `#87`, `#88`, `#89`, `#92`, `#93`), excluding non-product automation PR `#94`.
- Kept highlights constrained to themes directly supported by commit history in the same date window: security hardening, performance optimization, and UX/data-entry improvements.

---

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

- [x] Fix `PresenceDay.isDisputed` persistence in `Shared/LedgerRecomputeService.swift` for both update and insert upsert paths.
- [x] Add dispute visibility chip in `Learn/PresenceDayRow.swift` for non-manual disputed days.
- [x] Add dispute count surface in `Learn/ContentView.swift` and include it in the range summary UI.
- [x] Add dispute count in `Learn/DailyLedgerView.swift` and update filter label to `Show Disputed (N)`.
- [x] Add dispute summary callout + unknown-or-disputed suggestion gate in `Learn/PresenceDayDetailView.swift`.
- [x] Add/extend unit coverage in `LearnTests/LedgerRecomputeServiceTests.swift` for disputed persistence on update and insert.
- [x] Run targeted tests (`LedgerRecomputeServiceTests`, `InferenceEngineTests`) and full `LearnTests` suite.
- [x] Record review notes, outcomes, and residual risk.

## Review (Dispute Surfacing: Persistence Fix + Simple Visibility)

- Fixed disputed persistence in `LedgerRecomputeService.upsertPresenceDays(...)`:
  - Existing row path now sets `existing.isDisputed = result.isDisputed`.
  - Insert path now passes `isDisputed: result.isDisputed` into `PresenceDay(...)`.
- Added lightweight dispute visibility in UI:
  - `PresenceDayRow` now renders a `Disputed` warning capsule for `isDisputed && !isManuallyModified`.
  - `ContentView` now computes and displays `disputedDayCount` in the 2-year summary block.
  - `DailyLedgerView` now computes `disputedDayCount` and shows `Show Disputed (N)` in filter menu.
  - `PresenceDayDetailView` now shows dispute status in Summary and enables Suggestions for unknown or disputed days (when suggestion fields exist).
- Added regression coverage in `LedgerRecomputeServiceTests`:
  - `testRecomputePersistsDisputedFlagWhenUpdatingExistingPresenceDay`
  - `testRecomputePersistsDisputedFlagWhenInsertingPresenceDay`
- Verification:
  - Targeted:
    - `xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LearnTests/LedgerRecomputeServiceTests -only-testing:LearnTests/InferenceEngineTests test`
    - Result: **TEST SUCCEEDED**.
  - Full suite:
    - `xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LearnTests test`
    - Result: **TEST SUCCEEDED**.
- Residual risk:
  - Existing non-blocking actor-isolation warnings in `LedgerRecomputeService`/related types remain unchanged in this task.
