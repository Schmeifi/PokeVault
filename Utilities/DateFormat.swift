import Foundation

enum DateFormat {
    private static let medium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func medium(_ date: Date?) -> String {
        guard let date else { return "—" }
        return medium.string(from: date)
    }
}
