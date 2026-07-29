import XCTest
@testable import FamilyCountdown

final class CountdownTests: XCTestCase {

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return utc.date(from: comps)!
    }

    // MARK: - Holiday math

    func testEaster2026() {
        let easter = HolidayProvider.easterDate(year: 2026, calendar: utc)!
        XCTAssertEqual(utc.component(.month, from: easter), 4)
        XCTAssertEqual(utc.component(.day, from: easter), 5)   // Apr 5, 2026
    }

    func testEaster2027() {
        let easter = HolidayProvider.easterDate(year: 2027, calendar: utc)!
        XCTAssertEqual(utc.component(.month, from: easter), 3)
        XCTAssertEqual(utc.component(.day, from: easter), 28)  // Mar 28, 2027
    }

    func testThanksgiving2026() {
        let t = HolidayProvider.thanksgiving(year: 2026, calendar: utc)!
        XCTAssertEqual(utc.component(.month, from: t), 11)
        XCTAssertEqual(utc.component(.day, from: t), 26)       // Nov 26, 2026
    }

    // MARK: - TimeRemaining

    func testTimeRemainingBreakdown() {
        let now = date(2026, 1, 1, 0, 0)
        let target = utc.date(byAdding: .init(day: 2, hour: 3, minute: 4), to: now)!
        let r = TimeRemaining(from: now, to: target)
        XCTAssertEqual(r.days, 2)
        XCTAssertEqual(r.hours, 3)
        XCTAssertEqual(r.minutes, 4)
    }

    func testTimeRemainingClampsToZero() {
        let now = date(2026, 6, 1)
        let past = date(2026, 5, 1)
        let r = TimeRemaining(from: now, to: past)
        XCTAssertTrue(r.isZero)
    }

    // MARK: - Roll-forward & board

    func testRepeatingEventRollsToNextYear() {
        // Birthday is June 1. "Today" is 2026-06-02 — the day after this year's
        // occurrence — so it should roll forward to 2027-06-01.
        let event = CountdownEvent(label: "B-day", targetDate: date(2025, 6, 1),
                                   pinned: false, repeats: true)
        let now = date(2026, 6, 2, 9, 0)
        let occ = CountdownEngine.occurrence(of: event,
                                             today: utc.startOfDay(for: now),
                                             calendar: utc)
        XCTAssertEqual(utc.component(.year, from: occ), 2027)
        XCTAssertEqual(utc.component(.month, from: occ), 6)
        XCTAssertEqual(utc.component(.day, from: occ), 1)
    }

    func testRepeatingEventStaysOnTheDay() {
        // On the birthday itself, occurrence is today (so ARRIVED can show).
        let event = CountdownEvent(label: "B-day", targetDate: date(2025, 6, 1),
                                   pinned: false, repeats: true)
        let now = date(2026, 6, 1, 9, 0)
        let occ = CountdownEngine.occurrence(of: event,
                                             today: utc.startOfDay(for: now),
                                             calendar: utc)
        XCTAssertEqual(utc.component(.year, from: occ), 2026)
        XCTAssertEqual(utc.component(.day, from: occ), 1)
    }

    func testArrivedShowsOnTheDay() {
        // Event at midnight today; now is later the same day.
        let event = CountdownEvent(label: "Today", targetDate: date(2026, 6, 1, 0, 0),
                                   pinned: false, repeats: false)
        let now = date(2026, 6, 1, 10, 0)
        let board = CountdownEngine.board(from: [event], now: now, calendar: utc)
        XCTAssertEqual(board.count, 1)
        XCTAssertTrue(board[0].arrived)
    }

    func testNonRepeatingDropsOffDayAfter() {
        let event = CountdownEvent(label: "Gone", targetDate: date(2026, 6, 1, 0, 0),
                                   pinned: false, repeats: false)
        let now = date(2026, 6, 2, 0, 1)   // next day
        let board = CountdownEngine.board(from: [event], now: now, calendar: utc)
        XCTAssertTrue(board.isEmpty)
    }

    // MARK: - Store persistence (the editor's data path)

    func testStoreRoundTrips() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fc-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = EventStore(fileURL: url)
        let start = store.events.count
        var ev = CountdownEvent(label: "Round Trip", targetDate: date(2027, 3, 3),
                                pinned: true, repeats: false)
        store.add(ev)

        // Re-open from the same file: the added event must persist.
        let reopened = EventStore(fileURL: url)
        XCTAssertEqual(reopened.events.count, start + 1)
        XCTAssertTrue(reopened.events.contains { $0.label == "Round Trip" && $0.pinned })

        // Edit then delete.
        ev.label = "Edited"
        if let saved = reopened.events.first(where: { $0.label == "Round Trip" }) {
            ev = saved; ev.label = "Edited"; reopened.update(ev)
        }
        let afterEdit = EventStore(fileURL: url)
        XCTAssertTrue(afterEdit.events.contains { $0.label == "Edited" })

        if let toDelete = afterEdit.events.first(where: { $0.label == "Edited" }) {
            afterEdit.delete(toDelete)
        }
        let afterDelete = EventStore(fileURL: url)
        XCTAssertFalse(afterDelete.events.contains { $0.label == "Edited" })
    }

    func testDateFormatRoundTrips() {
        let iso = "2026-11-20T00:00:00-05:00"
        let d = ISO8601DateParsing.date(from: iso)
        XCTAssertNotNil(d)
        // Re-encoding produces a valid ISO-8601 string parseable back to the same instant.
        let back = ISO8601DateParsing.date(from: ISO8601DateParsing.string(from: d!))
        XCTAssertEqual(back, d)
    }

    // MARK: - Time shift (reinterpret wall-clock across zones)

    func testShiftEasternToCentralPreservesWallClock() {
        let eastern = TimeZone(identifier: "America/New_York")!
        let central = TimeZone(identifier: "America/Chicago")!
        // Nov 20, 2026 00:00 Eastern (EST, -05:00).
        let stored = ISO8601DateParsing.date(from: "2026-11-20T00:00:00-05:00")!

        let shifted = TimeShift.reinterpret(stored, from: eastern, to: central)

        // Displayed in Central, the shifted instant reads as the SAME wall-clock (midnight Nov 20).
        var cal = Calendar(identifier: .gregorian); cal.timeZone = central
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: shifted)
        XCTAssertEqual(c.year, 2026)
        XCTAssertEqual(c.month, 11)
        XCTAssertEqual(c.day, 20)
        XCTAssertEqual(c.hour, 0)
        XCTAssertEqual(c.minute, 0)
        // And the absolute instant moved one hour later (Central midnight is 1h after Eastern midnight).
        XCTAssertEqual(shifted.timeIntervalSince(stored), 3600, accuracy: 1)
    }

    func testShiftSameZoneIsNoOp() {
        let tz = TimeZone(identifier: "America/Chicago")!
        let d = date(2027, 5, 1, 9, 30)
        XCTAssertEqual(TimeShift.reinterpret(d, from: tz, to: tz), d)
    }

    func testPinnedSortsToTop() {
        // A pinned event dated later than a normal one still sorts above it.
        let laterPinned = CountdownEvent(label: "Pinned", targetDate: date(2026, 6, 10),
                                         pinned: true, repeats: false)
        let soonNormal = CountdownEvent(label: "Normal", targetDate: date(2026, 6, 5),
                                        pinned: false, repeats: false)
        let now = date(2026, 6, 1)
        let board = CountdownEngine.board(from: [laterPinned, soonNormal], now: now, calendar: utc)
        XCTAssertEqual(board.first?.label, "Pinned")
        XCTAssertEqual(board.last?.label, "Normal")
    }
}
