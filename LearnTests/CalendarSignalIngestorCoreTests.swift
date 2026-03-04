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
}
