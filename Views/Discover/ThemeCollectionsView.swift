import SwiftUI
import SwiftData

/// Themen-Sammlungen: kuratiert + eigene Tags, jeweils mit den zugehörigen Karten.
struct ThemeCollectionsView: View {
    @Query(sort: \ThemeTag.name) private var tags: [ThemeTag]
    @Query(sort: \OwnedCard.updatedAt, order: .reverse) private var owned: [OwnedCard]
    @Environment(\.modelContext) private var modelContext
    @State private var newTag = ""
    @State private var assigningTag: ThemeTag?

    private let curated: [(String, String, String)] = [
        ("Eeveelutions", "Nachtara, Evoli und Entwicklungen", "evoli"),
        ("Trainer Gallery", "TG-Nummern und Galerie-Druckungen", "tg"),
        ("V / VMAX", "V- und VMAX-Karten in der Sammlung", "v"),
        ("Feuer-Typen", "Karten vom Typ Feuer", "fire")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PV.spaceL) {
                PVScreenPanel {
                    Text("Themen")
                        .font(PV.title())
                        .foregroundStyle(PV.onScreen)
                    Text("Jedes Thema listet die Karten aus deiner Sammlung, die dazugehören.")
                        .font(PV.caption())
                        .foregroundStyle(PV.onScreenMuted)
                }

                ForEach(curated, id: \.0) { theme in
                    let matches = suggest(for: theme.2)
                    themePanel(title: theme.0, subtitle: theme.1, cards: matches)
                }

                PVCreamPanel {
                    Text("Eigene Tags")
                        .font(PV.headline())
                    HStack {
                        TextField("Neues Thema", text: $newTag)
                            .textFieldStyle(.roundedBorder)
                        Button("Plus") { addTag() }
                            .buttonStyle(.borderedProminent)
                            .tint(PV.primary)
                    }
                    if tags.isEmpty {
                        Text("Noch keine eigenen Themen.")
                            .font(PV.caption())
                            .foregroundStyle(PV.inkMuted)
                    }
                    ForEach(tags, id: \.id) { tag in
                        let matches = owned.filter { card in
                            guard let id = card.catalogEntry?.tcgdexId else { return false }
                            return tag.linkedTcgdexIds.contains { $0.caseInsensitiveCompare(id) == .orderedSame }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(tag.name)
                                    .font(PV.headline())
                                Spacer()
                                Button("Zuordnen") { assigningTag = tag }
                                    .buttonStyle(.bordered)
                                    .tint(PV.primary)
                            }
                            cardList(matches, emptyText: "Diesem Thema ist noch keine Karte zugeordnet.")
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding()
        }
        .pvScreenBackground()
        .sheet(item: $assigningTag) { tag in
            NavigationStack {
                ThemeAssignSheet(tag: tag, owned: owned)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func themePanel(title: String, subtitle: String, cards: [OwnedCard]) -> some View {
        PVScreenPanel {
            Text(title)
                .font(PV.headline())
                .foregroundStyle(PV.readout)
            Text(subtitle)
                .font(PV.caption())
                .foregroundStyle(PV.onScreenMuted)
            Text("\(cards.count) passende Exemplare")
                .font(PV.monoCaption())
                .foregroundStyle(PV.statusOK)
            cardList(cards, emptyText: "Keine Karte in der Sammlung passt zu diesem Thema.")
        }
        .pvDexAppear()
    }

    @ViewBuilder
    private func cardList(_ cards: [OwnedCard], emptyText: String) -> some View {
        if cards.isEmpty {
            Text(emptyText)
                .font(PV.caption())
                .foregroundStyle(PV.onScreenMuted)
        } else {
            ForEach(cards, id: \.id) { card in
                NavigationLink {
                    OwnedCardDetailView(card: card)
                } label: {
                    HStack(spacing: 10) {
                        CachedCardImageView(
                            candidates: card.catalogEntry?.imageCandidatesLow ?? [],
                            title: card.catalogEntry?.displayName ?? "Karte",
                            size: CGSize(width: 36, height: 50)
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.catalogEntry?.displayName ?? "Unbekannte Karte")
                                .font(PV.body())
                                .foregroundStyle(PV.onScreen)
                            Text(cardSubtitle(card))
                                .font(PV.monoCaption())
                                .foregroundStyle(PV.onScreenMuted)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cardSubtitle(_ card: OwnedCard) -> String {
        let set = card.catalogEntry?.setName ?? "—"
        let number = card.catalogEntry?.number ?? "?"
        return "\(set) · #\(number)"
    }

    private func suggest(for token: String) -> [OwnedCard] {
        let lower = token.lowercased()
        return owned.filter { card in
            let name = card.catalogEntry?.displayName.lowercased() ?? ""
            let number = card.catalogEntry?.number.lowercased() ?? ""
            let types = (card.catalogEntry?.types ?? []).joined(separator: " ").lowercased()
            let set = card.catalogEntry?.setId.lowercased() ?? ""
            switch lower {
            case "evoli":
                let eevee = ["evoli", "eevee", "nachtara", "umbreon", "aquana", "vaporeon", "flamara", "flareon", "blitza", "jolteon", "psiana", "espeon", "glaziola", "glaceon", "folipurba", "leafeon", "feelinara", "sylveon"]
                return eevee.contains { name.contains($0) }
            case "tg":
                return number.lowercased().hasPrefix("tg") || set.hasSuffix("tg")
            case "v":
                return name.contains(" v") || name.hasSuffix("v") || name.contains("vmax") || name.contains("vstar")
            case "fire":
                return types.contains("fire") || types.contains("feuer")
            default:
                return name.contains(lower) || number.contains(lower) || types.contains(lower)
            }
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(ThemeTag(name: trimmed))
        try? modelContext.save()
        newTag = ""
    }
}

private struct ThemeAssignSheet: View {
    @Bindable var tag: ThemeTag
    let owned: [OwnedCard]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            if owned.isEmpty {
                Text("Noch keine Karten in der Sammlung.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(owned, id: \.id) { card in
                    let id = card.catalogEntry?.tcgdexId ?? ""
                    Button {
                        toggle(id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.catalogEntry?.displayName ?? "Unbekannte Karte")
                                Text(id)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isLinked(id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(PV.primary)
                            }
                        }
                    }
                    .disabled(id.isEmpty)
                }
            }
        }
        .navigationTitle(tag.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") {
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }

    private func isLinked(_ id: String) -> Bool {
        tag.linkedTcgdexIds.contains { $0.caseInsensitiveCompare(id) == .orderedSame }
    }

    private func toggle(_ id: String) {
        guard !id.isEmpty else { return }
        var ids = tag.linkedTcgdexIds
        if let index = ids.firstIndex(where: { $0.caseInsensitiveCompare(id) == .orderedSame }) {
            ids.remove(at: index)
        } else {
            ids.append(id)
        }
        tag.linkedTcgdexIds = ids
    }
}
