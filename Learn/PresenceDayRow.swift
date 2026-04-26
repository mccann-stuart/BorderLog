//
//  PresenceDayRow.swift
//  Learn
//

import SwiftUI
import Foundation

struct PresenceDayRow: View {
    let day: PresenceDay
    @AppStorage(CountryDayCountingMode.storageKey, store: AppConfig.sharedDefaults) private var countryDayCountingModeRaw = CountryDayCountingMode.defaultMode.rawValue

    private var countryDayCountingMode: CountryDayCountingMode {
        CountryDayCountingMode.storedMode(from: countryDayCountingModeRaw)
    }

    private var dayTimeZone: TimeZone {
        if let id = day.timeZoneId, let tz = TimeZone(identifier: id) {
            return tz
        }
        return .current
    }

    private var dayText: String {
        // Optimization: Use iOS 15+ FormatStyle API instead of allocating an expensive DateFormatter
        // per row render. FormatStyle is a lightweight value type.
        var format = Date.FormatStyle(date: .abbreviated, time: .omitted)
        format.timeZone = dayTimeZone
        return day.date.formatted(format)
    }

    private var countryText: String {
        let countries = day.countedCountries(for: countryDayCountingMode)
        if !countries.isEmpty {
            return countries.map(\.countryName).joined(separator: ", ")
        }
        return "Unknown"
    }

    private var isTodayInDayTimeZone: Bool {
        DayKey.make(from: Date(), timeZone: dayTimeZone) == day.dayKey
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
                } else if day.stayCount > 0 {
                    Text("Stay")
                        .font(.system(.caption, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }

                if day.isDisputed && !day.isManuallyModified {
                    Label("Disputed", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(.caption, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.18))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }

                if isTodayInDayTimeZone {
                    Text("Today")
                        .font(.system(.caption, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
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
