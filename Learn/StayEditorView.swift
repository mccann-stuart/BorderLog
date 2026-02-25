//
//  StayEditorView.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import SwiftUI
import SwiftData

struct StayEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var presenceDays: [PresenceDay]

    private let existingStay: Stay?
    @State private var draft: StayDraft
    @State private var isConfirmingDelete = false
    @State private var isShowingOverlapAlert = false
    @State private var overlapMessage = ""

    private let noteCharacterLimit = 1000

    init(
        stay: Stay? = nil,
        presetEntry: Date? = nil,
        presetExit: Date? = nil,
        presetCountryName: String? = nil,
        presetCountryCode: String? = nil,
        forceExitDate: Bool = false
    ) {
        self.existingStay = stay
        _draft = State(initialValue: StayDraft(
            stay: stay,
            presetEntry: presetEntry,
            presetExit: presetExit,
            presetCountryName: presetCountryName,
            presetCountryCode: presetCountryCode,
            forceExitDate: forceExitDate
        ))
    }

    var body: some View {
        Form {
            LocationFormSection(
                countryName: $draft.countryName,
                countryCode: $draft.countryCode,
                region: $draft.region,
                style: existingStay == nil ? .picker : .freeText,
                suggestedCodes: suggestedCodes,
                ledgerCountryCounts: ledgerCountryCounts
            )

            Section("Dates") {
                DatePicker("Entry", selection: $draft.enteredOn, displayedComponents: .date)

                Toggle("Has exit date", isOn: $draft.hasExitDate)

                if draft.hasExitDate {
                    DatePicker(
                        "Exit",
                        selection: $draft.exitedOn,
                        in: draft.enteredOn...,
                        displayedComponents: .date
                    )
                } else {
                    Text("This stay will be treated as ongoing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notes") {
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...6)
                    .onChange(of: draft.notes) { _, newValue in
                        if newValue.count > noteCharacterLimit {
                            draft.notes = String(newValue.prefix(noteCharacterLimit))
                        }
                    }
                Text("\(draft.notes.count)/\(noteCharacterLimit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .navigationTitle(existingStay == nil ? "New Stay" : "Edit Stay")
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

            if existingStay != nil {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .confirmationDialog("Delete this stay?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                if let existingStay {
                    modelContext.delete(existingStay)
                }
                dismiss()
            }
        }
        .alert("Overlapping stays", isPresented: $isShowingOverlapAlert) {
            Button("Save Anyway", role: .destructive) {
                applySave()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(overlapMessage)
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

    private var suggestedCodes: [String] {
        guard existingStay == nil else { return [] }
        let calendar = Calendar.current
        let targetStart = calendar.startOfDay(for: draft.enteredOn)
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
        guard existingStay == nil else { return [] }
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
        let normalizedEntry = calendar.startOfDay(for: draft.enteredOn)
        let normalizedExit = draft.hasExitDate ? calendar.startOfDay(for: draft.exitedOn) : nil

        let searchStart = normalizedEntry
        let searchEnd = normalizedExit ?? Date.distantFuture

        let queryEnd: Date
        if normalizedExit == nil {
             queryEnd = Date.distantFuture
        } else {
             queryEnd = calendar.date(byAdding: .day, value: 1, to: searchEnd) ?? searchEnd
        }

        let distantFuture = Date.distantFuture

        let descriptor = FetchDescriptor<Stay>(
            predicate: #Predicate<Stay> { stay in
                stay.enteredOn < queryEnd &&
                (stay.exitedOn ?? distantFuture) >= searchStart
            }
        )

        let potentialOverlaps: [Stay]
        do {
            potentialOverlaps = try modelContext.fetch(descriptor)
        } catch {
             print("Fetch failed: \(error)")
             potentialOverlaps = []
        }

        let overlaps = StayValidation.overlappingStays(
            enteredOn: normalizedEntry,
            exitedOn: normalizedExit,
            stays: potentialOverlaps,
            excluding: existingStay,
            calendar: calendar
        )

        draft.enteredOn = normalizedEntry
        if let normalizedExit {
            draft.exitedOn = normalizedExit
        }

        if overlaps.isEmpty {
            applySave()
        } else {
            overlapMessage = overlapSummary(for: overlaps, calendar: calendar)
            isShowingOverlapAlert = true
        }
    }

    private func applySave() {
        let trimmedCountry = draft.countryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = draft.countryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCode = CountryCodeNormalizer.normalize(trimmedCode)
        let trimmedNotes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let exitDate = draft.hasExitDate ? draft.exitedOn : nil

        if let existingStay {
            existingStay.countryName = trimmedCountry
            existingStay.countryCode = normalizedCode
            existingStay.region = draft.region
            existingStay.enteredOn = draft.enteredOn
            existingStay.exitedOn = exitDate
            existingStay.notes = trimmedNotes
        } else {
            let stay = Stay(
                countryName: trimmedCountry,
                countryCode: normalizedCode,
                region: draft.region,
                enteredOn: draft.enteredOn,
                exitedOn: exitDate,
                notes: trimmedNotes
            )
            modelContext.insert(stay)
        }

        dismiss()
    }

    private func overlapSummary(for overlaps: [Stay], calendar: Calendar) -> String {
        let formatter = Date.FormatStyle(date: .abbreviated, time: .omitted)
        let lines = overlaps.prefix(3).map { stay -> String in
            let start = stay.enteredOn.formatted(formatter)
            let end = stay.exitedOn?.formatted(formatter) ?? "Present"
            return "- \(stay.displayTitle): \(start) - \(end)"
        }
        let suffix = overlaps.count > 3 ? "\n- and \(overlaps.count - 3) more" : ""
        return "This stay overlaps with existing entries:\n" + lines.joined(separator: "\n") + suffix
    }
}

private struct StayDraft {
    var countryName: String
    var countryCode: String
    var region: Region
    var enteredOn: Date
    var hasExitDate: Bool
    var exitedOn: Date
    var notes: String

    init(
        stay: Stay?,
        presetEntry: Date? = nil,
        presetExit: Date? = nil,
        presetCountryName: String? = nil,
        presetCountryCode: String? = nil,
        forceExitDate: Bool = false
    ) {
        if let stay {
            self.countryName = stay.countryName
            self.countryCode = stay.countryCode ?? ""
            self.region = stay.region
            self.enteredOn = stay.enteredOn
            self.hasExitDate = stay.exitedOn != nil
            self.exitedOn = stay.exitedOn ?? stay.enteredOn
            self.notes = stay.notes
        } else {
            let entryDate = presetEntry ?? Date()
            let trimmedCode = (presetCountryCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let shouldSetExitDate = forceExitDate || presetExit != nil

            self.countryName = presetCountryName ?? ""
            self.countryCode = presetCountryCode ?? ""
            if trimmedCode.isEmpty {
                self.region = .other
            } else if SchengenMembers.isMember(trimmedCode) {
                self.region = .schengen
            } else {
                self.region = .nonSchengen
            }
            self.enteredOn = entryDate
            self.hasExitDate = shouldSetExitDate
            self.exitedOn = shouldSetExitDate ? (presetExit ?? entryDate) : entryDate
            self.notes = ""
        }
    }
}

#Preview {
    StayEditorView()
        .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self, CalendarSignal.self], inMemory: true)
}
