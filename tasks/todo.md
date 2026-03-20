# Task Plan: Fix Git Sync

- [ ] Sync local main branch with remote origin/main.

---

# Task Plan (Calendar Header Safe Area Margins)

- Spec: keep the native `UICalendarView` and the existing 12pt calendar margin.
- Spec: extend that same horizontal inset to the calendar header content, including the native month title and weekday subtitle row.
- Spec: prefer the smallest layout change that affects the whole embedded calendar surface rather than adding separate ad hoc offsets.
- [ ] Update the Calendar tab layout so the native calendar header and body share the same horizontal inset.
- [ ] Run an app build and record the verification result.

## Review (Calendar Header Safe Area Margins)

- In progress.

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

# Task Plan (Calendar Header Safe Area Margins)

- Spec: keep the native `UICalendarView` and current Calendar tab structure intact.
- Spec: apply the same small horizontal margin to the calendar’s month header and weekday subtitle row as the main calendar body.
- Spec: keep the change limited to layout; do not alter selection, navigation, or summary behavior.
- [x] Inspect the Calendar tab layout and identify which header elements still need the inset.
- [x] Adjust the calendar header/title layout so it shares the same horizontal safe-area margin.
- [x] Stop before running builds/tests because the user explicitly requested a code-only change.

## Review (Calendar Header Safe Area Margins)

- Fix applied: set `UICalendarView` `layoutMargins` and `directionalLayoutMargins` to a 12-point horizontal inset in `makeUIView`, so `March 2026`, the chevrons, and the weekday subtitle row share the same safe-area spacing as the calendar body.
- Verification: not run, per user instruction to avoid testing.

---

# Rebuild Calendar Tab

- [x] Create PR branch (`feature/rebuild-calendar-tab`).
- [x] Investigate existing `CalendarTabView.swift` and related components.
- [x] Write detailed specs in `implementation_plan.md`.
- [x] Get user approval for the plan.
- [x] Rebuild the Calendar tab using native iOS 26 styling.
- [x] Verify the new UI and functionality.
- [x] Wrap up and mark done.
