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

    /// Logo- und Symbol-Kandidaten. Die API schreibt Symbole oft nach
    /// `assets.tcgdex.net/univ/…`, die Dateien liegen aber unter `/en/…`.
    /// WebP und PNG werden beide probiert.
    static func setAssetCandidates(
        logo: String?,
        symbol: String?,
        serieId: String? = nil,
        setId: String? = nil
    ) -> [URL] {
        var bases: [String] = []
        func add(_ raw: String?) {
            guard let base = normalizedBase(raw) else { return }
            bases.append(base)
            if base.contains("/univ/") {
                bases.append(base.replacingOccurrences(of: "/univ/", with: "/en/"))
            }
            if let english = swapAssetLocale(base, to: "en"), english != base {
                bases.append(english)
            }
        }
        add(logo)
        add(symbol)
        if let serieId, let setId, !serieId.isEmpty, !setId.isEmpty {
            bases.append("https://assets.tcgdex.net/en/\(serieId)/\(setId)/logo")
            bases.append("https://assets.tcgdex.net/en/\(serieId)/\(setId)/symbol")
        }

        let formats: [Format] = [.webp, .png]
        var urls: [URL] = []
        var seen = Set<String>()
        for base in bases {
            if hasFileExtension(base) {
                if seen.insert(base).inserted, let url = URL(string: base) {
                    urls.append(url)
                }
                continue
            }
            for format in formats {
                let value = "\(base).\(format.rawValue)"
                if seen.insert(value).inserted, let url = URL(string: value) {
                    urls.append(url)
                }
            }
        }
        return urls
    }

    /// When the locale endpoint omits `image`, build the documented asset base.
    /// Trainer/Galarian galleries are hosted on the parent set (`swsh9tg` → `swsh9`).
    static func fallbackCardBases(serieId: String?, setId: String?, localId: String?) -> [String] {
        guard let setId, let localId else { return [] }
        let trimmedSet = setId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocal = localId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSet.isEmpty, !trimmedLocal.isEmpty else { return [] }

        var series: [String] = []
        if let serieId {
            let trimmed = serieId.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { series.append(trimmed) }
        }
        let prefix = String(trimmedSet.prefix(while: { $0.isLetter }))
        if !prefix.isEmpty, prefix != series.first {
            series.append(prefix)
        }
        guard !series.isEmpty else { return [] }

        var setIds = [trimmedSet]
        if let parent = galleryParentSetId(trimmedSet), parent.caseInsensitiveCompare(trimmedSet) != .orderedSame {
            setIds.insert(parent, at: 0)
        }

        var bases: [String] = []
        for serie in series {
            for sid in setIds {
                bases.append("https://assets.tcgdex.net/en/\(serie)/\(sid)/\(trimmedLocal)")
            }
        }
        return bases
    }

    /// `swsh9tg` / `swsh9gg` are hosted on the parent set for art and often for the logo.
    static func galleryParentSetId(_ setId: String) -> String? {
        let trimmed = setId.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        guard lower.hasSuffix("tg") || lower.hasSuffix("gg"), trimmed.count > 2 else { return nil }
        return String(trimmed.dropLast(2))
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
