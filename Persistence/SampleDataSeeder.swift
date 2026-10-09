import Foundation
import SwiftData

/// Beispieldaten — **nie** automatisch beim normalen App-Start.
/// Nur Previews/Tests oder explizite Aktion „Beispieldaten laden“ in den Einstellungen.
/// Preise mit Quelle `.sample` sind KEINE Marktdaten.
enum SampleDataSeeder {
    static let sampleBannerText =
        "Beispieldaten – keine historischen Marktpreise. Werte sind Platzhalter für die UI."

    /// Stellt nur `AppSettings` sicher — leerer Store, kein Seed.
    @MainActor
    static func ensureSettings(in context: ModelContext) {
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let existingSettings = (try? context.fetch(settingsDescriptor)) ?? []
        if existingSettings.isEmpty {
            context.insert(AppSettings(showSampleDataBanner: false))
            try? context.save()
        }
    }

    /// Früherer Auto-Seed-Einstieg — jetzt **nur** Settings, keine Beispielkarten.
    @MainActor
    static func seedIfNeeded(in context: ModelContext) {
        ensureSettings(in: context)
    }

    /// Explizites Laden von Beispieldaten (Settings-Aktion / Previews / Tests).
    @MainActor
    @discardableResult
    static func loadSampleData(in context: ModelContext, force: Bool = false) -> Bool {
        ensureSettings(in: context)

        let cardsDescriptor = FetchDescriptor<OwnedCard>()
        let ownedCount = (try? context.fetchCount(cardsDescriptor)) ?? 0
        if ownedCount > 0, !force { return false }

        let set = PokemonSet(
            tcgdexSetId: "swsh3",
            name: "Darkness Ablaze",
            seriesName: "Sword & Shield",
            cardCountOfficial: 189,
            cardCountTotal: 201
        )
        context.insert(set)

        let furret = CardCatalogEntry(
            tcgdexId: "swsh3-136",
            cardmarketId: "483559",
            name: "Furret",
            localizedNames: ["en": "Furret", "de": "Wiesor"],
            cardmarketName: "Furret",
            setId: "swsh3",
            setName: "Darkness Ablaze",
            number: "136",
            rarity: "Uncommon",
            types: ["Colorless"],
            illustrator: "tetsuya koizumi",
            imageURL: "https://assets.tcgdex.net/en/swsh/swsh3/136",
            availableVariants: ["normal", "reverse"],
            cardmarketURL: nil
        )
        context.insert(furret)

        let pikachu = CardCatalogEntry(
            tcgdexId: "base1-58",
            name: "Pikachu",
            localizedNames: ["en": "Pikachu", "de": "Pikachu"],
            setId: "base1",
            setName: "Base Set",
            number: "58",
            rarity: "Common",
            types: ["Lightning"],
            illustrator: "Mitsuhiro Arita",
            imageURL: "https://assets.tcgdex.net/en/base/base1/58",
            availableVariants: ["normal"]
        )
        context.insert(pikachu)

        let charizard = CardCatalogEntry(
            tcgdexId: "base1-4",
            name: "Charizard",
            localizedNames: ["en": "Charizard", "de": "Glurak"],
            setId: "base1",
            setName: "Base Set",
            number: "4",
            rarity: "Rare Holo",
            types: ["Fire"],
            illustrator: "Mitsuhiro Arita",
            imageURL: "https://assets.tcgdex.net/en/base/base1/4",
            availableVariants: ["holo", "normal"]
        )
        context.insert(charizard)

        let sampleFurretPrice = PriceSnapshot(
            catalogEntry: furret,
            amountEUR: 0.15,
            source: .sample,
            metric: "Beispiel-Mittelwert",
            isSampleData: true,
            note: sampleBannerText
        )
        context.insert(sampleFurretPrice)

        let samplePikaPrice = PriceSnapshot(
            catalogEntry: pikachu,
            amountEUR: 2.50,
            source: .sample,
            metric: "Beispiel-Mittelwert",
            isSampleData: true,
            note: sampleBannerText
        )
        context.insert(samplePikaPrice)

        let owned1 = OwnedCard(
            catalogEntry: furret,
            quantity: 2,
            condition: .nearMint,
            language: .de,
            variant: .normal,
            purchasePrice: 0.10,
            note: "Beispielexemplar"
        )
        context.insert(owned1)

        let owned2 = OwnedCard(
            catalogEntry: pikachu,
            quantity: 1,
            condition: .excellent,
            language: .en,
            variant: .normal,
            manualValue: 3.00,
            note: "Manuelle Bewertung (Beispiel)"
        )
        context.insert(owned2)

        let owned3 = OwnedCard(
            catalogEntry: charizard,
            quantity: 1,
            condition: .good,
            language: .en,
            variant: .holo,
            note: "Ohne Marktpreis – Beispiel"
        )
        context.insert(owned3)

        let favorites = UserCollection(
            name: "Favoriten",
            collectionDescription: "Beispielsammlung",
            isSmart: false,
            accentColorHex: "#D97338"
        )
        context.insert(favorites)
        context.insert(CollectionMembership(collection: favorites, ownedCard: owned2))

        let wishList = Wishlist(name: "Beispiele")
        context.insert(wishList)
        let wishlist = WishlistEntry(
            catalogEntry: charizard,
            wishlist: wishList,
            priority: 1,
            maxPriceEUR: 50,
            note: "Wunschliste – Beispiel"
        )
        context.insert(wishlist)

        let tag = ThemeTag(name: "Klassiker", colorHex: "#E0A800")
        context.insert(tag)

        try? context.save()
        return true
    }

