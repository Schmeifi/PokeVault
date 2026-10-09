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
            context.insert(AppSettings(showSampleDataBanner: true))
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

        let wishlist = WishlistEntry(
            catalogEntry: charizard,
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
}
