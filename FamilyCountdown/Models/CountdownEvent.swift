import Foundation

/// A single countdown entry. Mirrors the web page's JSON shape
/// (`label`, `targetDate`, `pinned`, `repeats`) so files round-trip 1:1.
/// `id` is local-only and never encoded to the on-disk JSON.
struct CountdownEvent: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var label: String
    var targetDate: Date
    var pinned: Bool
    var repeats: Bool

    /// Marks holidays generated at runtime (not user-owned, not persisted/editable).
    var isGenerated: Bool = false

    enum CodingKeys: String, CodingKey {
        case label, targetDate, pinned, repeats
    }

    init(id: UUID = UUID(), label: String, targetDate: Date,
         pinned: Bool = false, repeats: Bool = false, isGenerated: Bool = false) {
        self.id = id
        self.label = label
        self.targetDate = targetDate
        self.pinned = pinned
        self.repeats = repeats
        self.isGenerated = isGenerated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        repeats = try c.decodeIfPresent(Bool.self, forKey: .repeats) ?? false

        let raw = try c.decode(String.self, forKey: .targetDate)
        guard let date = ISO8601DateParsing.date(from: raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: .targetDate, in: c,
                debugDescription: "Unrecognized ISO-8601 date: \(raw)")
        }
        targetDate = date
        id = UUID()
        isGenerated = false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(label, forKey: .label)
        try c.encode(ISO8601DateParsing.string(from: targetDate), forKey: .targetDate)
        try c.encode(pinned, forKey: .pinned)
        try c.encode(repeats, forKey: .repeats)
    }
}

/// ISO-8601 with explicit timezone offset (e.g. `2026-11-20T00:00:00-05:00`),
/// matching the web page's `targetDate` format. Encodes in the device's
/// current timezone so exported files look like the originals.
enum ISO8601DateParsing {
    private static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Emits with the device's local UTC offset (`+/-HH:MM`) so files match the web format.
    private static let writer: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return f
    }()

    static func date(from string: String) -> Date? {
        plain.date(from: string) ?? withFractional.date(from: string)
    }

    static func string(from date: Date) -> String {
        writer.string(from: date)
    }
}
