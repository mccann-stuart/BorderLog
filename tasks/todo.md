# Full Codebase Review Plan

- [x] Review project instructions and prior lessons.
- [x] Inventory markdown files and identify stale or missing project documentation.
- [x] Review SwiftData, privacy, authentication, import/export, and CloudKit-adjacent paths for obvious red-team issues.
- [x] Review SwiftUI screens for obvious UI correctness issues, especially safe-area, empty/error states, navigation, and destructive actions.
- [x] Implement small, root-cause fixes for confirmed issues only.
- [x] Update project markdown files with current status, usage, risk notes, and this review's findings.
- [ ] Run targeted build/tests or static checks that prove the changes.
- [ ] Add a review section here summarizing what changed, what was verified, and any residual risks.

# Double Count Days Mode Plan

- [x] Add a shared persisted day-counting mode and helpers for resolved-country vs double-count behavior.
- [x] Wire the setting into Settings and app/widget counting surfaces.
- [x] Update Schengen, dashboard, calendar, country detail, and widget counters to use the selected mode.
- [x] Add targeted unit tests for country summaries and Schengen counting.
- [ ] Run targeted tests and an iOS simulator build.
- [ ] Add a review section summarizing implementation, verification, and residual risks.
