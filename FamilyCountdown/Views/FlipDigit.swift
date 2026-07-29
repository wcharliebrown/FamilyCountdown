import SwiftUI

/// Shared look/feel + geometry for the split-flap cards, derived from one base
/// font size so the whole board scales together.
struct FlipMetrics: Equatable {
    var fontSize: CGFloat

    /// PQINA defaults ported from flip.min.js.
    static let duration: Double = 0.8      // flipDuration 800ms
    static let stagger: Double = 0.05      // 50ms right-to-left step
    static let fontName = "JetBrainsMono-ExtraBold"                   // OFL-licensed, safe to bundle

    // The split-flap tile is drawn here in SwiftUI (not baked into the font):
    // a white flap with a dark character and a hairline seam down the middle.
    static let glyphColor = Color(white: 0.06)                       // dark character on the flap
    static let cardTop = Color(white: 1.0)                           // upper leaf (white)
    static let cardBottom = Color(white: 0.93)                       // lower leaf (a hair darker, like a real flap)
    static let arrivedTile = Color(red: 0.85, green: 0.05, blue: 0.05) // red flap for ARRIVED
    static let seam = Color(white: 0.72)                             // hairline where the two leaves meet

    // Geometry ratios for the drawn flap + JetBrains Mono glyph inside it.
    static let glyphScale: CGFloat = 1.2       // draw the glyph larger than the base so it fills the flap
    static let widthRatio: CGFloat = 1.05      // flap width
    static let heightRatio: CGFloat = 1.42     // flap height (tall, like a real split-flap)
    static let intraSpacingRatio: CGFloat = 0.10   // gap between adjacent flaps
    static let groupSpacingRatio: CGFloat = 0.34   // gap between D / H / M / S groups
    static let advanceRatio: CGFloat = 1.15    // per-character footprint (flap + gap) for name layout

    // A full DDDD HH MM SS readout: 10 cards, 6 intra-group gaps, 3 group gaps.
    static var clockWidthUnits: CGFloat {
        10 * widthRatio + 6 * intraSpacingRatio + 3 * groupSpacingRatio
    }

    var width: CGFloat { (fontSize * Self.widthRatio).rounded() }
    var height: CGFloat { (fontSize * Self.heightRatio).rounded() }
    var glyphSize: CGFloat { fontSize * Self.glyphScale }
    var halfHeight: CGFloat { (height / 2).rounded() }
    var corner: CGFloat { max(3, fontSize * 0.07) }
    var perspective: CGFloat { 0.45 }
    var glyphYOffset: CGFloat { 0 }
    var clockWidth: CGFloat { fontSize * Self.clockWidthUnits }

    /// Width of one digit group (used to align column labels over each group).
    func groupWidth(_ digits: Int) -> CGFloat {
        CGFloat(digits) * width + CGFloat(max(0, digits - 1)) * fontSize * Self.intraSpacingRatio
    }
}

/// One flip card showing a single character, animating the classic two-leaf
/// mechanical fold whenever its `value` changes. `delay` staggers it within a group.
struct FlipDigit: View {
    let value: Character
    let metrics: FlipMetrics
    var delay: Double = 0

    @State private var oldChar: Character
    @State private var newChar: Character
    @State private var progress: Double = 1   // 1 = fully settled on the new char

    init(value: Character, metrics: FlipMetrics, delay: Double = 0) {
        self.value = value
        self.metrics = metrics
        self.delay = delay
        _oldChar = State(initialValue: value)
        _newChar = State(initialValue: value)
    }

    var body: some View {
        FlipCard(old: oldChar, new: newChar, progress: progress, metrics: metrics)
            .onChange(of: value) { _, newValue in
                guard newValue != newChar else { return }
                oldChar = newChar
                newChar = newValue
                progress = 0                                  // jump to show the old char
                withAnimation(.linear(duration: FlipMetrics.duration).delay(delay)) {
                    progress = 1                              // then flip to the new char
                }
            }
    }
}

