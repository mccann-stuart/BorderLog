import Foundation

enum VisitedCountriesTimeframe: String, CaseIterable, Identifiable {
    case last12Months = "Last 12 Months"
    case lastYear = "Last Year"
    case thisYear = "This Year"
    case last6Months = "Last 6 Months"
    case twoYearsPrior = "Two Years Prior"

    var id: Self { self }

    func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .last12Months:
            guard let start = calendar.date(byAdding: .month, value: -12, to: now) else { return true }
            return date >= start
        case .last6Months:
            guard let start = calendar.date(byAdding: .month, value: -6, to: now) else { return true }
            return date >= start
        case .thisYear:
            guard let start = calendar.date(from: calendar.dateComponents([.year], from: now)) else { return true }
            return date >= start
        case .lastYear:
            guard let startOfThisYear = calendar.date(from: calendar.dateComponents([.year], from: now)),
                  let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfThisYear) else { return true }
            return date >= startOfLastYear && date < startOfThisYear
        case .twoYearsPrior:
            guard let startOfThisYear = calendar.date(from: calendar.dateComponents([.year], from: now)),
                  let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfThisYear),
                  let startOfTwoYearsAgo = calendar.date(byAdding: .year, value: -2, to: startOfThisYear) else { return true }
            return date >= startOfTwoYearsAgo && date < startOfLastYear
        }
    }
}
