import SwiftUI
import SwiftData

struct OwnedCardDetailView: View {
    @Bindable var card: OwnedCard
    @Environment(\.modelContext) private var modelContext
    @State private var purchasePriceText: String = ""
    @State private var manualValueText: String = ""
    @State private var refreshMessage: String?

    var body: some View {
        let line = card.portfolioLine()
        List {
            Section {
                HStack {
                    Spacer()
                    CachedCardImageView(
                        imageURL: card.catalogEntry?.imageURLHigh,
                        title: card.catalogEntry?.displayName ?? "Karte",
                        size: CGSize(width: 160, height: 224)
                    )
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Katalog") {
                LabeledContent("Name", value: card.catalogEntry?.displayName ?? "—")
                LabeledContent("Set", value: card.catalogEntry?.setName ?? "—")
                LabeledContent("Nummer", value: card.catalogEntry?.number ?? "—")
                LabeledContent("Seltenheit", value: card.catalogEntry?.rarity ?? "—")
                LabeledContent("Typen", value: (card.catalogEntry?.types ?? []).joined(separator: ", ").nilIfEmpty ?? "—")
                LabeledContent("Illustrator", value: card.catalogEntry?.illustrator ?? "—")
                LabeledContent("Varianten", value: (card.catalogEntry?.availableVariants ?? []).map(displayVariant).joined(separator: ", ").nilIfEmpty ?? "—")
                LabeledContent("TCGdex-ID", value: card.catalogEntry?.tcgdexId ?? "—")
                LabeledContent("Cardmarket-ID", value: card.catalogEntry?.cardmarketId ?? "nicht zugeordnet")
            }

            Section("Exemplar") {
                Stepper("Anzahl: \(card.quantity)", value: $card.quantity, in: 1...99)
                Picker("Zustand", selection: Binding(
                    get: { card.condition },
                    set: { card.condition = $0; card.updatedAt = .now }
                )) {
                    ForEach(CardCondition.allCases) { item in
                        Text(item.displayNameDE).tag(item)
                    }
                }
                Picker("Sprache", selection: Binding(
                    get: { card.language },
                    set: { card.language = $0; card.updatedAt = .now }
                )) {
                    ForEach(CardLanguage.allCases) { item in
                        Text(item.displayNameDE).tag(item)
                    }
                }
                Picker("Variante", selection: Binding(
                    get: { card.variant },
                    set: { card.variant = $0; card.updatedAt = .now }
                )) {
                    ForEach(CardVariant.allCases) { item in
                        Text(item.displayNameDE).tag(item)
                    }
                }
                TextField("Notiz", text: Binding(
                    get: { card.note ?? "" },
                    set: { card.note = $0.isEmpty ? nil : $0; card.updatedAt = .now }
                ), axis: .vertical)
            }

            Section("Kaufpreis") {
                TextField("Kaufpreis (€)", text: $purchasePriceText)
                    .keyboardType(.decimalPad)
                    .onChange(of: purchasePriceText) { _, newValue in
                        let parsed = Double(newValue.replacingOccurrences(of: ",", with: "."))
                        card.purchasePrice = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : parsed
                        card.updatedAt = .now
                    }
                DatePicker(
                    "Kaufdatum",
                    selection: Binding(
                        get: { card.purchaseDate ?? .now },
                        set: { card.purchaseDate = $0; card.updatedAt = .now }
                    ),
                    displayedComponents: .date
                )
                Toggle(
                    "Kaufdatum gesetzt",
                    isOn: Binding(
                        get: { card.purchaseDate != nil },
                        set: { on in
                            card.purchaseDate = on ? (card.purchaseDate ?? .now) : nil
                            card.updatedAt = .now
                        }
                    )
                )
            }

            Section("Portfolio (Exemplar)") {
                LabeledContent("Kaufpreis gesamt", value: CurrencyFormat.euroOrDash(line.purchaseTotal))
                LabeledContent("Aktueller Wert", value: line.hasCurrent ? CurrencyFormat.euro(line.currentTotal) : PriceSource.unavailable.displayNameDE)
                LabeledContent("Differenz", value: {
                    if let diff = line.difference {
                        let pct = line.percent.map { " (\(CurrencyFormat.percent($0)))" } ?? ""
                        return "\(CurrencyFormat.signedEuro(diff))\(pct)"
                    }
                    return "—"
                }())
                PriceSourceLabel(
                    source: line.source,
                    metric: line.metric,
                    updatedAt: line.updatedAt,
                    isSample: line.source == .sample
                )
                valuationKindBadge(line.source)
            }

            Section("Manuelle Bewertung") {
                TextField("Manueller Einzelwert (€)", text: $manualValueText)
                    .keyboardType(.decimalPad)
                    .onChange(of: manualValueText) { _, newValue in
                        let parsed = Double(newValue.replacingOccurrences(of: ",", with: "."))
                        card.manualValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : parsed
                        card.updatedAt = .now
                    }
                Text("Wird genutzt, wenn kein TCGdex-Marktpreis vorliegt. Überschreibt keine echten Marktdaten in der Anzeige-Priorität.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("TCGdex-Preis aktualisieren") {
                    Task { await refreshPrice() }
                }
                if let refreshMessage {
                    Text(refreshMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(card.catalogEntry?.displayName ?? "Karte")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let purchase = card.purchasePrice {
                purchasePriceText = formatEditable(purchase)
            }
            if let manual = card.manualValue {
                manualValueText = formatEditable(manual)
            }
        }
        .onDisappear {
            try? modelContext.save()
        }
    }

    @ViewBuilder
    private func valuationKindBadge(_ source: PriceSource) -> some View {
        let text: String
        let color: Color
        switch source {
        case .tcgdexCardmarket, .lastStored:
            text = "Echte Marktdaten (Referenz)"
            color = .green
        case .manual:
            text = "Manuelle Bewertung"
            color = .blue
        case .sample:
            text = "Beispieldaten – keine Marktdaten"
            color = .orange
        case .unavailable:
            text = "Kein Marktpreis verfügbar"
            color = .secondary
        }
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
    }

    private func displayVariant(_ raw: String) -> String {
        CardVariant(rawValue: raw)?.displayNameDE ?? raw
    }

    private func formatEditable(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }

    private func refreshPrice() async {
        guard let tcgdexId = card.catalogEntry?.tcgdexId,
              !tcgdexId.hasPrefix("local-") else {
            refreshMessage = "Keine TCGdex-ID – Preis nicht abrufbar."
            return
        }
        do {
            let locale = card.language.rawValue
            let price = try await TCGdexProvider.shared.fetchPrice(for: tcgdexId, locale: locale)
                ?? .unavailable
            if let entry = card.catalogEntry {
                CatalogImportService().storePriceSnapshot(for: entry, price: price, in: modelContext)
                try modelContext.save()
            }
            if price.amountEUR == nil {
                refreshMessage = PriceSource.unavailable.displayNameDE
            } else {
                refreshMessage = "Preis aktualisiert (\(price.source.displayNameDE))."
            }
        } catch {
            refreshMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