/// Renders the card at a given animation `progress` (0…1):
/// phase 1 (0–0.5) the old top leaf folds down and away; phase 2 (0.5–1) the new
/// bottom leaf drops and bounces to settle.
private struct FlipCard: View {
    let old: Character
    let new: Character
    let progress: Double
    let metrics: FlipMetrics

    var body: some View {
        ZStack {
            // Static backing: new on top (revealed as old folds away), old on bottom
            // (until the falling new leaf covers it).
            VStack(spacing: 0) {
                Leaf(char: new, half: .top, metrics: metrics)
                Leaf(char: old, half: .bottom, metrics: metrics)
            }

            if progress < 0.5 {
                let t = easeIn(progress / 0.5)
                Leaf(char: old, half: .top, metrics: metrics)
                    .overlay(Color.black.opacity(0.55 * t))
                    .rotation3DEffect(.degrees(-90 * t), axis: (1, 0, 0),
                                      anchor: .bottom, perspective: metrics.perspective)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                let t = easeOutBounce((progress - 0.5) / 0.5)
                Leaf(char: new, half: .bottom, metrics: metrics)
                    .overlay(Color.black.opacity(0.5 * (1 - t)))
                    .rotation3DEffect(.degrees(90 * (1 - t)), axis: (1, 0, 0),
                                      anchor: .top, perspective: metrics.perspective)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }

            // Center seam.
            Rectangle()
                .fill(FlipMetrics.seam)
                .frame(height: max(1, metrics.fontSize * 0.03))
        }
        .frame(width: metrics.width, height: metrics.height)
        .clipShape(RoundedRectangle(cornerRadius: metrics.corner))
    }

    private func easeIn(_ t: Double) -> Double { t * t }

    /// Port of PQINA flip's `ease-out-bounce`.
    private func easeOutBounce(_ t: Double) -> Double {
        let n1 = 7.5625, d1 = 2.75
        var e = t
        if e < 1 / d1 { return n1 * e * e }
        if e < 2 / d1 { e -= 1.5 / d1; return n1 * e * e + 0.75 }
        if e < 2.5 / d1 { e -= 2.25 / d1; return n1 * e * e + 0.9375 }
        e -= 2.625 / d1; return n1 * e * e + 0.984375
    }
}

/// A single half (top or bottom) of a glyph rendered on a dark leaf.
private struct Leaf: View {
    enum Half { case top, bottom }
    let char: Character
    let half: Half
    let metrics: FlipMetrics
    var tileTop: Color = FlipMetrics.cardTop
    var tileBottom: Color = FlipMetrics.cardBottom
    var glyph: Color = FlipMetrics.glyphColor

    var body: some View {
        Text(String(char))
            .font(.custom(FlipMetrics.fontName, fixedSize: metrics.glyphSize))
            .foregroundStyle(glyph)
            .frame(width: metrics.width, height: metrics.height)   // glyph centered in full flap
            .offset(y: metrics.glyphYOffset)
            .frame(width: metrics.width, height: metrics.halfHeight,
                   alignment: half == .top ? .top : .bottom)        // window onto one half
            .clipped()
            .background(half == .top ? tileTop : tileBottom)
    }
}

/// A single resting flap (no animation), used for the static event-name and
/// ARRIVED lettering so names and digits read as the same physical tiles.
struct TileFace: View {
    let char: Character
    let metrics: FlipMetrics
    var tileTop: Color = FlipMetrics.cardTop
    var tileBottom: Color = FlipMetrics.cardBottom
    var glyph: Color = FlipMetrics.glyphColor

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Leaf(char: char, half: .top, metrics: metrics,
                     tileTop: tileTop, tileBottom: tileBottom, glyph: glyph)
                Leaf(char: char, half: .bottom, metrics: metrics,
                     tileTop: tileTop, tileBottom: tileBottom, glyph: glyph)
            }
            Rectangle()
                .fill(FlipMetrics.seam)
                .frame(height: max(1, metrics.fontSize * 0.03))
        }
        .frame(width: metrics.width, height: metrics.height)
        .clipShape(RoundedRectangle(cornerRadius: metrics.corner))
    }
}
