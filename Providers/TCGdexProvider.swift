import Foundation

/// Native TCGdex REST-Client – ausschließlich dokumentierte, kostenlose Endpunkte.
/// Basis: https://api.tcgdex.net/v2/{locale}/…
/// Docs: https://tcgdex.dev/
actor TCGdexProvider: PriceProvider {
    static let shared = TCGdexProvider()

    let displayName = "TCGdex"
    private let session: URLSession
    private let baseURL = URL(string: "https://api.tcgdex.net/v2")!
    private let maxConcurrent = 4
    private var inFlight = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .returnCacheDataElseLoad
            config.urlCache = URLCache(
                memoryCapacity: 16 * 1024 * 1024,
                diskCapacity: 64 * 1024 * 1024,
                diskPath: "tcgdex-http-cache"
            )
            config.timeoutIntervalForRequest = 30
            config.httpMaximumConnectionsPerHost = 4
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Public API (documented endpoints)

    /// GET /v2/{locale}/cards?name=&set.id=&localId=&pagination:…
    func searchCards(
        query: String,
        locale: String = "de",
        page: Int = 1,
        itemsPerPage: Int = 24
    ) async throws -> [TCGdexCardSummary] {
        try await searchCards(
            TCGdexCardSearchQuery(name: query, page: page, itemsPerPage: itemsPerPage),
            locale: locale
        )
    }

    func searchCards(
        _ query: TCGdexCardSearchQuery,
        locale: String = "de"
    ) async throws -> [TCGdexCardSummary] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("\(locale)/cards"),
            resolvingAgainstBaseURL: false
        )!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "pagination:page", value: String(max(1, query.page))),
            URLQueryItem(name: "pagination:itemsPerPage", value: String(min(100, max(1, query.itemsPerPage))))
        ]
        if let name = trimmed(query.name), !name.isEmpty {
            items.append(URLQueryItem(name: "name", value: name))
        }
        if let setId = trimmed(query.setId), !setId.isEmpty {
            // Strict set id match (documented filter on nested key).
            items.append(URLQueryItem(name: "set.id", value: "eq:\(setId)"))
        }
        if let localId = trimmed(query.localId), !localId.isEmpty {
            // Laxist filter – `eq:` liefert für localId oft leere Treffer.
            items.append(URLQueryItem(name: "localId", value: localId))
        }
        components.queryItems = items
        return try await get(components.url!)
    }

    /// Sucht mit Nummern-Alternativen (TG22, TG22/TG30) und gezielt per `id` nur wenn sinnvoll.
    /// Vermeidet Broad-`id=like:`-Spam bei kurzen Nummern (z. B. „1“, „V“).
    func searchCardsExpanded(
        _ query: TCGdexCardSearchQuery,
        localIdAlternates: [String] = [],
        locale: String = "de"
    ) async throws -> [TCGdexCardSummary] {
        var merged: [TCGdexCardSummary] = []
        var seen = Set<String>()
        let pageCap = min(40, max(1, query.itemsPerPage))

        func append(_ cards: [TCGdexCardSummary]) {
            for card in cards where seen.insert(card.id).inserted {
                merged.append(card)
                if merged.count >= pageCap { return }
            }
        }

        var capped = query
        capped.itemsPerPage = pageCap
        append(try await searchCards(capped, locale: locale))

        for alt in localIdAlternates where merged.count < pageCap {
            var q = capped
            q.localId = alt
            append(try await searchCards(q, locale: locale))
        }

        // `id=like:` nur bei ausreichend spezifischen Tokens (volle Card-ID oder TG/GG/…).
        if merged.count < 3,
           let localId = trimmed(query.localId),
           shouldUseIdLikeFilter(localId) {
            var components = URLComponents(
                url: baseURL.appendingPathComponent("\(locale)/cards"),
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [
                URLQueryItem(name: "id", value: "like:\(localId)"),
                URLQueryItem(name: "pagination:page", value: "1"),
                URLQueryItem(name: "pagination:itemsPerPage", value: String(pageCap))
            ]
            if let url = components.url {
                append(try await get(url))
            }
        }

        return Array(merged.prefix(pageCap))
    }

    /// Kurze reine Ziffern/`like:` erzeugen hunderte Treffer — nur spezifische IDs.
    private func shouldUseIdLikeFilter(_ localId: String) -> Bool {
        if localId.contains("-") { return true }
        if localId.count >= 3, localId.rangeOfCharacter(from: .letters) != nil { return true }
        return false
    }

    /// Sucht DE und EN, merget IDs, übernimmt EN-`image` wenn DE fehlt.
    func searchCardsBilingual(
        _ query: TCGdexCardSearchQuery,
        localIdAlternates: [String] = [],
        primaryLocale: String = "de",
        secondaryLocale: String = "en"
    ) async throws -> [TCGdexCardSummary] {
        let primary = try await searchCardsExpanded(
            query,
            localIdAlternates: localIdAlternates,
            locale: primaryLocale
        )
        let secondary = try await searchCardsExpanded(
            query,
            localIdAlternates: localIdAlternates,
            locale: secondaryLocale
        )

        var byId: [String: TCGdexCardSummary] = [:]
        for card in secondary {
            byId[card.id] = card
        }
        var merged: [TCGdexCardSummary] = []
        var seen = Set<String>()
        for card in primary {
            seen.insert(card.id)
            if card.image == nil, let enImage = byId[card.id]?.image {
                merged.append(card.withImage(enImage))
            } else {
                merged.append(card)
            }
        }
        for card in secondary where seen.insert(card.id).inserted {
            merged.append(card)
        }

        // Nummernsuche: wenn Primär leer war, secondary ist schon drin.
        return merged
    }

    /// Reichert fehlende Bilder über EN-Detail nach (dokumentiertes `image`-Feld).
    func enrichImages(for cards: [TCGdexCardSummary], localeHint: String = "en") async -> [TCGdexCardSummary] {
        var result: [TCGdexCardSummary] = []
        for card in cards {
            if card.image != nil {
                result.append(card)
                continue
            }
            if let detail = try? await fetchCard(id: card.id, locale: localeHint),
               let image = detail.image {
                result.append(card.withImage(image))
            } else if localeHint != "en",
                      let detail = try? await fetchCard(id: card.id, locale: "en"),
                      let image = detail.image {
                result.append(card.withImage(image))
            } else {
                result.append(card)
            }
        }
        return result
    }

    /// GET /v2/{locale}/cards/{id}
    func fetchCard(id: String, locale: String = "de") async throws -> TCGdexCardDetail {
        let url = baseURL.appendingPathComponent("\(locale)/cards/\(id)")
        return try await get(url)
    }

    /// GET /v2/{locale}/sets
    func fetchSets(locale: String = "de", page: Int = 1, itemsPerPage: Int = 50) async throws -> [TCGdexSetSummary] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("\(locale)/sets"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "pagination:page", value: String(page)),
            URLQueryItem(name: "pagination:itemsPerPage", value: String(itemsPerPage)),
            URLQueryItem(name: "sort:field", value: "releaseDate"),
            URLQueryItem(name: "sort:order", value: "DESC")
        ]
        return try await get(components.url!)
    }

    /// GET /v2/{locale}/sets?name=…
    func searchSets(
        query: String,
        locale: String = "de",
        page: Int = 1,
        itemsPerPage: Int = 40
    ) async throws -> [TCGdexSetSummary] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("\(locale)/sets"),
            resolvingAgainstBaseURL: false
        )!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "pagination:page", value: String(page)),
            URLQueryItem(name: "pagination:itemsPerPage", value: String(itemsPerPage)),
            URLQueryItem(name: "sort:field", value: "name"),
            URLQueryItem(name: "sort:order", value: "ASC")
        ]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: "name", value: trimmed))
        }
        components.queryItems = items
        return try await get(components.url!)
    }

    /// GET /v2/{locale}/sets/{id} — volles Set inkl. Kartenliste & Metadaten.
    func fetchSetDetail(id: String, locale: String = "de") async throws -> TCGdexSetDetail {
        let url = baseURL.appendingPathComponent("\(locale)/sets/\(id)")
        return try await get(url)
    }

    /// Alias: bisherige Signatur liefert Summary-Felder aus dem Detail.
    func fetchSet(id: String, locale: String = "de") async throws -> TCGdexSetSummary {
        let detail = try await fetchSetDetail(id: id, locale: locale)
        return TCGdexSetSummary(
            id: detail.id,
            name: detail.name,
            logo: detail.logo,
            symbol: detail.symbol,
            cardCount: detail.cardCount
        )
    }

    /// GET /v2/{locale}/series
    func fetchSeries(locale: String = "de") async throws -> [TCGdexSerieSummary] {
        let url = baseURL.appendingPathComponent("\(locale)/series")
        return try await get(url)
    }

    // MARK: - PriceProvider (nur vorhandene TCGdex-Cardmarket-Felder; keine erfundenen Preise)

    func fetchPrice(for tcgdexId: String, locale: String) async throws -> FetchedPrice? {
        let detail = try await fetchCard(id: tcgdexId, locale: locale)
        guard let cm = detail.pricing?.cardmarket else {
            return .unavailable
        }
        let amount = cm.trend ?? cm.avg ?? cm.avg7 ?? cm.avg30 ?? cm.low
        let metric: String?
        if cm.trend != nil { metric = "trend" }
        else if cm.avg != nil { metric = "avg" }
        else if cm.avg7 != nil { metric = "avg7" }
        else if cm.avg30 != nil { metric = "avg30" }
        else if cm.low != nil { metric = "low" }
        else { metric = nil }

        guard let amount else {
            return FetchedPrice(
                amountEUR: nil,
                source: .unavailable,
                metric: nil,
                cardmarketProductId: cm.idProduct.map(String.init),
                updatedAt: parseISO8601(cm.updated),
                note: "Kein Marktpreis verfügbar"
            )
        }

        let unit = (cm.unit ?? "EUR").uppercased()
        guard unit == "EUR" else {
            return FetchedPrice(
                amountEUR: nil,
                source: .unavailable,
                metric: metric,
                cardmarketProductId: cm.idProduct.map(String.init),
                updatedAt: parseISO8601(cm.updated),
                note: "Preis in \(unit) – nicht als EUR übernommen"
            )
        }

        return FetchedPrice(
            amountEUR: amount,
            source: .tcgdexCardmarket,
            metric: metric,
            cardmarketProductId: cm.idProduct.map(String.init),
            updatedAt: parseISO8601(cm.updated),
            note: "Cardmarket-Referenz über TCGdex; kein zustandsspezifischer Preis"
        )
    }

    // MARK: - Networking

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        try await withConcurrencySlot {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("PokeVault/0.2 (iOS; private collection)", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw TCGdexError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                throw TCGdexError.httpStatus(http.statusCode)
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw TCGdexError.decoding(error)
            }
        }
    }

    private func withConcurrencySlot<T: Sendable>(_ work: @Sendable () async throws -> T) async throws -> T {
        while inFlight >= maxConcurrent {
            await withCheckedContinuation { cont in
                waiters.append(cont)
            }
        }
        inFlight += 1
        defer {
            inFlight -= 1
            if !waiters.isEmpty {
                let next = waiters.removeFirst()
                next.resume()
            }
        }
        return try await work()
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseISO8601(_ string: String?) -> Date? {
        guard let string else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}

enum TCGdexError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Ungültige Antwort von TCGdex."
        case .httpStatus(let code):
            return "TCGdex HTTP-Fehler \(code)."
        case .decoding(let error):
            return "TCGdex-Antwort konnte nicht gelesen werden: \(error.localizedDescription)"
        }
    }
}
