# Learn App Target Notes

Last updated: 20 Apr 2026

This directory contains the BorderLog iOS app target. The canonical product and changelog document is the repo-root `README.md`; this file tracks implementation notes that are specific to the app target.

## Current Runtime Posture

- Persistence is local-first through SwiftData, with the primary store in the configured App Group when available so the widget and app can share travel data.
- CloudKit code paths remain feature-gated by `AppConfig.isCloudKitFeatureEnabled == false` until provisioning and release policy are confirmed.
- Debug data export is available only in `DEBUG` builds. It intentionally contains full-fidelity diagnostic data and is not a release audit/export feature.
- Reset All Data clears SwiftData entities, keychain-backed local profile/session values, and pending widget location snapshots in shared defaults.
- Keychain-backed profile/session values use device-bound accessibility while the device is unlocked.

## User-Facing App Areas

- `MainNavigationView.swift`: tab shell, onboarding gate, launch-time ingestion/bootstrap.
- `DashboardView.swift`: Schengen and country summaries.
- `CalendarTabView.swift`: calendar evidence review and monthly country summaries.
- `Learn/ContentView.swift`: daily ledger preview and manual stay entry.
- `SettingsView.swift`: permissions, privacy controls, reset, feature toggles, shared day-counting mode, and debug-only export.
- `WelcomeView.swift`, `ProfileSetupView.swift`, `PermissionsRequestView.swift`: onboarding pages.

## Verification

Run the app target from `Learn.xcodeproj`. For code changes, prefer targeted unit tests first, then an iOS simulator build. Use an explicit available simulator destination from `xcodebuild -showdestinations`, or `Any iOS Simulator Device` when only compilation is needed.
