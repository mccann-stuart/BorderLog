# Xcode Console Validation Plan

- [x] Classify each pasted console line as app-owned, configuration-owned, or framework/simulator noise.
- [x] Verify App Group, location, MapKit, and resource references against code, project settings, and built artifacts.
- [x] Implement root-cause fixes only for confirmed app-owned issues.
- [x] Run targeted Xcode verification.
- [x] Add a review section summarizing findings, verification, and residual risks.

## Xcode Console Validation Review

- The App Group storage path is configured and build-verified: Debug simulator packaging generated simulated App Group entitlements for `com.MCCANN.BorderLog` and `com.MCCANN.BorderLog.BorderLogWidget`, and `ModelContainerProvider.makeContainer()` opens the App Group SwiftData store. The `CFPrefsPlistSource` line is therefore treated as a CoreFoundation/App Group preferences warning, not a failing project entitlement.
- `Failed to locate resource named "default.csv"` is not from first-party code: the repo has no `default.csv` resource or bundle lookup, and airport CSV data is generated into `Shared/Resources/AirportCodesData.swift`. Treat this as framework/runtime noise unless a missing user-facing dataset appears.
- The widget location configuration is present: `BorderLogWidget/Info.plist` contains `NSWidgetWantsLocation = true`, the app target includes `NSLocationWhenInUseUsageDescription`, and `LocationSampleService` gates widget captures through `isAuthorizedForWidgetUpdates`. The `com.apple.locationd.effective_bundle` line points at a private Core Location check, not an entitlement this app can add directly.
- The `CAMetalLayer`, `PerfPowerTelemetryClientRegistrationService`, `PPSClientDonation`, Maps `SpringfieldUsage`, and `XPC connection was invalidated` lines are MapKit/simulator framework noise based on the code paths inspected. `WorldMapView` already avoids constructing its SwiftUI `Map` when the local geometry is zero-sized, so there is no confirmed app-owned zero-size Metal layer fix.
- No product code was changed because no pasted line mapped to a confirmed app-owned defect. Only this validation record was added.
- Verification: `xcodebuild build -project Learn.xcodeproj -scheme Learn -configuration Debug -destination 'generic/platform=iOS Simulator'` succeeded. Runtime launch/log replay was blocked because `xcrun simctl list devices available` could not connect to `CoreSimulatorService` in this sandbox.

# Full Codebase Review Plan

- [x] Review project instructions and prior lessons.
- [x] Inventory markdown files and identify stale or missing project documentation.
- [x] Review SwiftData, privacy, authentication, import/export, and CloudKit-adjacent paths for obvious red-team issues.
- [x] Review SwiftUI screens for obvious UI correctness issues, especially safe-area, empty/error states, navigation, and destructive actions.
- [x] Implement small, root-cause fixes for confirmed issues only.
- [x] Update project markdown files with current status, usage, risk notes, and this review's findings.
- [ ] Run targeted build/tests or static checks that prove the changes.
- [ ] Add a review section here summarizing what changed, what was verified, and any residual risks.

# Double Count Days Mode Plan

- [x] Add a shared persisted day-counting mode and helpers for resolved-country vs double-count behavior.
- [x] Wire the setting into Settings and app/widget counting surfaces.
- [x] Update Schengen, dashboard, calendar, country detail, and widget counters to use the selected mode.
- [x] Add targeted unit tests for country summaries and Schengen counting.
- [x] Run an iOS simulator build.
- [ ] Complete a clean targeted simulator test run after CoreSimulatorService recovers.
- [x] Add a review section summarizing implementation, verification, and residual risks.

## Double Count Days Mode Review

