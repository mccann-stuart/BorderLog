# Plan
- [x] Redesign the `Calendar` tab with a more native SwiftUI presentation that matches the requested iOS look and feel.
- [x] Refresh the month header, calendar grid, day cells, and country summary section without changing data behavior.
- [x] Build the app after the redesign and record the updated review notes.

# Review
- [x] `xcodebuild -scheme Learn -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/BorderLogDerivedData build` succeeds after the Calendar redesign.
- [x] The redesign changes presentation only; the existing calendar data service and tests were left intact.
