import SwiftUI

/// One board row: event name on the left, and on the right either the split-flap
/// countdown or a red ARRIVED once the event's day has come.
struct EventRow: View {
    let event: DisplayEvent
    let metrics: FlipMetrics
    let rowHeight: CGFloat

    var body: some View {
        HStack(spacing: 20) {
            TileText(text: event.label, metrics: metrics)

            Spacer(minLength: 12)

            if event.arrived {
                TileText(text: "ARRIVED", metrics: metrics,
                         tileTop: FlipMetrics.arrivedTile,
                         tileBottom: FlipMetrics.arrivedTile,
                         glyph: .white)
            } else {
                FlipClock(remaining: event.remaining, metrics: metrics)
            }
        }
        .frame(height: rowHeight)
    }
}
