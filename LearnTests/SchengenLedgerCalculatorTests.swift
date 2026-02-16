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
}
#endif
