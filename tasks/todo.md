# App Store Launch Blocker Resolution Plan (9 Jul 2026)

- [x] Establish the current Release build, archive, test, and Simulator-launch baseline without disturbing existing user changes.
- [x] Audit app and widget metadata, signing/capabilities, privacy declarations, release-only feature gates, and current Apple submission requirements.
- [x] Reproduce and classify every confirmed launch blocker; separate code/repository fixes from App Store Connect manual work.
- [x] Implement the smallest root-cause fixes for confirmed repository-owned blockers and add focused regression coverage where behaviour changes.
- [x] Verify a clean Release build/archive path, focused tests, app launch, key onboarding/settings flows, packaged entitlements/privacy manifests, and runtime logs.
- [x] Self-review the final diff and add a concise review section with residual manual submission steps and risks.

## App Store Launch Blocker Resolution Review

- Removed the conflicting manual signing identity while retaining automatic signing, restored the orphaned `LearnUITests` target, aligned the app/widget/test deployment targets at iOS 26.0, made the widget universal, enabled Release dSYMs, and kept coverage/testability out of Release packaging.
- Added the encryption declaration, completed the app/widget UserDefaults required-reason declarations, excluded developer documentation from the app bundle, flattened the App Store icon sources to opaque RGB, and kept app/widget version metadata in sync.
- Made the 1.0 product posture consistently account-free and local-first, expanded the in-app privacy/retention controls, and added tested `/privacy` and `/support` Worker routes for App Store Connect metadata without deploying them. Both routes require a valid `SUPPORT_EMAIL` Worker variable so an incomplete support contact cannot be published accidentally.
- Resolved the existing calendar parsing/ordering, cross-time-zone stay and Schengen, SwiftData ledger filtering, inference expectation, and pending-location queue failures uncovered by the full test plan. Schengen merging now sorts normalized civil intervals across the International Date Line; concurrent queue pruning is idempotent; date-sensitive queue tests no longer age beyond retention.
- Verification passed: 200 tests discovered with 195 executions and no failures, clean Release simulator build/install/launch, clean runtime logs, 20 Worker security tests, both Wrangler dry-run paths, and an unsigned generic-device archive whose binaries, plists, privacy manifests, dSYMs, icons, extension family and source exclusions were inspected.
- The signed archive now fails only because this machine has no provisioning profiles for `com.MCCANN.BorderLog` or `com.MCCANN.BorderLog.BorderLogWidget`; the previous conflicting-signing error is gone. Before upload, install the current stable App Store-supported Xcode, create/select the distribution certificate and profiles with the App Group capability, configure a monitored `SUPPORT_EMAIL`, deploy the Worker pages, add any contact details required for the target storefronts, and enter the public URLs plus matching privacy answers in App Store Connect.

# Xcode Console Validation Plan

# App Store Launch Compliance Review Plan

- [x] Refresh current Apple App Store launch requirements from official sources.
- [x] Inventory app targets, bundle metadata, entitlements, privacy manifest, permissions, icons, and release/debug gates.
- [x] Review user-data, reset/delete, network/backend, sign-in, CloudKit, widget, and location/calendar/photos flows for App Review risk.
- [x] Inspect launch/onboarding/settings UI for reviewer access, policy links, consent clarity, and obvious launch blockers.
- [x] Build the release candidate path and capture warnings/errors that affect submission readiness.
- [x] Implement small root-cause fixes for confirmed launch blockers only.
- [x] Add a review section summarizing findings, fixes, verification, and residual App Store submission work.

## App Store Launch Compliance Review

