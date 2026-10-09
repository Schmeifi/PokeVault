import Foundation

/// Spezielle Katalog-Teilmengen (Nummer-Präfix / Seltenheit), gestützt auf TCGdex-Felder.
enum DiscoverCategory: String, CaseIterable, Identifiable, Hashable {
    case trainerGallery
    case galarianGallery
    case shinyVault
    case illustrationRare
    case specialIllustrationRare
    case secretRare
    case ultraRare
    case holoRare

    var id: String { rawValue }

    var titleDE: String {
        switch self {
        case .trainerGallery: return "Trainer Gallery (TG)"
        case .galarianGallery: return "Galarian Gallery (GG)"
        case .shinyVault: return "Shiny Vault (SV)"
        case .illustrationRare: return "Illustration Rare"
        case .specialIllustrationRare: return "Special Illustration"
        case .secretRare: return "Secret Rare"
        case .ultraRare: return "Ultra Rare"
        case .holoRare: return "Holo Rare"
        }
    }

    var shortTitleDE: String {
        switch self {
        case .trainerGallery: return "TG"
        case .galarianGallery: return "GG"
        case .shinyVault: return "SV#"
        case .illustrationRare: return "IR"
        case .specialIllustrationRare: return "SIR"
        case .secretRare: return "Secret"
        case .ultraRare: return "Ultra"
        case .holoRare: return "Holo"
        }
    }

    var subtitleDE: String {
        switch self {
        case .trainerGallery: return "Kartennummern mit Präfix TG"
        case .galarianGallery: return "Kartennummern mit Präfix GG"
        case .shinyVault: return "SV-Nummern (z. B. SV001)"
        case .illustrationRare: return "Seltenheit Illustration Rare"
        case .specialIllustrationRare: return "Special Illustration Rare"
        case .secretRare: return "Secret / Versteckt Selten"
        case .ultraRare: return "Ultra Rare / Ultra Selten"
        case .holoRare: return "Holo Rare / Holografisch Selten"
        }
    }

    /// localId-Präfix (case-insensitive), sofern zutreffend.
    var localIdPrefix: String? {
        switch self {
        case .trainerGallery: return "TG"
        case .galarianGallery: return "GG"
        case .shinyVault: return "SV"
        default: return nil
        }
    }

    /// `like:`-Token für rarity-Filter (EN + DE Varianten).
    func rarityLikeTokens(locale: String) -> [String] {
        let de = locale.lowercased().hasPrefix("de")
        switch self {
        case .trainerGallery, .galarianGallery, .shinyVault:
            return []
        case .illustrationRare:
            return de ? ["Selten, Illustration", "Illustration"] : ["Illustration rare", "Illustration"]
        case .specialIllustrationRare:
            return de
                ? ["Selten, besondere Illustration", "besondere Illustration"]
                : ["Special illustration rare", "Special illustration"]
        case .secretRare:
            return de ? ["Versteckt Selten", "Secret"] : ["Secret Rare", "Secret"]
        case .ultraRare:
            return de ? ["Ultra Selten", "Ultra"] : ["Ultra Rare", "Ultra"]
        case .holoRare:
            return de ? ["Holografisch Selten", "Holo"] : ["Holo Rare", "Holo"]
        }
    }
}
