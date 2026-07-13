# Calendar source selection

- [x] Add a testable persisted calendar-source selection model and resolution logic.
- [x] Filter EventKit ingestion by the effective selection and support retryable full rebuilds.
- [x] Add the Calendar Sources settings screen and immediate Apply workflow.
- [x] Update product, privacy, and app-target documentation.
- [x] Add targeted unit coverage for persistence, resolution, and rebuild behaviour.
- [x] Run targeted tests, full tests, simulator build, and diff review.

## Review

- Added an AppConfig-backed all/custom calendar preference with safe identifier remapping, unavailable-reference retention, and an explicit pending-rebuild marker.
- Added a full-access-only Calendar Sources screen with account grouping, colour indicators, duplicate-title labels, Select All, Deselect All, draft changes, and explicit Apply.
- Applying serialises a two-year calendar-only evidence rebuild through `LedgerRefreshCoordinator`; incomplete work remains marked for launch-time retry.
- Targeted calendar tests passed: 20 tests, 0 failures. Host-side preference checks also passed.
- The complete simulator test bundle built successfully. The full run passed 235 of 237 unit tests and all 4 UI tests; two `LedgerRecomputeServiceTests` disputed-country tests still fail with four assertions in code outside the calendar-selection change set.
- `git diff --check` passed and the final diff was reviewed for scope.
