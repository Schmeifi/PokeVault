import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Lokales JSON/CSV/ZIP-Backup ohne Cloud.
@MainActor
enum BackupService {
    struct ExportPayload: Codable {
        var exportedAt: String
        var app: String
        var version: String
        var ownedCards: [OwnedDTO]
        var wishlist: [WishDTO]
        var catalog: [CatalogDTO]
    }

    struct OwnedDTO: Codable {
        var tcgdexId: String
        var name: String
        var setId: String
        var setName: String
        var number: String
        var quantity: Int
        var condition: String
        var language: String
        var variant: String
        var purchasePrice: Double?
        var purchaseDate: String?
        var manualValue: Double?
        var note: String?
    }

    struct WishDTO: Codable {
        var tcgdexId: String
        var name: String
        var priority: Int
        var targetPriceEUR: Double?
        var condition: String
        var language: String
        var note: String?
    }

    struct CatalogDTO: Codable {
        var tcgdexId: String
        var name: String
        var setId: String
        var setName: String
        var number: String
        var rarity: String?
        var imageURL: String?
    }

    static func makePayload(owned: [OwnedCard], wishlist: [WishlistEntry], catalog: [CardCatalogEntry]) -> ExportPayload {
        let iso = ISO8601DateFormatter()
        return ExportPayload(
            exportedAt: iso.string(from: Date()),
            app: "PokéVault",
            version: "0.3.1",
            ownedCards: owned.map { card in
                OwnedDTO(
                    tcgdexId: card.catalogEntry?.tcgdexId ?? "",
                    name: card.catalogEntry?.name ?? "",
                    setId: card.catalogEntry?.setId ?? "",
                    setName: card.catalogEntry?.setName ?? "",
                    number: card.catalogEntry?.number ?? "",
                    quantity: card.quantity,
                    condition: card.condition.rawValue,
                    language: card.language.rawValue,
                    variant: card.variant.rawValue,
                    purchasePrice: card.purchasePrice,
                    purchaseDate: card.purchaseDate.map { iso.string(from: $0) },
                    manualValue: card.manualValue,
                    note: card.note
                )
            },
            wishlist: wishlist.map { w in
                WishDTO(
                    tcgdexId: w.catalogEntry?.tcgdexId ?? "",
                    name: w.catalogEntry?.name ?? "",
                    priority: w.priority,
                    targetPriceEUR: w.targetPriceEUR ?? w.maxPriceEUR,
                    condition: w.desiredCondition.rawValue,
                    language: w.desiredLanguage.rawValue,
                    note: w.note
                )
            },
            catalog: catalog.map { c in
                CatalogDTO(
                    tcgdexId: c.tcgdexId,
                    name: c.name,
                    setId: c.setId,
                    setName: c.setName,
                    number: c.number,
                    rarity: c.rarity,
                    imageURL: c.imageURL
                )
            }
        )
    }

    static func exportJSON(payload: ExportPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    static func exportCSV(owned: [OwnedCard]) -> String {
        var lines = ["tcgdexId,name,setId,number,quantity,condition,language,variant,purchasePrice,manualValue"]
        for card in owned {
            let cols: [String] = [
                card.catalogEntry?.tcgdexId ?? "",
                escape(card.catalogEntry?.name ?? ""),
                card.catalogEntry?.setId ?? "",
                card.catalogEntry?.number ?? "",
                "\(card.quantity)",
                card.condition.rawValue,
                card.language.rawValue,
                card.variant.rawValue,
                card.purchasePrice.map { String($0) } ?? "",
                card.manualValue.map { String($0) } ?? ""
            ]
            lines.append(cols.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// Schreibt JSON + CSV in ein temporäres Verzeichnis (ZIP-ähnlich als Ordner-Bundle für Share).
    static func writeExportBundle(payload: ExportPayload, owned: [OwnedCard]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PokeVault-Backup-\(Int(Date().timeIntervalSince1970))", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let jsonURL = dir.appendingPathComponent("pokevault.json")
        let csvURL = dir.appendingPathComponent("owned.csv")
        try exportJSON(payload: payload).write(to: jsonURL)
        try exportCSV(owned: owned).data(using: .utf8)?.write(to: csvURL)
        // Minimales ZIP (store) — ohne Drittanbieter: JSON+CSV Ordner zum Teilen.
        // Echte ZIP-Kompression optional später; Share Sheet bekommt den Ordnerinhalt via JSON-Datei.
        return jsonURL
    }

    static func importJSON(_ data: Data, into context: ModelContext) throws -> Int {
        let payload = try JSONDecoder().decode(ExportPayload.self, from: data)
        var imported = 0
        for item in payload.ownedCards {
            guard !item.tcgdexId.isEmpty else { continue }
            let tcgdexId = item.tcgdexId
            let descriptor = FetchDescriptor<CardCatalogEntry>(
                predicate: #Predicate { $0.tcgdexId == tcgdexId }
            )
            let entry = try context.fetch(descriptor).first ?? CardCatalogEntry(
                tcgdexId: item.tcgdexId,
                name: item.name,
                setId: item.setId,
                setName: item.setName,
                number: item.number
            )
            entry.name = item.name
            entry.setId = item.setId
            entry.setName = item.setName
            entry.number = item.number
            if try context.fetch(descriptor).isEmpty {
                context.insert(entry)
            }
            let owned = OwnedCard(
                catalogEntry: entry,
                quantity: item.quantity,
                condition: CardCondition(rawValue: item.condition) ?? .nearMint,
                language: CardLanguage(rawValue: item.language) ?? .de,
                variant: CardVariant(rawValue: item.variant) ?? .normal,
                purchasePrice: item.purchasePrice,
                manualValue: item.manualValue,
                note: item.note
            )
            context.insert(owned)
            imported += 1
        }
        try context.save()
        return imported
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
