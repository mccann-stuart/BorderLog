//
//  PresenceDayRow.swift
//  Learn
//

import SwiftUI

struct PresenceDayRow: View {
    let day: PresenceDay

    private var dayText: String {
        day.dayKey
    }

    private var countryText: String {
        if let name = day.countryName ?? day.countryCode {
            return name
        }
        return "Unknown"
    }

    private var confidenceColor: Color {
        switch day.confidenceLabel {
        case .high: return .green
        case .medium: return .orange
        case .low: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(countryText)
                    .font(.system(.headline, design: .rounded))

                if day.isOverride {
                    Text("Override")
                        .font(.system(.caption, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            HStack {
                Text(dayText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(day.confidenceLabel.rawValue.capitalized)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(confidenceColor)
            }
        }
        .padding(.vertical, 4)
    }
}
