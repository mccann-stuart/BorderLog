//
//  CountryConfig.swift
//  Learn
//

import Foundation
import SwiftData

@Model
final class CountryConfig {
    @Attribute(.unique) var countryCode: String
    var maxAllowedDays: Int?

    init(countryCode: String, maxAllowedDays: Int? = nil) {
        self.countryCode = countryCode
        self.maxAllowedDays = maxAllowedDays
    }
}
