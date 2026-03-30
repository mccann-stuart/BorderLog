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
        guard let code else { return false }

        // ⚡ Bolt: Fast path for already-normalized 2-letter codes to avoid O(N) string heap allocations
        // `trimmingCharacters` and `uppercased` both allocate new strings, which is expensive
        // inside high-frequency loop operations (like DashboardView and SchengenLedgerCalculator).
        let utf8 = code.utf8
        if utf8.count == 2 {
            var iterator = utf8.makeIterator()
            if let c1 = iterator.next(), let c2 = iterator.next() {
                let isUppercaseAlpha = (c1 >= 65 && c1 <= 90) && (c2 >= 65 && c2 <= 90)
                if isUppercaseAlpha {
                    return iso2.contains(code) // Return immediately without reallocation
                }
            }
        }

        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return false }
        return iso2.contains(trimmed)
    }

    nonisolated static var sortedCodes: [String] { iso2.sorted() }
}
