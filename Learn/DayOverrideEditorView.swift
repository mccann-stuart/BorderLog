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

    private let existingOverride: DayOverride?
    @State private var draft: DayOverrideDraft
    @State private var isConfirmingDelete = false
    @State private var isShowingReplaceAlert = false
    @State private var replaceTarget: DayOverride?

    init(overrideDay: DayOverride? = nil) {
        self.existingOverride = overrideDay
        _draft = State(initialValue: DayOverrideDraft(overrideDay: overrideDay))
    }

    var body: some View {
        Form {
            Section("Date") {
                DatePicker("Day", selection: $draft.date, displayedComponents: .date)
            }

            LocationFormSection(
                countryName: $draft.countryName,
                countryCode: $draft.countryCode,
                region: $draft.region
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
        let trimmedNotes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingOverride {
            existingOverride.date = draft.date
            existingOverride.countryName = trimmedCountry
            existingOverride.countryCode = trimmedCode.isEmpty ? nil : trimmedCode.uppercased()
            existingOverride.region = draft.region
            existingOverride.notes = trimmedNotes
        } else {
            let newOverride = DayOverride(
                date: draft.date,
                countryName: trimmedCountry,
                countryCode: trimmedCode.isEmpty ? nil : trimmedCode.uppercased(),
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

    init(overrideDay: DayOverride?) {
        if let overrideDay {
            self.date = overrideDay.date
            self.countryName = overrideDay.countryName
            self.countryCode = overrideDay.countryCode ?? ""
            self.region = overrideDay.region
            self.notes = overrideDay.notes
        } else {
            self.date = Date()
            self.countryName = ""
            self.countryCode = ""
            self.region = .schengen
            self.notes = ""
        }
    }
}

#Preview {
    DayOverrideEditorView()
        .modelContainer(for: [Stay.self, DayOverride.self], inMemory: true)
}
