import SwiftUI
import SwiftData

struct WishlistView: View {
    @Query(sort: \WishlistEntry.priority, order: .forward) private var entries: [WishlistEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var message: String?

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Wunschliste leer",
                    systemImage: "star",
                    description: Text("Füge Karten aus dem Katalog hinzu.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(entries, id: \.id) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.catalogEntry?.displayName ?? "Karte")
                            .font(PV.headline())
                            .foregroundStyle(PV.onScreen)
                        Text("Prio \(entry.priority) · \(entry.desiredCondition.displayNameDE) · \(entry.desiredLanguage.displayNameDE)")
                            .font(PV.caption())
                            .foregroundStyle(PV.onScreenMuted)
                        if let target = entry.targetPriceEUR ?? entry.maxPriceEUR {
                            Text("Zielpreis: \(CurrencyFormat.euro(target))")
                                .font(PV.monoCaption())
                                .foregroundStyle(PV.readout)
                        }
                        HStack {
                            Button("Gekauft → Sammlung") {
                                markBought(entry)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(PV.statusOK)
                            .disabled(entry.isBought)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(PV.screenElevated)
                }
                .onDelete(perform: delete)
            }
        }
        .scrollContentBackground(.hidden)
        .pvScreenBackground()
        .navigationTitle("Wunschliste")
        .safeAreaInset(edge: .bottom) {
            if let message {
                Text(message)
                    .font(PV.caption())
                    .foregroundStyle(PV.onPrimaryContainer)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(PV.primaryContainer.opacity(0.35))
            }
        }
    }

    private func markBought(_ entry: WishlistEntry) {
        guard let catalog = entry.catalogEntry else { return }
        let owned = OwnedCard(
            catalogEntry: catalog,
            quantity: 1,
            condition: entry.desiredCondition,
            language: entry.desiredLanguage,
            purchasePrice: entry.targetPriceEUR ?? entry.maxPriceEUR
        )
        modelContext.insert(owned)
        entry.isBought = true
        entry.updatedAt = .now
        modelContext.delete(entry)
        try? modelContext.save()
        message = "„\(catalog.displayName)“ in die Sammlung übernommen."
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
        try? modelContext.save()
    }
}
