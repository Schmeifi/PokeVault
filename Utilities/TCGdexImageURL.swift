import Foundation

/// Baut dokumentierte TCGdex-Asset-URLs (https://tcgdex.dev/assets).
/// Karten: `{image}/{quality}.{extension}` — Sets: `{logo|symbol}.{extension}` (ohne quality).
enum TCGdexImageURL {
    enum Quality: String, Sendable {
        case high
        case low
    }

    enum Format: String, Sendable {
        case webp
        case png
        case jpg
    }

    /// Kartengrafik. `base` ist das API-Feld `image` ohne Extension.
    static func card(
        _ base: String?,
        quality: Quality = .high,
        format: Format = .webp
    ) -> URL? {
        guard let base = normalizedBase(base) else { return nil }
        if hasFileExtension(base) {
            return URL(string: base)
        }
        return URL(string: "\(base)/\(quality.rawValue).\(format.rawValue)")
    }

    /// Set-Logo oder -Symbol — nur Extension anhängen, kein quality-Segment.
    static func setAsset(_ base: String?, format: Format = .webp) -> URL? {
        guard let base = normalizedBase(base) else { return nil }
        if hasFileExtension(base) {
            return URL(string: base)
        }
        return URL(string: "\(base).\(format.rawValue)")
    }

    private static func normalizedBase(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func hasFileExtension(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.hasSuffix(".png")
            || lower.hasSuffix(".jpg")
            || lower.hasSuffix(".jpeg")
            || lower.hasSuffix(".webp")
    }
}
