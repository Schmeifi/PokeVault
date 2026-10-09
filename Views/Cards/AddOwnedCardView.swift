import SwiftUI
import SwiftData

struct AddOwnedCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var setName = ""
    @State private var setId = ""
    @State private var number = ""
    @State private var tcgdexId = ""
    @State private var rarity = ""
    @State private var quantity = 1
    @State private var condition: CardCondition = .nearMint
    @State private var language: CardLanguage = .de
    @State private var variant: CardVariant = .normal
    @State private var purchasePriceText = ""
    @State private var manualValueText = ""
    @State private var note = ""
    @State private var storageLocation = ""
    @State private var validationMessage: String?

    var body: some View {
        Form {
            Section {
                Text("Manueller Eintrag ohne Pflicht-API. TCGdex-ID ist optional und kann später ergänzt werden.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Katalog") {
                TextField("Kartenname *", text: $name)
                TextField("Set-Name", text: $setName)
                TextField("Set-ID (z. B. swsh3)", text: $setId)
                TextField("Kartennummer", text: $number)
                TextField("TCGdex-ID (optional)", text: $tcgdexId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Seltenheit", text: $rarity)
            }

            Section("Exemplar") {
                Stepper("Anzahl: \(quantity)", value: $quantity, in: 1...99)
                Picker("Zustand", selection: $condition) {
                    ForEach(CardCondition.allCases) { item in
                        Text(item.displayNameDE).tag(item)
                    }
                }
                Picker("Sprache", selection: $language) {
                    ForEach(CardLanguage.allCases) { item in
                        Text(item.displayNameDE).tag(item)
                    }
                }
                Picker("Variante", selection: $variant) {
                    ForEach(CardVariant.allCases) { item in
                        Text(item.displayNameDE).tag(item)
                    }
                }
                TextField("Kaufpreis (€)", text: $purchasePriceText)
                    .keyboardType(.decimalPad)
                TextField("Manuelle Bewertung (€)", text: $manualValueText)
                    .keyboardType(.decimalPad)
                TextField("Lagerort", text: $storageLocation)
                TextField("Notiz", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Karte hinzufügen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationMessage = "Bitte einen Kartennamen angeben."
            return
        }

        let catalogId = tcgdexId.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTcgdexId = catalogId.isEmpty
            ? "local-\(UUID().uuidString.lowercased())"
            : catalogId

        let entry = CardCatalogEntry(
            tcgdexId: resolvedTcgdexId,
            name: trimmedName,
            localizedNames: [language.rawValue: trimmedName],
            setId: setId.trimmingCharacters(in: .whitespacesAndNewlines),
            setName: setName.trimmingCharacters(in: .whitespacesAndNewlines),
            number: number.trimmingCharacters(in: .whitespacesAndNewlines),
            rarity: rarity.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        modelContext.insert(entry)

        let owned = OwnedCard(
            catalogEntry: entry,
            quantity: quantity,
            condition: condition,
            language: language,
            variant: variant,
            purchasePrice: Double(purchasePriceText.replacingOccurrences(of: ",", with: ".")),
            manualValue: Double(manualValueText.replacingOccurrences(of: ",", with: ".")),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            storageLocation: storageLocation.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        modelContext.insert(owned)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            validationMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    NavigationStack {
        AddOwnedCardView()
    }
    .modelContainer(ModelContainerFactory.previewContainer())
}
