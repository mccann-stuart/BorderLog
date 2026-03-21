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