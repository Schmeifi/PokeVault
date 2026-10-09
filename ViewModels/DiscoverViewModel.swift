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

    init(provider: TCGdexProvider = .shared) {
        self.provider = provider
    }

    var results: [TCGdexCardSummary] { hits.map(\.card) }

    func search() async {
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
            itemsPerPage: 40
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
        defer { isLoading = false }

        do {
            var cards: [TCGdexCardSummary]
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

            // Bilder: EN-Feld nachladen wenn fehlt (viele DE-Briefs ohne image).
            let missing = cards.filter { $0.image == nil }.prefix(12).map(\.id)
            if !missing.isEmpty {
                cards = await provider.enrichImages(for: cards, localeHint: "en")
            }

            await resolveSetNames(for: cards)
            hits = cards.map { card in
                let setId = card.inferredSetId
                return CardSearchHit(
                    card: card,
                    setId: setId,
                    setName: setId.flatMap { setNameCache[$0] },
                    localeUsed: locale
                )
            }

            let candidateLists = hits.map(\.card.imageCandidatesLow)
            await CardImageCache.shared.prefetch(candidatesList: candidateLists)
        } catch {
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
        let ids = Array(Set(cards.compactMap(\.inferredSetId))).prefix(20)
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
}