    /// Entfernt Beispieldaten (Sample-Preise, Beispiel-Exemplare, Beispiel-Wishlist/Sammlung).
    /// Löscht **nicht** echte Nutzerkarten ohne Sample-Marker. Kein Re-Seed.
    @MainActor
    @discardableResult
    static func clearSampleData(in context: ModelContext) -> Int {
        var removed = 0

        let ownedDescriptor = FetchDescriptor<OwnedCard>()
        let owned = (try? context.fetch(ownedDescriptor)) ?? []
        for card in owned where isSampleOwnedCard(card) {
            context.delete(card)
            removed += 1
        }

        let snapDescriptor = FetchDescriptor<PriceSnapshot>()
        let snaps = (try? context.fetch(snapDescriptor)) ?? []
        for snap in snaps where snap.isSampleData || snap.source == .sample {
            context.delete(snap)
            removed += 1
        }

        let wishDescriptor = FetchDescriptor<WishlistEntry>()
        let wishes = (try? context.fetch(wishDescriptor)) ?? []
        for wish in wishes {
            let note = (wish.note ?? "").lowercased()
            if note.contains("beispiel") {
                context.delete(wish)
                removed += 1
            }
        }

        let listDescriptor = FetchDescriptor<Wishlist>()
        let lists = (try? context.fetch(listDescriptor)) ?? []
        for list in lists {
            let name = list.name.lowercased()
            if name.contains("beispiel") || (list.entries.isEmpty && name == WishlistService.defaultName.lowercased()) {
                // Nur Beispiel-Listen löschen; leere Default-Liste behalten.
                if name.contains("beispiel") {
                    context.delete(list)
                    removed += 1
                }
            }
        }

        let colDescriptor = FetchDescriptor<UserCollection>()
        let cols = (try? context.fetch(colDescriptor)) ?? []
        for col in cols {
            let desc = (col.collectionDescription ?? "").lowercased()
            if desc.contains("beispiel") || (col.name == "Favoriten" && desc.contains("beispiel")) {
                context.delete(col)
                removed += 1
            }
        }

        // Orphan sample catalog entries (no remaining owned/wishlist)
        let catalogDescriptor = FetchDescriptor<CardCatalogEntry>()
        let catalog = (try? context.fetch(catalogDescriptor)) ?? []
        for entry in catalog {
            let sampleSnaps = entry.priceSnapshots.contains(where: { $0.isSampleData || $0.source == .sample })
            let knownSampleIds: Set<String> = ["swsh3-136", "base1-58", "base1-4"]
            if (sampleSnaps || knownSampleIds.contains(entry.tcgdexId)),
               entry.ownedCards.isEmpty,
               entry.wishlistEntries.isEmpty {
                context.delete(entry)
                removed += 1
            }
        }

        try? context.save()
        return removed
    }

    @MainActor
    static func hasSampleData(in context: ModelContext) -> Bool {
        let ownedDescriptor = FetchDescriptor<OwnedCard>()
        let owned = (try? context.fetch(ownedDescriptor)) ?? []
        if owned.contains(where: isSampleOwnedCard) { return true }
        let snapDescriptor = FetchDescriptor<PriceSnapshot>()
        let snaps = (try? context.fetch(snapDescriptor)) ?? []
        return snaps.contains(where: { $0.isSampleData || $0.source == .sample })
    }

    private static func isSampleOwnedCard(_ card: OwnedCard) -> Bool {
        let note = (card.note ?? "").lowercased()
        if note.contains("beispiel") { return true }
        // Nur Sample-Preis-Snapshots — nicht jede echte base1-4 löschen.
        if let entry = card.catalogEntry,
           entry.priceSnapshots.contains(where: { $0.isSampleData || $0.source == .sample }) {
            return true
        }
        return false
    }

}
