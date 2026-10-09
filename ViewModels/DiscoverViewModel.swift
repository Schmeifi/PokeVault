import Foundation
import Observation

enum DiscoverMode: String, CaseIterable, Identifiable {
    case search
    case sets

    var id: String { rawValue }

    var titleDE: String {
        switch self {
        case .search: return "Suche"
        case .sets: return "Sets"
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
    var results: [TCGdexCardSummary] = []
    var sets: [TCGdexSetSummary] = []
    var setQuery: String = ""
    var isLoading = false
    var errorMessage: String?
    var hasSearched = false
    var setsLoaded = false

    private let provider: TCGdexProvider

    init(provider: TCGdexProvider = .shared) {
        self.provider = provider
    }

    func search() async {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let setId = setFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = numberFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchQuery = TCGdexCardSearchQuery(
            name: name.isEmpty ? nil : name,
            setId: setId.isEmpty ? nil : setId,
            localId: number.isEmpty ? nil : number,
            page: 1,
            itemsPerPage: 40
        )
        guard !searchQuery.isEmpty else {
            results = []
            hasSearched = false
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        hasSearched = true
        defer { isLoading = false }

        do {
            if bilingual {
                var cards = try await provider.searchCardsBilingual(
                    searchQuery,
                    primaryLocale: locale,
                    secondaryLocale: locale == "de" ? "en" : "de"
                )
                // Falls Primärsprache leer und Bilingual schon EN geholt hat — fertig.
                if cards.isEmpty {
                    cards = try await provider.searchCards(searchQuery, locale: locale == "de" ? "en" : "de")
                }
                results = cards
            } else {
                results = try await provider.searchCards(searchQuery, locale: locale)
            }
            let urls = results.compactMap(\.imageURLLow)
            await CardImageCache.shared.prefetch(urls)
        } catch {
            errorMessage = error.localizedDescription
            results = []
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
            setsLoaded = true
        } catch {
            errorMessage = error.localizedDescription
            sets = []
        }
    }
}
