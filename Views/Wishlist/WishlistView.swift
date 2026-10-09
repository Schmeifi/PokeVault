import SwiftUI
import SwiftData

struct WishlistView: View {
    @Query(sort: \Wishlist.createdAt, order: .forward) private var lists: [Wishlist]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedListID: UUID?
    @State private var message: String?
    @State private var showCreate = false
    @State private var showRename = false
    @State private var draftName = ""

    private var selectedList: Wishlist? {
        if let selectedListID {
            return lists.first { $0.id == selectedListID } ?? lists.first
        }
        return lists.first
    }

    var body: some View {
        List {
            Section {
                if lists.isEmpty {
                    Text("Noch keine Wunschlisten.")
                        .font(PV.caption())
                        .foregroundStyle(PV.onScreenMuted)
                } else {
                    ForEach(lists, id: \.id) { list in
                        Button {
                            selectedListID = list.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(list.name)
                                        .font(PV.headline())
                                        .foregroundStyle(PV.onScreen)
                                    Text("\(list.activeCount) Karten")
                                        .font(PV.caption())
                                        .foregroundStyle(PV.onScreenMuted)
                                }
                                Spacer()
                                if list.id == selectedList?.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(PV.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(PV.screenElevated)
                    }
                    .onDelete(perform: deleteLists)
                }
            } header: {
                Text("Listen")
            }

            if let list = selectedList {
                Section {
                    let entries = list.entries
                        .filter { !$0.isBought }
                        .sorted { $0.priority < $1.priority }
                    if entries.isEmpty {
                        ContentUnavailableView(
                            "Liste leer",
                            systemImage: "star",
                            description: Text("Füge Karten aus Entdecken hinzu.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(entries, id: \.id) { entry in
                            entryRow(entry)
                                .listRowBackground(PV.screenElevated)
                        }
                        .onDelete { offsets in
                            deleteEntries(entries, at: offsets)
                        }
                    }
                } header: {
                    Text("\(list.name) · \(list.activeCount)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .pvScreenBackground()
        .navigationTitle("Wunschlisten")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Neue Liste") {
                        draftName = ""
                        showCreate = true
                    }
                    if selectedList != nil {
                        Button("Umbenennen") {
                            draftName = selectedList?.name ?? ""
                            showRename = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Listen verwalten")
            }
        }
        .alert("Neue Wunschliste", isPresented: $showCreate) {
            TextField("Name", text: $draftName)
            Button("Anlegen") {
                let list = WishlistService.create(named: draftName, in: modelContext)
                selectedListID = list.id
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .alert("Liste umbenennen", isPresented: $showRename) {
            TextField("Name", text: $draftName)
            Button("Speichern") {
                if let list = selectedList {
                    WishlistService.rename(list, to: draftName, in: modelContext)
                }
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .safeAreaInset(edge: .bottom) {
            if let message {
                Text(message)
                    .font(PV.caption())
                    .foregroundStyle(PV.onPrimary)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(PV.primary)
            }
        }
        .onAppear {
            WishlistService.ensureDefaultWishlist(in: modelContext)
            if selectedListID == nil {
                selectedListID = lists.first?.id
            }
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: WishlistEntry) -> some View {
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
                .tint(PV.primary)
                .disabled(entry.isBought)
            }
        }
        .padding(.vertical, 4)
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

    private func deleteEntries(_ entries: [WishlistEntry], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
        try? modelContext.save()
    }

    private func deleteLists(at offsets: IndexSet) {
        for index in offsets {
            WishlistService.delete(lists[index], in: modelContext)
        }
        selectedListID = lists.first?.id
    }
}

/// Sheet: Wunschliste wählen und Karte hinzufügen.
struct WishlistPickerSheet: View {
    let catalogEntry: CardCatalogEntry
    var desiredCondition: CardCondition = .nearMint
    var desiredLanguage: CardLanguage = .de
    var targetPriceEUR: Double? = nil
    var onDone: ((String) -> Void)?

    @Query(sort: \Wishlist.createdAt) private var lists: [Wishlist]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showCreate = false
    @State private var draftName = ""

    var body: some View {
        List {
            Section {
                Text(catalogEntry.displayName)
                    .font(PV.headline())
                    .foregroundStyle(PV.onScreen)
                Text("\(catalogEntry.setName) · #\(catalogEntry.number)")
                    .font(PV.caption())
                    .foregroundStyle(PV.onScreenMuted)
            }
            .listRowBackground(PV.listRow)

            Section("Wunschliste wählen") {
                ForEach(lists, id: \.id) { list in
                    Button {
                        WishlistService.add(
                            catalogEntry: catalogEntry,
                            to: list,
                            desiredCondition: desiredCondition,
                            desiredLanguage: desiredLanguage,
                            targetPriceEUR: targetPriceEUR,
                            in: modelContext
                        )
                        onDone?(list.name)
                        dismiss()
                    } label: {
                        HStack {
                            Text(list.name)
                                .foregroundStyle(PV.onScreen)
                            Spacer()
                            Text("\(list.activeCount)")
                                .font(PV.caption())
                                .foregroundStyle(PV.onScreenMuted)
                        }
                    }
                    .listRowBackground(PV.listRow)
                }
            }

            Section {
                Button("Neue Liste…") {
                    draftName = ""
                    showCreate = true
                }
                .foregroundStyle(PV.readout)
            }
            .listRowBackground(PV.listRow)
        }
        .scrollContentBackground(.hidden)
        .pvScreenBackground()
        .navigationTitle("Zur Wunschliste")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schließen") { dismiss() }
            }
        }
        .alert("Neue Wunschliste", isPresented: $showCreate) {
            TextField("Name", text: $draftName)
            Button("Anlegen") {
                let list = WishlistService.create(named: draftName, in: modelContext)
                WishlistService.add(
                    catalogEntry: catalogEntry,
                    to: list,
                    desiredCondition: desiredCondition,
                    desiredLanguage: desiredLanguage,
                    targetPriceEUR: targetPriceEUR,
                    in: modelContext
                )
                onDone?(list.name)
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .onAppear {
            WishlistService.ensureDefaultWishlist(in: modelContext)
        }
    }
}
