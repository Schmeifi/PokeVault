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
    @State private var illustrator = ""
    @State private var typesText = ""
    @State private var imageURL = ""
    @State private var availableVariants: [String] = []
    @State private var quantity = 1
    @State private var condition: CardCondition = .nearMint
    @State private var language: CardLanguage = .de
    @State private var variant: CardVariant = .normal
    @State private var purchasePriceText = ""
    @State private var purchaseDate: Date = .now
    @State private var includePurchaseDate = false
    @State private var manualValueText = ""
    @State private var note = ""
    @State private var storageLocation = ""
    @State private var validationMessage: String?
    @State private var showCatalogPicker = false
    @State private var catalogPreviewURL: URL?

    var body: some View {
        Form {
            Section {
                Button {
                    showCatalogPicker = true
                } label: {
                    Label("Im TCGdex-Katalog suchen", systemImage: "magnifyingglass")
                }
                Text("Übernimmt Name, Set, Nummer, Bild und Varianten. Kaufpreis trägst du selbst ein.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let catalogPreviewURL {
                Section("Vorschau") {
                    HStack {
                        Spacer()
                        CachedCardImageView(
                            imageURL: catalogPreviewURL,
                            title: name.isEmpty ? "Karte" : name,
                            size: CGSize(width: 120, height: 168)
                        )
                        Spacer()
                    }
                }
            }

            Section("Katalog") {
                TextField("Kartenname *", text: $name)
                TextField("Set-Name", text: $setName)
                TextField("Set-ID (z. B. swsh3)", text: $setId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Kartennummer", text: $number)
                TextField("TCGdex-ID (optional)", text: $tcgdexId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Seltenheit", text: $rarity)
                TextField("Illustrator", text: $illustrator)
                TextField("Typen (kommagetrennt)", text: $typesText)
            }

            Section("Kauf & Bewertung") {
                TextField("Kaufpreis (€) * empfohlen", text: $purchasePriceText)
                    .keyboardType(.decimalPad)
                Toggle("Kaufdatum merken", isOn: $includePurchaseDate)
                if includePurchaseDate {
                    DatePicker(
                        "Kaufdatum",
                        selection: $purchaseDate,
                        displayedComponents: .date
                    )
                }
                TextField("Manuelle Bewertung (€)", text: $manualValueText)
                    .keyboardType(.decimalPad)
                Text("Aktueller Marktwert kommt aus TCGdex (falls vorhanden), sonst der manuellen Bewertung. Preise werden nie erfunden.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                    ForEach(variantChoices, id: \.self) { item in
                        Text(item.displayNameDE).tag(item)
                    }
                }
                if !availableVariants.isEmpty {
                    Text("API-Varianten: \(availableVariants.map(displayVariant).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
        .sheet(isPresented: $showCatalogPicker) {
            NavigationStack {
                CatalogCardPickerView { detail, locale in
                    applyCatalog(detail: detail, locale: locale)
                }
            }
        }
    }

    private var variantChoices: [CardVariant] {
        let mapped = availableVariants.compactMap { CardVariant(rawValue: $0) }
        return mapped.isEmpty ? CardVariant.allCases : Array(Set(mapped + [.other])).sorted { $0.rawValue < $1.rawValue }
    }

    private func displayVariant(_ raw: String) -> String {
        CardVariant(rawValue: raw)?.displayNameDE ?? raw
    }

    private func applyCatalog(detail: TCGdexCardDetail, locale: String) {
        name = detail.name
        setName = detail.set?.name ?? ""
        setId = detail.set?.id ?? ""
        number = detail.localId ?? ""
        tcgdexId = detail.id
        rarity = detail.rarity ?? ""
        illustrator = detail.illustrator ?? ""
        typesText = (detail.types ?? []).joined(separator: ", ")
        imageURL = detail.image ?? ""
        availableVariants = detail.availableVariantLabels
        catalogPreviewURL = detail.imageURLHigh
        language = CardLanguage(rawValue: locale) ?? language
        if let first = availableVariants.compactMap({ CardVariant(rawValue: $0) }).first {
            variant = first
        }
        Task {
            // Optional: Preis-Snapshot vorbereiten, sobald gespeichert wird (über Import-Service).
            _ = detail
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

        let types = typesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let entry = CardCatalogEntry(
            tcgdexId: resolvedTcgdexId,
            name: trimmedName,
            localizedNames: [language.rawValue: trimmedName],
            setId: setId.trimmingCharacters(in: .whitespacesAndNewlines),
            setName: setName.trimmingCharacters(in: .whitespacesAndNewlines),
            number: number.trimmingCharacters(in: .whitespacesAndNewlines),
            rarity: rarity.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            types: types,
            illustrator: illustrator.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            imageURL: imageURL.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            availableVariants: availableVariants
        )
        modelContext.insert(entry)

        let purchase = Double(purchasePriceText.replacingOccurrences(of: ",", with: "."))
        let manual = Double(manualValueText.replacingOccurrences(of: ",", with: "."))

        let owned = OwnedCard(
            catalogEntry: entry,
            quantity: quantity,
            condition: condition,
            language: language,
            variant: variant,
            purchasePrice: purchase,
            purchaseDate: includePurchaseDate ? purchaseDate : nil,
            manualValue: manual,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            storageLocation: storageLocation.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        modelContext.insert(owned)

        // Wenn TCGdex-ID real: optional Preis nachziehen (nur vorhandene Felder).
        if !catalogId.isEmpty, !catalogId.hasPrefix("local-") {
            Task {
                do {
                    if let price = try await TCGdexProvider.shared.fetchPrice(
                        for: catalogId,
                        locale: language.rawValue
                    ) {
                        await MainActor.run {
                            CatalogImportService().storePriceSnapshot(
                                for: entry,
                                price: price,
                                in: modelContext
                            )
                            try? modelContext.save()
                        }
                    }
                } catch {
                    // Speichern der Karte bleibt gültig ohne Preis.
                }
            }
        }

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
