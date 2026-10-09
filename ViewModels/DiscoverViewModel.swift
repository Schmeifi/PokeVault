import Foundation
import Observation

enum DiscoverMode: String, CaseIterable, Identifiable {
    case search
    case sets
    case themes

    var id: String { rawValue }

    var titleDE: String {
        switch self {
        case .search: return "Suche"
        case .sets: return "Sets"
        case .themes: return "Themen"
        }
    }
}

@Observable
@MainActor
final class DiscoverViewModel {
    var mode: DiscoverMode = .search
    var query: String = ""
    var setFilter: String = ""
    var numberFilter: String = ""
    var locale: String = "de"
    var bilingual = true
    var hits: [CardSearchHit] = []
    var sets: [TCGdexSetSummary] = []
    var setQuery: String = ""
    var isLoading = false
    var errorMessage: String?
    var hasSearched = false
    var setsLoaded = false
    var setNameCache: [String: String] = [:]

    private let provider: TCGdexProvider
    private var searchTask: Task<Void, Never>?
    private var searchGeneration = 0

    init(provider: TCGdexProvider = .shared) {
        self.provider = provider
    }

    var results: [TCGdexCardSummary] { hits.map(\.card) }

    /// Debounced Suche (300 ms) — tippen löst nicht jeden Keystroke aus.
    func scheduleSearch(debounceMs: UInt64 = 300) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: debounceMs * 1_000_000)
            guard !Task.isCancelled else { return }
            await self?.search()
        }
    }

    func search() async {
        searchGeneration += 1
        let generation = searchGeneration

        let parsed = CardSearchQueryParser.parse(
            freeText: query,
            numberField: numberFilter,
            setField: setFilter
        )
        let searchQuery = TCGdexCardSearchQuery(
            name: parsed.name,
            setId: parsed.setId,
            localId: parsed.localId,
            page: 1,
            itemsPerPage: 24
        )
        guard !searchQuery.isEmpty else {
            hits = []
            hasSearched = false
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        hasSearched = true
        defer {
            if generation == searchGeneration {
                isLoading = false
            }
        }

        do {
            let cacheKey = await SearchResponseCache.shared.makeKey(
                name: searchQuery.name,
                setId: searchQuery.setId,
                localId: searchQuery.localId,
                alternates: parsed.localIdAlternates,
                locale: locale,
                bilingual: bilingual || parsed.looksLikeCardNumber
            )

            var cards: [TCGdexCardSummary]
            if let cached = await SearchResponseCache.shared.cards(for: cacheKey) {
                cards = cached
            } else {
                if bilingual || parsed.looksLikeCardNumber {
                    cards = try await provider.searchCardsBilingual(
                        searchQuery,
                        localIdAlternates: parsed.localIdAlternates,
                        primaryLocale: locale,
                        secondaryLocale: locale == "de" ? "en" : "de"
                    )
                } else {
                    cards = try await provider.searchCardsExpanded(
                        searchQuery,
                        localIdAlternates: parsed.localIdAlternates,
                        locale: locale
                    )
                }
                await SearchResponseCache.shared.store(cards, for: cacheKey)
            }

            guard generation == searchGeneration else { return }

            // Bilder: EN-Feld nachladen wenn fehlt (viele DE-Briefs ohne image).
            let missing = cards.filter { $0.image == nil }.prefix(8).map(\.id)
            if !missing.isEmpty {
                cards = await provider.enrichImages(for: cards, localeHint: "en")
            }

            guard generation == searchGeneration else { return }

            await resolveSetNames(for: cards)
            var built = cards.map { card -> CardSearchHit in
                let setId = card.inferredSetId
                return CardSearchHit(
                    card: card,
                    setId: setId,
                    setName: setId.flatMap { setNameCache[$0] },
                    localeUsed: locale
                )
            }

            // Preise für die ersten Treffer (freie TCGdex-Cardmarket-Felder).
            built = await enrichPrices(built, locale: locale)

            guard generation == searchGeneration else { return }
            hits = built

            let candidateLists = hits.map(\.card.imageCandidatesLow)
            await CardImageCache.shared.prefetch(candidatesList: candidateLists)
        } catch {
            guard generation == searchGeneration else { return }
            errorMessage = error.localizedDescription
            hits = []
        }
    }

    func loadSets(force: Bool = false) async {
        if setsLoaded && !force && setQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let trimmed = setQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                sets = try await provider.fetchSets(locale: locale, page: 1, itemsPerPage: 60)
            } else {
                var found = try await provider.searchSets(query: trimmed, locale: locale)
                if found.isEmpty, locale == "de" {
                    found = try await provider.searchSets(query: trimmed, locale: "en")
                }
                sets = found
            }
            for set in sets {
                setNameCache[set.id] = set.name
            }
            setsLoaded = true
        } catch {
            errorMessage = error.localizedDescription
            sets = []
        }
    }

    private func resolveSetNames(for cards: [TCGdexCardSummary]) async {
        let ids = Array(Set(cards.compactMap(\.inferredSetId))).prefix(12)
        for setId in ids {
            if setNameCache[setId] != nil { continue }
            if let detail = try? await provider.fetchSetDetail(id: setId, locale: locale) {
                setNameCache[setId] = detail.name
            } else if locale != "en",
                      let detail = try? await provider.fetchSetDetail(id: setId, locale: "en") {
                setNameCache[setId] = detail.name
            }
        }
    }

    /// Lädt Preise für bis zu 10 Treffer (begrenzte Parallelität im Provider).
    private func enrichPrices(_ hits: [CardSearchHit], locale: String) async -> [CardSearchHit] {
        var result = hits
        let limit = min(10, result.count)
        let provider = self.provider
        let unavailable = PriceSource.unavailable.displayNameDE
        await withTaskGroup(of: (Int, Double?, String).self) { group in
            for index in 0..<limit {
                let id = result[index].card.id
                group.addTask {
                    do {
                        if let price = try await provider.fetchPrice(for: id, locale: locale),
                           let amount = price.amountEUR {
                            let metric = price.metric.map { " · \($0)" } ?? ""
                            return (index, amount, "\(CurrencyFormat.euro(amount))\(metric)")
                        }
                        return (index, nil, unavailable)
                    } catch {
                        return (index, nil, unavailable)
                    }
                }
            }
            for await (index, amount, label) in group {
                result[index].priceEUR = amount
                result[index].priceLabel = label
            }
        }
        for index in limit..<result.count where result[index].priceLabel == nil {
            result[index].priceLabel = "Preis: tippen für Details"
        }
        return result
    }
}
