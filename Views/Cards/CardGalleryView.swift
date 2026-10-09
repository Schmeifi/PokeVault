import SwiftUI
import SwiftData

struct CardGalleryView: View {
    @Query private var ownedCards: [OwnedCard]
    @State private var searchText = ""
    @State private var sort: OwnedCardSort = .updatedDesc
    @State private var showAddSheet = false
    @State private var showSettings = false

    private var filtered: [OwnedCard] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: [OwnedCard]
        if trimmed.isEmpty {
            base = ownedCards
        } else {
            base = ownedCards.filter { card in
                let name = card.catalogEntry?.displayName ?? ""
                let set = card.catalogEntry?.setName ?? ""
                let number = card.catalogEntry?.number ?? ""
                return name.localizedCaseInsensitiveContains(trimmed)
                    || set.localizedCaseInsensitiveContains(trimmed)
                    || number.localizedCaseInsensitiveContains(trimmed)
            }
        }
        return sort.sorted(base)
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "Keine Karten" : "Keine Treffer",
                        systemImage: "rectangle.stack",
                        description: Text(
                            searchText.isEmpty
                                ? "Tippe auf +, um eine Karte manuell hinzuzufügen."
                                : "Passe die Suche an oder füge eine neue Karte hinzu."
                        )
                    )
                    .foregroundStyle(PV.onScreen)
                } else {
                    List(filtered, id: \.id) { card in
                        NavigationLink {
                            OwnedCardDetailView(card: card)
                        } label: {
                            OwnedCardRow(card: card)
                        }
                        .pvListRowStyle()
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Meine Karten")
            .scrollContentBackground(.hidden)
            .pvScreenBackground()
            .searchable(text: $searchText, prompt: "Name, Set oder Nummer")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sortierung", selection: $sort) {
                            ForEach(OwnedCardSort.allCases) { option in
                                Text(option.titleDE).tag(option)
                            }
                        }
                    } label: {
                        Label("Sortierung", systemImage: "arrow.up.arrow.down")
                            .foregroundStyle(PV.onChassis)
                    }
                    .accessibilityLabel("Sortierung")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(PV.onChassis)
                    }
                    .accessibilityLabel("Einstellungen")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(PV.onChassis)
                    }
                    .accessibilityLabel("Karte hinzufügen")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                NavigationStack {
                    AddOwnedCardView()
                }
                .pvThemedSheet()
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
                .pvThemedSheet()
            }
        }
    }
}

struct OwnedCardRow: View {
    let card: OwnedCard

    var body: some View {
        HStack(spacing: 12) {
            CachedCardImageView(
                candidates: card.catalogEntry?.imageCandidatesLow ?? [],
                title: card.catalogEntry?.displayName ?? "Karte"
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(card.catalogEntry?.displayName ?? "Unbekannte Karte")
                    .font(PV.headline())
                    .foregroundStyle(PV.onScreen)
                Text(subtitle)
                    .font(PV.caption())
                    .foregroundStyle(PV.onScreenMuted)
                Text(priceLine)
                    .font(PV.monoCaption())
                    .foregroundStyle(PV.readout)
                if let pnl = pnlLine {
                    Text(pnl)
                        .font(PV.caption())
                        .foregroundStyle(PV.onScreenMuted)
                }
            }
            Spacer(minLength: 0)
            Text("×\(card.quantity)")
                .font(PV.readout(.subheadline))
                .foregroundStyle(PV.onScreenMuted)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        let set = card.catalogEntry?.setName ?? "—"
        let number = card.catalogEntry?.number ?? "?"
        return "\(set) · #\(number) · \(card.condition.displayNameDE) · \(card.language.displayNameDE) · \(card.variant.displayNameDE)"
    }

    private var priceLine: String {
        let resolved = card.resolvedUnitValue()
        if let value = resolved.value {
            let tag = resolved.source == .sample ? " [Beispiel]" : ""
            return "Aktuell: \(CurrencyFormat.euro(value))\(tag) · \(resolved.source.displayNameDE)"
        }
        return PriceSource.unavailable.displayNameDE
    }

    private var pnlLine: String? {
        let line = card.portfolioLine()
        guard let purchase = line.purchaseTotal else {
            return "Kaufpreis: —"
        }
        var parts = ["Kauf: \(CurrencyFormat.euro(purchase))"]
        if let diff = line.difference {
            parts.append("Δ \(CurrencyFormat.signedEuro(diff))")
            if let percent = line.percent {
                parts.append(CurrencyFormat.percent(percent))
            }
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    CardGalleryView()
        .modelContainer(ModelContainerFactory.previewContainer())
}
