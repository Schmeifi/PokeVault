import SwiftUI
import SwiftData

struct SetListView: View {
    let sets: [TCGdexSetSummary]
    let locale: String
    var onSelectSet: (TCGdexSetSummary) -> Void

    var body: some View {
        List(sets) { set in
            Button {
                onSelectSet(set)
            } label: {
                HStack(spacing: 12) {
                    CachedCardImageView(
                        imageURL: set.logoURL ?? set.symbolURL,
                        title: set.name,
                        size: CGSize(width: 56, height: 40)
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(set.name)
                            .font(PV.headline())
                            .foregroundStyle(PV.onScreen)
                        Text(setSubtitle(set))
                            .font(PV.caption())
                            .foregroundStyle(PV.onScreenMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(PV.onScreenMuted)
                }
            }
            .buttonStyle(.plain)
            .pvListRowStyle()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func setSubtitle(_ set: TCGdexSetSummary) -> String {
        let official = set.cardCount?.official.map(String.init) ?? "?"
        let total = set.cardCount?.total.map(String.init) ?? "?"
        return "\(set.id) · \(official)/\(total) Karten"
    }
}

enum SetCardSort: String, CaseIterable, Identifiable {
    case number
    case rarity
    case name
    case price

    var id: String { rawValue }

    var titleDE: String {
        switch self {
        case .number: return "Nummer"
        case .rarity: return "Seltenheit"
        case .name: return "Name"
        case .price: return "Preis"
        }
    }
}

struct SetDetailView: View {
    let setId: String
    let locale: String
    var onPickCard: ((TCGdexCardSummary) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var detail: TCGdexSetDetail?
    @State private var enriched: [SetCardEnrichment] = []
    @State private var isLoading = true
    @State private var isEnriching = false
    @State private var enrichProgress: (Int, Int) = (0, 0)
    @State private var errorMessage: String?
    @State private var importMessage: String?
    @State private var sort: SetCardSort = .rarity
    @State private var wishlistCatalog: CardCatalogEntry?

    private var sortedCards: [SetCardEnrichment] {
        switch sort {
        case .number:
            return enriched.sorted {
                ($0.summary.localId ?? "").localizedStandardCompare($1.summary.localId ?? "") == .orderedAscending
            }
        case .rarity:
            return enriched.sorted {
                CardRaritySort.compare(
                    lhs: $0.rarity,
                    rhs: $1.rarity,
                    nameL: $0.summary.name,
                    nameR: $1.summary.name
                )
            }
        case .name:
            return enriched.sorted {
                $0.summary.name.localizedCaseInsensitiveCompare($1.summary.name) == .orderedAscending
            }
        case .price:
            return enriched.sorted {
                ($0.priceEUR ?? -1) > ($1.priceEUR ?? -1)
            }
        }
    }

    private var marketTotal: (sum: Double?, priced: Int, total: Int, label: String) {
        let total = enriched.count
        let priced = enriched.compactMap(\.priceEUR)
        guard !priced.isEmpty else {
            return (nil, 0, total, total == 0 ? "—" : "— (0/\(total) Preise)")
        }
        let sum = priced.reduce(0, +)
        if priced.count == total {
            return (sum, priced.count, total, CurrencyFormat.euro(sum))
        }
        return (sum, priced.count, total, "\(CurrencyFormat.euro(sum)) · teilweise (\(priced.count)/\(total))")
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Set wird geladen…")
                    .tint(PV.primary)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Set nicht ladbar",
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
            } else if let detail {
                List {
                    Section {
                        HStack {
                            Spacer()
                            CachedCardImageView(
                                imageURL: detail.logoURL ?? detail.symbolURL,
                                title: detail.name,
                                size: CGSize(width: 160, height: 80)
                            )
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        LabeledContent("Name", value: detail.name)
                        LabeledContent("Serie", value: detail.serie?.name ?? "—")
                        LabeledContent("Release", value: detail.releaseDate ?? "—")
                        LabeledContent(
                            "Karten",
                            value: {
                                let o = detail.cardCount?.official.map(String.init) ?? "?"
                                let t = detail.cardCount?.total.map(String.init) ?? "?"
                                return "\(o) offiziell / \(t) gesamt"
                            }()
                        )
                        LabeledContent("Set-Marktwert (TCGdex)", value: marketTotal.label)
                        if isEnriching {
                            ProgressView(
                                value: Double(enrichProgress.0),
                                total: Double(max(1, enrichProgress.1))
                            ) {
                                Text("Preise & Seltenheiten… \(enrichProgress.0)/\(enrichProgress.1)")
                                    .font(PV.caption())
                                    .foregroundStyle(PV.onScreenMuted)
                            }
                            .tint(PV.primary)
                        } else if marketTotal.priced < marketTotal.total, marketTotal.total > 0 {
                            Text("Summe nur über bekannte Cardmarket-EUR-Felder — fehlende Preise werden nicht geschätzt.")
                                .font(PV.caption())
                                .foregroundStyle(PV.onScreenMuted)
                        }
                        if let legal = detail.legal {
                            LabeledContent(
                                "Legal",
                                value: [
                                    legal.standard == true ? "Standard" : nil,
                                    legal.expanded == true ? "Expanded" : nil
                                ].compactMap { $0 }.joined(separator: ", ").nilIfEmpty ?? "—"
                            )
                        }
                        if let abbr = detail.abbreviation?.official {
                            LabeledContent("Kürzel", value: abbr)
                        }
                    }
                    .listRowBackground(PV.listRow)
                    .foregroundStyle(PV.onScreen)

                    Section {
                        Picker("Sortierung", selection: $sort) {
                            ForEach(SetCardSort.allCases) { option in
                                Text(option.titleDE).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                    }

                    Section("Karten im Set") {
                        ForEach(sortedCards) { card in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    CardSearchResultRow(card: card.summary)
                                    HStack(spacing: 8) {
                                        Text(card.displayRarity)
                                            .font(PV.caption())
                                            .foregroundStyle(PV.primary)
                                        Text(card.priceLabel ?? "—")
                                            .font(PV.monoCaption())
                                            .foregroundStyle(card.priceEUR == nil ? PV.statusWarn : PV.readout)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let onPickCard {
                                    onPickCard(card.summary)
                                } else {
                                    Task { await importCard(card.summary) }
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Wunschliste") {
                                    Task { await addToWishlist(card.summary) }
                                }
                                .tint(PV.primary)
                            }
                            .listRowBackground(PV.listRow)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .pvScreenBackground()
            }
        }
        .navigationTitle(detail?.name ?? setId)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Fortschritt") {
                    SetProgressView(setId: setId, locale: locale)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let importMessage {
                Text(importMessage)
                    .font(PV.caption())
                    .foregroundStyle(PV.onPrimary)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(PV.primary)
            }
        }
        .sheet(item: $wishlistCatalog) { entry in
            NavigationStack {
                WishlistPickerSheet(catalogEntry: entry) { listName in
                    importMessage = "Zur Wunschliste „\(listName)“ hinzugefügt."
                }
            }
            .presentationDetents([.medium])
        }
        .task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let loaded = try await TCGdexProvider.shared.fetchSetDetail(id: setId, locale: locale)
            detail = loaded
            let summaries = loaded.cards ?? []
            enriched = summaries.map {
                SetCardEnrichment(summary: $0, rarity: nil, category: nil, priceEUR: nil, priceLabel: nil)
            }
            _ = try? SetCatalogService().upsertSet(from: loaded, in: modelContext)
            try? modelContext.save()
            let lists = summaries.prefix(24).map(\.imageCandidatesLow)
            await CardImageCache.shared.prefetch(candidatesList: Array(lists))

            isEnriching = true
            enrichProgress = (0, summaries.count)
            let result = await TCGdexProvider.shared.enrichSetCards(summaries, locale: locale) { done, total in
                Task { @MainActor in
                    enrichProgress = (done, total)
                }
            }
            enriched = result
            isEnriching = false
        } catch {
            errorMessage = error.localizedDescription
            isEnriching = false
        }
    }

    private func importCard(_ card: TCGdexCardSummary) async {
        do {
            let importer = CatalogImportService()
            let entry = try await importer.importCard(id: card.id, locale: locale, in: modelContext)
            let owned = OwnedCard(
                catalogEntry: entry,
                quantity: 1,
                condition: .nearMint,
                language: CardLanguage(rawValue: locale) ?? .de
            )
            if let first = entry.availableVariants.first,
               let variant = CardVariant(rawValue: first) {
                owned.variant = variant
            }
            modelContext.insert(owned)
            try modelContext.save()
            importMessage = "„\(entry.displayName)“ hinzugefügt."
        } catch {
            importMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func addToWishlist(_ card: TCGdexCardSummary) async {
        do {
            let importer = CatalogImportService()
            let entry = try await importer.importCard(id: card.id, locale: locale, in: modelContext)
            wishlistCatalog = entry
        } catch {
            importMessage = "Wunschliste: \(error.localizedDescription)"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
