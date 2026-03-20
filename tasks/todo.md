# Task Plan (Adjacent Flight Event Evidence)

- Spec: when a day is inferred from a flight on the immediately next or previous day, the inferred day should still show that flight in the Calendar Events evidence section instead of appearing to have no calendar evidence.
- Spec: preserve the current destination-day and origin-day inference rules without duplicating unrelated calendar events onto adjacent days.
- Spec: fix the data flow so the linked flight evidence survives recompute and appears consistently in day details and any other evidence-driven surfaces.
- [x] Inspect the calendar-signal, inference, and day-detail evidence paths to find where adjacent inferred days lose their source flight event.
- [x] Patch the model/view pipeline so adjacent inferred flight days carry a linked calendar event reference.
- [x] Add focused regression coverage and record verification results or blockers.

## Review (Adjacent Flight Event Evidence)

- Root cause: `PresenceDayDetailView` fetched calendar evidence strictly by the selected day’s `dayKey`, but adjacent inferred flight days do not have a same-day `CalendarSignal`; their evidence lives on the neighboring flight day, so the detail screen showed `No calendar evidence` even when the day itself was calendar-derived.
- Fix applied: added `CalendarEvidenceResolver` to load same-day calendar signals first, then fall back to adjacent-day flight evidence only when the selected day is calendar-derived and lacks same-day signals; it prefers `CalendarFlightOrigin` signals and falls back narrowly to adjacent regular calendar signals that match the inferred country.
- UI behavior change: day details now show the adjacent flight event that caused the inference instead of an empty calendar evidence section for those inferred previous/next days.
- Regression coverage: added `CalendarEvidenceResolverTests` for adjacent origin-signal recovery, unknown-day fallback, same-day precedence, and bounded fallback to adjacent regular calendar signals.
- Verification: `git diff --check -- Learn/PresenceDayDetailView.swift Shared/CalendarEvidenceResolver.swift LearnTests/CalendarEvidenceResolverTests.swift tasks/todo.md` passed on March 20, 2026.
- Verification blocker: `xcodebuild build-for-testing -scheme Learn -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/BorderLogDerivedData -only-testing:LearnTests/CalendarEvidenceResolverTests` still fails in this environment before test execution because CoreSimulator cannot discover usable runtimes and SwiftData macro expansion is already failing in `Shared/Stay.swift` (`SwiftDataMacros.PersistentModelMacro ... produced malformed response`).

---

# Task Plan (Flight-Origin Same-Day Regression)

- Spec: preserve destination-based flight inference while restoring origin-country backfill for routes whose origin and destination still resolve to the same string `dayKey`.
- Spec: when a destination-based flight has a known origin country, use that origin context to promote the flight day when it is only low-confidence calendar evidence, and to promote the immediately previous unknown day.
- Spec: keep origin-side flight signals out of the base calendar winner so origin and destination evidence do not fight on the same day.
- [x] Patch flight ingestion so destination-based flights keep an origin-side calendar signal even when origin and destination share the same resolved day key.
- [x] Update inference so origin-side flight signals apply only in a targeted post-pass that promotes the flight day and previous unknown day to the origin country.
- [x] Add focused regression coverage for the same-date timezone-crossing case and record verification blockers.

## Review (Flight-Origin Same-Day Regression)

- Root cause: the previous flight-origin backfill path compared origin and destination `dayKey` values and dropped the origin signal whenever they matched, which broke westbound and other timezone-crossing routes that still land on the same string day key even though the departure-side country context should remain available.
- Fix applied: destination-based flights now keep a `CalendarFlightOrigin` signal whenever the origin resolves; `PresenceInferenceEngine` excludes that signal from base calendar scoring and uses it only in a targeted post-pass to promote the flight day when it is still unknown or calendar-only low confidence, plus the immediately previous unknown day, to a medium-confidence origin-country result.
- Regression coverage: added `InferenceEngineTests.testSameDateOriginFlightPromotesFlightDayAndPreviousUnknownDay` and updated `CalendarSignalIngestorCoreTests` to require origin-signal persistence even when origin and destination resolve to the same day key.
- Verification: `git diff --check -- Shared/CalendarSignalIngestor.swift Shared/PresenceInferenceEngine.swift LearnTests/InferenceEngineTests.swift LearnTests/CalendarSignalIngestorCoreTests.swift tasks/todo.md tasks/lessons.md` passed on March 20, 2026.
- Verification blocker: `xcodebuild test -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/BorderLogDerivedData -only-testing:LearnTests/InferenceEngineTests -only-testing:LearnTests/CalendarSignalIngestorCoreTests` could not run because this machine currently reports no usable simulator runtimes (`Unable to discover any Simulator runtimes` / `Unable to find a device matching the provided destination specifier`).
- Verification blocker: `xcodebuild build-for-testing -scheme Learn -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/BorderLogDerivedData -only-testing:LearnTests/InferenceEngineTests -only-testing:LearnTests/CalendarSignalIngestorCoreTests` is blocked in the current toolchain by a SwiftData macro/plugin failure in `Shared/CalendarSignal.swift` and `Shared/DayOverride.swift` (`SwiftDataMacros.PersistentModelMacro ... produced malformed response`).

