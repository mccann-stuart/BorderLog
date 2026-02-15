
import Testing
import Foundation
import SwiftData
@testable import Learn

struct DayOverrideValidationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func conflictingOverride_EmptyOverrides_ReturnsNil() {
        let result = DayOverrideValidation.conflictingOverride(
            for: date(2026, 1, 1),
            in: [],
            calendar: calendar
        )
        #expect(result == nil)
    }

    @Test func conflictingOverride_NoConflict_ReturnsNil() {
        let override1 = DayOverride(date: date(2026, 1, 5), countryName: "A")
        let result = DayOverrideValidation.conflictingOverride(
            for: date(2026, 1, 1),
            in: [override1],
            calendar: calendar
        )
        #expect(result == nil)
    }

    @Test func conflictingOverride_ConflictFound_ReturnsOverride() {
        let conflictDate = date(2026, 1, 5)
        let override1 = DayOverride(date: conflictDate, countryName: "A")
        let result = DayOverrideValidation.conflictingOverride(
            for: conflictDate,
            in: [override1],
            calendar: calendar
        )
        #expect(result === override1)
    }

    @Test func conflictingOverride_ExcludingSelf_ReturnsNil() {
        let conflictDate = date(2026, 1, 5)
        let override1 = DayOverride(date: conflictDate, countryName: "A")
        let result = DayOverrideValidation.conflictingOverride(
            for: conflictDate,
            in: [override1],
            excluding: override1,
            calendar: calendar
        )
        #expect(result == nil)
    }

    @Test func conflictingOverride_MultipleOverrides_FindsFirstConflict() {
        let conflictDate = date(2026, 1, 5)
        let override1 = DayOverride(date: date(2026, 1, 1), countryName: "A")
        let override2 = DayOverride(date: conflictDate, countryName: "B")
        let override3 = DayOverride(date: conflictDate, countryName: "C")

        let result = DayOverrideValidation.conflictingOverride(
            for: conflictDate,
            in: [override1, override2, override3],
            calendar: calendar
        )
        #expect(result === override2)
    }
}
