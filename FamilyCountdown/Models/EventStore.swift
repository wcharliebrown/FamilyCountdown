import Foundation
import Combine

/// Loads, persists, and mutates the user's event list as a local JSON file
/// (`Documents/FamilyCountdownEvents.json`), seeded on first launch from the
/// bundled `SeedEvents.json`. On-device only — no server/sync.
final class EventStore: ObservableObject {
    @Published private(set) var events: [CountdownEvent] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        load()
    }

    static func defaultFileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("FamilyCountdownEvents.json")
    }

    // MARK: - Loading / seeding

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode([CountdownEvent].self, from: data) {
            events = decoded
            return
        }
        // First launch (or unreadable): seed from the bundled JSON.
        events = Self.loadSeed()
        save()
    }

    static func loadSeed() -> [CountdownEvent] {
        guard let url = Bundle.main.url(forResource: "SeedEvents", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        let dec = JSONDecoder()
        return (try? dec.decode([CountdownEvent].self, from: data)) ?? []
    }

    // MARK: - Persistence

    func save() {
        guard let data = try? encoder.encode(events) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - CRUD

    func add(_ event: CountdownEvent) {
        events.append(event)
        save()
    }

    func update(_ event: CountdownEvent) {
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[idx] = event
        save()
    }

    func delete(_ event: CountdownEvent) {
        events.removeAll { $0.id == event.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        events.remove(atOffsets: offsets)
        save()
    }

    /// Apply a transform to every event and persist once.
    func transformAll(_ transform: (CountdownEvent) -> CountdownEvent) {
        events = events.map(transform)
        save()
    }
}