---

# Task Plan (Reduce Unknown Country Inference)

- Spec: preserve existing calendar-event destination-day and up-to-7-day bridge inference behavior while reducing days that fall through to `Unknown`.
- Spec: fix the signal-ingestion layer first so name-only country resolutions still become usable inference inputs.
- Spec: add regression coverage for the affected calendar/location resolution path and record targeted verification.
- [x] Patch country resolution and calendar signal ingestion so country name-only results still feed inference.
- [x] Add focused regression coverage for the recovered inference path.
- [x] Run targeted verification and record the result.

## Review (Reduce Unknown Country Inference)

- Root cause: the shared `CountryResolver` and the text-search branch of `CalendarSignalIngestor` preferred MapKit region fields and, in the calendar path, dropped results outright unless a country code was present, so name-only matches never reached inference and bridge logic had nothing to work with.
- Fix applied: country resolution now normalizes placemark country fields first and preserves name-only matches through `CountryResolution.normalized(...)`; calendar signal ingestion uses the same normalization instead of requiring a preexisting code.
- Regression coverage: added `CountryResolutionTests` for canonical name-only resolution and fallback name preservation.
- Verification: `git diff --check -- Shared/CountryResolver.swift Shared/CalendarSignalIngestor.swift LearnTests/CountryResolutionTests.swift tasks/todo.md tasks/lessons.md` passed on March 20, 2026.
- Verification blocker: `xcodebuild test -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/BorderLogDerivedData -only-testing:LearnTests/InferenceEngineTests -only-testing:LearnTests/CountryResolutionTests -only-testing:LearnTests/CalendarSignalIngestorCoreTests` could not run because this machine currently reports no usable simulator runtimes (`Unable to discover any Simulator runtimes` / `Unable to find a device matching the provided destination specifier`).
- Verification blocker: `xcodebuild build-for-testing -scheme Learn -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/BorderLogDerivedData -only-testing:LearnTests/InferenceEngineTests -only-testing:LearnTests/CountryResolutionTests -only-testing:LearnTests/CalendarSignalIngestorCoreTests` is blocked in the current toolchain by a SwiftData macro/plugin failure in `Shared/DayOverride.swift` and `Shared/CalendarSignal.swift` (`SwiftDataMacros.PersistentModelMacro ... produced malformed response`).

---

# Task Plan (Flight-Origin Backfill)

- Spec: preserve the existing destination-day flight inference for calendar events and add origin-country context only where it improves unknown-day recovery.
- Spec: when an overnight flight has a known origin country, treat the departure day and the immediately previous unknown day as that origin country with medium confidence.
- Spec: do not create same-day origin/destination conflicts for ordinary same-day flights.
- [x] Patch calendar flight ingestion to preserve overnight origin-country context without regressing the current destination-day behavior.
- [x] Update inference to promote overnight origin-flight departure days and the previous unknown day to medium confidence.
- [x] Add focused regression coverage and run targeted verification, recording blockers if the environment still prevents xcodebuild.

## Review (Flight-Origin Backfill)

- Root cause: destination-first calendar ingestion preserved the arrival country for overnight flights but dropped the origin-country context entirely, so the departure day stayed low-confidence or unknown and the immediately previous unknown day had nothing flight-based to inherit.
- Fix applied: overnight destination-based flights now persist a second calendar signal on the departure day with source `CalendarFlightOrigin`, and `PresenceInferenceEngine` uses that origin signal to promote the departure day plus the immediately previous unknown day to medium-confidence calendar-based results.
- Regression coverage: added `InferenceEngineTests.testOvernightOriginFlightPromotesDepartureDayAndPreviousUnknownDay` and `CalendarSignalIngestorCoreTests` coverage for keeping origin signals only when the flight actually spans into a different day.
- Verification: `git diff --check -- Shared/SignalTypes.swift Shared/LedgerRecomputeService.swift Shared/CalendarSignalIngestor.swift Shared/PresenceInferenceEngine.swift LearnTests/InferenceEngineTests.swift LearnTests/CalendarSignalIngestorCoreTests.swift tasks/todo.md tasks/lessons.md` passed on March 20, 2026.
- Verification blocker: `xcodebuild test -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/BorderLogDerivedData -only-testing:LearnTests/InferenceEngineTests -only-testing:LearnTests/CalendarSignalIngestorCoreTests` could not run because this machine currently reports no usable simulator runtimes (`Unable to discover any Simulator runtimes` / `Unable to find a device matching the provided destination specifier`).
- Verification blocker: `xcodebuild build-for-testing -scheme Learn -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/BorderLogDerivedData -only-testing:LearnTests/InferenceEngineTests -only-testing:LearnTests/CalendarSignalIngestorCoreTests` is blocked in the current toolchain by a SwiftData macro/plugin failure in `Shared/Stay.swift` (`SwiftDataMacros.PersistentModelMacro ... produced malformed response`).

