//
//  CountrySummaryComponents.swift
//  Learn
//
//  Created by Codex on 19/03/2026.
//

import SwiftUI

struct CardShell: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
    }
}

extension View {
    func cardShell() -> some View {
        modifier(CardShell())
    }
}

struct CountryDaysInfo: Identifiable {
    let countryName: String
    let countryCode: String?
    var totalDays: Int
    let region: Region
    var maxAllowedDays: Int?

    var id: String {
        CountryCodeNormalizer.normalize(countryCode) ?? countryName
    }

    var flagEmoji: String {
        guard let code = countryCode?.uppercased() else { return "🌍" }
        return countryCodeToEmoji(code)
    }
}

func countryCodeToEmoji(_ code: String) -> String {
    let base: UInt32 = 127397
    var emoji = ""
    let normalized = CountryCodeNormalizer.normalize(code) ?? code.uppercased()
    for scalar in normalized.unicodeScalars {
        if let unicodeScalar = UnicodeScalar(base + scalar.value) {
            emoji.append(String(unicodeScalar))
        }
    }
    return emoji.isEmpty ? "🌍" : emoji
}

struct CountryDaysRow: View {
    let info: CountryDaysInfo
    let warningThreshold: Int

    private var backgroundColor: Color {
        if info.totalDays >= 90 {
            return .red.opacity(0.15)
        } else if info.totalDays >= warningThreshold {
            return .yellow.opacity(0.15)
        }
        return .clear
    }

    private var badgeColor: Color {
        if info.totalDays >= 90 {
            return .red
        } else if info.totalDays >= warningThreshold {
            return .orange
        }
        return .secondary
    }

    private func daysAttributedText(maxDays: Int) -> AttributedString {
        var daysText = AttributedString("\(info.totalDays) of \(maxDays)")
        if let range = daysText.range(of: "\(info.totalDays)") {
            daysText[range].foregroundColor = badgeColor
        }
        if let range = daysText.range(of: " of \(maxDays)") {
            daysText[range].foregroundColor = .secondary
        }
        return daysText
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(info.flagEmoji)
                .font(.system(size: 40))

            VStack(alignment: .leading, spacing: 4) {
                Text(info.countryName)
                    .font(.system(.headline, design: .rounded))

                Text(info.region.rawValue)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let maxDays = info.maxAllowedDays {
                    Text(daysAttributedText(maxDays: maxDays))
                        .font(.system(.title2, design: .rounded).bold())

                    Text("allowed days".uppercased())
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(info.totalDays)")
                        .font(.system(.title2, design: .rounded).bold())
                        .foregroundStyle(badgeColor)

                    Text("days".uppercased())
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
