import SwiftUI
import SwiftData

/// Themen-Sammlungen: kuratiert + Typ-Vorschläge + manuelle Tags.
struct ThemeCollectionsView: View {
    @Query(sort: \ThemeTag.name) private var tags: [ThemeTag]
    @Query private var owned: [OwnedCard]
    @Environment(\.modelContext) private var modelContext
    @State private var newTag = ""

    private let curated: [(String, String, String)] = [
        ("Eeveelutions", "Nachtara, Evoli & Entwicklungen", "Darkness"),
        ("Trainer Gallery", "TG-Nummern & Galerie-Druckungen", "TG"),
        ("V / VMAX", "V- und VMAX-Kämpfer", "VMAX"),
        ("Feuer-Typen", "Fire-Energy-Karten in der Sammlung", "Fire")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PV.spaceL) {
                PVScreenPanel {
                    Text("Themen")
                        .font(PV.title())
                        .foregroundStyle(PV.onScreen)
                    Text("Kuratiert + Typ-Hinweise aus deinem Besitz. Unsichere Treffer sind gekennzeichnet.")
                        .font(PV.caption())
                        .foregroundStyle(PV.onScreenMuted)
                }

                ForEach(curated, id: \.0) { theme in
                    PVScreenPanel {
                        Text(theme.0)
                            .font(PV.headline())
                            .foregroundStyle(PV.readout)
                        Text(theme.1)
                            .font(PV.caption())
                            .foregroundStyle(PV.onScreenMuted)
                        let matches = suggest(for: theme.2)
                        Text("\(matches.count) passende Exemplare")
                            .font(PV.monoCaption())
                            .foregroundStyle(PV.statusOK)
                        if theme.2.count <= 3 {
                            Text("Hinweis: Text-/Nummern-Heuristik — unsicher ohne Scanner.")
                                .font(PV.caption())
                                .foregroundStyle(PV.statusWarn)
                        }
                    }
                    .pvDexAppear()
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
                    ForEach(tags, id: \.id) { tag in
                        Text(tag.name)
                            .font(PV.body())
                    }
                }
            }
            .padding()
        }
        .pvScreenBackground()
    }

    private func suggest(for token: String) -> [OwnedCard] {
        let lower = token.lowercased()
        return owned.filter { card in
            let name = card.catalogEntry?.displayName.lowercased() ?? ""
            let number = card.catalogEntry?.number.lowercased() ?? ""
            let types = (card.catalogEntry?.types ?? []).joined(separator: " ").lowercased()
            return name.contains(lower) || number.contains(lower) || types.contains(lower)
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
