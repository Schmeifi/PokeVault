import Foundation

enum CardLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case de = "de"
    case en = "en"
    case fr = "fr"
    case es = "es"
    case it = "it"
    case pt = "pt"
    case ja = "ja"
    case zh = "zh"
    case other = "other"

    var id: String { rawValue }

    var displayNameDE: String {
        switch self {
        case .de: return "Deutsch"
        case .en: return "Englisch"
        case .fr: return "Französisch"
        case .es: return "Spanisch"
        case .it: return "Italienisch"
        case .pt: return "Portugiesisch"
        case .ja: return "Japanisch"
        case .zh: return "Chinesisch"
        case .other: return "Andere"
        }
    }

    /// TCGdex path segment for this language when supported.
    var tcgdexLocale: String? {
        switch self {
        case .de, .en, .fr, .es, .it, .pt, .ja: return rawValue
        case .zh: return "zh-tw"
        case .other: return nil
        }
    }
}
