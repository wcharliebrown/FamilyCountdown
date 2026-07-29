import SwiftUI

/// Add/edit form for a single event.
struct EventEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsStore

    @State private var draft: CountdownEvent
    let isNew: Bool
    let onSave: (CountdownEvent) -> Void

    init(event: CountdownEvent, isNew: Bool, onSave: @escaping (CountdownEvent) -> Void) {
        _draft = State(initialValue: event)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Name", text: $draft.label)
                    DatePicker("Date & time", selection: $draft.targetDate)
                        .environment(\.timeZone, settings.timeZone)
                        .environment(\.calendar, settings.calendar)
                }
                Section {
                    Toggle("Repeats every year", isOn: $draft.repeats)
                    Toggle("Pinned (shown at top)", isOn: $draft.pinned)
                } footer: {
                    Text("Repeating events (birthdays) roll to next year the day after they arrive. Pinned events are always kept on the board, anchored at the top.")
                }
            }
            .navigationTitle(isNew ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.label = draft.label.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
