//
//  CountryCodeNormalizer.swift
//  Learn
//
//  Created by Codex on 16/02/2026.
//

import Foundation

enum CountryCodeNormalizer {
    nonisolated static func normalize(_ code: String?) -> String? {
        guard let code else { return nil }

        // ⚡ Bolt: Fast path for already-normalized 2-letter codes to avoid O(N) string heap allocations
        // `trimmingCharacters` and `uppercased` both allocate new strings, which is expensive
        // inside high-frequency UI loop operations (like DashboardView).
        let utf8 = code.utf8
        if utf8.count == 2 {
            var iterator = utf8.makeIterator()
            if let c1 = iterator.next(), let c2 = iterator.next() {
                let isUppercaseAlpha = (c1 >= 65 && c1 <= 90) && (c2 >= 65 && c2 <= 90)
                if isUppercaseAlpha {
                    if c1 == 85 && c2 == 75 { // "UK"
                        return "GB"
                    }
                    return code // Return identical string without reallocation
                }
            }
        }

        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let uppercased = trimmed.uppercased()
        if uppercased == "UK" {
            return "GB"
        }
        return uppercased
    }
}
