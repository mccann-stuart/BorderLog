//
//  String+Extensions.swift
//  Learn
//

import Foundation

extension String {
    /// ⚡ Bolt: Fast path to avoid O(N) heap allocations for strings that are already trimmed.
    var fastTrimmed: String {
        guard let first = self.first, let last = self.last else { return self }
        if !first.isWhitespace && !last.isWhitespace {
            return self
        }
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
