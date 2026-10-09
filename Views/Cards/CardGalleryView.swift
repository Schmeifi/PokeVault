import SwiftUI
import SwiftData

struct CardGalleryView: View {
    @Query private var ownedCards: [OwnedCard]
    @State private var searchText = ""
    @State private var sort: OwnedCardSort = .updatedDesc
    @State private var typeFilter: PV.ElementTone? = nil
    @State private var showAddSheet = false
    @State private var showSettings = false

    private var filtered: [OwnedCard] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var base: [OwnedCard]
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
        if let typeFilter {
            base = base.filter { tone(for: $0) == typeFilter }
        }
        return sort.sorted(base)
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: PV.gutter),
            GridItem(.flexible(), spacing: PV.gutter)
        ]
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty && typeFilter == nil ? "Keine Karten" : "Keine Treffer",
                        systemImage: "rectangle.stack",
                        description: Text(
                            searchText.isEmpty && typeFilter == nil
                                ? "Tippe auf +, um eine Karte manuell hinzuzufügen."
                                : "Passe Suche oder Typ-Filter an."
                        )
                    )
                    .foregroundStyle(PV.inkSecondary)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: PV.gutter) {
                            ForEach(filtered, id: \.id) { card in
                                NavigationLink {
                                    OwnedCardDetailView(card: card)
                                } label: {
                                    GalleryTypeCard(card: card, tone: tone(for: card))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, PV.margin)
                        .padding(.vertical, PV.spaceM)
                    }
                }
            }
            .navigationTitle("Meine Karten")
            .navigationBarTitleDisplayMode(.large)
            .pvScreenBackground()
            .searchable(text: $searchText, prompt: "Name, Set oder Nummer")
            .safeAreaInset(edge: .top, spacing: 0) {
                typeFilterBar
            }
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
                    }
                    .accessibilityLabel("Sortierung")
                }
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
                        Image(systemName: "plus.circle.fill")
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

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PV.spaceS) {
                filterChip(title: "Alle (\(ownedCards.count))", selected: typeFilter == nil) {
                    typeFilter = nil
                }
                ForEach([PV.ElementTone.grass, .fire, .water, .electric, .psychic]) { tone in
                    filterChip(title: tone.titleDE, selected: typeFilter == tone) {
                        typeFilter = tone
                    }
                }
            }
            .padding(.horizontal, PV.margin)
            .padding(.vertical, PV.spaceS)
        }
        .background(PV.canvas.opacity(0.92))
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PV.labelBadge())
                .foregroundStyle(selected ? PV.onPrimary : PV.onSurfaceVariant)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selected ? PV.primary : PV.surfaceContainer)
                )
        }
        .buttonStyle(.plain)
    }

    private func tone(for card: OwnedCard) -> PV.ElementTone {
        let types = card.catalogEntry?.types ?? []
        if !types.isEmpty {
            return .from(types: types)
        }
        let seed = card.catalogEntry?.displayName ?? card.id.uuidString
        return .from(seed: seed)
    }
}

struct GalleryTypeCard: View {
    let card: OwnedCard
    let tone: PV.ElementTone

    var body: some View {
        PVTypeColoredCard(tone: tone, minHeight: 210) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(card.catalogEntry?.displayName ?? "Unbekannt")
                        .font(PV.headline())
                        .foregroundStyle(tone.onHero)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Text("#\(card.catalogEntry?.number ?? "?")")
                        .font(PV.labelID())
                        .foregroundStyle(tone.onHero.opacity(0.75))
                }

                HStack(spacing: 4) {
                    ForEach(displayTypes.prefix(2), id: \.self) { type in
                        PVTypePill(title: type)
                    }
                    if displayTypes.isEmpty {
                        PVTypePill(title: tone.titleDE)
                    }
                }

                Spacer(minLength: 8)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let price = priceText {
                            Text(price)
                                .font(PV.statNumber())
                                .foregroundStyle(tone.onHero)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.22)))
                        }
                        Text("×\(card.quantity)")
                            .font(PV.caption())
                            .foregroundStyle(tone.onHero.opacity(0.85))
                    }
                    Spacer(minLength: 4)
                    CachedCardImageView(
                        candidates: card.catalogEntry?.imageCandidatesLow ?? [],
                        title: card.catalogEntry?.displayName ?? "Karte",
                        size: CGSize(width: 72, height: 100)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
                }
            }
        }
    }

    private var displayTypes: [String] {
        let raw = card.catalogEntry?.types ?? []
        if raw.isEmpty { return [] }
        return raw.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
    }

    private var priceText: String? {
        let resolved = card.resolvedUnitValue()
        guard let value = resolved.value else { return nil }
        return CurrencyFormat.euro(value)
    }
}

/// Listen-Zeile (Dashboard „Zuletzt“, Sammlungen) — Rare-Candy Sheet-Stil.
struct OwnedCardRow: View {
    let card: OwnedCard

    private var tone: PV.ElementTone {
        let types = card.catalogEntry?.types ?? []
        if !types.isEmpty { return .from(types: types) }
        return .from(seed: card.catalogEntry?.displayName ?? card.id.uuidString)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tone.hero.opacity(0.25))
                    .frame(width: 56, height: 78)
                CachedCardImageView(
                    candidates: card.catalogEntry?.imageCandidatesLow ?? [],
                    title: card.catalogEntry?.displayName ?? "Karte",
                    size: CGSize(width: 52, height: 72)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(card.catalogEntry?.displayName ?? "Unbekannte Karte")
                    .font(PV.headline())
                    .foregroundStyle(PV.inkTitle)
                Text(subtitle)
                    .font(PV.caption())
                    .foregroundStyle(PV.inkSecondary)
                Text(priceLine)
                    .font(PV.statNumber())
                    .foregroundStyle(PV.primary)
                if let pnl = pnlLine {
                    Text(pnl)
                        .font(PV.caption())
                        .foregroundStyle(PV.inkSecondary)
                }
            }
            Spacer(minLength: 0)
            Text("×\(card.quantity)")
                .font(PV.bodyStrong())
                .foregroundStyle(PV.inkMuted)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        let set = card.catalogEntry?.setName ?? "—"
        let number = card.catalogEntry?.number ?? "?"
        return "\(set) · #\(number) · \(card.condition.displayNameDE)"
    }

    private var priceLine: String {
        let resolved = card.resolvedUnitValue()
        if let value = resolved.value {
            let tag = resolved.source == .sample ? " [Beispiel]" : ""
            return "\(CurrencyFormat.euro(value))\(tag)"
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
