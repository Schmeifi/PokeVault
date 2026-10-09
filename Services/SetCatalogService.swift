import Foundation
import SwiftData

/// Synchronisiert TCGdex-Sets in lokale `PokemonSet`-Einträge (SwiftData).
@MainActor
final class SetCatalogService {
    private let provider: TCGdexProvider

    init(provider: TCGdexProvider = .shared) {
        self.provider = provider
    }

    func upsertSet(
        from detail: TCGdexSetDetail,
        in context: ModelContext
    ) throws -> PokemonSet {
        let setId = detail.id
        let descriptor = FetchDescriptor<PokemonSet>(
            predicate: #Predicate { $0.tcgdexSetId == setId }
        )
        let existing = try context.fetch(descriptor).first
        let set = existing ?? PokemonSet(tcgdexSetId: detail.id, name: detail.name)

        set.name = detail.name
        set.seriesName = detail.serie?.name
        set.logoURL = detail.logo
        set.symbolURL = detail.symbol
        set.cardCountOfficial = detail.cardCount?.official
        set.cardCountTotal = detail.cardCount?.total
        set.releaseDate = detail.parsedReleaseDate
        set.updatedAt = .now

        if existing == nil {
            context.insert(set)
        }
        return set
    }

    func upsertSetSummary(
        _ summary: TCGdexSetSummary,
        seriesName: String? = nil,
        in context: ModelContext
    ) throws -> PokemonSet {
        let setId = summary.id
        let descriptor = FetchDescriptor<PokemonSet>(
            predicate: #Predicate { $0.tcgdexSetId == setId }
        )
        let existing = try context.fetch(descriptor).first
        let set = existing ?? PokemonSet(tcgdexSetId: summary.id, name: summary.name)
        set.name = summary.name
        if let seriesName { set.seriesName = seriesName }
        set.logoURL = summary.logo
        set.symbolURL = summary.symbol
        set.cardCountOfficial = summary.cardCount?.official
        set.cardCountTotal = summary.cardCount?.total
        set.updatedAt = .now
        if existing == nil {
            context.insert(set)
        }
        return set
    }

    /// Lädt eine Seite Sets von TCGdex und speichert sie lokal.
    @discardableResult
    func syncSetsPage(
        locale: String = "de",
        page: Int = 1,
        itemsPerPage: Int = 50,
        in context: ModelContext
    ) async throws -> [PokemonSet] {
        let summaries = try await provider.fetchSets(
            locale: locale,
            page: page,
            itemsPerPage: itemsPerPage
        )
        var result: [PokemonSet] = []
        for summary in summaries {
            result.append(try upsertSetSummary(summary, in: context))
        }
        try context.save()
        return result
    }
}
