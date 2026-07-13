//
//  CalendarSourceSelectionTests.swift
//  LearnTests
//

import XCTest
@testable import Learn

final class CalendarSourceSelectionTests: XCTestCase {
    func testAbsentPreferenceDefaultsToAllCalendars() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(store.load(), .all)
        XCTAssertFalse(store.needsRebuild)
    }

    func testExplicitEmptySelectionRoundTripsAsNone() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        try store.save(.selected([]), markingRebuild: false)

        XCTAssertEqual(store.load(), .selected([]))
        XCTAssertEqual(store.load().summary, "None")
        XCTAssertTrue(store.load().resolve(available: [workCalendar]).selectedIdentifiers.isEmpty)
    }

    func testCustomSelectionRoundTripsAcrossStoreInstances() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let selection = CalendarSourceSelection.selected([workCalendar, personalCalendar])

        try store.save(selection, markingRebuild: false)

        XCTAssertEqual(CalendarSourceSelectionStore(defaults: defaults).load(), selection)
        XCTAssertEqual(selection.summary, "2 selected")
    }

    func testAllSelectionIncludesCalendarsAddedAfterPreferenceWasCreated() {
        let originalResolution = CalendarSourceSelection.all.resolve(available: [workCalendar])
        let laterResolution = CalendarSourceSelection.all.resolve(
            available: [workCalendar, personalCalendar]
        )

        XCTAssertEqual(originalResolution.selectedIdentifiers, [workCalendar.identifier])
        XCTAssertEqual(
            laterResolution.selectedIdentifiers,
            [workCalendar.identifier, personalCalendar.identifier]
        )
        XCTAssertEqual(laterResolution.migratedSelection, .all)
    }

    func testCustomSelectionDoesNotIncludeCalendarsAddedLater() {
        let selection = CalendarSourceSelection.selected([workCalendar])

        let resolution = selection.resolve(available: [workCalendar, personalCalendar])

        XCTAssertEqual(resolution.selectedIdentifiers, [workCalendar.identifier])
        XCTAssertEqual(resolution.migratedSelection, selection)
        XCTAssertTrue(resolution.unavailableReferences.isEmpty)
    }

    func testChangedIdentifierRemapsWhenSourceAndTitleMatchUniquely() {
        let previousReference = CalendarSourceReference(
            identifier: "old-work-id",
            title: workCalendar.title,
            sourceIdentifier: workCalendar.sourceIdentifier,
            sourceTitle: workCalendar.sourceTitle
        )

        let resolution = CalendarSourceSelection.selected([previousReference]).resolve(
            available: [workCalendar, personalCalendar]
        )

        XCTAssertEqual(resolution.selectedIdentifiers, [workCalendar.identifier])
        XCTAssertEqual(resolution.migratedSelection, .selected([workCalendar]))
        XCTAssertTrue(resolution.unavailableReferences.isEmpty)
    }

    func testAmbiguousFallbackRemainsUnavailableAndRetained() {
        let previousReference = CalendarSourceReference(
            identifier: "old-shared-id",
            title: "Shared",
            sourceIdentifier: "icloud",
            sourceTitle: "iCloud"
        )
        let firstMatch = CalendarSourceReference(
            identifier: "shared-a",
            title: "Shared",
            sourceIdentifier: "icloud",
            sourceTitle: "iCloud"
        )
        let secondMatch = CalendarSourceReference(
            identifier: "shared-b",
            title: "Shared",
            sourceIdentifier: "icloud",
            sourceTitle: "iCloud"
        )

        let resolution = CalendarSourceSelection.selected([previousReference]).resolve(
            available: [firstMatch, secondMatch]
        )

        XCTAssertTrue(resolution.selectedIdentifiers.isEmpty)
        XCTAssertEqual(resolution.migratedSelection, .selected([previousReference]))
        XCTAssertEqual(resolution.unavailableReferences, [previousReference])
    }

    func testMissingCalendarRemainsUnavailableAndRetained() {
        let resolution = CalendarSourceSelection.selected([workCalendar]).resolve(
            available: [personalCalendar]
        )

        XCTAssertTrue(resolution.selectedIdentifiers.isEmpty)
        XCTAssertEqual(resolution.migratedSelection, .selected([workCalendar]))
        XCTAssertEqual(resolution.unavailableReferences, [workCalendar])
    }

    func testPendingRebuildMarkerPersistsUntilCompleted() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        try store.save(.selected([workCalendar]), markingRebuild: true)

        let relaunchedStore = CalendarSourceSelectionStore(defaults: defaults)
        XCTAssertTrue(relaunchedStore.needsRebuild)

        // A metadata-only identifier migration must not clear pending rebuild work.
        try relaunchedStore.save(.selected([workCalendar]), markingRebuild: false)
        XCTAssertTrue(relaunchedStore.needsRebuild)

        relaunchedStore.markRebuildCompleted()
        XCTAssertFalse(relaunchedStore.needsRebuild)
    }

    func testApplyStateRequiresAccessAndAChangedDraft() {
        XCTAssertTrue(
            CalendarSourceSelectionViewState.canApply(
                draft: .selected([]),
                applied: .all,
                hasReadAccess: true,
                isApplying: false
            )
        )
        XCTAssertFalse(
            CalendarSourceSelectionViewState.canApply(
                draft: .all,
                applied: .all,
                hasReadAccess: true,
                isApplying: false
            )
        )
        XCTAssertFalse(
            CalendarSourceSelectionViewState.canApply(
                draft: .selected([]),
                applied: .all,
                hasReadAccess: false,
                isApplying: false
            )
        )
        XCTAssertFalse(
            CalendarSourceSelectionViewState.canApply(
                draft: .selected([]),
                applied: .all,
                hasReadAccess: true,
                isApplying: true
            )
        )
    }

    func testDuplicateTitlesWithinAnAccountReceiveDeterministicLabels() {
        let first = CalendarSourceReference(
            identifier: "calendar-a",
            title: "Travel",
            sourceIdentifier: "icloud",
            sourceTitle: "iCloud"
        )
        let second = CalendarSourceReference(
            identifier: "calendar-b",
            title: "Travel",
            sourceIdentifier: "icloud",
            sourceTitle: "iCloud"
        )

        XCTAssertEqual(
            CalendarSourceSelectionViewState.duplicateTitleLabel(
                for: first,
                among: [second, first, personalCalendar]
            ),
            "Calendar 1"
        )
        XCTAssertEqual(
            CalendarSourceSelectionViewState.duplicateTitleLabel(
                for: second,
                among: [second, first, personalCalendar]
            ),
            "Calendar 2"
        )
        XCTAssertNil(
            CalendarSourceSelectionViewState.duplicateTitleLabel(
                for: personalCalendar,
                among: [second, first, personalCalendar]
            )
        )
    }

    private var workCalendar: CalendarSourceReference {
        CalendarSourceReference(
            identifier: "work-calendar",
            title: "Work",
            sourceIdentifier: "exchange",
            sourceTitle: "Work Account"
        )
    }

    private var personalCalendar: CalendarSourceReference {
        CalendarSourceReference(
            identifier: "personal-calendar",
            title: "Personal",
            sourceIdentifier: "icloud",
            sourceTitle: "iCloud"
        )
    }

    private func makeStore() throws -> (CalendarSourceSelectionStore, UserDefaults, String) {
        let suiteName = "CalendarSourceSelectionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (CalendarSourceSelectionStore(defaults: defaults), defaults, suiteName)
    }
}
