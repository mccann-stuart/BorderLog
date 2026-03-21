# Task: Warning Cleanup (Swift 6 / iOS 26)

## Plan
- [x] Inspect the reported warning groups and confirm the smallest safe fixes
- [x] Remove redundant `await` usage and pure helper isolation warnings
- [x] Replace deprecated `MKMapItem.placemark` reads with supported iOS 26 address APIs
- [x] Resolve the remaining SwiftData actor-isolation warnings without refactoring behavior
- [ ] Run a targeted build and capture the verification result

## Review
- [x] Added narrow `nonisolated` annotations for pure helper/value code that should not inherit actor isolation
- [x] Replaced `MKMapItem.placemark` country extraction with iOS 26 `addressRepresentations`/`location` usage in calendar and geocode flows
- [x] Removed redundant `await` sites called out by the build log
- [x] `swiftc -parse` passed for all edited files
- [ ] `xcodebuild build` is still blocked in this environment by the pre-existing SwiftData macro/plugin failure in `Shared/PresenceDay.swift`

# Task: Fix CountryResolver region code compile error

## Plan
- [x] Inspect the failing line and confirm the current MapKit address API
- [x] Replace invalid region code access with a supported region identifier
- [x] Verify diagnostics for the updated file

## Review
- [x] Updated country code extraction to use `addressRepresentations?.region?.identifier`
- [x] Xcode diagnostics report no issues in `Learn/Shared/CountryResolver.swift`

# Task: Fix CalendarSignalIngestor region code compile error

## Plan
- [x] Inspect the failing `MKAddressRepresentations` access in the calendar search path
- [x] Replace invalid region code access with a supported locale region identifier
- [x] Verify diagnostics for `Learn/Shared/CalendarSignalIngestor.swift`
- [x] Run an Xcode build to confirm no new compile errors

## Review
- [x] Updated calendar search country code extraction to use `addressRepresentations?.region?.identifier`
- [x] Xcode diagnostics report no issues in `Learn/Shared/CalendarSignalIngestor.swift`
- [x] Xcode build succeeded

# Task: Fix CalendarFlightParsing Equatable isolation warning

## Plan
- [x] Inspect `CalendarEventIngestability` computed properties using `==`/`!=`
- [x] Replace comparisons with `switch` to avoid isolated Equatable usage in nonisolated context
- [x] Verify diagnostics for `Shared/CalendarFlightParsing.swift`

## Review
- [x] Replaced `==`/`!=` comparisons with `switch` to avoid isolated Equatable usage
- [x] Xcode diagnostics report no issues in `Shared/CalendarFlightParsing.swift`
