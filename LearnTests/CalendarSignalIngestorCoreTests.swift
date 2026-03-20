import XCTest
import SwiftData
import CoreLocation
@testable import Learn

final class CalendarSignalIngestorCoreTests: XCTestCase {
    private final class StubResolver: CountryResolving {
        func resolveCountry(for location: CLLocation) async -> CountryResolution? {
            nil
        }
    }

    private func makeIngestor() throws -> CalendarSignalIngestor {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CalendarSignal.self, configurations: config)
        return CalendarSignalIngestor(modelContainer: container, resolver: StubResolver())
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

    func testPrimarySignalSelectionUsesDestinationAndEndDateWhenDestinationExists() async throws {
        let ingestor = try makeIngestor()
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)

        let selection = await ingestor.testPrimarySignalSelection(
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
        XCTAssertFalse(selection.usesCoordinate)
    }

    func testPrimarySignalSelectionFallsBackToStructuredOriginWhenNoDestination() async throws {
        let ingestor = try makeIngestor()
        let start = Date(timeIntervalSince1970: 1_000)

        let selection = await ingestor.testPrimarySignalSelection(
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
        XCTAssertTrue(selection.usesCoordinate)
    }

    func testShouldPersistOriginSignalForOvernightDestinationFlight() async throws {
        let ingestor = try makeIngestor()
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 90_000)

        let shouldPersist = await ingestor.testShouldPersistOriginSignal(
            originDayKey: "2026-03-09",
            destinationDayKey: "2026-03-10",
            eventStartDate: start,
            eventEndDate: end,
            eventTimeZoneId: "Europe/London"
        )

        XCTAssertTrue(shouldPersist)
    }

    func testDoesNotPersistOriginSignalWhenDestinationResolvesToSameDay() async throws {
        let ingestor = try makeIngestor()
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)

        let shouldPersist = await ingestor.testShouldPersistOriginSignal(
            originDayKey: "2026-03-09",
            destinationDayKey: "2026-03-09",
            eventStartDate: start,
            eventEndDate: end,
            eventTimeZoneId: "Europe/London"
        )

        XCTAssertFalse(shouldPersist)
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
