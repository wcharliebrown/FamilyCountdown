import SwiftUI

/// Bulk re-stamps every saved event's time by reinterpreting its wall-clock
/// reading from one zone to another. E.g. an event stored as midnight Eastern,
/// shifted From=Eastern To=Central, becomes midnight Central (the instant moves,
/// the wall-clock stays). Only user events are changed; holidays regenerate.
struct ShiftTimesView: View {
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var fromID: String
    @State private var toID: String
    @State private var didApply = false

    init() {
        let resolved = SettingsStore().isAutomatic
            ? TimeZone.autoupdatingCurrent.identifier
            : (UserDefaults.standard.string(forKey: "timeZoneIdentifier") ?? TimeZone.current.identifier)
        _fromID = State(initialValue: TimeZone.current.identifier)
        _toID = State(initialValue: resolved)
    }

    private var fromTZ: TimeZone { TimeZone(identifier: fromID) ?? .current }
    private var toTZ: TimeZone { TimeZone(identifier: toID) ?? .current }
    private var isNoOp: Bool { fromID == toID }

    var body: some View {
        Form {
            Section {
                zoneLink(title: "From (interpret current times as)", id: $fromID)
                zoneLink(title: "To (change them to)", id: $toID)
            } footer: {
                Text("Each event keeps its wall-clock reading but moves to that time in the “To” zone.")
            }

            if let sample = sampleEvent {
                Section("Preview") {
                    Text(sample.label).font(.headline)
                    LabeledContent("Now") { Text(format(sample.targetDate, in: toTZ)) }
                    LabeledContent("After") {
                        Text(format(reinterpret(sample.targetDate), in: toTZ))
                            .foregroundStyle(isNoOp ? .secondary : .primary)
                    }
                }
            }

            Section {
                Button {
                    apply()
                } label: {
                    Text("Shift \(store.events.count) Event\(store.events.count == 1 ? "" : "s")")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isNoOp || store.events.isEmpty)
            } footer: {
                if didApply { Text("Done. Times updated.").foregroundStyle(.green) }
            }
        }
        .navigationTitle("Shift Event Times")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func zoneLink(title: String, id: Binding<String>) -> some View {
        NavigationLink {
            TimeZonePickerView(identifier: id, allowAutomatic: false, title: title)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(SettingsStore.pretty(id.wrappedValue))
            }
        }
    }

    private var sampleEvent: CountdownEvent? {
        store.events.sorted { $0.targetDate < $1.targetDate }.first
    }

    /// Reinterpret `date`'s wall-clock components from `fromTZ` to `toTZ`.
    private func reinterpret(_ date: Date) -> Date {
        TimeShift.reinterpret(date, from: fromTZ, to: toTZ)
    }

    private func format(_ date: Date, in tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func apply() {
        store.transformAll { ev in
            var e = ev
            e.targetDate = reinterpret(ev.targetDate)
            return e
        }
        didApply = true
        fromID = toID   // collapse to a no-op so it can't be applied twice by mistake
    }
}
