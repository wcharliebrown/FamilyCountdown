import SwiftUI

/// One board row: event name on the left, and on the right either the split-flap
/// countdown or a red ARRIVED once the event's day has come.
struct EventRow: View {
    let event: DisplayEvent
    let metrics: FlipMetrics
    let rowHeight: CGFloat

    var body: some View {
        HStack(spacing: 20) {
            Text(event.label)
                .font(.custom(FlipMetrics.fontName, size: metrics.fontSize))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 12)

            if event.arrived {
                Text("ARRIVED")
                    .font(.custom(FlipMetrics.fontName, size: metrics.fontSize))
                    .foregroundStyle(Color(red: 1, green: 0, blue: 0))   // #ff0000
            } else {
                FlipClock(remaining: event.remaining, metrics: metrics)
            }
        }
        .frame(height: rowHeight)
    }
}
