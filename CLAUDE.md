# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

BorderLog is a local-first iOS app (primary) + WidgetKit extension that tracks daily country presence and computes Schengen Zone day-counts for expats. It is free, no subscriptions. Distribution is via the App Store.

Key runtime constraints:
- **CloudKit sync** is feature-gated off (`AppConfig.isCloudKitFeatureEnabled == false`). Local SwiftData/App Group storage is the active persistence path.
- **Sign in with Apple** is feature-flagged off (`AuthenticationManager.isAppleSignInEnabled == false`). Onboarding uses a local session ID.
- **Debug data export** is compiled and surfaced only in `DEBUG` builds — it contains full-fidelity diagnostics (raw coordinates, event titles, photo hashes, user identifiers) and must never appear in release builds.

## Build & Test Commands

All commands target `Learn.xcodeproj`.

```bash
# Build (compile-check only, no device required)
xcodebuild build -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=Any iOS Simulator Device' | xcpretty

# Run all unit tests
xcodebuild test -project Learn.xcodeproj -scheme Learn -testPlan Learn -destination 'platform=iOS Simulator,name=iPhone 16' | xcpretty

# Run a single test class
xcodebuild test -project Learn.xcodeproj -scheme Learn -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LearnTests/CalendarFlightParsingTests | xcpretty

# List available simulator destinations
xcodebuild -showdestinations -project Learn.xcodeproj -scheme Learn
```

The backend is a Cloudflare Worker (JavaScript):
```bash
# Deploy backend
cd backend && npx wrangler deploy

# Run backend tests
cd Learn && node test_security.mjs
```

## Architecture Overview

### Targets & Code Layout

| Directory | Target | Purpose |
|---|---|---|
| `Learn/` | iOS app (`Learn`) | UI views, app entry point, local-only helpers |
| `Shared/` | Shared by app + widget | Models, inference engine, ledger, signal ingestors |
| `BorderLogWidget/` | WidgetKit extension | 3 widgets: current location, top countries, Schengen |
| `LearnTests/` | Unit test target | Pure logic tests, no UI |
| `LearnUITests/` | UI test target | Launch/flow tests |
| `backend/src/` | Cloudflare Worker | R2-backed config artifact serving |

### Data Flow: Signal → Ledger → UI

The core pipeline runs asynchronously gated by `LedgerRefreshCoordinator.shared` (a serial actor preventing concurrent recomputes):

1. **Signal ingestion** — Three ingestors write raw evidence into SwiftData:
   - `CalendarSignalIngestor` — reads EventKit, classifies flights/travel via `CalendarFlightParsing`, writes `CalendarSignal` records.
   - `PhotoSignalIngestor` — reads Photos EXIF/location metadata, writes `PhotoSignal` records.
   - `LocationSampleService` — captures GPS bursts (app foreground + widget), writes `LocationSample` records. The widget queues snapshots in `PendingLocationSnapshot` (shared `UserDefaults`); the app drains these on `scenePhase == .active`.

2. **Ledger recomputation** — `LedgerRecomputeService` (`@ModelActor`) fetches signals for a date range and calls `PresenceInferenceEngine` to resolve a `PresenceDayResult` per calendar day. Results are upserted into `PresenceDay` SwiftData records. Recompute can be scoped to specific `dayKey`s (triggered by ingestors) or full-history (`recomputeAll`).

3. **Inference** — `PresenceInferenceEngine` is a pure, `nonisolated` struct that takes an `InferenceContext` and produces weighted country allocations. Weights are configured by `InferencePipelineConfig`. The engine runs multi-pass stabilization (up to 15 passes) to settle adjacent-day context effects.

4. **UI reads** — SwiftUI views use SwiftData `@Query` (already sorted) to read `PresenceDay` records. `SchengenLedgerCalculator` derives rolling 180-day Schengen counts from `PresenceDay`.

### SwiftData Schema & Migrations