- Implemented shared `CountryDayCountingMode` app-group storage plus `PresenceDay` counting helpers that keep manual overrides collapsed, use one resolved country in default mode, use all resolved allocations in Double Count Days mode, and ignore unresolved suggestions.
- Applied the setting across dashboard country totals/map, calendar summaries/decorations, country detail lists, presence-day rows, top-country widgets, and app/widget Schengen summaries. Schengen counts a day once when any counted allocation is Schengen.
- Added targeted unit tests for primary-only vs double-count country summaries and for secondary/multiple-Schengen allocation behavior.
- Verified `xcodebuild build -scheme Learn -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/BorderLogDoubleCountDerivedData` succeeds.
- Targeted simulator tests were attempted for `SchengenLedgerCalculatorTests` and `CalendarTabDataServiceTests`. The initial run compiled and executed the new double-count tests, but did not finish cleanly because one existing calendar test hit a simulator launch/product lookup failure. A fresh rerun with `/tmp/BorderLogDoubleCountTests` was blocked before test execution because CoreSimulatorService could not discover simulator runtimes after `simdiskimaged` stopped responding.

# Debug Export Remediation Plan

- [x] Replace the pending widget location queue with a file-backed app-group queue that dedupes deterministic snapshot IDs and deletes only after a successful ingest save.
- [x] Restrict widget-triggered location capture to the current-location widget so read-only widgets stop creating extra snapshots.
- [x] Add a shared ledger refresh coordinator and route launch, scene activation, manual scans, pending-widget ingest, and debug export consistency through it.
- [x] Update photo ingest checkpoint semantics so the creation-date checkpoint reflects the max scanned asset date.
- [x] Add debug export diagnostics for snapshot consistency, inferred-day derivation, evidence phase counts, and weak location samples.
- [x] Add focused unit tests for pending queue behavior, failed ingest retry safety, photo checkpoint semantics, and debug export diagnostics.
- [x] Run targeted tests and the requested simulator suite.
- [x] Add a review section summarizing the changes, verification, and residual risks.

## Debug Export Remediation Review

- Implemented or verified the file-backed pending-location queue, retry-safe pending ingest, current-location-only widget capture, serialized refresh coordination, max-scanned photo checkpoint semantics, and debug export metadata for snapshot consistency, inferred-day derivation, evidence phase counts, weak location samples, and full-fidelity privacy warning.
- Added focused coverage for concurrent pending snapshot enqueue dedupe, pending snapshot retry safety, burst-capture concurrency, photo checkpoint advancement for duplicate/non-geotagged/sequenced scans, and debug export derivation/accuracy diagnostics.
- Verification passed: `xcodebuild test -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/BorderLogDebugRemediationTests -only-testing:LearnTests/PendingLocationSnapshotTests -only-testing:LearnTests/DebugDataStoreExportServiceTests -only-testing:LearnTests/PhotoSignalIngestorCoreTests -only-testing:LearnTests/LocationConcurrencyTests`.
- Verification failed outside the focused remediation slice: the full `xcodebuild test -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/BorderLogDebugRemediationFullTests` run executed 179 tests with 13 failures in existing calendar ordering/parsing, Schengen window, stay duration, inference, ledger recompute, and real fetcher boundary tests. The remediation-focused tests passed inside the full run.
- Build iOS Apps plugin verification passed: `build_sim` succeeded for scheme `Learn`, the app installed on iPhone 17, launched with bundle id `com.MCCANN.BorderLog`, and `snapshot_ui` showed the BorderLog onboarding screen.
- Residual risk: the build still emits existing Swift 6 actor-isolation warnings across shared SwiftData/model actor code; those warnings are not introduced by this remediation but should be retired before enabling Swift 6 language mode.

# Basics And Race-Condition Hardening Plan

- [ ] Fix the `LearnTests` compile blocker in `InferenceEngineTests`.
- [ ] Refactor location capture continuation state so concurrent burst captures cannot replace each other.
- [ ] Add deterministic location capture coordinator race tests.
- [ ] Triage focused actor-isolation warnings for pure helper/value types touched by this work.
- [ ] Run the planned generic simulator build and focused simulator tests.
- [ ] Run a broader `LearnTests` pass if focused tests pass, and separate unrelated failures.
- [ ] Add a review section summarizing implementation, verification, and residual risks.
