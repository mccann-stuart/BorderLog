- [x] Investigate missing CountryPolygonsData reference
- [x] Implement fix in CountryPolygonLoader target visibility
- [ ] Verify with Xcode diagnostics
- [ ] Document results in tasks/todo.md (review section)

## Country Polygon Map Loading
- [x] Inspect map rendering flow and settings toggle behavior
- [x] Review CountryPolygonLoader/CountryPolygonsData for loading/parsing issues
- [x] Check in with user before implementing fix
- [x] Implement minimal fix so polygons load when toggled on
- [x] Verify behavior and document results in tasks/todo.md

## Review
- Verified with Xcode diagnostics for `Learn/Shared/CountryPolygonLoader.swift`.
- No missing-symbol error for `CountryPolygonsData` after move.
- Remaining warnings (pre-existing):
  - Main actor-isolated Decodable conformance used in nonisolated context (line 81).
  - Main actor-isolated static property referenced from Sendable closure (line 87).
- Verified `Shared/CountryPolygonsData.swift` base64 decodes + zlib decompresses correctly after replacement.
- Updated `WorldMapView` to observe `CountryPolygonLoader.shared`, so `isLoaded` triggers map refresh.
