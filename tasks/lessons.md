# Self-Improvement Lessons

## SwiftData UI Freezing
- **Pattern**: Running heavy SwiftData synchronous fetches (`modelContext.fetch`) inside loops, combined with other tasks (geocoding) on the `@MainActor`.
- **Lesson**: Never run large datastore tasks on the main thread in Swift. Always use a background `ModelContext` (e.g. via `@ModelActor` or by initializing a new `ModelContext` on a background thread) for operations like batch ingestion or ledger recomputation.

## Xcode Duplicate Info.plist Output (Widget)
- **Pattern**: `Multiple commands produce .../BorderLogWidget.appex/Info.plist` on a clean build when the widget’s `Info.plist` is both the target’s Info.plist (`INFOPLIST_FILE`) and auto-added to build resources by a file-system–synchronized group.
- **Lesson**: Ensure the widget `Info.plist` is not included in Copy Bundle Resources. For file-system–synchronized groups, add a build-file exception for `Info.plist` (or remove it from target membership) so only the Info.plist processing phase produces it.

## CloudKit Entitlements Gating
- **Pattern**: Enabling CloudKit entitlements and UI without confirming the app’s entitlement set.
- **Lesson**: Gate CloudKit features behind a flag and enable entitlements only after provisioning is confirmed; keep the code ready but inactive by default.

## AGENTS.md Detection Miss
- **Pattern**: Reported that `AGENTS.md` did not exist when it actually did.
- **Lesson**: Always confirm `AGENTS.md` discovery from repo root using `rg --files -g 'AGENTS.md' .` and, if empty, double-check with `find . -name AGENTS.md` before stating it’s missing.

## Stay Editor Parity
- **Pattern**: New Stay UI did not auto-populate country fields like New Override.
- **Lesson**: When adding/editing Stay UI, default to `LocationFormSection` picker mode for new stays so Country, Country Code, and Region stay auto-populated and consistent with overrides.

## Unnecessary Plan Confirmation
- **Pattern**: Asked for explicit plan confirmation despite the user requesting to stop asking.
- **Lesson**: After writing a plan, proceed unless the user explicitly requests a pause; avoid extra confirmation prompts.

## Build Prompting
- **Pattern**: Asked whether to run builds after being told not to ask again.
- **Lesson**: Do not ask about running builds; only run if explicitly requested.

## Simulator Destination Selection
- **Pattern**: Used a simulator destination name that was not available in the current Xcode runtime list.
- **Lesson**: Before build/test runs, either target `Any iOS Simulator Device` or pick an explicit destination from `xcodebuild`’s reported available destinations (in this environment, `iPhone 17`), and avoid parallel build/test invocations that can lock the same build database.

## Native UI Quality Bar
- **Pattern**: Delivered a new tab with working data behavior but a visual design that did not meet the expected native iOS quality bar.
- **Lesson**: For new top-level SwiftUI surfaces, design the visual hierarchy intentionally from the start: prefer system materials, restrained gradients, strong spacing, native controls, and section/card structures that feel like first-party iOS instead of shipping a functional but rough layout and iterating only after user pushback.

## Responsive Calendar Grid
- **Pattern**: Styled a seven-column calendar with fixed-size day content, which caused the month grid to push outside the safe area on smaller screens.
- **Lesson**: For dense calendar layouts, size day cells from the available container width instead of assuming fixed dimensions; add safe-area-aware outer padding only after the internal grid is responsive.

## Calendar Row Insets
- **Pattern**: Removed all `List` row insets around a `UICalendarView`, which left the native calendar flush to the screen edge and visually outside the intended safe zone.
- **Lesson**: When embedding wide UIKit content inside a SwiftUI `List`, do not default to `.listRowInsets(EdgeInsets())`; preserve or reintroduce small horizontal row insets unless truly edge-to-edge behavior is required and verified on device widths.

## Respect No-Test Requests
- **Pattern**: Continued toward verification after the user explicitly asked for a code-only change without testing.
- **Lesson**: When the user says not to test or build, stop the verification step immediately, record that it was intentionally skipped, and close out with the untested status clearly stated.

## Calendar Header Coverage
- **Pattern**: Fixed the calendar body safe-area issue by changing only the row container and assumed the native `UICalendarView` header content would align automatically.
- **Lesson**: When adjusting margins for embedded UIKit calendars, verify the month header and weekday subtitle row separately; prefer a single inset applied to the calendar surface itself when both header and grid need to move together.

## UICalendarView Margin Assumption
- **Pattern**: Assumed `UICalendarView` would honor `layoutMargins`/`directionalLayoutMargins` for its native month header and chevrons, but the screenshot showed those elements still rendering flush to the edges.
- **Lesson**: For `UICalendarView`, prefer wrapping the calendar in a container view and constraining it with explicit horizontal insets when the whole control, including the native header, needs to move together.

## Unknown Bucket Coverage
- **Pattern**: Fixed country-count aggregation paths without also surfacing days whose `PresenceDay` exists but still resolves to no country, which hid part of the selected range from total-count views.
- **Lesson**: Whenever a range summary buckets days by country, treat unresolved days as a first-class `Unknown` bucket with the same selection scope and drill-down behavior as the named-country rows.

## MapKit Country Extraction
- **Pattern**: Treated MapKit region fields as country identity and, in calendar search results, discarded matches unless a country code already existed, which caused usable name-only country matches to fall through to `Unknown`.
- **Lesson**: For MapKit-backed country inference, prefer placemark `countryCode`/`country` first and normalize name-only matches instead of requiring a code before persisting the signal.
