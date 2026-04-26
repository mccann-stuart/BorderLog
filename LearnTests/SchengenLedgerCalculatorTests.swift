#if canImport(XCTest)
import XCTest
import Foundation
@testable import Learn

final class SchengenLedgerCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return cal
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        return calendar.date(from: comps)!
    }

    private func allocatedPresenceDay(
        dayKey: String,
        date: Date,
        allocations: [ContributedCountry]
    ) -> PresenceDay {
        PresenceDay(
            dayKey: dayKey,
            date: date,
            timeZoneId: calendar.timeZone.identifier,
            contributedCountries: allocations,
            zoneOverlays: [],
            evidence: [],
            confidence: allocations.first?.probability ?? 0,
            confidenceLabel: allocations.isEmpty ? .low : .medium,
            sources: .location,
            isOverride: false,
            stayCount: 0,
            photoCount: 0,
            locationCount: 1
        )
    }

    func testSchengenLedgerCountsAndUnknown() {
        let ref = day(2026, 2, 15)
        let day1 = PresenceDay(
            dayKey: "2026-02-15",
            date: ref,
            timeZoneId: calendar.timeZone.identifier,
            countryCode: "ES",
            countryName: "Spain",
            confidence: 0.9,
            confidenceLabel: .high,
            sources: [.stay],
            isOverride: false,
            stayCount: 1,
            photoCount: 0,
            locationCount: 0
        )

        let summary = SchengenLedgerCalculator.summary(for: [day1], asOf: ref, calendar: calendar)
        XCTAssertEqual(summary.usedDays, 1)
        XCTAssertEqual(summary.unknownDays, 179)
    }

    func testSchengenLedgerCountsNameOnlySchengenDay() {
        let ref = day(2026, 2, 15)
        let spainName = Locale.autoupdatingCurrent.localizedString(forRegionCode: "ES") ?? "Spain"
        let day1 = PresenceDay(
            dayKey: "2026-02-15",
            date: ref,
            timeZoneId: calendar.timeZone.identifier,
            countryCode: nil,
            countryName: spainName,
            confidence: 0.9,
            confidenceLabel: .medium,
            sources: .none,
            isOverride: false,
            stayCount: 0,
            photoCount: 0,
            locationCount: 0
        )

        let summary = SchengenLedgerCalculator.summary(for: [day1], asOf: ref, calendar: calendar)
        XCTAssertEqual(summary.usedDays, 1)
        XCTAssertEqual(summary.unknownDays, 179)
    }

    func testSchengenLedgerDoubleCountIncludesSecondarySchengenCountry() {
        let ref = day(2026, 2, 15)
        let day1 = allocatedPresenceDay(
            dayKey: "2026-02-15",
            date: ref,
            allocations: [
                ContributedCountry(countryCode: "GB", countryName: "United Kingdom", probability: 0.51),
                ContributedCountry(countryCode: "FR", countryName: "France", probability: 0.49)
            ]
        )

        let resolvedSummary = SchengenLedgerCalculator.summary(
            for: [day1],
            asOf: ref,
            calendar: calendar,
            countingMode: .resolvedCountry
        )
        XCTAssertEqual(resolvedSummary.usedDays, 0)
        XCTAssertEqual(resolvedSummary.unknownDays, 179)

        let doubleCountSummary = SchengenLedgerCalculator.summary(
            for: [day1],
            asOf: ref,
            calendar: calendar,
            countingMode: .doubleCountDays
        )
        XCTAssertEqual(doubleCountSummary.usedDays, 1)
        XCTAssertEqual(doubleCountSummary.unknownDays, 179)
    }

    func testSchengenLedgerDoubleCountCountsMultipleSchengenCountriesOncePerDay() {
        let ref = day(2026, 2, 15)
        let day1 = allocatedPresenceDay(
            dayKey: "2026-02-15",
            date: ref,
            allocations: [
                ContributedCountry(countryCode: "FR", countryName: "France", probability: 0.51),
                ContributedCountry(countryCode: "DE", countryName: "Germany", probability: 0.49)
            ]
        )

        let summary = SchengenLedgerCalculator.summary(
            for: [day1],
            asOf: ref,
            calendar: calendar,
            countingMode: .doubleCountDays
        )
        XCTAssertEqual(summary.usedDays, 1)
        XCTAssertEqual(summary.unknownDays, 179)
    }
}
#endif
