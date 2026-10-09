import Foundation
import SwiftData

/// CRUD + Migration für Mehrfach-Wunschlisten.
@MainActor
enum WishlistService {
    static let defaultName = "Wunschliste"

    /// Stellt sicher, dass mindestens eine Liste existiert und orphaned Entries zugeordnet sind.
    @discardableResult
    static func ensureDefaultWishlist(in context: ModelContext) -> Wishlist {
        let descriptor = FetchDescriptor<Wishlist>(sortBy: [SortDescriptor(\.createdAt)])
        let lists = (try? context.fetch(descriptor)) ?? []
        let primary: Wishlist
        if let first = lists.first {
            primary = first
        } else {
            let created = Wishlist(name: defaultName)
            context.insert(created)
            primary = created
        }

        let entryDescriptor = FetchDescriptor<WishlistEntry>()
        let entries = (try? context.fetch(entryDescriptor)) ?? []
        for entry in entries where entry.wishlist == nil {
            entry.wishlist = primary
            entry.updatedAt = .now
        }
        try? context.save()
        return primary
    }

    static func create(named name: String, in context: ModelContext) -> Wishlist {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = Wishlist(name: trimmed.isEmpty ? defaultName : trimmed)
        context.insert(list)
        try? context.save()
        return list
    }

    static func rename(_ list: Wishlist, to name: String, in context: ModelContext) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        list.name = trimmed
        list.updatedAt = .now
        try? context.save()
    }

    static func delete(_ list: Wishlist, in context: ModelContext) {
        context.delete(list)
        try? context.save()
        ensureDefaultWishlist(in: context)
    }

    /// Fügt eine Katalogkarte einer Wunschliste hinzu (kein Duplikat derselben TCGdex-ID in derselben Liste).
    @discardableResult
    static func add(
        catalogEntry: CardCatalogEntry,
        to list: Wishlist,
        priority: Int = 3,
        desiredCondition: CardCondition = .nearMint,
        desiredLanguage: CardLanguage = .de,
        targetPriceEUR: Double? = nil,
        note: String? = nil,
        in context: ModelContext
    ) -> WishlistEntry {
        if let existing = list.entries.first(where: { $0.catalogEntry?.tcgdexId == catalogEntry.tcgdexId && !$0.isBought }) {
            existing.updatedAt = .now
            try? context.save()
            return existing
        }
        let entry = WishlistEntry(
            catalogEntry: catalogEntry,
            priority: priority,
            note: note,
            desiredCondition: desiredCondition,
            desiredLanguage: desiredLanguage,
            targetPriceEUR: targetPriceEUR
        )
        entry.wishlist = list
        context.insert(entry)
        list.updatedAt = .now
        try? context.save()
        return entry
    }
}
