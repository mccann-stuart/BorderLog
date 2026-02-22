
import XCTest
import Foundation
@testable import Learn

final class DayKeyPerformanceTests: XCTestCase {

    func testBenchmarkDayKeyCreation() {
        let calendar = Calendar.current
        let timeZone = calendar.timeZone
        let today = Date()

        // Warmup
        _ = DayKey.make(from: today, timeZone: timeZone)

        let start = Date()
        for _ in 0..<10_000 {
            _ = DayKey.make(from: today, timeZone: timeZone)
        }
        let end = Date()
        print("DayKey.make (10,000 iterations) took: \(end.timeIntervalSince(start)) seconds")
    }

    func testBenchmarkDayKeyParsing() {
        let calendar = Calendar.current
        let timeZone = calendar.timeZone
        let key = "2026-02-22"

        // Warmup
        _ = DayKey.date(for: key, timeZone: timeZone)

        let start = Date()
        for _ in 0..<10_000 {
            _ = DayKey.date(for: key, timeZone: timeZone)
        }
        let end = Date()
        print("DayKey.date (10,000 iterations) took: \(end.timeIntervalSince(start)) seconds")
    }
}
