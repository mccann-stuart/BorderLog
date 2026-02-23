import Foundation

extension DashboardView.VisitedCountriesTimeframe {
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
        }
    }
}
