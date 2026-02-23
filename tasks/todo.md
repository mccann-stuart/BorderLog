- [x] Investigate missing CountryPolygonsData reference
- [x] Implement fix in CountryPolygonLoader target visibility
- [ ] Verify with Xcode diagnostics
- [ ] Document results in tasks/todo.md (review section)

## CloudKitDataResetService Generic Inference Fix
- [x] Inspect CloudKitDataResetService.swift and identify the generic inference issue
- [x] Propose fix and check in with user before implementation
- [x] Apply minimal code change to resolve the compiler error
- [x] Verify with Xcode diagnostics and document results in Review

## CloudKit Sync Toggle + Reset
- [x] Add CloudKit checklist and confirm approach with user
- [x] Update entitlements for app + widget, add AppGroupId to widget Info.plist
- [x] Add shared defaults + CloudKit config constants
- [x] Wire SwiftData ModelContainer to CloudKit when enabled
- [x] Add CloudKit data reset service
- [x] Update Settings UI with iCloud sync toggle + delete button
- [x] Disable CloudKit feature flag and remove CloudKit entitlements
- [ ] Verify build and manual scenarios (toggle on/off, delete)
- [ ] Document results in Review section

## Country Polygon Map Loading
- [x] Inspect map rendering flow and settings toggle behavior
- [x] Review CountryPolygonLoader/CountryPolygonsData for loading/parsing issues
- [x] Check in with user before implementing fix
- [x] Implement minimal fix so polygons load when toggled on
- [x] Verify behavior and document results in tasks/todo.md

## Review
- Verified `Learn/Shared/ModelContainerProvider.swift` with Xcode diagnostics (no issues).
- Verified with Xcode diagnostics for `Learn/Shared/CountryPolygonLoader.swift`.
- No missing-symbol error for `CountryPolygonsData` after move.
- Remaining warnings (pre-existing):
  - Main actor-isolated Decodable conformance used in nonisolated context (line 81).
  - Main actor-isolated static property referenced from Sendable closure (line 87).
- Verified `Shared/CountryPolygonsData.swift` base64 decodes + zlib decompresses correctly after replacement.
- Updated `WorldMapView` to observe `CountryPolygonLoader.shared`, so `isLoaded` triggers map refresh.
- CloudKit entitlements added for app + widget; AppGroupId added to widget Info.plist.
- Added shared defaults + CloudKit config constants; ModelContainer now uses CloudKit when enabled.
- Added CloudKit reset service and Settings UI toggle + delete action.
- CloudKit feature is disabled via flag; CloudKit entitlements removed pending provisioning.
- Build not run: `xcodebuild -version` fails because Xcode is not selected (CommandLineTools only).
- Verified with Xcode diagnostics for `Learn/Shared/CloudKitDataResetService.swift` after updating CloudKit completion handlers and continuation types.
- [x] Inspect `ModelContainerProvider` CloudKit configuration usage
- [x] Update CloudKit database handling to satisfy non-optional initializer
- [x] Verify diagnostics for `Learn/Shared/ModelContainerProvider.swift`
