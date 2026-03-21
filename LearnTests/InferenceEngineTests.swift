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

    private func localizedCountryName(_ code: String) -> String {
        Locale.autoupdatingCurrent.localizedString(forRegionCode: code) ?? code
    }

    func testOverrideWinsOverSignals() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)

        let overrides = [
            OverridePresenceInfo(
                dayKey: dayKey,
                dayTimeZoneId: calendar.timeZone.identifier,
                countryCode: "FR",
                countryName: "France"
            )
        ]
        let photos = [PhotoSignalInfo(dayKey: dayKey, countryCode: "ES", countryName: "Spain", timeZoneId: nil)]
        let locations = [LocationSignalInfo(dayKey: dayKey, countryCode: "ES", countryName: "Spain", accuracyMeters: 10, timeZoneId: nil)]

        let results = PresenceInferenceEngine.compute(
            dayKeys: [dayKey],
            stays: [],
            overrides: overrides,
            locations: locations,
            photos: photos, calendarSignals: [],
            rangeEnd: date,
            calendar: calendar
        )

        XCTAssertEqual(results.first?.contributedCountries.first?.countryCode, "FR")
        XCTAssertEqual(results.first?.isOverride, true)
        XCTAssertTrue(results.first?.evidence.contains(where: { $0.source == "override" }) == true)
        XCTAssertTrue(results.first?.evidence.contains(where: { $0.source == "photo" }) == true)
    }

    func testUnknownWhenScoreBelowThreshold() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)
        let locations = [LocationSignalInfo(dayKey: dayKey, countryCode: "ES", countryName: "Spain", accuracyMeters: 10000, timeZoneId: nil)] // Adds +0.6

        let results = PresenceInferenceEngine.compute(
            dayKeys: [dayKey],
            stays: [],
            overrides: [],
            locations: locations,
            photos: [], calendarSignals: [],
            rangeEnd: date,
            calendar: calendar
        )

        XCTAssertTrue(results.first?.contributedCountries.isEmpty == true)
        XCTAssertEqual(results.first?.confidenceLabel, .low)
        // Ensure evidence still surfaces transparently even if unknown
        XCTAssertEqual(results.first?.evidence.first?.countryCode, "ES")
    }

    func testNuancedTransitDayAllocatesProbability() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)
        let locations = [
            LocationSignalInfo(dayKey: dayKey, countryCode: "FR", countryName: "France", accuracyMeters: 10, timeZoneId: nil), // 3.0
            LocationSignalInfo(dayKey: dayKey, countryCode: "FR", countryName: "France", accuracyMeters: 10, timeZoneId: nil), // 3.0
            LocationSignalInfo(dayKey: dayKey, countryCode: "ES", countryName: "Spain", accuracyMeters: 10, timeZoneId: nil)  // 3.0
        ]

        let results = PresenceInferenceEngine.compute(
            dayKeys: [dayKey],
            stays: [],
            overrides: [],
            locations: locations,
            photos: [],
            calendarSignals: [],
            rangeEnd: date,
            calendar: calendar
        )
        
        let contributed = results.first?.contributedCountries ?? []
        XCTAssertEqual(contributed.count, 2)
        XCTAssertEqual(contributed[0].countryCode, "FR")
        XCTAssertEqual(contributed[1].countryCode, "ES")
        XCTAssertEqual(contributed[0].probability, 6.0 / 9.0, accuracy: 0.01)
        XCTAssertEqual(contributed[1].probability, 3.0 / 9.0, accuracy: 0.01)
        
        let evidence = results.first?.evidence ?? []
        XCTAssertEqual(evidence.count, 3)
    }

    func testDisputedWhenConfidenceDeltaSmall() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)
        let photos = [
            PhotoSignalInfo(dayKey: dayKey, countryCode: "FR", countryName: "France", timeZoneId: nil),
            PhotoSignalInfo(dayKey: dayKey, countryCode: "FR", countryName: "France", timeZoneId: nil),
            PhotoSignalInfo(dayKey: dayKey, countryCode: "ES", countryName: "Spain", timeZoneId: nil)
        ]

        let results = PresenceInferenceEngine.compute(
            dayKeys: [dayKey],
            stays: [],
            overrides: [],
            locations: [],
            photos: photos, calendarSignals: [],
            rangeEnd: date,
            calendar: calendar
        )

        XCTAssertEqual(results.first?.contributedCountries.first?.countryCode, "FR")
        XCTAssertEqual(results.first?.isDisputed, true)
    }

    func testDeterministicTimeZoneSelectionWhenScoresTie() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)

        let photos = [
            PhotoSignalInfo(dayKey: dayKey, countryCode: "FR", countryName: "France", timeZoneId: "UTC"),
            PhotoSignalInfo(dayKey: dayKey, countryCode: "FR", countryName: "France", timeZoneId: "Europe/Paris")
        ]

        let results = PresenceInferenceEngine.compute(
            dayKeys: [dayKey],
            stays: [],
            overrides: [],
            locations: [],
            photos: photos,
            calendarSignals: [],
            rangeEnd: date,
            calendar: calendar
        )

        XCTAssertEqual(results.first?.timeZoneId, "Europe/Paris")
    }

    func testBridgesSevenDayVoidWhenCanonicalCountriesMatch() {
        let start = day(2026, 2, 1)
        let end = day(2026, 2, 9)
        let dayKeys = Set((1...9).map { day in
            DayKey.make(from: self.day(2026, 2, day), timeZone: calendar.timeZone)
        })
        let spainName = localizedCountryName("ES")

        let photos = [
            PhotoSignalInfo(
                dayKey: DayKey.make(from: start, timeZone: calendar.timeZone),
                countryCode: nil,
                countryName: spainName,
                timeZoneId: "UTC"
            ),
            PhotoSignalInfo(
                dayKey: DayKey.make(from: end, timeZone: calendar.timeZone),
                countryCode: "ES",
                countryName: spainName,
                timeZoneId: "UTC"
            )
        ]

        let results = PresenceInferenceEngine.compute(
            dayKeys: dayKeys,
            stays: [],
            overrides: [],
            locations: [],
            photos: photos,
            calendarSignals: [],
            rangeEnd: end,
            calendar: calendar
        )

        let bridgedKeys = (2...8).map { day in
            DayKey.make(from: self.day(2026, 2, day), timeZone: calendar.timeZone)
        }

        for key in bridgedKeys {
            let result = results.first { $0.dayKey == key }
            XCTAssertEqual(result?.contributedCountries.first?.countryCode, "ES")
            XCTAssertEqual(result?.contributedCountries.first?.countryName, spainName)
            XCTAssertEqual(result?.confidenceLabel, .medium)
            XCTAssertTrue(result?.evidence.contains(where: { $0.source == "GapBridgingContext" }) == true)
        }
    }

    func testDoesNotBridgeEightDayVoidWhenCountriesMatch() {
        let start = day(2026, 2, 1)
        let end = day(2026, 2, 10)
        let dayKeys = Set((1...10).map { day in
            DayKey.make(from: self.day(2026, 2, day), timeZone: calendar.timeZone)
        })
        let spainName = localizedCountryName("ES")

        let photos = [
            PhotoSignalInfo(
                dayKey: DayKey.make(from: start, timeZone: calendar.timeZone),
                countryCode: nil,
                countryName: spainName,
                timeZoneId: "UTC"
            ),
            PhotoSignalInfo(
                dayKey: DayKey.make(from: end, timeZone: calendar.timeZone),
                countryCode: "ES",
                countryName: spainName,
                timeZoneId: "UTC"
            )
        ]

        let results = PresenceInferenceEngine.compute(
            dayKeys: dayKeys,
            stays: [],
            overrides: [],
            locations: [],
            photos: photos,
            calendarSignals: [],
            rangeEnd: end,
            calendar: calendar
        )

        let unresolvedKeys = (2...9).map { day in
            DayKey.make(from: self.day(2026, 2, day), timeZone: calendar.timeZone)
        }

        for key in unresolvedKeys {
            let result = results.first { $0.dayKey == key }
            XCTAssertTrue(result?.contributedCountries.isEmpty == true)
        }
    }

    func testOvernightOriginFlightPromotesDepartureDayAndPreviousUnknownDay() {
        let previousDate = day(2026, 2, 1)
        let departureDate = day(2026, 2, 2)
        let arrivalDate = day(2026, 2, 3)

        let previousDayKey = DayKey.make(from: previousDate, timeZone: calendar.timeZone)
        let departureDayKey = DayKey.make(from: departureDate, timeZone: calendar.timeZone)
        let arrivalDayKey = DayKey.make(from: arrivalDate, timeZone: calendar.timeZone)

        let results = PresenceInferenceEngine.compute(
            dayKeys: [previousDayKey, departureDayKey, arrivalDayKey],
            stays: [],
            overrides: [],
            locations: [],
            photos: [],
            calendarSignals: [
                CalendarSignalInfo(
                    dayKey: departureDayKey,
                    countryCode: "GB",
                    countryName: localizedCountryName("GB"),
                    timeZoneId: "Europe/London",
                    bucketingTimeZoneId: "Europe/London",
                    eventIdentifier: "flight-overnight#origin",
                    source: "CalendarFlightOrigin"
                ),
                CalendarSignalInfo(
                    dayKey: arrivalDayKey,
                    countryCode: "US",
                    countryName: localizedCountryName("US"),
                    timeZoneId: "America/New_York",
                    bucketingTimeZoneId: "America/New_York",
                    eventIdentifier: "flight-overnight",
                    source: "Calendar"
                )
            ],
            rangeEnd: arrivalDate,
            calendar: calendar
        )

        let previous = results.first { $0.dayKey == previousDayKey }
        XCTAssertEqual(previous?.contributedCountries.first?.countryCode, "GB")
        XCTAssertEqual(previous?.confidenceLabel, .medium)
        XCTAssertTrue(previous?.sources.contains(.calendar) == true)
        XCTAssertTrue(previous?.evidence.contains(where: { $0.source == "CalendarFlightOriginPromotion" }) == true)

        let departure = results.first { $0.dayKey == departureDayKey }
        XCTAssertEqual(departure?.contributedCountries.first?.countryCode, "GB")
        XCTAssertEqual(departure?.confidenceLabel, .medium)
        XCTAssertTrue(departure?.sources.contains(.calendar) == true)

        let arrival = results.first { $0.dayKey == arrivalDayKey }
        XCTAssertEqual(arrival?.contributedCountries.first?.countryCode, "US")
    }

    func testSameDateOriginFlightPromotesFlightDayAndPreviousUnknownDay() {
        let previousDate = day(2026, 3, 14)
        let flightDate = day(2026, 3, 15)

        let previousDayKey = DayKey.make(from: previousDate, timeZone: calendar.timeZone)
        let flightDayKey = DayKey.make(from: flightDate, timeZone: calendar.timeZone)

        let results = PresenceInferenceEngine.compute(
            dayKeys: [previousDayKey, flightDayKey],
            stays: [],
            overrides: [],
            locations: [],
            photos: [],
            calendarSignals: [
                CalendarSignalInfo(
                    dayKey: flightDayKey,
                    countryCode: "GB",
                    countryName: localizedCountryName("GB"),
                    timeZoneId: "Europe/London",
                    bucketingTimeZoneId: "Europe/London",
                    eventIdentifier: "flight-same-day#origin",
                    source: "CalendarFlightOrigin"
                ),
                CalendarSignalInfo(
                    dayKey: flightDayKey,
                    countryCode: "US",
                    countryName: localizedCountryName("US"),
                    timeZoneId: "America/Los_Angeles",
                    bucketingTimeZoneId: "America/Los_Angeles",
                    eventIdentifier: "flight-same-day",
                    source: "Calendar"
                )
            ],
            rangeEnd: flightDate,
            calendar: calendar
        )

        let previous = results.first { $0.dayKey == previousDayKey }
        XCTAssertEqual(previous?.contributedCountries.first?.countryCode, "GB")
        XCTAssertEqual(previous?.confidenceLabel, .medium)
        XCTAssertEqual(previous?.timeZoneId, "Europe/London")

        let flightDay = results.first { $0.dayKey == flightDayKey }
        XCTAssertEqual(flightDay?.contributedCountries.first?.countryCode, "GB")
        XCTAssertEqual(flightDay?.confidenceLabel, .medium)
        XCTAssertEqual(flightDay?.timeZoneId, "Europe/London")
    }
}
#endif
