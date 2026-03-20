# Task Plan: Fix Git Sync

- [ ] Sync local main branch with remote origin/main.

---

# Task Plan (Calendar Safe Area Margins)

- [x] Review `Learn/CalendarTabView.swift` and identify the layout cause of the calendar overflowing the safe area.
- [x] Add small safe-area-aware horizontal margins to keep the Calendar content on screen.
- [x] Run an app build and record the verification result.

## Review (Calendar Safe Area Margins)

- Cause identified: the calendar row removes all list insets with `.listRowInsets(EdgeInsets())`, which leaves the `UICalendarView` flush to the screen edge.
- Fix applied: changed the calendar row to `EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)` so the native calendar stays slightly inset from the screen edges.
- Verification: `xcodebuild -scheme Learn -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/BorderLogDerivedData build` completed successfully on March 20, 2026 with `** BUILD SUCCEEDED **`.

---

# Rebuild Calendar Tab

- [x] Create PR branch (`feature/rebuild-calendar-tab`).
- [x] Investigate existing `CalendarTabView.swift` and related components.
- [x] Write detailed specs in `implementation_plan.md`.
- [x] Get user approval for the plan.
- [x] Rebuild the Calendar tab using native iOS 26 styling.
- [x] Verify the new UI and functionality.
- [x] Wrap up and mark done.
