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
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Public API (documented endpoints)

    /// GET /v2/{locale}/cards?name=…&pagination:page=&pagination:itemsPerPage=
    func searchCards(
        query: String,
        locale: String = "de",
        page: Int = 1,
        itemsPerPage: Int = 24
    ) async throws -> [TCGdexCardSummary] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("\(locale)/cards"),
            resolvingAgainstBaseURL: false
        )!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "pagination:page", value: String(page)),
            URLQueryItem(name: "pagination:itemsPerPage", value: String(itemsPerPage))
        ]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: "name", value: trimmed))
        }
        components.queryItems = items
        return try await get(components.url!)
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
            URLQueryItem(name: "pagination:itemsPerPage", value: String(itemsPerPage))
        ]
        return try await get(components.url!)
    }

    /// GET /v2/{locale}/sets/{id}
    func fetchSet(id: String, locale: String = "de") async throws -> TCGdexSetSummary {
        let url = baseURL.appendingPathComponent("\(locale)/sets/\(id)")
        return try await get(url)
    }

    /// GET /v2/{locale}/series
    func fetchSeries(locale: String = "de") async throws -> [TCGdexSerieSummary] {
        let url = baseURL.appendingPathComponent("\(locale)/series")
        return try await get(url)
    }

    // MARK: - PriceProvider

    func fetchPrice(for tcgdexId: String, locale: String) async throws -> FetchedPrice? {
        let detail = try await fetchCard(id: tcgdexId, locale: locale)
        guard let cm = detail.pricing?.cardmarket else {
            return .unavailable
        }
        // Bevorzugt Trend, sonst Durchschnitt – Kennzahl transparent ausweisen.
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

        // Einheit prüfen – nur EUR als Euro ausweisen.
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
            request.setValue("PokeVault/0.1 (iOS; private collection)", forHTTPHeaderField: "User-Agent")

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
