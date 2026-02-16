//
//  CountryCodeNormalizer.swift
//  Learn
//
//  Created by Codex on 16/02/2026.
//

import Foundation

enum CountryCodeNormalizer {
    static func normalize(_ code: String?) -> String? {
        guard let code else { return nil }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let uppercased = trimmed.uppercased()
        if uppercased == "UK" {
            return "GB"
        }
        return uppercased
    }
}
