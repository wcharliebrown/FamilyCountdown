import Foundation

/// Generates US holidays (New Year's, Easter, Independence Day, Thanksgiving,
/// Christmas) for the current and next year, matching the web page. These are
/// transient — regenerated at runtime, never persisted or editable.
enum HolidayProvider {

    /// Holidays for `[thisYear, thisYear + 1]`, built at local midnight.
    static func holidays(now: Date = Date(),
                         calendar: Calendar = .autoupdatingCurrent) -> [CountdownEvent] {
        let thisYear = calendar.component(.year, from: now)
        var result: [CountdownEvent] = []
        for year in [thisYear, thisYear + 1] {
            result.append(make("New Year's Day", year, 1, 1, calendar))
            if let easter = easterDate(year: year, calendar: calendar) {
                result.append(event("Easter", easter))
            }
            result.append(make("Independence Day", year, 7, 4, calendar))
            if let thx = thanksgiving(year: year, calendar: calendar) {
                result.append(event("Thanksgiving", thx))
            }
            result.append(make("Christmas", year, 12, 25, calendar))
        }
        return result
    }

    // MARK: - Builders

    private static func make(_ label: String, _ year: Int, _ month: Int, _ day: Int,
                             _ calendar: Calendar) -> CountdownEvent {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = 0; c.minute = 0; c.second = 0
        let date = calendar.date(from: c) ?? Date()
        return event(label, date)
    }

    private static func event(_ label: String, _ date: Date) -> CountdownEvent {
        CountdownEvent(label: label, targetDate: date, pinned: false,
                       repeats: false, isGenerated: true)
    }

    // MARK: - Computed holidays

    /// Fourth Thursday of November.
    static func thanksgiving(year: Int, calendar: Calendar) -> Date? {
        var c = DateComponents()
        c.year = year; c.month = 11
        c.weekday = 5          // Thursday (1 = Sunday)
        c.weekdayOrdinal = 4   // the 4th one
        c.hour = 0; c.minute = 0; c.second = 0
        return calendar.date(from: c)
    }

    /// Western (Gregorian) Easter Sunday — Anonymous Gregorian "Computus" algorithm.
    static func easterDate(year: Int, calendar: Calendar) -> Date? {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1

        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = 0; comps.minute = 0; comps.second = 0
        return calendar.date(from: comps)
    }
}
