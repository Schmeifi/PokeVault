import Foundation
import UIKit

/// Lokaler Disk-Cache für TCGdex-Kartenbilder (offline-sicher, HTTP-Cache-freundlich).
actor CardImageCache {
    static let shared = CardImageCache()

    private let session: URLSession
    private let fileManager: FileManager
    private let directory: URL
    private let maxConcurrent = 3
    private var inFlight = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var memory: [String: Data] = [:]
    private let memoryLimit = 64
    /// Merkt erfolgreiche End-URLs je logischer Base (absoluteString der ersten Candidate-Base).
    private var resolvedURLByKey: [String: URL] = [:]

    init(session: URLSession? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.directory = base.appendingPathComponent("PokeVaultCardImages", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .returnCacheDataElseLoad
            config.urlCache = URLCache(
                memoryCapacity: 24 * 1024 * 1024,
                diskCapacity: 96 * 1024 * 1024,
                diskPath: "tcgdex-image-http-cache"
            )
            config.timeoutIntervalForRequest = 25
            config.httpMaximumConnectionsPerHost = 3
            self.session = URLSession(configuration: config)
        }
    }

    func imageData(for url: URL, allowNetwork: Bool = true) async throws -> Data {
        try await imageData(candidates: [url], allowNetwork: allowNetwork)
    }

    /// Probiert Kandidaten (webp/png, de/en, TG-Fallback) bis einer gelingt.
    func imageData(candidates: [URL], allowNetwork: Bool = true) async throws -> Data {
        guard let first = candidates.first else { throw CardImageCacheError.offlineMiss }
        let groupKey = first.absoluteString

        if let known = resolvedURLByKey[groupKey],
           let cached = try? await cachedData(for: known) {
            return cached
        }

        for url in candidates {
            if let cached = try? await cachedData(for: url) {
                resolvedURLByKey[groupKey] = url
                return cached
            }
        }

        guard allowNetwork else { throw CardImageCacheError.offlineMiss }

        var lastError: Error = CardImageCacheError.offlineMiss
        for url in candidates {
            do {
                let data = try await download(url)
                let fileURL = directory.appendingPathComponent(cacheKey(for: url))
                try? data.write(to: fileURL, options: .atomic)
                remember(key: cacheKey(for: url), data: data)
                resolvedURLByKey[groupKey] = url
                return data
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError
    }

    func cachedImage(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        if let data = memory[key] { return UIImage(data: data) }
        let fileURL = directory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func prefetch(candidatesList: [[URL]]) async {
        for candidates in candidatesList.prefix(16) {
            _ = try? await imageData(candidates: candidates, allowNetwork: true)
        }
    }

    func prefetch(_ urls: [URL]) async {
        await prefetch(candidatesList: urls.map { [$0] })
    }

    func clearMemory() {
        memory.removeAll()
    }

    private func cachedData(for url: URL) throws -> Data {
        let key = cacheKey(for: url)
        if let cached = memory[key] { return cached }
        let fileURL = directory.appendingPathComponent(key)
        let disk = try Data(contentsOf: fileURL)
        guard !disk.isEmpty else { throw CardImageCacheError.offlineMiss }
        remember(key: key, data: disk)
        return disk
    }

    private func download(_ url: URL) async throws -> Data {
        try await withConcurrencySlot {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("PokeVault/0.3 (iOS; private collection)", forHTTPHeaderField: "User-Agent")
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw CardImageCacheError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                throw CardImageCacheError.httpStatus(http.statusCode)
            }
            // CDN liefert bei 404 manchmal image/* mit HTML-Body — ablehnen wenn zu klein/HTML.
            if let mime = http.mimeType?.lowercased(), mime.contains("html") {
                throw CardImageCacheError.httpStatus(404)
            }
            guard data.count > 256 else {
                throw CardImageCacheError.httpStatus(404)
            }
            return data
        }
    }

    private func remember(key: String, data: Data) {
        memory[key] = data
        if memory.count > memoryLimit {
            let overflow = memory.count - memoryLimit
            for key in memory.keys.prefix(overflow) {
                memory.removeValue(forKey: key)
            }
        }
    }

    private func cacheKey(for url: URL) -> String {
        let digest = StableHash.hex(of: url.absoluteString)
        let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
        return "\(digest).\(ext)"
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
                waiters.removeFirst().resume()
            }
        }
        return try await work()
    }
}

enum CardImageCacheError: LocalizedError {
    case offlineMiss
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .offlineMiss:
            return "Bild nicht im Offline-Cache."
        case .invalidResponse:
            return "Ungültige Bildantwort."
        case .httpStatus(let code):
            return "Bild-Download fehlgeschlagen (HTTP \(code))."
        }
    }
}

enum StableHash {
    static func hex(of string: String) -> String {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }
}
