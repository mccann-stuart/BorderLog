# Inference Engine Rewrite Plan

## Phase 1: Planning & Design
- [x] Analyze Section 15 of PRESENCE_INFERENCE_PRD.md and current implementation
- [x] Design the decoupled middleware scoring pipeline
- [x] Design Incremental Ledger Updates and Asynchronous Ingestion Queues
- [x] Define the new `PresenceDay` data model with multi-country representation and transparent evidence
- [x] Design the dynamic confidence calibration and contextual gap-bridging (using day before and after)
- [x] Write detailed specification in `implementation_plan.md`

## Phase 2: Core Engine Rewrite (`PresenceInferenceEngine.swift`)
- [ ] Create `InferencePipeline` with middleware architecture
- [ ] Implement `SignalProcessor` protocol for stays, overrides, calendar, photos, locations
- [ ] Implement dynamic confidence calibration (parameterized decay)
- [ ] Implement nuanced transit-day modeling (fractional days)
- [ ] Implement day-before and day-after contextual influence (gap bridging)
- [ ] Output new `PresenceDayResult` with full evidence transparency

## Phase 3: Ingestors & Services Rewrite
- [x] Rewrite `LedgerRecomputeService.swift` for incremental ledger updates (dependency graph)
- [x] Rewrite `LocationSampleService.swift` to use asynchronous queues
- [x] Rewrite `PhotoSignalIngestor.swift` to use asynchronous queues
- [x] Rewrite `CalendarSignalIngestor.swift` to include non-flight context parsing

## Phase 4: Testing & Verification
- [x] Rewrite `InferenceEngineTests.swift` to validate new architecture
- [x] Run full test suite and fix issues
- [x] Validate manual stays, overrides, calendar (flights/trains), photos, and location edge cases
- [x] Write Walkthrough of changes

## Widget Fix: PresenceDay fields
- [x] Inspect PresenceDay model and BorderLogWidget usage around the error lines
- [x] Update BorderLogWidget to use correct PresenceDay fields/accessors
- [x] Verify diagnostics/build and document results

## Review
- [x] XcodeRefreshCodeIssuesInFile: no issues in BorderLogWidget.swift

## Task: Fix PresenceDay country access in CalendarTabDataService
- [x] Inspect PresenceDay model usage and missing members
- [x] Implement PresenceDay computed accessors for primary country
- [x] Verify diagnostics in CalendarTabDataService.swift

## Review
- [x] XcodeRefreshCodeIssuesInFile: CalendarTabDataService.swift (warnings only)
- [ ] BuildProject: failed - PresenceDayDetailView preview uses outdated PresenceDay initializer

## Task: Fix PresenceDayDetailView preview initializer
- [x] Inspect PresenceDayDetailView preview call and PresenceDay initializer
- [x] Update preview to include contributedCountries, zoneOverlays, evidence
- [x] Verify diagnostics/build

## Review
- [x] XcodeRefreshCodeIssuesInFile: PresenceDayDetailView.swift

## Task: Debug Data Store Export In Settings
- [x] Add a background debug export service with codable payload, summaries, and day-level diagnostics
- [x] Add an iPhone Settings export flow with file export UI, progress, and error handling
- [x] Add focused unit tests for payload generation, summaries, and day union coverage
- [ ] Run targeted verification for the new export feature and document results

## Review
- [x] Added a full-fidelity JSON export payload with records, summaries, and day-level diagnostics
- [x] Added a Settings export button, progress state, file exporter, and export failure handling
- [x] Added targeted exporter tests covering payload shape, summary values, and day union logic
- [ ] `swiftc -parse` passed for the new files, but Xcode verification is blocked by local simulator/runtime and SwiftData macro failures

## Task: Fix SettingsView Debug Export Permission Raw Value Type
- [x] Inspect SettingsView permission status helpers and DebugExportPermissionStatus
- [x] Update rawValue conversion to Int for permission statuses
- [x] Verify diagnostics in SettingsView.swift

## Review
- [x] XcodeRefreshCodeIssuesInFile: SettingsView.swift
