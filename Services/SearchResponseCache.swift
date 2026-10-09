import Foundation

/// Kurzer In-Memory-Cache für TCGdex-Suchergebnisse (Debounce + weniger Doppel-Requests).
actor SearchResponseCache {
    static let shared = SearchResponseCache()

    private struct Entry {
        var cards: [TCGdexCardSummary]
        var storedAt: Date
    }

    private var storage: [String: Entry] = [:]
    private let ttl: TimeInterval = 120

    func cards(for key: String) -> [TCGdexCardSummary]? {
        guard let entry = storage[key] else { return nil }
        if Date().timeIntervalSince(entry.storedAt) > ttl {
            storage.removeValue(forKey: key)
            return nil
        }
        return entry.cards
    }

    func store(_ cards: [TCGdexCardSummary], for key: String) {
        storage[key] = Entry(cards: cards, storedAt: .now)
        // Einfache Größenbegrenzung
        if storage.count > 64 {
            let sorted = storage.sorted { $0.value.storedAt < $1.value.storedAt }
            for item in sorted.prefix(storage.count - 48) {
                storage.removeValue(forKey: item.key)
            }
        }
    }

    func makeKey(
        name: String?,
        setId: String?,
        localId: String?,
        alternates: [String],
        locale: String,
        bilingual: Bool
    ) -> String {
        [
            name ?? "",
            setId ?? "",
            localId ?? "",
            alternates.joined(separator: ","),
            locale,
            bilingual ? "bi" : "mono"
        ].joined(separator: "|")
    }
}
