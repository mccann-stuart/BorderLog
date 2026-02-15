//
//  LearnTests.swift
//  LearnTests
//
//  Created by Mccann Stuart on 13/02/2026.
//

import Testing
@testable import Learn

struct SchengenCalculatorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func countsUniqueDaysAcrossOverlappingStays() async throws {
        let stays = [
            Stay(countryName: "France", region: .schengen, enteredOn: date(2026, 2, 1), exitedOn: date(2026, 2, 5)),
            Stay(countryName: "Spain", region: .schengen, enteredOn: date(2026, 2, 4), exitedOn: date(2026, 2, 6)),
        ]

        let summary = SchengenCalculator.summary(for: stays, asOf: date(2026, 2, 15), calendar: calendar)

        #expect(summary.usedDays == 6)
        #expect(summary.remainingDays == 84)
        #expect(summary.overstayDays == 0)
    }
}