Current active schema: `BorderLogSchemaV7` (defined in `Shared/ModelContainerProvider.swift`). All prior versions (V1–V6) have lightweight migration stages. `PresenceDay` is the model that has evolved most across versions.

`ModelContainerProvider.makeContainer()` follows a tiered store resolution: App Group container (shared with widget) → local sandbox store → in-memory fallback. Store epoch (`storeEpochV2`, currently `8`) triggers a destructive wipe when bumped.

The primary `PresenceDay` model type (V7 active) lives in `Shared/PresenceDay.swift`.

### Key Shared Types

- `DayKey` — `"yyyy-MM-dd"` string identifying a calendar day. Generated without `DateFormatter` (manual `Calendar.dateComponents`) for performance.
- `PresenceDay` — the persisted per-day result, including `countryAllocations: [PresenceCountryAllocation]`, `evidenceEntries`, confidence scores, and signal counts.
- `Stay` — manual travel record (entered on / left on / country).
- `DayOverride` — user-specified country override for a day (weight 1000 in inference).
- `CountryConfig` — per-country user settings (e.g. day-counting mode).

### App Group & Widget Sharing

The app and widget share a SwiftData store via App Group `group.com.MCCANN.Border`. The widget writes `PendingLocationSnapshot` entries to shared `UserDefaults`; the main app drains and stores them on foreground. `AppConfig` is `nonisolated` and safe to call from any context.

### Backend

`backend/src/index.js` is a Cloudflare Worker that serves versioned config artifacts (JSON) from an R2 bucket (`CONFIG_BUCKET`). It is read-only (GET/HEAD only) and applies strict security headers on all responses.

## Performance Conventions

These patterns are enforced throughout the codebase — follow them when adding or modifying hot-path code:

- **Single-pass loops**: Replace chained `.filter` / `.map` / `.sorted` chains with a single `for` loop when computing multiple metrics over the same collection.
- **SwiftData predicates**: Always use `#Predicate` in `FetchDescriptor` for range queries; never fetch all records and filter in memory.
- **No re-sort of `@Query` results**: `@Query(sort:)` results are pre-sorted; `.filter` preserves order. Don't call `.sorted()` after filtering unless the sort key changed.
- **Top-K without sort**: Use `.max(by:)` / `.min(by:)` or a manual O(N) scan to find top-1 or top-K elements; never `.sorted().prefix(K)`.
- **Lazy prefix filtering**: Use `.lazy.filter { }.prefix(N)` before converting to `Array` when only the first N matches are needed.
- **Dictionary init**: Use `reduce(into: [Key:Value](minimumCapacity: n))` instead of `Dictionary(uniqueKeysWithValues: array.map { ... })` to avoid intermediate array allocation; use `if dict[key] == nil` for uniqueness.
- **Hoisted regex**: Declare `NSRegularExpression` as `private nonisolated static let` — never instantiate inside a loop or function body.
- **Early break on sorted sequences**: When iterating a reverse-sorted array with a known time bound, `break` once past the lower bound. Pass `isReverseSorted: Bool` explicitly rather than guessing.
- **`DayKey` generation**: Use `Calendar.dateComponents` + string interpolation, not `DateFormatter`.

See `PERFORMANCE_RATIONALE.md` for detailed before/after analysis of each optimization, and `.jules/sentinel.md` for the canonical lessons log.

## Task Management

- Write plans to `tasks/todo.md` with checkable items before starting non-trivial work.
- Log corrections and new patterns to `tasks/lessons.md` after any mistake.
- Treat `README.md` (repo root) as the product/changelog source of truth; `Learn/README.md` covers app-target implementation notes only.

## Feature Flags

Before enabling dormant code paths, confirm:
- **CloudKit**: `AppConfig.isCloudKitFeatureEnabled` — keep `false` until provisioning is confirmed.
- **Sign in with Apple**: `AuthenticationManager.isAppleSignInEnabled` — keep `false` for local development.
- **Debug export**: guarded by `#if DEBUG` — must not reach release builds.
