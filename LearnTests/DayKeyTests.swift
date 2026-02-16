#if canImport(XCTest)
import XCTest
import Foundation
@testable import Learn

final class DayKeyTests: XCTestCase {
    func testDayKeyUsesTimeZone() {
        let utc = TimeZone(secondsFromGMT: 0)!
        let cet = TimeZone(secondsFromGMT: 3600)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc

        let date = calendar.date(from: DateComponents(year: 2026, month: 2, day: 15, hour: 23, minute: 30))!

        let utcKey = DayKey.make(from: date, timeZone: utc)
        let cetKey = DayKey.make(from: date, timeZone: cet)

        XCTAssertEqual(utcKey, "2026-02-15")
        XCTAssertEqual(cetKey, "2026-02-16")
    }
}
#endif
