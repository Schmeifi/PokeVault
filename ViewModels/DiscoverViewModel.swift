import Foundation
import Observation

@Observable
@MainActor
final class DiscoverViewModel {
    var query: String = ""
    var locale: String = "de"
    var results: [TCGdexCardSummary] = []
    var isLoading = false
    var errorMessage: String?
    var hasSearched = false

    private let provider: TCGdexProvider

    init(provider: TCGdexProvider = .shared) {
        self.provider = provider
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
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
            // Deutsch zuerst; bei leerem Ergebnis Englisch nachladen.
            var cards = try await provider.searchCards(query: trimmed, locale: locale)
            if cards.isEmpty, locale == "de" {
                cards = try await provider.searchCards(query: trimmed, locale: "en")
            }
            results = cards
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
    }
}
