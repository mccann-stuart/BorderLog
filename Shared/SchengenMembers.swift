import Foundation

enum SchengenMembers {
    // Hard-coded Schengen membership for M1 (illustrative; updateable in later milestones)
    nonisolated static let iso2: Set<String> = [
        "AT", // Austria
        "BE", // Belgium
        "CZ", // Czechia
        "DE", // Germany
        "DK", // Denmark
        "EE", // Estonia
        "ES", // Spain
        "FI", // Finland
        "FR", // France
        "GR", // Greece
        "HU", // Hungary
        "IT", // Italy
        "LV", // Latvia
        "LI", // Liechtenstein
        "LT", // Lithuania
        "LU", // Luxembourg
        "MT", // Malta
        "NL", // Netherlands
        "NO", // Norway
        "PL", // Poland
        "PT", // Portugal
        "SE", // Sweden
        "SI", // Slovenia
        "SK", // Slovakia
        "IS", // Iceland
        "CH", // Switzerland
        "HR"  // Croatia (joined Schengen 2023)
    ]

    nonisolated static func isMember(_ code: String?) -> Bool {
        guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), !code.isEmpty else {
            return false
        }
        return iso2.contains(code)
    }

    nonisolated static var sortedCodes: [String] { iso2.sorted() }
}
