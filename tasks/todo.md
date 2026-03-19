# Plan
- [x] Add the new `Calendar` main tab and update shared country summary UI helpers for reuse.
- [x] Implement calendar snapshot types and a background aggregation service over raw evidence.
- [x] Build the calendar month UI, day navigation, and country-days summary table.
- [x] Add unit tests for deduping, multi-country days, flight markers, stay expansion, range filtering, and month bounds.
- [x] Run targeted verification and record review notes.

# Review
- [x] `xcodebuild -scheme Learn -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/BorderLogDerivedData build` succeeds after the Calendar tab changes.
- [x] `xcodebuild build-for-testing -scheme Learn -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/BorderLogDerivedData -only-testing:LearnTests/CalendarTabDataServiceTests` succeeds, so the new test target compiles.
- [x] `xcodebuild test -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/BorderLogDerivedData -only-testing:LearnTests/CalendarTabDataServiceTests` could not be completed because `CoreSimulatorService` was unavailable in this environment.
- [x] Residual warnings remain in existing Swift 6 actor-isolation code paths, including the new `CalendarTabDataService` fetches against SwiftData models, but no new build errors remain.
