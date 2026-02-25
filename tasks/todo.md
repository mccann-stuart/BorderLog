# TODO

- [x] Confirm how AppGroupId is provided (APP_GROUP_ID build setting or Info.plist value) for app + widget.
- [x] Add fallback AppGroupId resolution for shared store when Info.plist key is missing/empty.
- [x] Ensure widget and app read/write the same SwiftData store (App Group container).
- [x] Verify with Xcode diagnostics/build log and note results.
- [x] Add Settings > Data Sources indicator for the widget's last write timestamp.
- [x] Verify SettingsView diagnostics.

# Review

- [x] Updated AppGroupId fallback to always use `group.com.MCCANN.Border` when Info.plist value is missing/empty.
- [x] Xcode diagnostics: no issues in `Learn/Shared/ModelContainerProvider.swift`.
- [x] Added widget last write indicator in Settings/Data Sources, reading latest widget `LocationSample`.
- [x] Xcode diagnostics: no issues in `Learn/SettingsView.swift`.
