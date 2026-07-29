import Foundation
import Combine

/// User preferences. Currently the display time zone used for day boundaries
/// (ARRIVED / roll-forward), holiday midnights, and the editor's date fields.
/// Empty identifier == Automatic (follows the device, which iOS keeps current
/// from the network when available).
final class SettingsStore: ObservableObject {
    private let key = "timeZoneIdentifier"

    @Published var timeZoneIdentifier: String {
        didSet { UserDefaults.standard.set(timeZoneIdentifier, forKey: key) }
    }

    init() {
        timeZoneIdentifier = UserDefaults.standard.string(forKey: key) ?? ""
    }

    var isAutomatic: Bool { timeZoneIdentifier.isEmpty }

    var timeZone: TimeZone {
        if timeZoneIdentifier.isEmpty { return .autoupdatingCurrent }
        return TimeZone(identifier: timeZoneIdentifier) ?? .autoupdatingCurrent
    }

    var calendar: Calendar {
        var c = Calendar.autoupdatingCurrent
        c.timeZone = timeZone
        return c
    }

    /// Human-readable label for the current selection.
    var timeZoneLabel: String {
        isAutomatic ? "Automatic" : Self.pretty(timeZone.identifier)
    }

    static func pretty(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: " ")
    }

    /// Medium date + short time, rendered in the selected time zone.
    func mediumString(from date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = timeZone
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
