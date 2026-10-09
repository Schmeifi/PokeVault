import SwiftUI
import SwiftData

struct CollectionsListView: View {
    @Query(sort: \UserCollection.updatedAt, order: .reverse) private var collections: [UserCollection]
    @State private var showCreate = false
    @State private var newName = ""
    @State private var showSettings = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if collections.isEmpty {
                    ContentUnavailableView(
                        "Keine Sammlungen",
                        systemImage: "folder",
                        description: Text("Lege eine Sammlung an, um Exemplare zu gruppieren.")
                    )
                    .foregroundStyle(PV.onScreen)
                } else {
                    List(collections, id: \.id) { collection in
                        NavigationLink {
                            CollectionDetailView(collection: collection)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(collection.name)
                                    .font(PV.headline())
                                    .foregroundStyle(PV.onScreen)
                                Text(collection.collectionDescription ?? (collection.isSmart ? "Smarte Sammlung" : "Manuelle Sammlung"))
                                    .font(PV.caption())
                                    .foregroundStyle(PV.onScreenMuted)
                                Text("\(collection.memberships.count) Einträge")
                                    .font(PV.monoCaption())
                                    .foregroundStyle(PV.readout)
                            }
                            .padding(.vertical, 4)
                        }
                        .pvListRowStyle()
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .pvScreenBackground()
            .navigationTitle("Sammlungen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(PV.primary)
                    }
                    .accessibilityLabel("Einstellungen")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(PV.primary)
                    }
                    .accessibilityLabel("Sammlung anlegen")
                }
            }
            .alert("Neue Sammlung", isPresented: $showCreate) {
                TextField("Name", text: $newName)
                Button("Abbrechen", role: .cancel) {
                    newName = ""
                }
                Button("Anlegen") {
                    createCollection()
                }
            } message: {
                Text("Name der Sammlung eingeben.")
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
                .pvThemedSheet()
            }
        }
    }

    private func createCollection() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let collection = UserCollection(name: trimmed)
        modelContext.insert(collection)
        try? modelContext.save()
        newName = ""
    }
}

struct CollectionDetailView: View {
    @Bindable var collection: UserCollection
    @Query(sort: \OwnedCard.updatedAt, order: .reverse) private var allOwned: [OwnedCard]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddPicker = false

    private var memberCards: [OwnedCard] {
        collection.memberships.compactMap(\.ownedCard)
    }

    private var availableToAdd: [OwnedCard] {
        let memberIds = Set(memberCards.map(\.id))
        return allOwned.filter { !memberIds.contains($0.id) }
    }

    var body: some View {
        List {
            if let description = collection.collectionDescription, !description.isEmpty {
                Section {
                    Text(description)
                        .foregroundStyle(PV.onScreenMuted)
                }
                .listRowBackground(PV.listRow)
            }

            Section("Karten (\(memberCards.count))") {
                if memberCards.isEmpty {
                    Text("Noch keine Karten — tippe +, um Exemplare hinzuzufügen.")
                        .foregroundStyle(PV.onScreenMuted)
                } else {
                    ForEach(memberCards, id: \.id) { card in
                        NavigationLink {
                            OwnedCardDetailView(card: card)
                        } label: {
                            OwnedCardRow(card: card)
                        }
                        .pvListRowStyle()
                    }
                    .onDelete(perform: removeMembers)
                }
            }
            .listRowBackground(PV.listRow)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .pvScreenBackground()
        .navigationTitle(collection.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddPicker = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(PV.primary)
                }
                .accessibilityLabel("Karten hinzufügen")
                .disabled(availableToAdd.isEmpty && allOwned.isEmpty)
            }
        }
        .sheet(isPresented: $showAddPicker) {
            NavigationStack {
                AddCardsToCollectionView(
                    collection: collection,
                    candidates: availableToAdd
                )
            }
            .pvThemedSheet()
        }
    }

    private func removeMembers(at offsets: IndexSet) {
        let cards = memberCards
        for index in offsets {
            guard cards.indices.contains(index) else { continue }
            CollectionMembershipService.remove(cards[index], from: collection, in: modelContext)
        }
        try? modelContext.save()
    }
}

/// Auswahl bestehender Exemplare für eine manuelle Sammlung.
struct AddCardsToCollectionView: View {
    @Bindable var collection: UserCollection
    let candidates: [OwnedCard]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []

    var body: some View {
        Group {
            if candidates.isEmpty {
                ContentUnavailableView(
                    "Keine weiteren Karten",
                    systemImage: "rectangle.stack",
                    description: Text(
                        collection.memberships.isEmpty
                            ? "Lege zuerst Exemplare unter „Meine Karten“ oder „Entdecken“ an."
                            : "Alle Exemplare sind bereits in dieser Sammlung."
                    )
                )
            } else {
                List(candidates, id: \.id) { card in
                    Button {
                        if selected.contains(card.id) {
                            selected.remove(card.id)
                        } else {
                            selected.insert(card.id)
                        }
                    } label: {
                        HStack {
                            OwnedCardRow(card: card)
                            Spacer(minLength: 8)
                            Image(systemName: selected.contains(card.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(card.id) ? PV.statusOK : PV.onScreenMuted)
                        }
                    }
                    .buttonStyle(.plain)
                    .pvListRowStyle()
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .pvScreenBackground()
        .navigationTitle("Karten hinzufügen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Hinzufügen (\(selected.count))") {
                    addSelected()
                }
                .disabled(selected.isEmpty)
            }
        }
    }

    private func addSelected() {
        for card in candidates where selected.contains(card.id) {
            CollectionMembershipService.add(card, to: collection, in: modelContext)
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    CollectionsListView()
        .modelContainer(ModelContainerFactory.previewContainer())
}
