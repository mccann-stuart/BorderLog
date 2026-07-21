import XCTest
import SwiftData
import CoreLocation
@testable import Learn


extension CalendarSignalIngestor {
    func testUpsertScenario(
        existingDayKey: String,
        resolved: ResolvedCalendarSignal
    ) -> (
        changed: Bool,
        touchedDayKeys: [String],
        finalDayKey: String,
        finalTimeZoneId: String?,
        finalBucketingTimeZoneId: String?
    ) {
        let existing = CalendarSignal(
            timestamp: Date(timeIntervalSince1970: 0),
            dayKey: existingDayKey,
            latitude: 0,
            longitude: 0,
            countryCode: "GB",
            countryName: "United Kingdom",
            timeZoneId: "UTC",
            bucketingTimeZoneId: "UTC",
            eventIdentifier: "event-1",
            title: "Old",
            source: "Calendar"
        )
        var map: [String: CalendarSignal] = ["event-1": existing]
        var touchedDayKeys = Set<String>()
        let changed = upsertSignal(
            identifier: "event-1",
            resolved: resolved,
            title: "New",
            existingSignalByIdentifier: &map,
            touchedDayKeys: &touchedDayKeys
        )
        let updated = map["event-1"] ?? existing
        return (
            changed: changed,
            touchedDayKeys: touchedDayKeys.sorted(),
            finalDayKey: updated.dayKey,
            finalTimeZoneId: updated.timeZoneId,
            finalBucketingTimeZoneId: updated.bucketingTimeZoneId
        )
    }

    func testDeleteScenario(existingDayKey: String) -> (deleted: Int, touchedDayKeys: [String], remaining: Int) {
        let existing = CalendarSignal(
            timestamp: Date(timeIntervalSince1970: 0),
            dayKey: existingDayKey,
            latitude: 0,
            longitude: 0,
            countryCode: "GB",
            countryName: "United Kingdom",
            timeZoneId: "UTC",
            bucketingTimeZoneId: "UTC",
            eventIdentifier: "event-2",
            title: "Old",
            source: "Calendar"
        )
        var map: [String: CalendarSignal] = ["event-2": existing]
        var touchedDayKeys = Set<String>()
        let deleted = deleteSignalIfExists(
            identifier: "event-2",
            existingSignalByIdentifier: &map,
            touchedDayKeys: &touchedDayKeys
        )
        return (deleted: deleted, touchedDayKeys: touchedDayKeys.sorted(), remaining: map.count)
    }

    func testOrphanCleanup(
        existingDayKeys: [String],
        seenIdentifiers: Set<String>
    ) -> (deleted: Int, touchedDayKeys: [String], remainingIdentifiers: [String]) {
        var existingSignalByIdentifier: [String: CalendarSignal] = [:]
        for (index, dayKey) in existingDayKeys.enumerated() {
            let identifier = "event-\(index)"
            existingSignalByIdentifier[identifier] = CalendarSignal(
                timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                dayKey: dayKey,
                latitude: 0,
                longitude: 0,
                countryCode: "GB",
                countryName: "United Kingdom",
                timeZoneId: "UTC",
                bucketingTimeZoneId: "UTC",
                eventIdentifier: identifier,
                title: "Event \(index)",
                source: "Calendar"
            )
        }

        var touchedDayKeys = Set<String>()
        let deleted = deleteOrphanedSignals(
            existingSignalByIdentifier: &existingSignalByIdentifier,
            seenIdentifiers: seenIdentifiers,
            touchedDayKeys: &touchedDayKeys
        )
        return (
            deleted: deleted,
            touchedDayKeys: touchedDayKeys.sorted(),
            remainingIdentifiers: existingSignalByIdentifier.keys.sorted()
        )
    }

