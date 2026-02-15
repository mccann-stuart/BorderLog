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
    @Query(sort: [SortDescriptor(\Stay.enteredOn, order: .reverse)]) private var stays: [Stay]

    private let existingStay: Stay?
    @State private var draft: StayDraft
    @State private var isConfirmingDelete = false
    @State private var isShowingOverlapAlert = false
    @State private var overlapMessage = ""

    init(stay: Stay? = nil) {
        self.existingStay = stay
        _draft = State(initialValue: StayDraft(stay: stay))
    }

    var body: some View {
        Form {
            Section("Location") {
                TextField("Country", text: $draft.countryName)

                TextField("Country Code", text: $draft.countryCode)
                    .textInputAutocapitalization(.characters)

                Picker("Region", selection: $draft.region) {
                    ForEach(Region.allCases) { region in
                        Text(region.rawValue).tag(region)
                    }
                }
            }

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
    }

    private var canSave: Bool {
        !draft.countryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func attemptSave() {
        let calendar = Calendar.current
        let normalizedEntry = calendar.startOfDay(for: draft.enteredOn)
        let normalizedExit = draft.hasExitDate ? calendar.startOfDay(for: draft.exitedOn) : nil

        let overlaps = StayValidation.overlappingStays(
            enteredOn: normalizedEntry,
            exitedOn: normalizedExit,
            stays: stays,
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
        let trimmedNotes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let exitDate = draft.hasExitDate ? draft.exitedOn : nil

        if let existingStay {
            existingStay.countryName = trimmedCountry
            existingStay.countryCode = trimmedCode.isEmpty ? nil : trimmedCode.uppercased()
            existingStay.region = draft.region
            existingStay.enteredOn = draft.enteredOn
            existingStay.exitedOn = exitDate
            existingStay.notes = trimmedNotes
        } else {
            let stay = Stay(
                countryName: trimmedCountry,
                countryCode: trimmedCode.isEmpty ? nil : trimmedCode.uppercased(),
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

    init(stay: Stay?) {
        if let stay {
            self.countryName = stay.countryName
            self.countryCode = stay.countryCode ?? ""
            self.region = stay.region
            self.enteredOn = stay.enteredOn
            self.hasExitDate = stay.exitedOn != nil
            self.exitedOn = stay.exitedOn ?? stay.enteredOn
            self.notes = stay.notes
        } else {
            self.countryName = ""
            self.countryCode = ""
            self.region = .schengen
            self.enteredOn = Date()
            self.hasExitDate = false
            self.exitedOn = Date()
            self.notes = ""
        }
    }
}

#Preview {
    StayEditorView()
        .modelContainer(for: [Stay.self, DayOverride.self], inMemory: true)
}