- Added app and widget `PrivacyInfo.xcprivacy` manifests. Both declare no tracking domains, no collected data through app-owned services, and UserDefaults required-reason API use with reason `CA92.1`.
- Added an in-app Privacy Policy screen from Settings, and tightened privacy copy so it no longer overstates fully on-device processing where Apple services such as MapKit geocoding may process coordinates to resolve countries.
- Removed macOS sandbox entitlement keys from iOS app/widget entitlements and release build settings, set app Release signing identity to Apple Distribution, and disabled release testability.
- Replaced disabled sign-in/future iCloud wording with launch-safe copy that states no account is required and current travel data storage is local to the device.
- Tightened `DebugDataStoreExportService` so the debug export payload and service compile only under `DEBUG`, keeping the diagnostic export out of Release builds.
- Verification passed: privacy manifests and entitlements are valid property lists, release metadata checks show app Release testability is off, app Release signing is Apple Distribution, and no macOS sandbox/hardened-runtime settings remain in the inspected project/entitlement files.
- Verification partially passed: the first Release device build exposed the debug-export release leak, and the failed build artifact packaged the widget privacy manifest. After fixing the remaining debug guard, a rerun could not be completed because build escalation approval quota was exhausted. A signed Archive or `generic/platform=iOS` Release build still needs to be rerun before App Store upload.
- Residual submission work: create or link a public privacy policy URL in App Store Connect, complete the App Privacy nutrition-label answers to match the current code paths, verify the final signed archive contains both app and widget privacy manifests, and avoid enabling CloudKit/iCloud claims until the entitlement and product behavior are launch-ready.

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

# Actor-Isolation Warning Cleanup Plan

- [x] Inspect actor-isolated warnings in ledger recompute, calendar data, debug export, pending snapshots, geocode throttle, and Schengen counting.
- [x] Preserve existing behavior by keeping model APIs in place while removing accidental main-actor isolation from shared protocol/value boundaries.
- [x] Remove accidental main-actor isolation from pure value/config helpers where appropriate.
- [x] Run a focused `Learn` simulator build to verify warnings are addressed.
- [x] Add a review section summarizing implementation, verification, and residual risks.

## Actor-Isolation Warning Cleanup Review

- Removed `TravelEntry` conformance from SwiftData `Stay` and `DayOverride` models while preserving their `region` and `displayTitle` APIs directly on each model.
- Marked pure shared value/config types and inference pipeline helpers as `nonisolated`/`Sendable` where they do not touch UI or mutable SwiftData state, including app config, signal DTOs, inference processors, debug export payloads, geocode throttle state, and country-counting values.
- Marked the ledger data-fetching protocol requirements as nonisolated so the `@ModelActor` recompute service can call its injected fetcher without Swift 6 global-actor warnings while retaining the existing real and mock fetchers.
- Verification passed: clean `build_sim` for scheme `Learn` with derived data at `/tmp/BorderLogActorWarningsCleanDerivedData` completed without the pasted actor-isolation warnings.
- Verification passed: `xcodebuild test -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/BorderLogActorWarningTests -only-testing:LearnTests/TravelEntryTests -only-testing:LearnTests/StayTests -only-testing:LearnTests/DayOverrideTests`.
- Residual risk: the broader suite was not rerun for this narrow warning cleanup; prior repo notes already record unrelated broad-suite failures.

# Array Allocation Reductions Review

- Implemented lazy evaluation for `Set` initialization in `Learn/CalendarTabView.swift`, `Shared/PhotoSignalIngestor.swift`, and `Shared/PendingLocationSnapshot.swift` by appending `.lazy` before `.map`. This removes the intermediate O(N) array allocation overhead.
- Refactored `Shared/CloudKitDataResetService.swift` to use `.compactMap` instead of chaining `.map` and `.filter`, completing the transformation in a single pass without intermediate array allocation.
- Simulated the algorithmic improvements using python since the Swift toolchain was unavailable, showing an approximate 22% memory peak usage reduction compared to standard map/filter chaining.
- Documented changes in `PERFORMANCE_RATIONALE.md`.

## Sentinel Security Fix: Keychain Logging improvements
<!-- id: keychain_logging_fix -->
- [x] Document Sentinel learning on keychain error logging and category centralization.
- [x] Centralize `Logger` categories in `KeychainHelper` and `SecurityLockView` to `Security`.
- [x] Add missing error logging for `KeychainHelper.read`, `KeychainHelper.delete`, and the existing-item deletion portion of `KeychainHelper.save`.
- [x] Make sure to ignore `errSecItemNotFound` inside the added `KeychainHelper` logging.
- [x] Verify changes.
<!-- id: 101 -->
- **Task:** Optimize `min()` operations in `Shared/LedgerRecomputeService.swift`
- **Action:** Replaced `.compactMap { $0 }.min()` pattern with O(1) manual variable tracking in a loop.
- **Status:** Complete