    func testDestinationFirstLegacyEndCleanup(
        existingDayKey: String,
        resolved: ResolvedCalendarSignal
    ) -> (changed: Bool, deletedLegacyEnd: Int, remainingIdentifiers: [String]) {
        let legacyPrimary = CalendarSignal(
            timestamp: Date(timeIntervalSince1970: 0),
            dayKey: existingDayKey,
            latitude: 0,
            longitude: 0,
            countryCode: "GB",
            countryName: "United Kingdom",
            timeZoneId: "UTC",
            bucketingTimeZoneId: "UTC",
            eventIdentifier: "event-3",
            title: "Old",
            source: "Calendar"
        )
        let legacyEnd = CalendarSignal(
            timestamp: Date(timeIntervalSince1970: 0),
            dayKey: existingDayKey,
            latitude: 0,
            longitude: 0,
            countryCode: "DE",
            countryName: "Germany",
            timeZoneId: "UTC",
            bucketingTimeZoneId: "UTC",
            eventIdentifier: "event-3#end",
            title: "Old End",
            source: "Calendar"
        )
        var map: [String: CalendarSignal] = [
            "event-3": legacyPrimary,
            "event-3#end": legacyEnd
        ]
        var touchedDayKeys = Set<String>()
        let changed = upsertSignal(
            identifier: "event-3",
            resolved: resolved,
            title: "New",
            existingSignalByIdentifier: &map,
            touchedDayKeys: &touchedDayKeys
        )
        let deletedLegacyEnd = deleteSignalIfExists(
            identifier: "event-3#end",
            existingSignalByIdentifier: &map,
            touchedDayKeys: &touchedDayKeys
        )
        return (
            changed: changed,
            deletedLegacyEnd: deletedLegacyEnd,
            remainingIdentifiers: map.keys.sorted()
        )
    }
}

final class CalendarSignalIngestorCoreTests: XCTestCase {
    private final class StubResolver: CountryResolving {
        func resolveCountry(for location: CLLocation) async -> CountryResolution? {
            nil
        }
    }

