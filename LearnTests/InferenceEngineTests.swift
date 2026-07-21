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

    private func travelSignal(
        dayKey: String,
        countryCode: String,
        timeZoneId: String,
        eventIdentifier: String,
        source: String
    ) -> CalendarSignalInfo {
        CalendarSignalInfo(
            dayKey: dayKey,
            countryCode: countryCode,
            countryName: localizedCountryName(countryCode),
            timeZoneId: timeZoneId,
            bucketingTimeZoneId: timeZoneId,
            eventIdentifier: eventIdentifier,
            source: source
        )
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

    func testLocationEvidenceTracksRawAndCalibratedWeights() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)
        let results = PresenceInferenceEngine.compute(
            dayKeys: [dayKey],
            stays: [],
            overrides: [],
            locations: [LocationSignalInfo(dayKey: dayKey, countryCode: "ES", countryName: "Spain", accuracyMeters: 10_000, timeZoneId: "UTC")],
            photos: [],
            calendarSignals: [],
            rangeEnd: date,
            calendar: calendar
        )

        guard let evidence = results.first?.evidence.first else {
            XCTFail("Expected calibrated location evidence")
            return
        }
        XCTAssertEqual(evidence.source, "location")
        XCTAssertEqual(evidence.phase, .base)
        XCTAssertEqual(evidence.rawWeight, 3.0, accuracy: 0.001)
        XCTAssertEqual(evidence.calibratedWeight, 0.6, accuracy: 0.001)
        XCTAssertFalse(evidence.contributedToFinalResult)
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

    func testResolvedDayMarksEvidenceForEveryRetainedAllocation() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)
        let results = PresenceInferenceEngine.compute(
            dayKeys: [dayKey],
            stays: [],
            overrides: [],
            locations: [],
            photos: [
                PhotoSignalInfo(dayKey: dayKey, countryCode: "FR", countryName: "France", timeZoneId: nil),
                PhotoSignalInfo(dayKey: dayKey, countryCode: "FR", countryName: "France", timeZoneId: nil),
                PhotoSignalInfo(dayKey: dayKey, countryCode: "ES", countryName: "Spain", timeZoneId: nil)
            ],
            calendarSignals: [],
            rangeEnd: date,
            calendar: calendar
        )

        let contributedCountries = results.first?.contributedCountries ?? []
        XCTAssertEqual(contributedCountries.map(\.countryCode), ["FR", "ES"])

        let evidence = results.first?.evidence ?? []
        XCTAssertEqual(evidence.count, 3)
        XCTAssertEqual(evidence.filter { $0.countryCode == "FR" && $0.contributedToFinalResult }.count, 2)
        XCTAssertTrue(evidence.contains(where: { $0.countryCode == "ES" && $0.contributedToFinalResult }))
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
        XCTAssertEqual(results.first?.confidenceLabel, .medium)
    }

    func testWeakLocationOnlyEvidenceCannotBeHighConfidence() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)

        let results = PresenceInferenceEngine.compute(
            dayKeys: [dayKey],
            stays: [],
            overrides: [],
            locations: [
                LocationSignalInfo(
                    dayKey: dayKey,
                    countryCode: "ES",
                    countryName: "Spain",
                    accuracyMeters: 101,
                    timeZoneId: nil
                )
            ],
            photos: [],
            calendarSignals: [],
            rangeEnd: date,
            calendar: calendar
        )

        XCTAssertEqual(results.first?.contributedCountries.first?.countryCode, "ES")
        XCTAssertEqual(results.first?.confidenceLabel, .medium)
        XCTAssertEqual(results.first?.locationCount, 1)
        XCTAssertTrue(results.first?.confidenceBreakdown.calibrationSummary.contains("weak-location-only") == true)
    }

    func testSameDayLocationBurstCannotBeHighConfidence() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)
        let locations = (0..<6).map { offset in
            LocationSignalInfo(
                dayKey: dayKey,
                countryCode: "ES",
                countryName: "Spain",
                accuracyMeters: 10,
                timeZoneId: nil,
                timestamp: date.addingTimeInterval(Double(offset)),
                sourceRaw: LocationSampleSource.app.rawValue
            )
        }

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

        XCTAssertEqual(results.first?.contributedCountries.first?.countryCode, "ES")
        XCTAssertEqual(results.first?.confidence ?? .nan, 1, accuracy: 0.001)
        XCTAssertEqual(results.first?.confidenceLabel, .medium)
        XCTAssertEqual(results.first?.locationCount, 6)
        XCTAssertEqual(results.first?.evidence.count, 6)
        XCTAssertTrue(results.first?.confidenceBreakdown.calibrationSummary.contains("correlated-location-burst") == true)
    }

    func testIndependentSameDayLocationsCanRemainHighConfidence() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)
        let locations = [
            LocationSignalInfo(
                dayKey: dayKey,
                countryCode: "ES",
                countryName: "Spain",
                accuracyMeters: 10,
                timeZoneId: nil,
                timestamp: date,
                sourceRaw: LocationSampleSource.app.rawValue
            ),
            LocationSignalInfo(
                dayKey: dayKey,
                countryCode: "ES",
                countryName: "Spain",
                accuracyMeters: 10,
                timeZoneId: nil,
                timestamp: date.addingTimeInterval(4 * 60 * 60),
                sourceRaw: LocationSampleSource.app.rawValue
            )
        ]

        let result = PresenceInferenceEngine.compute(
            dayKeys: [dayKey],
            stays: [],
            overrides: [],
            locations: locations,
            photos: [],
            calendarSignals: [],
            rangeEnd: date,
            calendar: calendar
        ).first

        XCTAssertEqual(result?.confidenceLabel, .high)
        XCTAssertFalse(result?.confidenceBreakdown.calibrationSummary.contains("correlated-location-burst") == true)
    }

    func testCorrelatedLocationBurstWithWeakMixedEvidenceCannotBeHighConfidence() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)
        let locations = (0..<2).map { offset in
            LocationSignalInfo(
                dayKey: dayKey,
                countryCode: "ES",
                countryName: "Spain",
                accuracyMeters: 10,
                timeZoneId: nil,
                timestamp: date.addingTimeInterval(Double(offset)),
                sourceRaw: LocationSampleSource.widget.rawValue
            )
        }
        let calendarSignal = CalendarSignalInfo(
            dayKey: dayKey,
            countryCode: "ES",
            countryName: "Spain",
            timeZoneId: nil,
            bucketingTimeZoneId: nil,
            source: "Calendar"
        )

        let result = PresenceInferenceEngine.compute(
            dayKeys: [dayKey],
            stays: [],
            overrides: [],
            locations: locations,
            photos: [],
            calendarSignals: [calendarSignal],
            rangeEnd: date,
            calendar: calendar
        ).first

        XCTAssertEqual(result?.confidenceLabel, .medium)
        XCTAssertTrue(result?.confidenceBreakdown.calibrationSummary.contains("correlated-location-burst") == true)
    }

    func testCorrelatedLocationBurstDoesNotCapIndependentStrongStay() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)
        let locations = (0..<2).map { offset in
            LocationSignalInfo(
                dayKey: dayKey,
                countryCode: "ES",
                countryName: "Spain",
                accuracyMeters: 10,
                timeZoneId: nil,
                timestamp: date.addingTimeInterval(Double(offset)),
                sourceRaw: LocationSampleSource.app.rawValue
            )
        }
        let stay = StayPresenceInfo(
            entryDayKey: dayKey,
            exitDayKey: dayKey,
            dayTimeZoneId: calendar.timeZone.identifier,
            countryCode: "ES",
            countryName: "Spain"
        )

        let result = PresenceInferenceEngine.compute(
            dayKeys: [dayKey],
            stays: [stay],
            overrides: [],
            locations: locations,
            photos: [],
            calendarSignals: [],
            rangeEnd: date,
            calendar: calendar
        ).first

        XCTAssertEqual(result?.confidenceLabel, .high)
        XCTAssertFalse(result?.confidenceBreakdown.calibrationSummary.contains("correlated-location-burst") == true)
    }

    func testZeroWeightContextCandidateDoesNotCapStrongBaseEvidence() {
        let date = day(2026, 2, 15)
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)
        let stay = StayPresenceInfo(
            entryDayKey: dayKey,
            exitDayKey: dayKey,
            dayTimeZoneId: calendar.timeZone.identifier,
            countryCode: "ES",
            countryName: "Spain"
        )
        let originCandidate = CalendarSignalInfo(
            dayKey: dayKey,
            countryCode: "ES",
            countryName: "Spain",
            timeZoneId: nil,
            bucketingTimeZoneId: nil,
            eventIdentifier: "trip#origin",
            source: "CalendarFlightOrigin"
        )

        let result = PresenceInferenceEngine.compute(
            dayKeys: [dayKey],
            stays: [stay],
            overrides: [],
            locations: [],
            photos: [],
            calendarSignals: [originCandidate],
            rangeEnd: date,
            calendar: calendar
        ).first

        XCTAssertEqual(result?.confidenceLabel, .high)
        XCTAssertFalse(result?.confidenceBreakdown.calibrationSummary.contains("contextual") == true)
        XCTAssertFalse(result?.evidence.first(where: { $0.source == "calendar.origin" })?.contributedToFinalResult == true)
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
        let calendar = self.calendar
        let start = day(2026, 2, 1)
        let end = day(2026, 2, 9)
        let dayKeys = Set((1...9).lazy.map { day in
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
        let calendar = self.calendar
        let start = day(2026, 2, 1)
        let end = day(2026, 2, 10)
        let dayKeys = Set((1...10).lazy.map { day in
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

    func testOvernightTravelPromotesPreviousAndDepartureDaysWithDistinctContext() {
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

        guard let previous = results.first(where: { $0.dayKey == previousDayKey }) else {
            XCTFail("Expected the day before departure to be promoted")
            return
        }
        XCTAssertEqual(previous.contributedCountries.first?.countryCode, "GB")
        XCTAssertEqual(previous.confidence, 0.85, accuracy: 0.001)
        XCTAssertEqual(previous.confidenceLabel, .medium)
        XCTAssertTrue(previous.confidenceBreakdown.calibrationSummary.contains("contextual") == true)
        XCTAssertTrue(previous.sources.contains(.calendar))
        XCTAssertTrue(previous.evidence.contains(where: { $0.source == "CalendarTravelBeforePromotion" }))

        guard let departure = results.first(where: { $0.dayKey == departureDayKey }) else {
            XCTFail("Expected the departure day to be promoted")
            return
        }
        XCTAssertEqual(departure.contributedCountries.first?.countryCode, "GB")
        XCTAssertEqual(departure.confidence, 0.55, accuracy: 0.001)
        XCTAssertEqual(departure.confidenceLabel, .medium)
        XCTAssertTrue(departure.sources.contains(.calendar))
        XCTAssertTrue(departure.evidence.contains(where: { $0.source == "CalendarFlightOriginPromotion" }))

        let arrival = results.first { $0.dayKey == arrivalDayKey }
        XCTAssertEqual(arrival?.contributedCountries.first?.countryCode, "US")
    }

    func testSameDateTravelKeepsDestinationOnFlightDayAndPromotesPreviousDayToOrigin() {
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

        guard let previous = results.first(where: { $0.dayKey == previousDayKey }) else {
            XCTFail("Expected the day before departure to be promoted")
            return
        }
        XCTAssertEqual(previous.contributedCountries.first?.countryCode, "GB")
        XCTAssertEqual(previous.confidence, 0.85, accuracy: 0.001)
        XCTAssertEqual(previous.confidenceLabel, .medium)
        XCTAssertEqual(previous.timeZoneId, "Europe/London")
        XCTAssertTrue(previous.evidence.contains(where: { $0.source == "CalendarTravelBeforePromotion" }))

        guard let flightDay = results.first(where: { $0.dayKey == flightDayKey }) else {
            XCTFail("Expected the flight day to remain resolved")
            return
        }
        XCTAssertEqual(flightDay.contributedCountries.first?.countryCode, "US")
        XCTAssertEqual(flightDay.confidenceLabel, .high)
        XCTAssertEqual(flightDay.timeZoneId, "America/Los_Angeles")
        XCTAssertTrue(flightDay.evidence.contains(where: {
            $0.countryCode == "GB" && !$0.contributedToFinalResult
        }))
    }

    func testTravelEventPromotesDayBeforeDepartureAndDayAfterArrival() {
        let dayBeforeDeparture = day(2026, 3, 9)
        let departureDay = day(2026, 3, 10)
        let arrivalDay = day(2026, 3, 11)
        let dayAfterArrival = day(2026, 3, 12)

        let dayBeforeDepartureKey = DayKey.make(from: dayBeforeDeparture, timeZone: calendar.timeZone)
        let departureDayKey = DayKey.make(from: departureDay, timeZone: calendar.timeZone)
        let arrivalDayKey = DayKey.make(from: arrivalDay, timeZone: calendar.timeZone)
        let dayAfterArrivalKey = DayKey.make(from: dayAfterArrival, timeZone: calendar.timeZone)

        let results = PresenceInferenceEngine.compute(
            dayKeys: [dayBeforeDepartureKey, departureDayKey, arrivalDayKey, dayAfterArrivalKey],
            stays: [],
            overrides: [],
            locations: [],
            photos: [],
            calendarSignals: [
                travelSignal(
                    dayKey: departureDayKey,
                    countryCode: "GB",
                    timeZoneId: "Europe/London",
                    eventIdentifier: "trip-1#origin",
                    source: "CalendarFlightOrigin"
                ),
                travelSignal(
                    dayKey: arrivalDayKey,
                    countryCode: "DE",
                    timeZoneId: "Europe/Berlin",
                    eventIdentifier: "trip-1",
                    source: "Calendar"
                )
            ],
            rangeEnd: dayAfterArrival,
            calendar: calendar
        )

        guard let before = results.first(where: { $0.dayKey == dayBeforeDepartureKey }) else {
            XCTFail("Expected day before departure to be promoted")
            return
        }
        XCTAssertEqual(before.contributedCountries.first?.countryCode, "GB")
        XCTAssertEqual(before.confidence, 0.85, accuracy: 0.001)
        XCTAssertEqual(before.confidenceLabel, .medium)
        XCTAssertTrue(before.sources.contains(.calendar))
        XCTAssertEqual(before.calendarCount, 1)
        XCTAssertTrue(before.evidence.contains(where: { $0.source == "CalendarTravelBeforePromotion" }))

        guard let after = results.first(where: { $0.dayKey == dayAfterArrivalKey }) else {
            XCTFail("Expected day after arrival to be promoted")
            return
        }
        XCTAssertEqual(after.contributedCountries.first?.countryCode, "DE")
        XCTAssertEqual(after.confidence, 0.85, accuracy: 0.001)
        XCTAssertEqual(after.confidenceLabel, .medium)
        XCTAssertTrue(after.sources.contains(.calendar))
        XCTAssertEqual(after.calendarCount, 1)
        XCTAssertTrue(after.evidence.contains(where: { $0.source == "CalendarTravelAfterPromotion" }))
    }

    func testTravelEventDoesNotReplaceOverrideOrResolvedNonCalendarDay() {
        let dayBeforeDeparture = day(2026, 3, 9)
        let departureDay = day(2026, 3, 10)
        let arrivalDay = day(2026, 3, 11)
        let dayAfterArrival = day(2026, 3, 12)

        let dayBeforeDepartureKey = DayKey.make(from: dayBeforeDeparture, timeZone: calendar.timeZone)
        let departureDayKey = DayKey.make(from: departureDay, timeZone: calendar.timeZone)
        let arrivalDayKey = DayKey.make(from: arrivalDay, timeZone: calendar.timeZone)
        let dayAfterArrivalKey = DayKey.make(from: dayAfterArrival, timeZone: calendar.timeZone)

        let results = PresenceInferenceEngine.compute(
            dayKeys: [dayBeforeDepartureKey, departureDayKey, arrivalDayKey, dayAfterArrivalKey],
            stays: [],
            overrides: [
                OverridePresenceInfo(
                    dayKey: dayBeforeDepartureKey,
                    dayTimeZoneId: calendar.timeZone.identifier,
                    countryCode: "FR",
                    countryName: localizedCountryName("FR")
                )
            ],
            locations: [
                LocationSignalInfo(
                    dayKey: dayAfterArrivalKey,
                    countryCode: "US",
                    countryName: localizedCountryName("US"),
                    accuracyMeters: 10,
                    timeZoneId: "America/New_York"
                )
            ],
            photos: [],
            calendarSignals: [
                travelSignal(
                    dayKey: departureDayKey,
                    countryCode: "GB",
                    timeZoneId: "Europe/London",
                    eventIdentifier: "trip-2#origin",
                    source: "CalendarFlightOrigin"
                ),
                travelSignal(
                    dayKey: arrivalDayKey,
                    countryCode: "DE",
                    timeZoneId: "Europe/Berlin",
                    eventIdentifier: "trip-2",
                    source: "Calendar"
                )
            ],
            rangeEnd: dayAfterArrival,
            calendar: calendar
        )

        let before = results.first { $0.dayKey == dayBeforeDepartureKey }
        XCTAssertEqual(before?.contributedCountries.first?.countryCode, "FR")
        XCTAssertTrue(before?.isOverride == true)
        XCTAssertFalse(before?.evidence.contains(where: { $0.source == "CalendarTravelBeforePromotion" }) == true)

        let after = results.first { $0.dayKey == dayAfterArrivalKey }
        XCTAssertEqual(after?.contributedCountries.first?.countryCode, "US")
        XCTAssertFalse(after?.evidence.contains(where: { $0.source == "CalendarTravelAfterPromotion" }) == true)
    }

    func testTravelBackedTransitionInfillPromotesMarch2026GapsAndKeepsSuggestions() {
        let calendar = self.calendar
        let dayKeys = Set((6...15).lazy.map { day in
            DayKey.make(from: self.day(2026, 3, day), timeZone: calendar.timeZone)
        })

        let results = PresenceInferenceEngine.compute(
            dayKeys: dayKeys,
            stays: [],
            overrides: [],
            locations: [],
            photos: [],
            calendarSignals: [
                travelSignal(
                    dayKey: DayKey.make(from: day(2026, 3, 6), timeZone: calendar.timeZone),
                    countryCode: "GB",
                    timeZoneId: "Europe/London",
                    eventIdentifier: "trip-a#origin",
                    source: "CalendarFlightOrigin"
                ),
                travelSignal(
                    dayKey: DayKey.make(from: day(2026, 3, 10), timeZone: calendar.timeZone),
                    countryCode: "DE",
                    timeZoneId: "Europe/Berlin",
                    eventIdentifier: "trip-a",
                    source: "Calendar"
                ),
                travelSignal(
                    dayKey: DayKey.make(from: day(2026, 3, 12), timeZone: calendar.timeZone),
                    countryCode: "GB",
                    timeZoneId: "Europe/London",
                    eventIdentifier: "trip-b#origin",
                    source: "CalendarFlightOrigin"
                ),
                travelSignal(
                    dayKey: DayKey.make(from: day(2026, 3, 15), timeZone: calendar.timeZone),
                    countryCode: "US",
                    timeZoneId: "America/New_York",
                    eventIdentifier: "trip-b",
                    source: "Calendar"
                )
            ],
            rangeEnd: day(2026, 3, 15),
            calendar: calendar
        )

        for travelGapDay in [7, 8, 9] {
            guard let result = results.first(where: {
                $0.dayKey == DayKey.make(from: self.day(2026, 3, travelGapDay), timeZone: calendar.timeZone)
            }) else {
                XCTFail("Expected transition-infilled result for day \(travelGapDay)")
                continue
            }
            XCTAssertEqual(result.contributedCountries.map { $0.countryCode ?? "" }, ["GB", "DE"])
            XCTAssertEqual(result.contributedCountries.first?.probability ?? 0, 0.51, accuracy: 0.001)
            XCTAssertEqual(result.contributedCountries.dropFirst().first?.probability ?? 0, 0.49, accuracy: 0.001)
            XCTAssertEqual(result.suggestedCountryCode1, "GB")
            XCTAssertEqual(result.suggestedCountryCode2, "DE")
            XCTAssertTrue(result.isDisputed)
            XCTAssertEqual(result.confidence, 0.51, accuracy: 0.001)
            XCTAssertEqual(result.confidenceLabel, .medium)
            XCTAssertNotEqual(result.confidenceLabel, .high)
            XCTAssertTrue(result.evidence.contains(where: { $0.source == "CalendarTransitionInfill" }))
        }

        for travelGapDay in [13, 14] {
            guard let result = results.first(where: {
                $0.dayKey == DayKey.make(from: self.day(2026, 3, travelGapDay), timeZone: calendar.timeZone)
            }) else {
                XCTFail("Expected transition-infilled result for day \(travelGapDay)")
                continue
            }
            XCTAssertEqual(result.contributedCountries.map { $0.countryCode ?? "" }, ["GB", "US"])
            XCTAssertEqual(result.suggestedCountryCode1, "GB")
            XCTAssertEqual(result.suggestedCountryCode2, "US")
            XCTAssertTrue(result.isDisputed)
            XCTAssertEqual(result.confidenceLabel, .medium)
            XCTAssertTrue(result.evidence.contains(where: { $0.source == "CalendarTransitionInfill" }))
        }
    }

    func testDifferentCountryGapWithoutTravelEvidenceRemainsSuggestionOnly() {
        let calendar = self.calendar
        let dayKeys = Set((6...10).lazy.map { day in
            DayKey.make(from: self.day(2026, 3, day), timeZone: calendar.timeZone)
        })

        let results = PresenceInferenceEngine.compute(
            dayKeys: dayKeys,
            stays: [],
            overrides: [],
            locations: [],
            photos: [],
            calendarSignals: [
                travelSignal(
                    dayKey: DayKey.make(from: day(2026, 3, 6), timeZone: calendar.timeZone),
                    countryCode: "GB",
                    timeZoneId: "Europe/London",
                    eventIdentifier: "trip-c",
                    source: "Calendar"
                ),
                travelSignal(
                    dayKey: DayKey.make(from: day(2026, 3, 10), timeZone: calendar.timeZone),
                    countryCode: "DE",
                    timeZoneId: "Europe/Berlin",
                    eventIdentifier: "trip-d",
                    source: "Calendar"
                )
            ],
            rangeEnd: day(2026, 3, 10),
            calendar: calendar
        )

        for gapDay in [7, 8, 9] {
            let result = results.first {
                $0.dayKey == DayKey.make(from: self.day(2026, 3, gapDay), timeZone: calendar.timeZone)
            }
            XCTAssertTrue(result?.contributedCountries.isEmpty == true)
            XCTAssertEqual(result?.suggestedCountryCode1, "GB")
            XCTAssertEqual(result?.suggestedCountryCode2, "DE")
            XCTAssertFalse(result?.evidence.contains(where: { $0.source == "CalendarTransitionInfill" }) == true)
        }
    }

    func testStayProcessorBasicCoverage() {
        let calendar = self.calendar
        let start = day(2026, 4, 1)
        let end = day(2026, 4, 5)
        let startKey = DayKey.make(from: start, timeZone: calendar.timeZone)
        let endKey = DayKey.make(from: end, timeZone: calendar.timeZone)

        let dayKeys = Set((1...5).map { day in
            DayKey.make(from: self.day(2026, 4, day), timeZone: calendar.timeZone)
        })

        let stay = StayPresenceInfo(
            entryDayKey: startKey,
            exitDayKey: endKey,
            dayTimeZoneId: calendar.timeZone.identifier,
            countryCode: "US",
            countryName: "United States"
        )

        let results = PresenceInferenceEngine.compute(
            dayKeys: dayKeys,
            stays: [stay],
            overrides: [],
            locations: [],
            photos: [],
            calendarSignals: [],
            rangeEnd: end,
            calendar: calendar
        )

        XCTAssertEqual(results.count, 5)
        for result in results {
            XCTAssertEqual(result.contributedCountries.first?.countryCode, "US")
            XCTAssertTrue(result.sources.contains(.stay))
            XCTAssertEqual(result.stayCount, 1)
            XCTAssertTrue(result.evidence.contains(where: { $0.source == "stay-coverage" }))
        }
    }

    func testStayProcessorClampsToRangeEnd() {
        let calendar = self.calendar
        let start = day(2026, 4, 1)
        let end = day(2026, 4, 10)
        let rangeEnd = day(2026, 4, 5)

        let startKey = DayKey.make(from: start, timeZone: calendar.timeZone)
        let endKey = DayKey.make(from: end, timeZone: calendar.timeZone)

        let dayKeys = Set((1...10).map { day in
            DayKey.make(from: self.day(2026, 4, day), timeZone: calendar.timeZone)
        })

        let stay = StayPresenceInfo(
            entryDayKey: startKey,
            exitDayKey: endKey,
            dayTimeZoneId: calendar.timeZone.identifier,
            countryCode: "FR",
            countryName: "France"
        )

        let results = PresenceInferenceEngine.compute(
            dayKeys: dayKeys,
            stays: [stay],
            overrides: [],
            locations: [],
            photos: [],
            calendarSignals: [],
            rangeEnd: rangeEnd,
            calendar: calendar
        )

        let upToRangeEnd = results.filter {
            guard let date = DayKey.date(for: $0.dayKey, timeZone: calendar.timeZone) else { return false }
            return date <= rangeEnd
        }

        let pastRangeEnd = results.filter {
            guard let date = DayKey.date(for: $0.dayKey, timeZone: calendar.timeZone) else { return false }
            return date > rangeEnd
        }

        XCTAssertEqual(upToRangeEnd.count, 5)
        for result in upToRangeEnd {
            XCTAssertEqual(result.contributedCountries.first?.countryCode, "FR")
            XCTAssertTrue(result.sources.contains(.stay))
        }

        XCTAssertEqual(pastRangeEnd.count, 5)
        for result in pastRangeEnd {
            XCTAssertTrue(result.contributedCountries.isEmpty)
            XCTAssertFalse(result.sources.contains(.stay))
        }
    }

    func testStayProcessorSkipsDaysOutsideContextKeys() {
        let calendar = self.calendar
        let start = day(2026, 4, 1)
        let end = day(2026, 4, 5)

        let startKey = DayKey.make(from: start, timeZone: calendar.timeZone)
        let endKey = DayKey.make(from: end, timeZone: calendar.timeZone)

        let dayKeys = Set([1, 5].map { day in
            DayKey.make(from: self.day(2026, 4, day), timeZone: calendar.timeZone)
        })

        let stay = StayPresenceInfo(
            entryDayKey: startKey,
            exitDayKey: endKey,
            dayTimeZoneId: calendar.timeZone.identifier,
            countryCode: "ES",
            countryName: "Spain"
        )

        let results = PresenceInferenceEngine.compute(
            dayKeys: dayKeys,
            stays: [stay],
            overrides: [],
            locations: [],
            photos: [],
            calendarSignals: [],
            rangeEnd: end,
            calendar: calendar
        )

        XCTAssertEqual(results.count, 2)
        for result in results {
            XCTAssertEqual(result.contributedCountries.first?.countryCode, "ES")
            XCTAssertTrue(result.sources.contains(.stay))
        }
    }

    func testStayProcessorInvalidCountry() {
        let calendar = self.calendar
        let start = day(2026, 4, 1)
        let end = day(2026, 4, 5)

        let startKey = DayKey.make(from: start, timeZone: calendar.timeZone)
        let endKey = DayKey.make(from: end, timeZone: calendar.timeZone)

        let dayKeys = Set((1...5).map { day in
            DayKey.make(from: self.day(2026, 4, day), timeZone: calendar.timeZone)
        })

        let stay = StayPresenceInfo(
            entryDayKey: startKey,
            exitDayKey: endKey,
            dayTimeZoneId: calendar.timeZone.identifier,
            countryCode: nil, // invalid country
            countryName: ""
        )

        let results = PresenceInferenceEngine.compute(
            dayKeys: dayKeys,
            stays: [stay],
            overrides: [],
            locations: [],
            photos: [],
            calendarSignals: [],
            rangeEnd: end,
            calendar: calendar
        )

        for result in results {
            XCTAssertTrue(result.contributedCountries.isEmpty)
            XCTAssertFalse(result.sources.contains(.stay))
        }
    }
}
#endif
