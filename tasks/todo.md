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
