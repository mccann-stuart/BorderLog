#if canImport(XCTest)
import XCTest
import Foundation
@testable import Learn

final class InferenceEngineTests: XCTestCase {
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

    func testOverrideWinsOverSignals() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)

        let overrides = [OverridePresenceInfo(date: date, countryCode: "FR", countryName: "France")]
        let photos = [PhotoSignalInfo(dayKey: dayKey, countryCode: "ES", countryName: "Spain", timeZoneId: nil)]
        let locations = [LocationSignalInfo(dayKey: dayKey, countryCode: "ES", countryName: "Spain", accuracyMeters: 10, timeZoneId: nil)]

        let results = PresenceInferenceEngine.compute(
            dayKeys: [dayKey],
            stays: [],
            overrides: overrides,
            locations: locations,
            photos: photos,
            rangeEnd: date,
            calendar: calendar
        )

        XCTAssertEqual(results.first?.countryCode, "FR")
        XCTAssertEqual(results.first?.isOverride, true)
    }

    func testUnknownWhenScoreBelowThreshold() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)
        let locations = [LocationSignalInfo(dayKey: dayKey, countryCode: "ES", countryName: "Spain", accuracyMeters: 10000, timeZoneId: nil)]

        let results = PresenceInferenceEngine.compute(
            dayKeys: [dayKey],
            stays: [],
            overrides: [],
            locations: locations,
            photos: [],
            rangeEnd: date,
            calendar: calendar
        )

        XCTAssertNil(results.first?.countryCode)
        XCTAssertEqual(results.first?.confidenceLabel, .low)
    }
}
#endif
