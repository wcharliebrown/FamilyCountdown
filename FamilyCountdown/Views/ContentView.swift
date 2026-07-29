import SwiftUI

/// The station-board display: black, landscape, up to as many rows as fit.
/// Names on the left, split-flap countdowns on the right; a subtle gear opens the editor.
struct ContentView: View {
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var settings: SettingsStore

    @State private var now = Date()
    @State private var showEditor = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let board = CountdownEngine.board(from: allEvents, now: now,
                                              calendar: settings.calendar)
            let maxChars = board.map { $0.label.count }.max() ?? 1
            let layout = BoardLayout(size: geo.size, longestLabel: maxChars)
            // Pinned events are always kept on screen (at the top); the rest of
            // the rows are filled with the soonest non-pinned events.
            let pinned = board.filter { $0.pinned }
            let nonPinned = board.filter { !$0.pinned }
            let pinnedShown = Array(pinned.prefix(layout.maxRows))
            let nonPinnedShown = Array(nonPinned.prefix(max(0, layout.maxRows - pinnedShown.count)))
            let visible = pinnedShown + nonPinnedShown

            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()

                if visible.isEmpty {
                    emptyState(layout)
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            ClockHeader(metrics: layout.metrics)
                        }
                        .frame(height: layout.headerHeight, alignment: .bottom)

                        ForEach(visible) { event in
                            EventRow(event: event, metrics: layout.metrics,
                                     rowHeight: layout.rowHeight)
                            Rectangle()
                                .fill(Color(white: 0.2))
                                .frame(height: 1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, layout.hPadding)
                    .padding(.top, layout.topInset)
                }

                gearButton
            }
        }
        .ignoresSafeArea()
        .onReceive(tick) { now = $0 }
        .sheet(isPresented: $showEditor) {
            EventEditorList()
                .environmentObject(store)
                .environmentObject(settings)
        }
    }

    /// User events plus generated US holidays (deduped by label against user events).
    private var allEvents: [CountdownEvent] {
        let userLabels = Set(store.events.map { $0.label.lowercased() })
        let holidays = HolidayProvider.holidays(now: now, calendar: settings.calendar)
            .filter { !userLabels.contains($0.label.lowercased()) }
        return store.events + holidays
    }

    private var gearButton: some View {
        Button {
            showEditor = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 22))
                .foregroundStyle(Color(white: 0.35))
                .padding(18)
        }
        .accessibilityLabel("Edit events")
    }

    private func emptyState(_ layout: BoardLayout) -> some View {
        VStack(spacing: 16) {
            Text("No upcoming events")
                .font(.custom(FlipMetrics.fontName, size: layout.metrics.fontSize))
                .foregroundStyle(Color(white: 0.6))
            Text("Tap the gear to add one")
                .font(.system(size: 18))
                .foregroundStyle(Color(white: 0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Derives one uniform font size, row height, and how many rows fit for the
/// current screen. The font size is the largest that still lets the longest
/// event name and the full DDDD·HH·MM·SS clock share a single line — so every
/// row (names and digits alike) renders at exactly the same size.
struct BoardLayout {
    let metrics: FlipMetrics
    let rowHeight: CGFloat
    let hPadding: CGFloat
    let topInset: CGFloat
    let headerHeight: CGFloat
    let maxRows: Int

    init(size: CGSize, longestLabel: Int) {
        hPadding = 40
        topInset = 44          // reserved strip so the gear never overlaps the header
        // Fixed horizontal chrome: left/right padding + name↔clock gaps.
        let chrome: CGFloat = hPadding * 2 + 60
        let nameUnits = CGFloat(max(1, longestLabel)) * FlipMetrics.advanceRatio
        let widthFit = (size.width - chrome) / (nameUnits + FlipMetrics.clockWidthUnits)
        let heightCap = min(58, size.height * 0.05)
        let fontSize = max(16, min(heightCap, widthFit))

        metrics = FlipMetrics(fontSize: fontSize)
        headerHeight = fontSize * 0.24 + 10          // label + gap under the header
        let vPadding = fontSize * 0.34
        rowHeight = metrics.height + vPadding * 2
        maxRows = max(1, Int((size.height - topInset - headerHeight) / (rowHeight + 1)))
    }
}
