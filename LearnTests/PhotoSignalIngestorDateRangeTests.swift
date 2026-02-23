#if canImport(XCTest)
import XCTest
import Foundation
@testable import Learn

final class PhotoSignalIngestorDateRangeTests: XCTestCase {
    func testSequencedConfigUses730DayWindowDescending() {
        let calendar = makeUTCcalendar()
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 23, hour: 12, minute: 0))!
        let state = PhotoIngestState()

        let config = PhotoSignalIngestor.ingestQueryConfig(
            mode: .sequenced,
            state: state,
            now: now,
            calendar: calendar
        )
        let expectedStart = calendar.date(byAdding: .day, value: -730, to: now)!

        XCTAssertEqual(config.startDate, expectedStart)
        XCTAssertEqual(config.endDate, now)
        XCTAssertEqual(config.sortAscending, false)
    }

    func testAutoConfigUses12MonthsWhenNoPriorState() {
        let calendar = makeUTCcalendar()
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 23, hour: 12, minute: 0))!
        let state = PhotoIngestState()

        let config = PhotoSignalIngestor.ingestQueryConfig(
            mode: .auto,
            state: state,
            now: now,
            calendar: calendar
        )
        let expectedStart = calendar.date(byAdding: .month, value: -12, to: now)!

        XCTAssertEqual(config.startDate, expectedStart)
        XCTAssertNil(config.endDate)
        XCTAssertEqual(config.sortAscending, true)
    }

    func testAutoConfigUsesLastAssetPlusOneSecond() {
        let calendar = makeUTCcalendar()
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 23, hour: 12, minute: 0))!
        let lastDate = calendar.date(byAdding: .day, value: -10, to: now)!
        let state = PhotoIngestState(lastAssetCreationDate: lastDate)

        let config = PhotoSignalIngestor.ingestQueryConfig(
            mode: .auto,
            state: state,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(config.startDate, lastDate.addingTimeInterval(1))
        XCTAssertNil(config.endDate)
        XCTAssertEqual(config.sortAscending, true)
    }
}

private func makeUTCcalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}
#endif
