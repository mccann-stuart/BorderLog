# TODO

- [x] Plan: Locate shared UI components/modifiers for top banners, chips, and loading status.
- [x] Search `Learn/` and `Shared/` for existing reusable banner/chip/loading views and modifiers.
- [x] Identify best integration point for a reusable refresh banner view.
- [x] Summarize concise file references and rationale.

- [x] Plan: Add shared refresh-in-progress UI indicator across existing pages.
- [x] Define shared "data refresh in progress" state API on `InferenceActivity`.
- [x] Implement reusable top banner component for refresh progress status.
- [x] Attach banner to main navigation so Dashboard, Details, and Settings show refresh state.
- [x] Validate build compiles for modified SwiftUI files.

- [x] Plan: Add "Two Years Prior" visited countries timeframe (calendar year two years ago).
- [x] Update VisitedCountriesTimeframe enum + contains logic.
- [ ] Verify UI picker shows "Two Years Prior" (Dashboard + Country Detail).
- [x] Run Learn tests for "Two Years Prior" timeframe change.

- [ ] Plan: Scan repo for VisitedCountriesTimeframe or visited countries filter logic beyond DashboardView.swift and Shared/VisitedCountriesTimeframe.swift.
- [ ] Search codebase for VisitedCountriesTimeframe/visited countries filter references.
- [ ] Review any matches outside the two specified files and capture implications.
- [ ] Report findings.

- [x] Plan: Treat stay-backed days as manual + editable from Day Details.
- [x] Add PresenceDay.isManuallyModified and update manual/disputed filters.
- [x] Add Stay badge for stay-backed days in ledger rows.
- [x] Make stays in Day Details tappable to edit.
- [ ] Run Learn tests for stay-manual/Day Details changes.

- [x] Plan: Fix CFPreferences App Group warning by gating App Group defaults on container availability.
- [x] Add App Group availability check and use it for shared defaults + SwiftData group container.
- [x] Update GeocodeThrottleStore to avoid suite defaults when App Group container is unavailable.
- [x] Build Learn scheme (generic iOS) and capture diagnostics.

- [x] Plan: Match New Stay UI to New Override auto-populated location fields.
- [x] Update StayEditorView location section to use picker + suggestions for new stays.
- [x] Run Learn tests for New Stay UI change (failed: DataManagerTests.testResetAllDataRemovesData()).

- [x] Plan: Reintroduce Stays UI (Details +, Day Details Add Stay, recompute on stay changes).
- [x] Update Details + to open Stay editor and add Stay-driven recompute.
- [x] Add Day Details "Add Stay" action with prefilled multi-day editor.
- [x] Extend StayEditorView presets for entry/exit/country and force exit.
- [ ] Run tests for Learn scheme (iPhone 15 simulator).

- [x] Add data store status row in Settings (Data Sources).
- [x] Derive data store label/color from ModelContainer configurations.
- [x] Validate build compiles (SettingsView).

- [x] Confirm how AppGroupId is provided (APP_GROUP_ID build setting or Info.plist value) for app + widget.
- [x] Add fallback AppGroupId resolution for shared store when Info.plist key is missing/empty.
- [x] Ensure widget and app read/write the same SwiftData store (App Group container).
- [x] Verify with Xcode diagnostics/build log and note results.
- [x] Add Settings > Data Sources indicator for the widget's last write timestamp.
- [x] Verify SettingsView diagnostics.

# Review

- [ ] Pending: "Two Years Prior" UI verification (Dashboard + Country Detail).
- [ ] Pending: "Two Years Prior" tests (`xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 15' test`).
- [ ] Tests failed: missing iPhone 15 simulator for "Two Years Prior" tests.
- [ ] Tests failed: `DataManagerTests.testResetAllDataRemovesData()` on iPhone 17 simulator.

- [ ] Pending: CFPreferences App Group warning fix verification (runtime log check).
- [x] Build: `xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'generic/platform=iOS' build`.

- [ ] Pending: New Stay UI auto-populate verification.
- [ ] Tests failed: `DataManagerTests.testResetAllDataRemovesData()` (xcodebuild iPhone 17 simulator).

- [ ] Pending: Stays UI reintroduction + stay recompute verification.

- [x] Data store status row added with configuration-based label + color.
- [x] Xcode build: `xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'generic/platform=iOS' build`.

- [x] Updated AppGroupId fallback to always use `group.com.MCCANN.Border` when Info.plist value is missing/empty.
- [x] Xcode diagnostics: no issues in `Learn/Shared/ModelContainerProvider.swift`.
- [x] Added widget last write indicator in Settings/Data Sources, reading latest widget `LocationSample`.
- [x] Xcode diagnostics: no issues in `Learn/SettingsView.swift`.
- [x] Repo scan complete for banner/chip/loading reuse points; refresh status banner is implemented and hosted from `MainNavigationView.swift`.
- [x] Build: `xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'generic/platform=iOS' build` after refresh-banner integration.
