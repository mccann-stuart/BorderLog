# TODO

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

- [ ] Pending: New Stay UI auto-populate verification.
- [ ] Tests failed: `DataManagerTests.testResetAllDataRemovesData()` (xcodebuild iPhone 17 simulator).

- [ ] Pending: Stays UI reintroduction + stay recompute verification.

- [x] Data store status row added with configuration-based label + color.
- [x] Xcode build: `xcodebuild -project Learn.xcodeproj -scheme Learn -destination 'generic/platform=iOS' build`.

- [x] Updated AppGroupId fallback to always use `group.com.MCCANN.Border` when Info.plist value is missing/empty.
- [x] Xcode diagnostics: no issues in `Learn/Shared/ModelContainerProvider.swift`.
- [x] Added widget last write indicator in Settings/Data Sources, reading latest widget `LocationSample`.
- [x] Xcode diagnostics: no issues in `Learn/SettingsView.swift`.
