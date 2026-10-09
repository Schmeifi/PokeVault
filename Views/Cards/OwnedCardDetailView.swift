import SwiftUI
import SwiftData

struct OwnedCardDetailView: View {
    @Bindable var card: OwnedCard
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    CardThumbnailView(
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

            Section("Wert") {
                let resolved = card.resolvedUnitValue()
                LabeledContent("Einzelwert", value: CurrencyFormat.euro(resolved.value))
                PriceSourceLabel(
                    source: resolved.source,
                    metric: card.catalogEntry?.priceSnapshots.sorted(by: { $0.capturedAt > $1.capturedAt }).first?.metric,
                    updatedAt: card.catalogEntry?.priceSnapshots.sorted(by: { $0.capturedAt > $1.capturedAt }).first?.capturedAt,
                    isSample: resolved.source == .sample
                )
                if resolved.source == .sample {
                    SampleDataBanner(message: "Dieser Wert ist ein Beispielplatzhalter – kein echter Marktpreis.")
                }
                if let purchase = card.purchasePrice {
                    LabeledContent("Kaufpreis", value: CurrencyFormat.euro(purchase))
                }
                if let manual = card.manualValue {
                    LabeledContent("Manuelle Bewertung", value: CurrencyFormat.euro(manual))
                }
            }
        }
        .navigationTitle(card.catalogEntry?.displayName ?? "Karte")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            try? modelContext.save()
        }
    }
}
