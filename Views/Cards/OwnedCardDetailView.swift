import SwiftUI
import SwiftData
import Charts

struct OwnedCardDetailView: View {
    @Bindable var card: OwnedCard
    @Query(sort: \UserCollection.updatedAt, order: .reverse) private var collections: [UserCollection]
    @Environment(\.modelContext) private var modelContext
    @State private var purchasePriceText: String = ""
    @State private var manualValueText: String = ""
    @State private var refreshMessage: String?
    @State private var showCollectionPicker = false

    private var detailTone: PV.ElementTone {
        let types = card.catalogEntry?.types ?? []
        if !types.isEmpty {
            return .from(types: types)
        }
        return .from(seed: card.catalogEntry?.displayName ?? card.id.uuidString)
    }

    private var portfolioLine: CardPortfolioLine {
        card.portfolioLine()
    }

    private var memberCollections: [UserCollection] {
        collections.filter { col in
            col.memberships.contains { $0.ownedCard?.id == card.id }
        }
    }

    private var priceHistory: [PriceSnapshot] {
        card.catalogEntry.map { PriceHistoryService.snapshots(for: $0) } ?? []
    }

    var body: some View {
        List {
            heroSection
            catalogSection
            exemplarSection
            purchaseSection
            portfolioSection
            manualValueSection
            historySection
            collectionsSection
            actionsSection
        }
        .scrollContentBackground(.hidden)
        .pvScreenBackground()
        .navigationTitle(card.catalogEntry?.displayName ?? "Karte")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadEditableFields)
        .onDisappear { try? modelContext.save() }
        .sheet(isPresented: $showCollectionPicker) {
            collectionPickerSheet
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var heroSection: some View {
        Section {
            OwnedCardDetailHero(
                tone: detailTone,
                name: card.catalogEntry?.displayName ?? "Karte",
                number: card.catalogEntry?.number ?? "?",
                types: Array((card.catalogEntry?.types ?? []).prefix(3)),
                imageCandidates: card.catalogEntry?.imageCandidatesHigh ?? []
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var catalogSection: some View {
        Section("Katalog") {
            LabeledContent("Name", value: card.catalogEntry?.displayName ?? "—")
            LabeledContent("Set", value: card.catalogEntry?.setName ?? "—")
            LabeledContent("Nummer", value: card.catalogEntry?.number ?? "—")
            LabeledContent("Seltenheit", value: card.catalogEntry?.rarity ?? "—")
            LabeledContent("Typen", value: (card.catalogEntry?.types ?? []).joined(separator: ", ").nilIfEmpty ?? "—")
            LabeledContent("Illustrator", value: card.catalogEntry?.illustrator ?? "—")
            LabeledContent("Varianten", value: variantsLabel)
            LabeledContent("TCGdex-ID", value: card.catalogEntry?.tcgdexId ?? "—")
            LabeledContent("Cardmarket-ID", value: card.catalogEntry?.cardmarketId ?? "nicht zugeordnet")
        }
    }

    @ViewBuilder
    private var exemplarSection: some View {
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
    }

    @ViewBuilder
    private var purchaseSection: some View {
        Section("Kaufpreis") {
            TextField("Kaufpreis (€)", text: $purchasePriceText)
                .keyboardType(.decimalPad)
                .onChange(of: purchasePriceText) { _, newValue in
                    applyPurchasePrice(newValue)
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
    }

    @ViewBuilder
    private var portfolioSection: some View {
        Section("Portfolio (Exemplar)") {
            LabeledContent("Kaufpreis gesamt", value: CurrencyFormat.euroOrDash(portfolioLine.purchaseTotal))
            LabeledContent(
                "Aktueller Wert",
                value: portfolioLine.currentTotal.map(CurrencyFormat.euro)
                    ?? PriceSource.unavailable.displayNameDE
            )
            LabeledContent("Differenz", value: differenceLabel(portfolioLine))
            PriceSourceLabel(
                source: portfolioLine.source,
                metric: portfolioLine.metric,
                updatedAt: portfolioLine.updatedAt,
                isSample: portfolioLine.source == .sample
            )
            valuationKindBadge(portfolioLine.source)
        }
    }

    @ViewBuilder
    private var manualValueSection: some View {
        Section("Manuelle Bewertung") {
            TextField("Manueller Einzelwert (€)", text: $manualValueText)
                .keyboardType(.decimalPad)
                .onChange(of: manualValueText) { _, newValue in
                    applyManualValue(newValue)
                }
            Text("Wird genutzt, wenn kein TCGdex-Marktpreis vorliegt. Überschreibt keine echten Marktdaten in der Anzeige-Priorität.")
                .font(PV.caption())
                .foregroundStyle(PV.onScreenMuted)
        }
        .listRowBackground(PV.listRow)
    }

    @ViewBuilder
    private var historySection: some View {
        Section("Preisverlauf (echte Snapshots)") {
            if priceHistory.count >= 2 {
                Chart(priceHistory, id: \.id) { snap in
                    if let amount = snap.amountEUR {
                        LineMark(
                            x: .value("Zeit", snap.capturedAt),
                            y: .value("EUR", amount)
                        )
                        .foregroundStyle(PV.readout)
                    }
                }
                .frame(height: 140)
            } else {
                Text("Noch keine Historie — nach mehreren TCGdex-Aktualisierungen erscheint die Kurve. Keine erfundenen Punkte.")
                    .font(PV.caption())
                    .foregroundStyle(PV.onScreenMuted)
            }
        }
        .listRowBackground(PV.listRow)
    }

    @ViewBuilder
    private var collectionsSection: some View {
        Section("Sammlungen") {
            if memberCollections.isEmpty {
                Text("In keiner Sammlung")
                    .foregroundStyle(PV.onScreenMuted)
            } else {
                ForEach(memberCollections, id: \.id) { col in
                    HStack {
                        Text(col.name)
                            .foregroundStyle(PV.onScreen)
                        Spacer()
                        Button("Entfernen", role: .destructive) {
                            CollectionMembershipService.remove(card, from: col, in: modelContext)
                            try? modelContext.save()
                        }
                        .font(PV.caption())
                    }
                }
            }
            Button("Zu Sammlung hinzufügen…") {
                showCollectionPicker = true
            }
            .foregroundStyle(PV.readout)
            .disabled(collections.isEmpty)
        }
        .listRowBackground(PV.listRow)
    }

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            Button("TCGdex-Preis aktualisieren") {
                Task { await refreshPrice() }
            }
            .foregroundStyle(PV.readout)
            Button("Zur Wunschliste") {
                addWishlist()
            }
            .foregroundStyle(PV.readout)
            if let refreshMessage {
                Text(refreshMessage)
                    .font(PV.caption())
                    .foregroundStyle(PV.onScreenMuted)
            }
        }
        .listRowBackground(PV.listRow)
    }

    private var collectionPickerSheet: some View {
        NavigationStack {
            List(collections, id: \.id) { col in
                let already = col.memberships.contains { $0.ownedCard?.id == card.id }
                Button {
                    CollectionMembershipService.add(card, to: col, in: modelContext)
                    try? modelContext.save()
                    showCollectionPicker = false
                } label: {
                    HStack {
                        Text(col.name)
                            .foregroundStyle(PV.onScreen)
                        Spacer()
                        if already {
                            Text("Bereits Mitglied")
                                .font(PV.caption())
                                .foregroundStyle(PV.onScreenMuted)
                        }
                    }
                }
                .disabled(already)
                .pvListRowStyle()
            }
            .scrollContentBackground(.hidden)
            .pvScreenBackground()
            .navigationTitle("Sammlung wählen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { showCollectionPicker = false }
                }
            }
        }
        .pvThemedSheet()
    }

    // MARK: - Helpers

    private var variantsLabel: String {
        (card.catalogEntry?.availableVariants ?? [])
            .map(displayVariant)
            .joined(separator: ", ")
            .nilIfEmpty ?? "—"
    }

    private func differenceLabel(_ line: CardPortfolioLine) -> String {
        guard let diff = line.difference else { return "—" }
        let pct = line.percent.map { " (\(CurrencyFormat.percent($0)))" } ?? ""
        return "\(CurrencyFormat.signedEuro(diff))\(pct)"
    }

    private func loadEditableFields() {
        if let purchase = card.purchasePrice {
            purchasePriceText = formatEditable(purchase)
        }
        if let manual = card.manualValue {
            manualValueText = formatEditable(manual)
        }
    }

    private func applyPurchasePrice(_ newValue: String) {
        let parsed = Double(newValue.replacingOccurrences(of: ",", with: "."))
        card.purchasePrice = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : parsed
        card.updatedAt = .now
    }

    private func applyManualValue(_ newValue: String) {
        let parsed = Double(newValue.replacingOccurrences(of: ",", with: "."))
        card.manualValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : parsed
        card.updatedAt = .now
    }

    private func valuationKindBadge(_ source: PriceSource) -> some View {
        let style = valuationKindStyle(source)
        return Text(style.text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(style.color)
    }

    private func valuationKindStyle(_ source: PriceSource) -> (text: String, color: Color) {
        switch source {
        case .tcgdexCardmarket, .lastStored:
            return ("Echte Marktdaten (Referenz)", .green)
        case .manual:
            return ("Manuelle Bewertung", .blue)
        case .sample:
            return ("Beispieldaten – keine Marktdaten", .orange)
        case .unavailable:
            return ("Kein Marktpreis verfügbar", .secondary)
        }
    }

    private func displayVariant(_ raw: String) -> String {
        CardVariant(rawValue: raw)?.displayNameDE ?? raw
    }

    private func formatEditable(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }

    private func refreshPrice() async {
        guard let entry = card.catalogEntry,
              !entry.tcgdexId.hasPrefix("local-") else {
            refreshMessage = "Keine TCGdex-ID – Preis nicht abrufbar."
            return
        }
        do {
            let price = try await PriceHistoryService.refreshFromTCGdex(
                entry: entry,
                locale: card.language.rawValue,
                in: modelContext
            )
            if price.amountEUR == nil {
                refreshMessage = PriceSource.unavailable.displayNameDE
            } else {
                refreshMessage = "Preis aktualisiert (\(price.source.displayNameDE))."
            }
        } catch {
            refreshMessage = error.localizedDescription
        }
    }

    private func addWishlist() {
        guard let entry = card.catalogEntry else { return }
        let wish = WishlistEntry(
            catalogEntry: entry,
            priority: 2,
            desiredCondition: card.condition,
            desiredLanguage: card.language,
            targetPriceEUR: card.resolvedUnitValue().value
        )
        modelContext.insert(wish)
        try? modelContext.save()
        refreshMessage = "Auf die Wunschliste gesetzt."
    }
}

/// Rare Candy type-hero for owned-card detail (keeps List body type-checkable).
private struct OwnedCardDetailHero: View {
    let tone: PV.ElementTone
    let name: String
    let number: String
    let types: [String]
    let imageCandidates: [URL]

    var body: some View {
        PVTypeColoredCard(tone: tone, minHeight: 160) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(name)
                        .font(PV.title())
                        .foregroundStyle(tone.onHero)
                    Text("#\(number)")
                        .font(PV.labelID())
                        .foregroundStyle(tone.onHero.opacity(0.8))
                    HStack(spacing: 6) {
                        ForEach(types, id: \.self) { type in
                            PVTypePill(title: type)
                        }
                    }
                }
                Spacer()
                CachedCardImageView(
                    candidates: imageCandidates,
                    title: name,
                    size: CGSize(width: 110, height: 154)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
