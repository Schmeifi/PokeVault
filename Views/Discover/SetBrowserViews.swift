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

struct SetDetailView: View {
    let setId: String
    let locale: String
    var onPickCard: ((TCGdexCardSummary) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var detail: TCGdexSetDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var importMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Set wird geladen…")
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

                    Section("Karten im Set") {
                        ForEach(detail.cards ?? []) { card in
                            HStack {
                                CardSearchResultRow(card: card)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let onPickCard {
                                    onPickCard(card)
                                } else {
                                    Task { await importCard(card) }
                                }
                            }
                        }
                    }
                }
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
                    .font(.footnote)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
            }
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
            _ = try? SetCatalogService().upsertSet(from: loaded, in: modelContext)
            try? modelContext.save()
            let lists = (loaded.cards ?? []).prefix(24).map(\.imageCandidatesLow)
            await CardImageCache.shared.prefetch(candidatesList: Array(lists))
        } catch {
            errorMessage = error.localizedDescription
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
            // Variante aus Katalog-Flags, falls eindeutig.
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
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
