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
}
