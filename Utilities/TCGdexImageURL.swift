import Foundation

/// Baut dokumentierte TCGdex-Asset-URLs (https://tcgdex.dev/assets).
/// Karten: `{image}/{quality}.{extension}` — Sets: `{logo|symbol}.{extension}` (ohne quality).
enum TCGdexImageURL {
    enum Quality: String, Sendable, CaseIterable {
        case high
        case low
    }

    enum Format: String, Sendable, CaseIterable {
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

    /// Kandidaten in dokumentierter Form: Qualität/Format + Sprachvariante im Asset-Pfad.
    /// Keine erfundenen Bases — nur Abwandlungen eines API-`image`-Werts.
    static func cardCandidates(
        fromImageField image: String?,
        preferredQuality: Quality = .low
    ) -> [URL] {
        guard let base = normalizedBase(image), !hasFileExtension(base) else {
            if let single = card(image, quality: preferredQuality, format: .webp) {
                return [single]
            }
            return []
        }

        var bases = [base]
        // Dokumentierte Sprachsegmente im Asset-Hostpfad: …/de/… ↔ …/en/…
        if let swapped = swapAssetLocale(base, to: "en"), swapped != base {
            bases.append(swapped)
        }
        if let swapped = swapAssetLocale(base, to: "de"), swapped != base {
            bases.append(swapped)
        }

        let qualities: [Quality] = preferredQuality == .low ? [.low, .high] : [.high, .low]
        let formats: [Format] = [.webp, .png]
        var urls: [URL] = []
        var seen = Set<String>()
        for b in bases {
            for q in qualities {
                for f in formats {
                    let s = "\(b)/\(q.rawValue).\(f.rawValue)"
                    if seen.insert(s).inserted, let url = URL(string: s) {
                        urls.append(url)
                    }
                }
            }
        }
        return urls
    }

    /// Trainer-Gallery-Hilfspfad: TCGdex hostet TG-Assets häufig unter dem Haupt-Set (ohne `tg`-Suffix).
    /// Nur verwendet, wenn API-`image` fehlt; URL wird erst nach erfolgreichem Download genutzt.
    static func trainerGalleryFallbackBases(
        serieId: String?,
        setId: String?,
        localId: String?,
        locale: String = "en"
    ) -> [String] {
        guard let serieId, let setId, let localId else { return [] }
        let lid = localId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard lid.uppercased().hasPrefix("TG") || setId.lowercased().hasSuffix("tg") else {
            return []
        }
        var setIds = [setId]
        let lower = setId.lowercased()
        if lower.hasSuffix("tg") {
            let parent = String(setId.dropLast(2))
            if !parent.isEmpty { setIds.append(parent) }
        }
        return setIds.map { "https://assets.tcgdex.net/\(locale)/\(serieId)/\($0)/\(lid)" }
    }

    /// Set-Logo oder -Symbol — nur Extension anhängen, kein quality-Segment.
    static func setAsset(_ base: String?, format: Format = .webp) -> URL? {
        guard let base = normalizedBase(base) else { return nil }
        if hasFileExtension(base) {
            return URL(string: base)
        }
        return URL(string: "\(base).\(format.rawValue)")
    }

    static func swapAssetLocale(_ base: String, to locale: String) -> String? {
        // https://assets.tcgdex.net/{lang}/…
        let marker = "assets.tcgdex.net/"
        guard let range = base.range(of: marker) else { return nil }
        let after = base[range.upperBound...]
        guard let slash = after.firstIndex(of: "/") else { return nil }
        let rest = after[after.index(after: slash)...]
        return "https://assets.tcgdex.net/\(locale)/\(rest)"
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
