import SwiftUI
import SwiftData

struct CardGalleryView: View {
    @Query(sort: \OwnedCard.updatedAt, order: .reverse) private var ownedCards: [OwnedCard]
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var showSettings = false

    private var filtered: [OwnedCard] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ownedCards }
        return ownedCards.filter { card in
            let name = card.catalogEntry?.displayName ?? ""
            let set = card.catalogEntry?.setName ?? ""
            let number = card.catalogEntry?.number ?? ""
            return name.localizedCaseInsensitiveContains(trimmed)
                || set.localizedCaseInsensitiveContains(trimmed)
                || number.localizedCaseInsensitiveContains(trimmed)
        }
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
                } else {
                    List(filtered, id: \.id) { card in
                        NavigationLink {
                            OwnedCardDetailView(card: card)
                        } label: {
                            OwnedCardRow(card: card)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Meine Karten")
            .searchable(text: $searchText, prompt: "Name, Set oder Nummer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Einstellungen")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Karte hinzufügen")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                NavigationStack {
                    AddOwnedCardView()
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}

struct OwnedCardRow: View {
    let card: OwnedCard

    var body: some View {
        HStack(spacing: 12) {
            CardThumbnailView(
                imageURL: card.catalogEntry?.imageURLHigh,
                title: card.catalogEntry?.displayName ?? "Karte"
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(card.catalogEntry?.displayName ?? "Unbekannte Karte")
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(priceLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("×\(card.quantity)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        let set = card.catalogEntry?.setName ?? "—"
        let number = card.catalogEntry?.number ?? "?"
        return "\(set) · #\(number) · \(card.condition.displayNameDE) · \(card.language.displayNameDE)"
    }

    private var priceLine: String {
        let resolved = card.resolvedUnitValue()
        if let value = resolved.value {
            let tag = resolved.source == .sample ? " [Beispiel]" : ""
            return "\(CurrencyFormat.euro(value))\(tag) · \(resolved.source.displayNameDE)"
        }
        return PriceSource.unavailable.displayNameDE
    }
}

#Preview {
    CardGalleryView()
        .modelContainer(ModelContainerFactory.previewContainer())
}