---

# Task Plan (Unknown Summary Drill-Downs)

- Spec: wherever aggregate day totals are shown for a selected range, expose an `Unknown` count when days in that same range have no resolved location.
- Spec: tapping `Unknown` should open a filtered day list scoped to the current selection, using the existing day-detail flow.
- Spec: keep the count/range logic aligned with the current Dashboard timeframe picker and Calendar Travel Summary range picker.
- [x] Add unknown-day summary metadata for Calendar range snapshots.
- [x] Update Dashboard Visited Countries and Calendar Travel Summary to surface unknown counts with drill-down navigation.
- [x] Add regression coverage for Calendar unknown summary metadata and record the targeted verification blocker.
- [x] Record the implementation and verification result.

## Review (Unknown Summary Drill-Downs)

- Root cause: aggregate country totals only rendered known-country buckets, so days with a persisted `PresenceDay` but no resolved country disappeared from Dashboard and Calendar summaries even though those same day records existed for drill-down.
- Fix applied: Dashboard `Visited Countries` now collects timeframe-scoped unknown `PresenceDay` rows into an `Unknown` summary row that opens `FilteredLedgerView`, and Calendar `Travel Summary` now carries summary-range unknown day keys through `CalendarTabSnapshot` so the same drill-down works outside the visible month.
- Regression coverage: added a `CalendarTabDataServiceTests` case that proves `summaryUnknownDayKeys` includes an unknown `PresenceDay` inside the selected summary range without polluting the visible-month day grid.
- Verification: `git diff --check -- DashboardView.swift Learn/CalendarTabView.swift Shared/CalendarTabDataService.swift LearnTests/CalendarTabDataServiceTests.swift tasks/todo.md tasks/lessons.md` passed on March 20, 2026.
- Verification blocker: `xcodebuild test -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/BorderLogDerivedData -only-testing:LearnTests/CalendarTabDataServiceTests` could not run because this machine currently reports no usable simulator runtimes (`Unable to discover any Simulator runtimes` / `Unable to find a device matching the provided destination specifier`).
- Verification blocker: `xcodebuild build-for-testing -scheme Learn -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/BorderLogDerivedData -only-testing:LearnTests/CalendarTabDataServiceTests` is also blocked in the current toolchain by a SwiftData macro/plugin failure in `Shared/Stay.swift` (`SwiftDataMacros.PersistentModelMacro ... produced malformed response`).

---

# Task Plan (Inference Canonical Country Resolution)

- Spec: canonical country resolution must happen inside `PresenceInferenceEngine`, before `PresenceDay` results are persisted or consumed by downstream summaries.
- Spec: preserve the existing bridge-gap behavior for matching countries across data voids up to 7 days inclusive; a 6- or 7-day void should still infer the matching country.
- Spec: boundary matching for bridge inference should use canonical country identity, not require both raw `countryCode` values to already be present.
- [x] Refactor inference-time country normalization so scoring and winners use canonical code-or-name identity.
- [x] Keep gap bridging at `<= 7` days using canonical boundary country matching.
- [x] Add inference regression coverage for name-only canonicalization and a 7-day bridge void.
- [x] Run targeted verification and record the outcome.

## Review (Inference Canonical Country Resolution)

- Root cause: `PresenceInferenceEngine` bucketed evidence by raw `(countryCode, countryName)` pairs and treated gap days as unknown whenever `countryCode == nil`, so name-only evidence could stay uncanonicalized, split the same country into separate buckets, and prevent bridge inference from firing even when the boundary countries matched by name.
- Fix applied: inference now canonicalizes country identity before scoring, winner selection, dispute suggestions, and `PresenceDayResult` emission, so persisted `PresenceDay` rows already carry canonical country resolution when a code can be derived.
- Bridge behavior: the gap-fill pass still bridges voids of up to 7 days inclusive, but now it compares canonical boundary countries instead of requiring both raw country codes to already be present.
- Regression coverage: updated `InferenceEngineTests` to assert name-only known countries canonicalize to `ES`, that a 7-day void bridges when the boundary countries match canonically, and that an 8-day void still does not bridge.
- Verification: `xcodebuild test -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/BorderLogDerivedData -only-testing:LearnTests/InferenceEngineTests -only-testing:LearnTests/CalendarTabDataServiceTests -only-testing:LearnTests/SchengenLedgerCalculatorTests` succeeded on March 20, 2026. Existing unrelated Swift 6 isolation warnings in `LedgerRecomputeService.swift`, `CountryResolver.swift`, and `CalendarTabDataService.swift` remain.

