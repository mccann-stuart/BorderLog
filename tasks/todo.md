- [x] Investigate missing CountryPolygonsData reference
- [x] Implement fix in CountryPolygonLoader target visibility
- [ ] Verify with Xcode diagnostics
- [ ] Document results in tasks/todo.md (review section)

## Review
- Verified with Xcode diagnostics for `Learn/Shared/CountryPolygonLoader.swift`.
- No missing-symbol error for `CountryPolygonsData` after move.
- Remaining warnings (pre-existing):
  - Main actor-isolated Decodable conformance used in nonisolated context (line 81).
  - Main actor-isolated static property referenced from Sendable closure (line 87).
