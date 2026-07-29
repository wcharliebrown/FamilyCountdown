import SwiftUI

/// A zero-padded group of flip digits (e.g. 4 for days, 2 for h/m/s) with a
/// right-to-left 50ms stagger so the rightmost digit leads the cascade.
struct FlipGroup: View {
    let value: Int
    let digits: Int
    let metrics: FlipMetrics

    private var chars: [Character] {
        let s = String(format: "%0\(digits)d", max(0, value))
        // Guard against overflow beyond the digit count (days capped at 9999 upstream).
        return Array(s.suffix(digits))
    }

    var body: some View {
        HStack(spacing: metrics.fontSize * FlipMetrics.intraSpacingRatio) {
            let cs = chars
            ForEach(Array(cs.enumerated()), id: \.offset) { idx, ch in
                FlipDigit(value: ch, metrics: metrics,
                          delay: Double(cs.count - 1 - idx) * FlipMetrics.stagger)
            }
        }
    }
}

/// Renders a string as a row of resting flap tiles — used for event names and
/// the ARRIVED word so they match the split-flap digits.
struct TileText: View {
    let text: String
    let metrics: FlipMetrics
    var tileTop: Color = FlipMetrics.cardTop
    var tileBottom: Color = FlipMetrics.cardBottom
    var glyph: Color = FlipMetrics.glyphColor

    var body: some View {
        HStack(spacing: metrics.fontSize * FlipMetrics.intraSpacingRatio) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                TileFace(char: ch, metrics: metrics,
                         tileTop: tileTop, tileBottom: tileBottom, glyph: glyph)
            }
        }
    }
}

/// Column labels (DAYS / HOURS / MINUTES / SECONDS) sized and spaced to sit
/// directly over each digit group of a FlipClock.
struct ClockHeader: View {
    let metrics: FlipMetrics

    var body: some View {
        HStack(spacing: metrics.fontSize * FlipMetrics.groupSpacingRatio) {
            label("DAYS", digits: 4)
            label("HOURS", digits: 2)
            label("MINUTES", digits: 2)
            label("SECONDS", digits: 2)
        }
    }

    private func label(_ text: String, digits: Int) -> some View {
        Text(text)
            .font(.system(size: metrics.fontSize * 0.24, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(Color(white: 0.5))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: metrics.groupWidth(digits))
    }
}

/// The full DDDD HH MM SS split-flap readout — spacing between groups, exactly
/// like the web board.
struct FlipClock: View {
    let remaining: TimeRemaining
    let metrics: FlipMetrics

    var body: some View {
        HStack(spacing: metrics.fontSize * FlipMetrics.groupSpacingRatio) {
            FlipGroup(value: remaining.days, digits: 4, metrics: metrics)
            FlipGroup(value: remaining.hours, digits: 2, metrics: metrics)
            FlipGroup(value: remaining.minutes, digits: 2, metrics: metrics)
            FlipGroup(value: remaining.seconds, digits: 2, metrics: metrics)
        }
    }
}
