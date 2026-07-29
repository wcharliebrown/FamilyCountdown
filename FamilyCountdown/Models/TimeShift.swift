import Foundation

/// Reinterprets a date's wall-clock reading from one time zone to another —
/// the calendar components (Y/M/D/H/M/S) are read in `from` and re-stamped in
/// `to`, so the displayed time stays but the absolute instant moves.
enum TimeShift {
    static func reinterpret(_ date: Date, from: TimeZone, to: TimeZone) -> Date {
        var fromCal = Calendar(identifier: .gregorian)
        fromCal.timeZone = from
        let comps = fromCal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date)
        var toCal = Calendar(identifier: .gregorian)
        toCal.timeZone = to
        return toCal.date(from: comps) ?? date
    }
}
