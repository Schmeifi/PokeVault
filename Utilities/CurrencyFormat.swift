import Foundation

enum CurrencyFormat {
    private static let euro: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()

    static func euro(_ value: Double?) -> String {
        guard let value else { return "Kein Marktpreis verfügbar" }
        return euro.string(from: NSNumber(value: value)) ?? String(format: "%.2f €", value)
    }

    static func euroOrDash(_ value: Double?) -> String {
        guard let value else { return "—" }
        return euro(value)
    }

    /// Vorzeichenbehafteter Euro-Betrag, z. B. "+1,20 €" / "−0,40 €".
    static func signedEuro(_ value: Double?) -> String {
        guard let value else { return "—" }
        let formatted = euro(abs(value))
        if value > 0 { return "+\(formatted)" }
        if value < 0 { return "−\(formatted)" }
        return formatted
    }

    static func percent(_ value: Double?, fractionDigits: Int = 1) -> String {
        guard let value else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        formatter.locale = Locale(identifier: "de_DE")
        let number = formatter.string(from: NSNumber(value: abs(value))) ?? String(format: "%.\(fractionDigits)f", abs(value))
        let sign = value > 0 ? "+" : (value < 0 ? "−" : "")
        return "\(sign)\(number) %"
    }
}
