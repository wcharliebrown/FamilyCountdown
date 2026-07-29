import SwiftUI

/// Editable list of the user's events (generated holidays are not shown here —
/// they're computed automatically and can't be edited).
struct EventEditorList: View {
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var editing: CountdownEvent?
    @State private var isNew = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        TimeZonePickerView(identifier: $settings.timeZoneIdentifier)
                    } label: {
                        HStack {
                            Text("Time Zone")
                            Spacer()
                            Text(settings.timeZoneLabel).foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink {
                        ShiftTimesView().environmentObject(store).environmentObject(settings)
                    } label: {
                        Text("Shift Event Times…")
                    }
                } header: {
                    Text("Display")
                } footer: {
                    Text("Time Zone sets when each day rolls over. Shift Event Times re-stamps your saved events from one zone to another (e.g. treat times authored in Eastern as the same wall-clock time in Central).")
                }

                Section {
                    ForEach(sortedEvents) { event in
                        Button {
                            editing = event
                            isNew = false
                        } label: {
                            row(event)
                        }
                        .tint(.primary)
                    }
                    .onDelete(perform: delete)
                } footer: {
                    Text("US holidays (New Year's, Easter, July 4th, Thanksgiving, Christmas) are added automatically and don't appear here.")
                }
            }
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = CountdownEvent(label: "", targetDate: defaultDate())
                        isNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editing) { event in
                EventEditor(event: event, isNew: isNew) { saved in
                    if isNew { store.add(saved) } else { store.update(saved) }
                }
                .environmentObject(settings)
            }
        }
    }

    private var sortedEvents: [CountdownEvent] {
        store.events.sorted { $0.targetDate < $1.targetDate }
    }

    private func row(_ event: CountdownEvent) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.label.isEmpty ? "(untitled)" : event.label)
                    .font(.headline)
                Text(settings.mediumString(from: event.targetDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if event.pinned {
                Image(systemName: "pin.fill").foregroundStyle(.orange)
            }
            if event.repeats {
                Image(systemName: "repeat").foregroundStyle(.secondary)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let targets = offsets.map { sortedEvents[$0] }
        for t in targets { store.delete(t) }
    }

    /// Next midnight, as a sensible default for a new event.
    private func defaultDate() -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.startOfDay(for: tomorrow)
    }
}
