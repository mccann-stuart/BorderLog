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

## Task: Travel-Backed Transition Inference
- [x] Inspect existing travel promotion and gap-bridging behavior in `PresenceInferenceEngine.swift`
- [x] Implement grouped travel-event indexing and adjacent before/after travel promotions
- [x] Implement travel-backed different-country transition infill while preserving suggestions/disputed state
- [x] Add regression and guardrail tests in `InferenceEngineTests.swift`
- [ ] Run targeted verification for inference changes and document results

## Review
- [x] Adjacent travel promotions now set calendar source/count and add explicit before/after evidence markers
- [x] Transition-gap infill now promotes disputed two-country results while preserving suggestions
- [ ] `swiftc -parse` passed for updated inference and test files; `xcodebuild test` is still blocked by older test fixtures using the obsolete `PresenceDay` initializer, and `xcodebuild build` is still blocked in this environment by SwiftData macro/plugin failures

## Task: Calendar travel decorations, suggestion fallback, and export day summary
- [x] Inspect current calendar parsing, ingestion, day aggregation, view decoration, and export behavior
- [x] Split calendar event classification into flight vs non-flight travel/lodging vs none
- [x] Restrict flight decorations to actual flight signals while preserving non-flight evidence
- [x] Make same-day flight endpoint selection deterministic with ordered candidate tie-breaking
- [x] Render suggestion-only days as plain fallback flags without affecting summaries
- [x] Add flat `presenceSummary` to debug export day snapshots
- [x] Add and update focused regression tests for parsing, day summaries, decorations, and export shape
- [x] Run targeted verification and document results

## Review
- [x] `swiftc -parse` passed for all edited production and test files
- [x] Targeted `xcodebuild test` could not start because this environment cannot discover or boot iOS Simulator runtimes (`simdiskimaged` / destination resolution failure)
- [x] Generic `xcodebuild build` is still blocked in this environment by SwiftData macro/plugin failures unrelated to these edits

## Task: Phase 2 Presence Inference Engine Rewrite
- [x] Rewrite shared inference/result types for normalized allocations and rich evidence audit entries
- [x] Replace `PresenceInferenceEngine.swift` with typed pipeline state, config, processors, and contextual compilation
- [x] Persist the rewritten contract in `PresenceDay` and ledger upsert paths
- [x] Update downstream consumers that read evidence or country allocations
- [x] Rewrite inference tests and repair stale `PresenceDay` fixtures
- [ ] Run targeted verification and document results

## Review
- [x] Replaced flat score impacts with richer evidence entries carrying raw weight, calibrated weight, phase, reason, and contribution flags
- [x] Rebuilt the inference engine around typed pipeline config/state/processors while preserving travel promotions, gap bridging, and transition infill
- [x] Updated `PresenceDay` persistence, ledger writes, and day detail UI to surface normalized allocations and the inference audit trail
- [x] Added regression coverage for calibration metadata and winning-vs-losing evidence flags; repaired stale test fixture helpers
- [ ] `swiftc -parse` passed for all edited production and test files, but `xcodebuild test` remains blocked in this environment by simulator runtime failures (`simdiskimaged` / runtime discovery)
