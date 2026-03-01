# Task Plan

- [x] Identify the exact Sendable warning site in CountryPolygonLoader and decide on the safest fix
- [x] Apply the minimal code change to remove the main-actor isolated static access from the background closure
- [x] Verify with Xcode diagnostics and document results below

## Review

- Moved the alpha3->alpha2 mapping to a file-scope constant and marked GeoJSON model structs as nonisolated to keep decoding on a background queue.
- XcodeRefreshCodeIssuesInFile: no issues in Learn/Shared/CountryPolygonLoader.swift.

---

# Task Plan (Schengen Dashboard Visibility Toggle)

- [x] Add a persisted `@AppStorage` key in `SettingsView.swift` and replace static Schengen configuration row with a toggle.
- [x] Add the same `@AppStorage` key in `DashboardView.swift` and gate `SchengenSummarySection` rendering.
- [ ] Verify compilation/tests for the Learn scheme and document evidence.
- [ ] Record completed review notes for behavior, persistence, and regression scope.

## Review (Schengen Dashboard Visibility Toggle)

- Pending implementation.
