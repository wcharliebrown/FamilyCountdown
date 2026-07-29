import Foundation

/// Days/hours/minutes/seconds remaining until a target instant.
struct TimeRemaining: Equatable {
    var days: Int
    var hours: Int
    var minutes: Int
    var seconds: Int

    /// Non-negative breakdown of `target - now`, clamped to zero once passed.
    /// Days are capped at 9999 (4 flip digits).
    init(from now: Date, to target: Date) {
        let total = max(0, Int(target.timeIntervalSince(now)))
        days = min(9999, total / 86_400)
        let rem = total % 86_400
        hours = rem / 3_600
        minutes = (rem % 3_600) / 60
        seconds = rem % 60
    }

    var isZero: Bool { days == 0 && hours == 0 && minutes == 0 && seconds == 0 }
}

/// A row ready for display: the resolved event, its (possibly rolled-forward)
/// occurrence, and whether it has "arrived".
struct DisplayEvent: Identifiable, Equatable {
    let id: UUID
    let label: String
    let occurrence: Date
    let arrived: Bool
    let pinned: Bool
    let remaining: TimeRemaining
}

/// Pure logic for turning the raw event list (+ generated holidays) into the
/// sorted, rolled-forward, filtered board shown on screen.
enum CountdownEngine {

    /// Build the display list for `now`:
    /// - repeating events roll their year forward to the next occurrence that is
    ///   today or later;
    /// - an event shows ARRIVED for the whole calendar day it lands on (once passed);
    /// - the day after, non-repeating events drop off (repeating ones have already
    ///   rolled to next year);
    /// - sort: non-pinned first (soonest on top), then pinned (soonest on top).
    static func board(from events: [CountdownEvent],
                      now: Date = Date(),
                      calendar: Calendar = .autoupdatingCurrent) -> [DisplayEvent] {
        let today = calendar.startOfDay(for: now)

        let resolved: [DisplayEvent] = events.compactMap { ev in
            let occ = occurrence(of: ev, today: today, calendar: calendar)
            let occDay = calendar.startOfDay(for: occ)

            if occDay < today {
                // Already fully past its day. Repeating events should have rolled;
                // if we still land here, drop the row.
                return nil
            }

            // Arrived = its instant has passed but we're still on its calendar day.
            let arrived = now >= occ && occDay == today
            return DisplayEvent(id: ev.id, label: ev.label, occurrence: occ,
                                arrived: arrived, pinned: ev.pinned,
                                remaining: TimeRemaining(from: now, to: occ))
        }

        return resolved.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }    // pinned first (top)
            return a.occurrence < b.occurrence
        }
    }

    /// The occurrence to display. For repeating events, advance the year until the
    /// date is today or later (keeps ARRIVED visible on the day itself). Non-repeating
    /// events return their stored date unchanged.
    static func occurrence(of event: CountdownEvent,
                           today: Date,
                           calendar: Calendar) -> Date {
        guard event.repeats else { return event.targetDate }

        var date = event.targetDate
        // Roll forward whole years until the occurrence's day is today or later.
        var guardCount = 0
        while calendar.startOfDay(for: date) < today && guardCount < 200 {
            guard let next = calendar.date(byAdding: .year, value: 1, to: date) else { break }
            date = next
            guardCount += 1
        }
        return date
    }
}
