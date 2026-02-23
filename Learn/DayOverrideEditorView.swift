//
//  DayOverrideEditorView.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import SwiftUI
import SwiftData

struct DayOverrideEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\DayOverride.date, order: .reverse)]) private var overrides: [DayOverride]
    @Query private var presenceDays: [PresenceDay]

    private let existingOverride: DayOverride?
    @State private var draft: DayOverrideDraft
    @State private var isConfirmingDelete = false
    @State private var isShowingReplaceAlert = false
    @State private var replaceTarget: DayOverride?

    init(overrideDay: DayOverride? = nil, presetDate: Date? = nil, presetCountryName: String? = nil, presetCountryCode: String? = nil) {
        self.existingOverride = overrideDay
        _draft = State(initialValue: DayOverrideDraft(
            overrideDay: overrideDay,
            presetDate: presetDate,
            presetCountryName: presetCountryName,
            presetCountryCode: presetCountryCode
        ))
    }

    var body: some View {
        Form {
            Section("Date") {
                DatePicker("Day", selection: $draft.date, displayedComponents: .date)
            }

            LocationFormSection(
                countryName: $draft.countryName,
                countryCode: $draft.countryCode,
                region: $draft.region,
                style: existingOverride == nil ? .picker : .freeText,
                suggestedCodes: suggestedCodes,
                ledgerCountryCounts: ledgerCountryCounts
            )

            Section("Notes") {
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(existingOverride == nil ? "New Override" : "Edit Override")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    attemptSave()
                }
                .disabled(!canSave)
            }

            if existingOverride != nil {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .confirmationDialog("Delete this override?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                if let existingOverride {
                    modelContext.delete(existingOverride)
                }
                dismiss()
            }
        }
        .alert("Replace existing override?", isPresented: $isShowingReplaceAlert) {
            Button("Replace", role: .destructive) {
                if let replaceTarget {
                    applySave(replacing: replaceTarget)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("An override already exists for this day. Replacing it will remove the previous entry.")
        }
        .onChange(of: draft.countryCode) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                draft.region = .other
            } else if SchengenMembers.isMember(trimmed) {
                draft.region = .schengen
            } else {
                draft.region = .nonSchengen
            }
        }
    }

    // MARK: - Suggestion & Ledger Data

    private var suggestedCodes: [String] {
        guard existingOverride == nil else { return [] }
        let calendar = Calendar.current
        let targetStart = calendar.startOfDay(for: draft.date)
        guard let targetEnd = calendar.date(byAdding: .day, value: 1, to: targetStart) else { return [] }

        let matchingDay = presenceDays.first { day in
            let dayStart = calendar.startOfDay(for: day.date)
            return dayStart >= targetStart && dayStart < targetEnd
        }

        var codes: [String] = []
        if let day = matchingDay {
            if let c = day.countryCode, !c.isEmpty { codes.append(c.uppercased()) }
            if let c = day.suggestedCountryCode1, !c.isEmpty {
                let upper = c.uppercased()
                if !codes.contains(upper) { codes.append(upper) }
            }
            if let c = day.suggestedCountryCode2, !c.isEmpty {
                let upper = c.uppercased()
                if !codes.contains(upper) { codes.append(upper) }
            }
        }
        return Array(codes.prefix(3))
    }

    private var ledgerCountryCounts: [(code: String, count: Int)] {
        guard existingOverride == nil else { return [] }
        var counts: [String: Int] = [:]
        for day in presenceDays {
            if let code = day.countryCode, !code.isEmpty {
                counts[code.uppercased(), default: 0] += 1
            }
        }
        return counts
            .map { (code: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var canSave: Bool {
        !draft.countryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func attemptSave() {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: draft.date)
        draft.date = normalizedDate

        if let conflict = DayOverrideValidation.conflictingOverride(
            for: normalizedDate,
            in: overrides,
            excluding: existingOverride,
            calendar: calendar
        ) {
            replaceTarget = conflict
            isShowingReplaceAlert = true
            return
        }

        applySave(replacing: nil)
    }

    private func applySave(replacing: DayOverride?) {
        if let replacing {
            modelContext.delete(replacing)
        }

        let trimmedCountry = draft.countryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = draft.countryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCode = CountryCodeNormalizer.normalize(trimmedCode)
        let trimmedNotes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingOverride {
            existingOverride.date = draft.date
            existingOverride.countryName = trimmedCountry
            existingOverride.countryCode = normalizedCode
            existingOverride.region = draft.region
            existingOverride.notes = trimmedNotes
        } else {
            let newOverride = DayOverride(
                date: draft.date,
                countryName: trimmedCountry,
                countryCode: normalizedCode,
                region: draft.region,
                notes: trimmedNotes
            )
            modelContext.insert(newOverride)
        }

        dismiss()
    }
}

private struct DayOverrideDraft {
    var date: Date
    var countryName: String
    var countryCode: String
    var region: Region
    var notes: String

    init(overrideDay: DayOverride?, presetDate: Date? = nil, presetCountryName: String? = nil, presetCountryCode: String? = nil) {
        if let overrideDay {
            self.date = overrideDay.date
            self.countryName = overrideDay.countryName
            self.countryCode = overrideDay.countryCode ?? ""
            self.region = overrideDay.region
            self.notes = overrideDay.notes
        } else {
            self.date = presetDate ?? Date()
            self.countryName = presetCountryName ?? ""
            self.countryCode = presetCountryCode ?? ""
            let trimmedCode = (presetCountryCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedCode.isEmpty {
                self.region = .other
            } else if SchengenMembers.isMember(trimmedCode) {
                self.region = .schengen
            } else {
                self.region = .nonSchengen
            }
            self.notes = ""
        }
    }
}

#Preview {
    DayOverrideEditorView()
        .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self], inMemory: true)
}
