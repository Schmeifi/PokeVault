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
                } else {
                    List(collections, id: \.id) { collection in
                        NavigationLink {
                            CollectionDetailView(collection: collection)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(collection.name)
                                    .font(.headline)
                                Text(collection.collectionDescription ?? (collection.isSmart ? "Smarte Sammlung" : "Manuelle Sammlung"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("\(collection.memberships.count) Einträge")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Sammlungen")
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
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
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

    var body: some View {
        List {
            if let description = collection.collectionDescription, !description.isEmpty {
                Section {
                    Text(description)
                }
            }

            Section("Karten") {
                if collection.memberships.isEmpty {
                    Text("Noch keine Karten in dieser Sammlung.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(collection.memberships, id: \.id) { membership in
                        if let card = membership.ownedCard {
                            OwnedCardRow(card: card)
                        }
                    }
                }
            }
        }
        .navigationTitle(collection.name)
    }
}

#Preview {
    CollectionsListView()
        .modelContainer(ModelContainerFactory.previewContainer())
}
