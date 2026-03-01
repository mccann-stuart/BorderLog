Product Requirements Document (PRD)

BorderLog (Working Title) — Local‑first Country Presence + Schengen Tracker for Expats

Document status: Draft v0.2
Last updated: 15 Feb 2026
Platforms: iOS (primary), iPadOS (nice-to-have)
Distribution: App Store
Pricing: Free (no subscriptions, no paid tiers)

Weekly Changelog

Week of Feb 17–23, 2026

Highlights:
- Added disputed status inference for presence days, including filters and UI support.
- Introduced BorderLogSchemaV4 with PresenceDay migration and CountryConfig.
- Implemented calendar-signal flight inference (airport parsing + route inference).
- Fixed ledger gaps by ensuring missing days are filled and surfaced in the ledger.

Key PRs:
- [#81](https://github.com/mccann-stuart/BorderLog/pull/81) Calendar signal flight inference follow-up.
- [#80](https://github.com/mccann-stuart/BorderLog/pull/80) Calendar signal flight inference.
- [#79](https://github.com/mccann-stuart/BorderLog/pull/79) Move “Last 2 Years” section adjustments.
- [#77](https://github.com/mccann-stuart/BorderLog/pull/77) Fix ledger missing days.
- [#76](https://github.com/mccann-stuart/BorderLog/pull/76) Fix backend log leak.

⸻

1. Executive Summary

BorderLog is a privacy-first iOS app that helps expatriates and frequent travelers track days in/out of countries and remain compliant with zone rules like Schengen’s 90/180. The app is local-first: user data is stored on-device using SwiftData and can optionally sync across the user’s own devices via CloudKit (no app-owned user database). SwiftData supports on-device persistence and can sync across devices when CloudKit is enabled in app entitlements.  ￼

Unlike manual spreadsheet approaches, BorderLog infers daily country presence by combining:
	1.	Location snapshots written into a local table (captured opportunistically by an iOS Widget extension)
	2.	Photo location metadata (GPS in photo EXIF, exposed via Photos/PhotoKit asset location)
	3.	Manual entries & user corrections, which override inference

Photo and location permissions are strictly opt-in; the app remains usable in “manual-only” mode.

⸻

2. Problem Statement

Expats and “border-rule constrained” travelers must answer questions like:
	•	“How many days have I been in Schengen in the last 180 days?”
	•	“How many days have I been out of my host country this year?”
	•	“If I enter Schengen on X and stay Y days, will I breach 90/180?”

Schengen’s short-stay rule is commonly expressed as max 90 days in any rolling 180-day period, counting back 180 days from each day of stay.  ￼
This rule is easy to misunderstand without tooling.

Existing solutions often require heavy manual entry. People also have fragmented evidence (photos, location history, calendar notes) but no coherent way to reconcile it into an audit-friendly “day ledger.”

⸻

3. Goals, Non‑Goals, and Principles

3.1 Goals
	1.	Accurate “days in/out” ledger per country and per zone (Schengen MVP).
	2.	Automated suggestions for daily country presence from on-device signals.
	3.	Fast correction workflows: user can override any day or trip segment.
	4.	Forecasting: simulate planned travel and see rule impacts.
	5.	Privacy-first by architecture: user travel data stays on device + iCloud (CloudKit) only; no user travel data stored on app servers.
	6.	Minimal backend only for app data updates (country lists, zone membership, ruleset configs).

3.2 Non‑Goals (MVP)
	•	Providing legal advice or guaranteeing compliance (tool is informational).
	•	Visa application services, government API integrations.
	•	“Always-on” background tracking (battery/privacy constraints; widget-based snapshots are opportunistic).

3.3 Product Principles
	•	Local-first: offline usable; network used only for updates + optional iCloud sync.
	•	Explainability: show why a day was classified (sources + confidence).
	•	User control: manual overrides always win.
	•	Sane defaults: Schengen 90/180 is preconfigured; everything else is optional.

⸻

4. Target Users & Primary Use Cases

4.1 Personas
	1.	Expat Resident
	•	Needs to track days outside host country (residency rules, renewal requirements, tax planning).
	2.	Digital Nomad
	•	Moves frequently; wants reliable Schengen 90/180 compliance forecasting.
	3.	Frequent Business Traveler
	•	Multiple EU entries; needs quick “days remaining” and clean history export.

4.2 Top Jobs To Be Done
	•	“Tell me how many days I’ve used in Schengen and how many remain.”
	•	“Reconstruct my last 6–12 months of travel with minimal manual effort.”
	•	“Fix mistakes quickly when the app inference is wrong.”
	•	“Export a defensible travel history.”

⸻

5. Key User Journeys

Journey A — First Launch & Setup
	1.	Welcome → value prop + privacy stance
	2.	Sign in with Apple (required)
	3.	Optional profile setup (passport nationality, home country, etc.)
	4.	Permission requests (optional, staged):
	•	Location permissions (for widget + app inference)
	•	Photos library permissions (read-only)
	5.	App generates initial travel ledger using available sources.

Note: Sign in with Apple is implemented using Authentication Services (e.g., ASAuthorizationAppleIDProvider and SwiftUI SignInWithAppleButton).  ￼

Journey B — Daily Inference + Review
	1.	App proposes a country for each day (with confidence).
	2.	User reviews timeline; taps a day to see evidence:
	•	widget location samples
	•	photo locations
	•	manual entries
	3.	User confirms or overrides.

Journey C — Plan a Trip (Forecast Mode)
	1.	User selects planned entry date + planned exit date (or duration).
	2.	App simulates effect on:
	•	Schengen 90/180 usage
	•	days in/out of selected countries
	3.	App highlights first predicted violation date and remaining buffer.

Journey D — Export / Audit
	1.	User exports travel ledger as CSV/PDF
	2.	Export includes:
	•	per-day country
	•	trips (aggregated)
	•	Schengen days used per day (optional appendix)

⸻

6. Functional Requirements

6.1 Authentication & Identity

FR-Auth-1 — Required Apple Sign-in
	•	App requires Sign in with Apple at first run and after sign-out.
	•	Only Apple authentication is supported (no email/password, no Google).
	•	Store Apple user identifier locally for session continuity; do not create a server-side user record.

FR-Auth-2 — UI compliance
	•	Use Apple-provided buttons (SignInWithAppleButton for SwiftUI).  ￼

FR-Auth-3 — Optional profile
Profile fields are optional and stored locally:
	•	Passport nationality (optional)
	•	Additional citizenships (optional)
	•	Home country (optional)
	•	“Primary zone of concern” (optional; default Schengen)

⸻

6.2 Data Sources & Permissions

BorderLog supports three sources. All are opt-in; manual-only remains functional.

6.2.1 Location Samples (Widget + App)
FR-Loc-1 — Widget location capture (opportunistic)
	•	Provide an iOS Home Screen widget that can request location and write a location sample into a local “location samples” table.
	•	Widget constraints: widget extensions don’t run continuously; location is best-effort when the system refreshes the widget timeline.  ￼
	•	Widget requires NSWidgetWantsLocation in widget extension Info.plist.  ￼
	•	Containing app must request location permission before widget can receive location.  ￼

FR-Loc-2 — Location permissions UX
	•	Request location permission in-app with clear purpose string.
	•	Provide a manual-only path if denied.
	•	Location is sensitive; onboarding must explain implications.  ￼

FR-Loc-3 — Minimal storage
	•	Store only:
	•	timestamp
	•	lat/lon
	•	accuracy
	•	capture source (widget/app)
	•	device timezone at capture (for day bucketing)
	•	Do not store full route traces; aggressively downsample.

6.2.2 Photo Location Metadata (Photo EXIF via PhotoKit)
FR-Photo-1 — Read photo location metadata only
	•	With user permission, scan photo library for assets that include location metadata and creation time.
	•	PhotoKit exposes asset location via PHAsset.location.  ￼

FR-Photo-2 — Permission handling
	•	Request Photos authorization using PHPhotoLibrary.requestAuthorization and respect access level.  ￼
	•	Support limited library access (iOS feature); app should still function with partial photo set.

FR-Photo-3 — Minimize retained data
	•	Store derived signals (timestamp + coordinate + localIdentifier hash); do not copy images.

6.2.3 Manual Entries & Corrections
FR-Manual-1 — Manual trip entry
User can add “stay segments”:
	•	Country
	•	Entry date
	•	Exit date (or “still here”)

FR-Manual-2 — Day-level overrides
	•	User can mark a specific day as being in a different country (override the model).
	•	Overrides always take precedence over inferred values.

FR-Manual-3 — Data validation
	•	Prevent impossible overlaps unless user explicitly allows (e.g., transit days).
	•	Provide warnings for gaps.

⸻

6.3 Country Resolution (Coordinate → Country)

The system must map a coordinate to an ISO country code.

FR-Geo-1 — On-device first mapping
	•	Prefer an on-device boundary lookup using a bundled dataset (e.g., Natural Earth country polygons, which is public domain).  ￼
	•	This avoids repeated network geocoding and supports offline inference.

FR-Geo-2 — Optional geocoder fallback
	•	If boundary lookup fails, optionally use CLGeocoder reverse geocoding to obtain country/ISO code.
	•	Constraints: geocoding generally requires network for detailed placemark results and shouldn’t be performed when the user won’t immediately see results (avoid background geocoding).  ￼

FR-Geo-3 — Unknown handling
	•	If neither method resolves a country, mark the day as Unknown and prompt for manual correction.

⸻

6.4 Presence Inference Engine

The core engine produces a Daily Presence Ledger: for each date, which country (and which zones) the user was present in.

6.4.1 Inputs
	•	Location samples (widget/app)
	•	Photo signals (location + creationDate)
	•	Manual stays and day overrides
	•	Country/zone definitions & rule configs (from bundled + remote updates)

6.4.2 Outputs
	•	PresenceDay records (date → countryCode, confidence, evidence summary, override flag)
	•	TripSegments (optional derived view for UX/export)

6.4.3 Inference logic (high-level)
Step 1: Bucket signals by local day
	•	Use timestamp + stored device timezone-at-capture.
	•	Each day aggregates signals.

Step 2: Candidate country scoring
	•	Manual day override: score = ∞ (wins)
	•	Manual stay segment: very high weight
	•	Location samples: high weight, adjusted by accuracy and number of samples
	•	Photo signals: medium weight (users tend to take photos where they are)
	•	Calendar signals: lower weight (helpful but less reliable)

Step 3: Select day country
	•	Choose highest-scoring country if above threshold.
	•	Otherwise Unknown.

Step 4: Smooth & detect implausible flips
	•	If a single-day country differs between two long runs, prompt user (“Were you transiting?”).

Step 5: Build zone presence
	•	Map each day’s country into zones (e.g., Schengen) using the zone membership list.

6.4.4 Explainability requirement
Each day detail view must show:
	•	Final country label
	•	Confidence label (High/Medium/Low)
	•	Evidence list (e.g., 3 photos in Italy, 2 widget samples in Italy)
	•	“Override” control

⸻

6.5 Schengen 90/180 Rule Module

FR-Schengen-1 — Implement 90/180 rolling window
	•	For any date D, compute the number of Schengen days within the 180-day window ending on D.
	•	Rule: maximum 90 days within any 180-day period.  ￼

FR-Schengen-2 — Dashboard
Display:
	•	Days used in last 180
	•	Days remaining
	•	First day remaining hits 0 (projected), if a planned trip exists
	•	Recent days timeline

FR-Schengen-3 — Country list + zone membership is updateable
	•	Zone definitions must be remote-configurable because membership and interpretation can change.
	•	Provide baseline list and update via backend.
	•	Example of Schengen list presentation: GOV.UK provides an updated list and describes the rolling 180-day approach.  ￼

⸻

6.6 General “Days In/Out” Tracking (Per Country)

FR-Country-1 — Per-country counters
For any selected country:
	•	Days present in last 30/90/180/365 days
	•	Days present this calendar year
	•	Days absent this calendar year (if country is marked “home/host”)

FR-Country-2 — Custom thresholds (user-defined)
	•	User can define a threshold rule:
	•	“Warn me if I exceed X days in last Y days”
	•	“Warn me if I’m below X days this year”
	•	Not legal advice; phrased as “alerts” and “targets.”

⸻

6.7 Forecasting

FR-Forecast-1 — Planned trip simulation
User enters:
	•	Destination country (or Schengen)
	•	Entry date
	•	Exit date (or duration)

Outputs:
	•	Incremental days used
	•	Whether it breaches configured rules

FR-Forecast-2 — Scenarios
	•	Allow saving multiple “what-if” plans.

⸻

6.8 Widgets

FR-Widget-1 — Schengen glance widget
	•	Show days remaining and status (OK / nearing limit / exceeded).

FR-Widget-2 — “Log current country” widget action
	•	One-tap action opens app to confirm today’s country or add a manual correction.

FR-Widget-3 — Location access in widgets
	•	Must follow Apple’s widget location requirements (NSWidgetWantsLocation, permissions requested in host app).  ￼

⸻

6.9 Export & Audit Trail

FR-Export-1 — CSV export
Include:
	•	Date, Country, SourceConfidence, OverrideFlag
	•	Optional: Zone flags (Schengen true/false)

FR-Export-2 — PDF summary
	•	Human-readable travel history
	•	Schengen summary (days used/remaining at export time)

FR-Export-3 — Data provenance
	•	Export optionally includes “Evidence counts” (e.g., 4 photos, 2 location samples) without exposing coordinates unless user opts-in.

⸻

7. Data Storage & Sync Requirements

7.1 Local-first SwiftData store (no server-side user data)

NFR-Data-1 — SwiftData persistence
	•	All user travel data is stored locally via SwiftData.

NFR-Data-2 — CloudKit sync for user’s own devices
	•	Enable CloudKit-backed sync so SwiftData can keep model data consistent across the user’s devices when iCloud is enabled. SwiftData’s container can automatically handle syncing if CloudKit entitlements are enabled.  ￼

7.2 Shared storage for app + widget

Because the widget also writes samples, the app must use a shared container strategy.

NFR-Data-3 — App Group store location
	•	Persist the SwiftData store in an App Group container so the widget extension can read/write shared data.
	•	Apple notes SwiftData sample patterns using App Groups to share containers between a SwiftData widget extension and host app, persisting the store to the root of the app group container.  ￼

⸻

8. Proposed Local Data Model (SwiftData Entities)

No User entity. Identity is an auth/session concern, not a persisted “account.”

8.1 Reference / Config Entities
	•	CountryRef
	•	iso2 (PK), name, optional schengenMember (derived), lastUpdatedVersion
	•	ZoneRef
	•	zoneId (e.g., “schengen”), name, members (iso2 set), effectiveFrom, effectiveTo?
	•	RuleConfig
	•	ruleId, type (e.g., rollingWindow), params (X,Y), appliesToZoneId?, appliesToCountryIso2?, enabled
	•	RemoteConfigState
	•	currentVersion, etag, lastCheckAt

8.2 Signals
	•	LocationSample
	•	timestamp, lat, lon, accuracyMeters, source (widget/app), tzAtCapture
	•	PhotoSignal
	•	timestamp, lat, lon, assetIdHash, tzAtCapture

8.3 User Assertions / Corrections
	•	ManualStay
	•	countryIso2, entryDate, exitDate?, note?
	•	DayOverride
	•	date, countryIso2, note?

8.4 Derived Ledger
	•	PresenceDay
	•	date (PK), countryIso2? (nullable), confidence (0–1), sourcesUsed (bitset), isOverride

⸻

9. Technical Architecture

9.1 On-device components (iOS)

Client stack
	•	SwiftUI UI layer
	•	SwiftData persistence layer (App Group store)
	•	CloudKit sync enabled via SwiftData configuration (iCloud private database)  ￼
	•	WidgetKit extension
	•	Core Location for location samples (with explicit permission flow)  ￼
	•	PhotoKit for photo metadata ingestion  ￼

Processing pipeline
	•	Background-friendly ingestion (best effort)
	•	Foreground recomputation of ledger (deterministic)
	•	Local notifications for thresholds (no server push required)

9.2 Cloud backend (minimal; no personal data)

Components
	1.	Cloudflare Pages
	•	Hosts static marketing site + privacy policy + documentation.
	•	Pages supports deploying static HTML sites.  ￼
	2.	Cloudflare Worker
	•	Serves a tiny API for configuration and data updates to the app.
	•	Worker uses Fetch API for HTTP handling.  ￼
	3.	Cloudflare R2
	•	Stores versioned configuration artifacts:
	•	manifest.json (latest versions)
	•	countries.json
	•	zones.json (Schengen membership, effective dates)
	•	rules.json
	•	Optional: compressed country boundary dataset updates
	•	R2 supports an S3-compatible API and is designed as distributed object storage.  ￼
	•	Workers can access R2 via bucket bindings and expose external access via routes.  ￼

API endpoints (illustrative)
	•	GET /config/manifest → versions + ETag
	•	GET /config/zones/{version} → zone definitions
	•	GET /config/rules/{version} → rule templates (Schengen rolling window)
	•	GET /config/countries/{version} → country names/codes

Security posture
	•	No authentication required if data is public; alternatively, sign payloads and verify in app.
	•	Aggressive caching at edge; use ETag/If-None-Match to minimize downloads.

⸻

10. Non‑Functional Requirements

10.1 Privacy
	•	No user travel data is sent to app servers.
	•	All inference happens locally.
	•	Clear disclosures for:
	•	location usage
	•	photo metadata usage
	•	Provide “Delete all local data” button.

10.2 Security
	•	Store local data in app sandbox/app group; rely on iOS data protection.
	•	Use HTTPS for config downloads.
	•	Consider signing config artifacts to prevent tampering.

10.3 Performance & Battery
	•	Widget location sampling is opportunistic and should not attempt continuous tracking. Widgets don’t run continuously, and location support requires special handling.  ￼
	•	Photo scanning must be incremental (scan since last processed date).
	•	Ledger recomputation target: < 500ms for 5 years history on modern devices.

10.4 Reliability
	•	App fully functional offline (manual mode).
	•	If CloudKit unavailable, local data still works; sync resumes when available.

⸻

11. Risks & Mitigations
	1.	Inference errors (wrong country)
	•	Mitigation: confidence + explainability; easy override; “Unknown” is acceptable.
	2.	Widget location limitations
	•	Mitigation: treat widget signals as opportunistic; allow app-based capture; manual correction.
	3.	Geocoding/network dependency
	•	Mitigation: on-device polygon mapping; use geocoder as optional fallback (and avoid background geocoding).  ￼
	4.	Changing zone membership (e.g., Schengen updates)
	•	Mitigation: remote-configurable zone definitions via Cloudflare Worker/R2.

⸻

12. Milestones (Suggested)

M1 — Foundations
	•	SwiftData schema + App Group store
	•	Sign in with Apple required flow
	•	Manual stays + day overrides
	•	Schengen calculator engine (90/180)
	•	Summary dashboard

M2 — Inference v1
	•	Widget location capture + ingestion
	•	Photo signal ingestion
	•	Daily ledger generation + confidence + explainability UI

M3 — Forecast + Export
	•	Forecast mode
	•	CSV/PDF export
	•	Local notifications for thresholds

M4 — Minimal backend for updates
	•	Cloudflare Pages + Worker + R2
	•	Versioned config downloads with caching

⸻

13. Open Questions (Design Decisions to Lock)
	1.	Day boundary definition: device timezone-at-capture vs user-selected “home” timezone (impacts edge cases near midnight).
	2.	Coordinate retention: store raw coordinates long-term vs store only derived country/day (privacy vs auditability).
	3.	What “manual entry” represents: passport stamp dates vs actual time-in-country; how to communicate that clearly.

⸻

If you want, I can also provide:
	•	A concrete SwiftData schema + migration plan outline
	•	Pseudocode for the daily inference + Schengen rolling-window calculation
	•	A screen-by-screen UX spec (information architecture + interactions)


# BorderLog
Enable expatriates, digital nomads, and frequent international travelers to accurately track physical presence across countries and visa zones (e.g., Schengen Area) to ensure compliance with visa, residency, and tax regulations.

## M1 foundations
- Log stays with country, region, entry date, optional exit date, and notes
- Rolling Schengen 90/180 summary with used, remaining, and overstay days
- Local persistence using SwiftData

## M1 plan
1. Define the SwiftData schema for stays, day overrides, and Schengen rollups.
2. Wire the App Group SwiftData store and basic data migrations.
3. Implement required Sign in with Apple flow and first-run gate.
4. Build manual stay CRUD UI with validation for overlaps and missing exits.
5. Build day-level override UI with a simple per-day editor.
6. Implement the Schengen 90/180 rolling-window engine and unit tests.
7. Add a summary dashboard for used/remaining/overstay days.
8. Add seed/sample data and a reset path for QA.
9. Run a smoke test pass on a clean device and document known gaps.

## M2 milestone — Inference v1
- Widget location capture + ingestion
- Photo signal ingestion
- Daily ledger generation + confidence + explainability UI
- Dashboard Schengen 90/180 card visibility toggle controlled from Settings

## M2 plan
1. Add SwiftData schema v2 with `LocationSample`, `PhotoSignal`, `PresenceDay`, and `PhotoIngestState`, plus a lightweight migration.
2. Define new model files with unique constraints on `PresenceDay.dayKey` and `PhotoSignal.assetIdHash`.
3. Add shared utilities: `DayKey`, `CountryResolving` protocol, and `CLGeocoderCountryResolver` with caching.
4. Implement `LocationSampleService` to capture a single fix, resolve country/timezone, store a sample, and trigger ledger recompute.
5. Implement `PhotoSignalIngestor` to scan the last 12 months (incremental on subsequent runs), hash asset IDs, store signals, and trigger recompute.
6. Create a WidgetKit extension that captures location on refresh and displays the last sample.
7. Build `PresenceInferenceEngine` scoring logic with weights (override > stay > location > photo > calendar).
8. Add `LedgerRecomputeService` to upsert `PresenceDay` by dayKey and handle unknowns.
9. Add a Daily Ledger section in Details with confidence pills, evidence, and an override action.
10. Switch Dashboard metrics to use `PresenceDay` with unknown-day reporting.
11. Add permission status/actions for location and photos + manual rescan in Settings.
12. Update Info.plist keys and App Group entitlements for app + widget.
13. Extend data reset/seed to include new models and optional sample ledger.
14. Add unit tests for inference scoring, day-key bucketing, unknown-day behavior, and Schengen ledger summary.
15. Keep README and in-app setup copy aligned with M2 inference capabilities.
16. Add a persisted Settings toggle to show/hide the Dashboard Schengen 90/180 card.

## Run
Open `Learn.xcodeproj` in Xcode and run the iOS app target.
