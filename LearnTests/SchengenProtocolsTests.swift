import XCTest
@testable import Learn

final class SchengenProtocolsTests: XCTestCase {

    func testStayInfoInitialization() {
        let enteredOn = Date(timeIntervalSince1970: 1000000)
        let exitedOn = Date(timeIntervalSince1970: 2000000)
        let region = Region.schengen
        let entryDayKey = "2026-02-15"
        let exitDayKey = "2026-02-25"

        // Full initialization
        let stayFull = StayInfo(
            enteredOn: enteredOn,
            exitedOn: exitedOn,
            region: region,
            entryDayKey: entryDayKey,
            exitDayKey: exitDayKey
        )

        XCTAssertEqual(stayFull.enteredOn, enteredOn)
        XCTAssertEqual(stayFull.exitedOn, exitedOn)
        XCTAssertEqual(stayFull.region, region)
        XCTAssertEqual(stayFull.entryDayKey, entryDayKey)
        XCTAssertEqual(stayFull.exitDayKey, exitDayKey)

        // Minimal initialization (optionals nil)
        let stayMinimal = StayInfo(
            enteredOn: enteredOn,
            exitedOn: nil,
            region: .nonSchengen
        )

        XCTAssertEqual(stayMinimal.enteredOn, enteredOn)
        XCTAssertNil(stayMinimal.exitedOn)
        XCTAssertEqual(stayMinimal.region, .nonSchengen)
        XCTAssertNil(stayMinimal.entryDayKey)
        XCTAssertNil(stayMinimal.exitDayKey)
    }

    func testOverrideInfoInitialization() {
        let date = Date(timeIntervalSince1970: 3000000)
        let region = Region.schengen
        let dayKey = "2026-03-01"

        // Full initialization
        let overrideFull = OverrideInfo(
            date: date,
            region: region,
            dayKey: dayKey
        )

        XCTAssertEqual(overrideFull.date, date)
        XCTAssertEqual(overrideFull.region, region)
        XCTAssertEqual(overrideFull.dayKey, dayKey)

        // Minimal initialization (optional nil)
        let overrideMinimal = OverrideInfo(
            date: date,
            region: .other
        )

        XCTAssertEqual(overrideMinimal.date, date)
        XCTAssertEqual(overrideMinimal.region, .other)
        XCTAssertNil(overrideMinimal.dayKey)
    }
}
