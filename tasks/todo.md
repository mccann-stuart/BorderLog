# Calendar source selection

- [x] Add a testable persisted calendar-source selection model and resolution logic.
- [x] Filter EventKit ingestion by the effective selection and support retryable full rebuilds.
- [x] Add the Calendar Sources settings screen and immediate Apply workflow.
- [x] Update product, privacy, and app-target documentation.
- [x] Add targeted unit coverage for persistence, resolution, and rebuild behaviour.
- [x] Run targeted tests, full tests, simulator build, and diff review.

## Review

- Added an AppConfig-backed all/custom calendar preference with safe identifier remapping, unavailable-reference retention, and an explicit pending-rebuild marker.
- Added a full-access-only Calendar Sources screen with account grouping, colour indicators, duplicate-title labels, Select All, Deselect All, draft changes, and explicit Apply.
- Applying serialises a two-year calendar-only evidence rebuild through `LedgerRefreshCoordinator`; incomplete work remains marked for launch-time retry.
- Targeted calendar tests passed: 20 tests, 0 failures. Host-side preference checks also passed.
- The complete simulator test bundle built successfully. The full run passed 235 of 237 unit tests and all 4 UI tests; two `LedgerRecomputeServiceTests` disputed-country tests still fail with four assertions in code outside the calendar-selection change set.
- `git diff --check` passed and the final diff was reviewed for scope.

# Xcode run diagnostics validation

- [x] Run the focused airport-resource and model-container recovery tests using isolated Derived Data.
- [x] Build the app for a generic iOS Simulator without changing project or scheme settings.
- [x] Inspect the signed device app and widget entitlements for the shared App Group.
- [x] Clear and filter the live Xcode console, then verify launch, App Group storage, and Dashboard map behaviour on Stu iP.
- [x] Review the final diff and confirm the existing Xcode 27 project and scheme changes were preserved.

## Review

- Focused `AirportCodeResolverTests` and `ModelContainerProviderRecoveryTests` passed: 8 tests, 0 failures, on the iPhone 17 iOS 27.0 simulator with isolated Derived Data.
- The generic iOS Simulator build succeeded with `CODE_SIGNING_ALLOWED=NO`; no project or scheme settings were changed for diagnostic suppression.
- The 17:53 device artefacts passed strict code-signature verification. Both `Learn.app` and `BorderLogWidget.appex` contain `group.com.MCCANN.Border`, and neither the file nor string `default.csv` exists in the app bundle.
- Device Hub showed BorderLog running on Stu iP with persisted travel data and a fully rendered, responsive Dashboard map.
- Filtering the corresponding Xcode run to `subsystem:com.MCCANN.Border` left only `Using App Group store at group: group.com.MCCANN.Border`; no BorderLog-owned warning or error remained.
- The Apple framework diagnostics were left unsuppressed in the raw console, and the pre-existing Xcode 27 project/scheme updates were preserved.