    private func makeIngestor(
        calendarSelectionStore: CalendarSourceSelectionStore = .shared
    ) throws -> CalendarSignalIngestor {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CalendarSignal.self, configurations: config)
        return CalendarSignalIngestor(
            modelContainer: container,
            resolver: StubResolver(),
            calendarSelectionStore: calendarSelectionStore
        )
    }

    func testUpsertScenarioUpdatesExistingSignalAndTouchesOldAndNewDayKeys() async throws {
        let ingestor = try makeIngestor()
        let resolved = CalendarSignalIngestor.ResolvedCalendarSignal(
            timestamp: Date(timeIntervalSince1970: 1_000),
            dayKey: "2026-03-02",
            timeZoneId: "Europe/Paris",
            bucketingTimeZoneId: "Europe/Paris",
            latitude: 48.8566,
            longitude: 2.3522,
            countryCode: "FR",
            countryName: "France"
        )

        let result = await ingestor.testUpsertScenario(
            existingDayKey: "2026-03-01",
            resolved: resolved
        )

        XCTAssertTrue(result.changed)
        XCTAssertEqual(result.touchedDayKeys, ["2026-03-01", "2026-03-02"])
        XCTAssertEqual(result.finalDayKey, "2026-03-02")
        XCTAssertEqual(result.finalTimeZoneId, "Europe/Paris")
        XCTAssertEqual(result.finalBucketingTimeZoneId, "Europe/Paris")
    }

    func testDeleteScenarioRemovesExistingSignalAndTouchesOldDayKey() async throws {
        let ingestor = try makeIngestor()
        let result = await ingestor.testDeleteScenario(existingDayKey: "2026-03-03")

        XCTAssertEqual(result.deleted, 1)
        XCTAssertEqual(result.touchedDayKeys, ["2026-03-03"])
        XCTAssertEqual(result.remaining, 0)
    }

    func testPendingSelectionRebuildUpgradesRequestedScanUntilCompleted() async throws {
        let suiteName = "CalendarSignalIngestorCoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let selectionStore = CalendarSourceSelectionStore(defaults: defaults)
        try selectionStore.save(.selected([]), markingRebuild: true)
        let ingestor = try makeIngestor(calendarSelectionStore: selectionStore)

        let pendingMode = await ingestor.effectiveIngestMode(for: .auto)
        XCTAssertEqual(pendingMode, .selectionRebuild)

        selectionStore.markRebuildCompleted()
        let completedMode = await ingestor.effectiveIngestMode(for: .auto)
        XCTAssertEqual(completedMode, .auto)
    }

    func testSelectionRebuildOrphanCleanupDeletesAllFetchedSignals() async throws {
        let ingestor = try makeIngestor()
        let result = await ingestor.testOrphanCleanup(
            existingDayKeys: ["2024-01-01", "2025-02-02", "2026-03-03"],
            seenIdentifiers: []
        )

        XCTAssertEqual(result.deleted, 3)
        XCTAssertEqual(result.touchedDayKeys, ["2024-01-01", "2025-02-02", "2026-03-03"])
        XCTAssertTrue(result.remainingIdentifiers.isEmpty)
    }

    func testPrimarySignalSelectionUsesDestinationAndEndDateWhenDestinationExists() async throws {
        let ingestor = try makeIngestor()
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)

        let selection = await ingestor.selectPrimarySignalInput(
            parsedFrom: nil,
            parsedTo: "MUC",
            eventStartDate: start,
            eventEndDate: end,
            structuredLocationTitle: "Manchester Airport",
            structuredCoordinate: CLLocationCoordinate2D(latitude: 53.3494, longitude: -2.2795),
            eventLocation: "Manchester MAN"
        )

        XCTAssertEqual(selection.locationString, "MUC")
        XCTAssertTrue(selection.usesDestinationRule)
        XCTAssertEqual(selection.date, end)
        XCTAssertFalse(selection.coordinate != nil)
    }

    func testPrimarySignalSelectionFallsBackToStructuredOriginWhenNoDestination() async throws {
        let ingestor = try makeIngestor()
        let start = Date(timeIntervalSince1970: 1_000)

        let selection = await ingestor.selectPrimarySignalInput(
            parsedFrom: nil,
            parsedTo: nil,
            eventStartDate: start,
            eventEndDate: nil,
            structuredLocationTitle: "Manchester Airport",
            structuredCoordinate: CLLocationCoordinate2D(latitude: 53.3494, longitude: -2.2795),
            eventLocation: "Manchester MAN"
        )

        XCTAssertEqual(selection.locationString, "Manchester Airport")
        XCTAssertFalse(selection.usesDestinationRule)
        XCTAssertEqual(selection.date, start)
        XCTAssertTrue(selection.coordinate != nil)
    }

    func testShouldPersistOriginSignalForOvernightDestinationFlight() async throws {
        let ingestor = try makeIngestor()
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 90_000)

        let originResolved = CalendarSignalIngestor.ResolvedCalendarSignal(
            timestamp: start,
            dayKey: "2026-03-09",
            timeZoneId: "UTC",
            bucketingTimeZoneId: "UTC",
            latitude: 0,
            longitude: 0,
            countryCode: "GB",
            countryName: "United Kingdom"
        )

        let shouldPersist = await ingestor.shouldPersistOriginSignal(originResolved: originResolved)

        XCTAssertTrue(shouldPersist)
    }

    func testPersistsOriginSignalWhenDestinationResolvesToSameDay() async throws {
        let ingestor = try makeIngestor()
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)

        let originResolved = CalendarSignalIngestor.ResolvedCalendarSignal(
            timestamp: start,
            dayKey: "2026-03-09",
            timeZoneId: "UTC",
            bucketingTimeZoneId: "UTC",
            latitude: 0,
            longitude: 0,
            countryCode: "GB",
            countryName: "United Kingdom"
        )

        let shouldPersist = await ingestor.shouldPersistOriginSignal(originResolved: originResolved)

        XCTAssertTrue(shouldPersist)
    }

    func testDestinationFirstLegacyEndCleanupRemovesStaleEndSignal() async throws {
        let ingestor = try makeIngestor()
        let resolved = CalendarSignalIngestor.ResolvedCalendarSignal(
            timestamp: Date(timeIntervalSince1970: 2_000),
            dayKey: "2026-03-10",
            timeZoneId: "Europe/Berlin",
            bucketingTimeZoneId: "Europe/Berlin",
            latitude: 48.3538,
            longitude: 11.7861,
            countryCode: "DE",
            countryName: "Germany"
        )

        let result = await ingestor.testDestinationFirstLegacyEndCleanup(
            existingDayKey: "2026-03-09",
            resolved: resolved
        )

        XCTAssertTrue(result.changed)
        XCTAssertEqual(result.deletedLegacyEnd, 1)
        XCTAssertEqual(result.remainingIdentifiers, ["event-3"])
    }

}
