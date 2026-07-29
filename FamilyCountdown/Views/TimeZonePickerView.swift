import SwiftUI

/// Searchable time-zone chooser writing into a bound identifier.
/// An empty identifier means "Automatic" (follows the device); pass
/// `allowAutomatic: false` to require an explicit zone.
struct TimeZonePickerView: View {
    @Binding var identifier: String
    var allowAutomatic: Bool = true
    var title: String = "Time Zone"

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var identifiers: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers.sorted()
        guard !search.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            if allowAutomatic {
                Section {
                    Button { select("") } label: {
                        row(title: "Automatic",
                            subtitle: "Follows this device (\(SettingsStore.pretty(TimeZone.autoupdatingCurrent.identifier)))",
                            checked: identifier.isEmpty)
                    }
                }
            }
            Section {
                ForEach(identifiers, id: \.self) { id in
                    Button { select(id) } label: {
                        row(title: SettingsStore.pretty(id),
                            subtitle: offsetLabel(id),
                            checked: identifier == id)
                    }
                }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search time zones")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func select(_ id: String) {
        identifier = id
        dismiss()
    }

    private func row(title: String, subtitle: String, checked: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if checked { Image(systemName: "checkmark").foregroundStyle(.tint) }
        }
    }

    private func offsetLabel(_ id: String) -> String {
        guard let tz = TimeZone(identifier: id) else { return "" }
        let secs = tz.secondsFromGMT()
        let sign = secs < 0 ? "-" : "+"
        let h = abs(secs) / 3600, m = (abs(secs) % 3600) / 60
        return String(format: "GMT%@%02d:%02d", sign, h, m)
    }
}
