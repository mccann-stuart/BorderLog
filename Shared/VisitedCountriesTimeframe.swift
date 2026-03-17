import Foundation

enum VisitedCountriesTimeframe: String, CaseIterable, Identifiable {
    case last12Months = "Last 12 Months"
    case lastYear = "Last Year"
    case thisYear = "This Year"
    case last6Months = "Last 6 Months"
    case twoYearsPrior = "Two Years Prior"

    var id: Self { self }

    func dateRange(now: Date = Date(), calendar: Calendar = .current) -> Range<Date>? {
        switch self {
        case .last12Months:
            guard let start = calendar.date(byAdding: .month, value: -12, to: now) else { return nil }
            return start..<Date.distantFuture
        case .last6Months:
            guard let start = calendar.date(byAdding: .month, value: -6, to: now) else { return nil }
            return start..<Date.distantFuture
        case .thisYear:
            guard let start = calendar.date(from: calendar.dateComponents([.year], from: now)) else { return nil }
            return start..<Date.distantFuture
        case .lastYear:
            guard let startOfThisYear = calendar.date(from: calendar.dateComponents([.year], from: now)),
                  let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfThisYear) else { return nil }
            return startOfLastYear..<startOfThisYear
        case .twoYearsPrior:
            guard let startOfThisYear = calendar.date(from: calendar.dateComponents([.year], from: now)),
                  let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfThisYear),
                  let startOfTwoYearsAgo = calendar.date(byAdding: .year, value: -2, to: startOfThisYear) else { return nil }
            return startOfTwoYearsAgo..<startOfLastYear
        }
    }

    func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let range = dateRange(now: now, calendar: calendar) else {
            return true // Fallback to original behavior of returning true on calendar failure
        }
        return range.contains(date)
    }
}