---

# Task Plan (Resolved Country Normalization)

- Spec: treat a resolved country name and its ISO country code as the same country identity everywhere counts, flags, and map totals are computed.
- Spec: when a `PresenceDay` has a resolved country name but no stored code, derive the canonical country code for summaries, flags, map coverage, country drill-downs, and Schengen counting.
- Spec: calendar day decorations should prefer the resolved `PresenceDay` country when available, so a day with a Summary location shows a flag even if raw evidence is empty.
- [x] Add a shared canonical country-resolution helper for code-or-name inputs.
- [x] Apply the canonical country resolution to dashboard totals, country detail filtering, Schengen totals, and calendar snapshot output.
- [x] Add regression coverage for name-only resolved days contributing to coded totals and flags.
- [x] Run targeted verification and record the outcome.

## Review (Resolved Country Normalization)

- Root cause: resolved days with `countryName` but no `countryCode` were treated as a separate country identity, which split totals, dropped those days from flag/map views, and left calendar decorations blank even when the day Summary had a location.
- Fix applied: added canonical country resolution from either code or name, then used it in dashboard visited-country aggregation, country detail filtering, Schengen counting, row flag rendering, and calendar snapshot summaries.
- Calendar behavior change: month day decorations now prefer the resolved `PresenceDay` country when one exists, so inferred/name-only days show a flag that matches the Summary result while still preserving raw flight markers.
- Regression coverage: expanded `CalendarTabDataServiceTests` to verify name-only resolved days still show an `ES` flag and merge into coded `ES` totals, and added a `SchengenLedgerCalculatorTests` case for a name-only Schengen day.
- Verification: `xcodebuild test -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/BorderLogDerivedData -only-testing:LearnTests/CalendarTabDataServiceTests -only-testing:LearnTests/SchengenLedgerCalculatorTests` succeeded on March 20, 2026. Existing unrelated Swift 6 isolation warnings in `CountryResolver.swift` and `CalendarTabDataService.swift` remain.

---

# Task Plan (Bridge-Day Presence Counts)

- Spec: treat the resolved `PresenceDay` location as the source of truth for counting visited-country totals, including inferred bridge days with no direct stay, calendar, photo, or location evidence.
- Spec: keep calendar day decorations and evidence inspection driven by raw signals, but make Travel Summary totals align with the Summary section shown for each day.
- Spec: limit behavior changes to counting/summary paths; do not weaken existing day-detail evidence visibility.
- [x] Review lessons and inspect the counting paths for dashboard, country detail, daily ledger, and calendar summaries.
- [x] Update the shared summary logic so bridge-day `PresenceDay` records contribute to Travel Summary and country totals.
- [x] Add regression coverage for inferred bridge days with no raw evidence.
- [x] Run targeted verification and record the outcome.

## Review (Bridge-Day Presence Counts)

- Root cause: `CalendarTabDataService` rebuilt Travel Summary totals from raw stays, photos, location samples, and calendar events, so inferred `PresenceDay` bridge days with `sources: .none` were omitted even though the day Summary showed a resolved country.
- Fix applied: Travel Summary counting now prefers the resolved `PresenceDay` for each day key and falls back to raw evidence only when no `PresenceDay` exists, while month decorations and flight markers still use the raw-signal accumulator.
- Regression coverage: added a `CalendarTabDataServiceTests` case that inserts a bridge-day `PresenceDay` with no raw evidence and verifies the day remains decoration-empty but still counts toward the country summary.
- Verification: `xcodebuild test -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/BorderLogDerivedData -only-testing:LearnTests/CalendarTabDataServiceTests` succeeded on March 20, 2026.

---

# Task Plan: Fix Git Sync

- [ ] Sync local main branch with remote origin/main.

---

# Task Plan (Calendar Header Safe Area Margins)

- Spec: keep the native `UICalendarView` and the existing 12pt calendar margin.
- Spec: extend that same horizontal inset to the calendar header content, including the native month title and weekday subtitle row.
- Spec: prefer the smallest layout change that affects the whole embedded calendar surface rather than adding separate ad hoc offsets.
- [x] Update the Calendar tab layout so the native calendar header and body share the same horizontal inset.
- [x] Stop before running builds/tests because the user explicitly requested a code-only change.

## Review (Calendar Header Safe Area Margins)

- Previous attempt failed: setting `UICalendarView` `layoutMargins` and `directionalLayoutMargins` did not move the native month header or chevrons.
- Fix applied: embedded `UICalendarView` inside a container `UIView` and constrained it to the container’s 12pt horizontal `layoutMarginsGuide`, so the entire native calendar surface is inset together.
- Verification: not run, per user instruction to avoid testing.

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
