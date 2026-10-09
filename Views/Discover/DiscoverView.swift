import SwiftUI
import SwiftData

struct DiscoverView: View {
    @State private var viewModel = DiscoverViewModel()
    @State private var showSettings = false
    @State private var selectedSet: TCGdexSetSummary?
    @State private var previewDetail: TCGdexCardDetail?
    @State private var importMessage: String?
    @State private var isImporting = false
    @State private var wishlistCatalog: CardCatalogEntry?
    @State private var pendingWishlistDetail: TCGdexCardDetail?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Modus", selection: $viewModel.mode) {
                    ForEach(DiscoverMode.allCases) { mode in
                        Text(mode.titleDE).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                switch viewModel.mode {
                case .search:
                    searchPane
                case .sets:
                    setsPane
                case .categories:
                    CategoryBrowseView(viewModel: viewModel)
                case .themes:
                    ThemeCollectionsView()
                }

                if let importMessage {
                    Text(importMessage)
                        .font(PV.caption())
                        .foregroundStyle(PV.onScreenMuted)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(PV.surfaceContainerLow)
                }
            }
            .navigationTitle("Entdecken")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Einstellungen")
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            .navigationDestination(item: $selectedSet) { set in
                SetDetailView(setId: set.id, locale: viewModel.locale)
            }
            .sheet(item: $previewDetail) { detail in
                NavigationStack {
                    CatalogCardPreviewSheet(
                        detail: detail,
                        locale: viewModel.locale,
                        onConfirm: { chosen in
                            Task { await importDetail(chosen) }
                            previewDetail = nil
                        },
                        onAddToWishlist: { chosen in
                            pendingWishlistDetail = chosen
                            previewDetail = nil
                        }
                    )
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $wishlistCatalog) { entry in
                NavigationStack {
                    WishlistPickerSheet(catalogEntry: entry) { listName in
                        importMessage = "Zur Wunschliste „\(listName)“ hinzugefügt."
                    }
                }
                .presentationDetents([.medium])
            }
            .onChange(of: viewModel.mode) { _, mode in
                if mode == .sets {
                    Task { await viewModel.loadSets() }
                }
            }
            .task(id: pendingWishlistDetail?.id) {
                guard let detail = pendingWishlistDetail else { return }
                await prepareWishlist(from: detail)
                pendingWishlistDetail = nil
            }
        }
    }

    private var searchPane: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Name oder Kartennummer (z. B. TG22). Filter: Set, Seltenheit, Pokémon. Nur TCGdex.")
                    .font(PV.caption())
                    .foregroundStyle(PV.onScreenMuted)

                TextField("Name oder Nummer", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await viewModel.search() } }

                categoryChips

                DisclosureGroup(isExpanded: $viewModel.showFilters) {
                    filterFields
                } label: {
                    HStack {
                        Text("Filter")
                            .font(PV.headline())
                            .foregroundStyle(PV.onScreen)
                        if viewModel.activeFilterCount > 0 {
                            Text("\(viewModel.activeFilterCount)")
                                .font(PV.caption())
                                .fontWeight(.semibold)
                                .foregroundStyle(PV.onPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(PV.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .tint(PV.primary)

                HStack {
                    Picker("Sprache", selection: $viewModel.locale) {
                        Text("Deutsch").tag("de")
                        Text("Englisch").tag("en")
                    }
                    .pickerStyle(.segmented)
                    Toggle("DE+EN", isOn: $viewModel.bilingual)
                    Button("Suchen") {
                        Task { await viewModel.search() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PV.primary)
                    .disabled(viewModel.isLoading || isImporting)
                }
            }
            .padding()
            .background(PV.surface)

            searchResults
        }
        .task {
            await viewModel.loadRaritiesIfNeeded()
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Alle", selected: viewModel.selectedCategory == nil) {
                    viewModel.applyCategory(nil)
                }
                ForEach(DiscoverCategory.allCases) { category in
                    chip(category.shortTitleDE, selected: viewModel.selectedCategory == category) {
                        viewModel.applyCategory(category)
                        Task { await viewModel.search() }
                    }
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PV.caption())
                .fontWeight(.semibold)
                .foregroundStyle(selected ? PV.onPrimary : PV.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? PV.primary : PV.primaryContainer.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var filterFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Pokémon / Name", text: $viewModel.pokemonNameFilter)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            TextField("Set-ID (z. B. swsh9tg)", text: $viewModel.setFilter)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            HStack {
                TextField("Nr. (TG22)", text: $viewModel.numberFilter)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                if viewModel.availableRarities.isEmpty {
                    TextField("Seltenheit", text: $viewModel.rarityFilter)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Picker("Seltenheit", selection: $viewModel.rarityFilter) {
                        Text("Alle").tag("")
                        ForEach(viewModel.availableRarities, id: \.self) { rarity in
                            Text(rarity).tag(rarity)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(PV.primary)
                }
            }
            HStack {
                Button("Filter zurücksetzen") {
                    viewModel.clearFilters()
                }
                .font(PV.caption())
                Spacer()
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var searchResults: some View {
        if viewModel.isLoading || isImporting {
            ProgressView(isImporting ? "Übernehme Karte…" : "Suche bei TCGdex…")
                .tint(PV.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView(
                "Suche fehlgeschlagen",
                systemImage: "wifi.exclamationmark",
                description: Text(errorMessage)
            )
        } else if viewModel.hasSearched && viewModel.hits.isEmpty {
            ContentUnavailableView(
                "Keine Treffer",
                systemImage: "magnifyingglass",
                description: Text("Nummer wie TG22, Set-ID, Seltenheit oder Name anpassen.")
            )
        } else if !viewModel.hasSearched {
            ContentUnavailableView(
                "Entdecken",
                systemImage: "sparkle.magnifyingglass",
                description: Text("Beispiel: „TG22“ oder Filter „IR“ für Illustration Rares.")
            )
        } else {
            List(viewModel.hits) { hit in
                VStack(alignment: .leading, spacing: 8) {
                    CardSearchResultRow(hit: hit, actionTitle: "Öffnen") {
                        Task { await openCard(id: hit.card.id) }
                    }
                    HStack {
                        Button("Wunschliste") {
                            Task { await addHitToWishlist(hit) }
                        }
                        .buttonStyle(.bordered)
                        .tint(PV.primary)
                        .font(PV.caption())
                        Spacer()
                    }
                }
                .listRowBackground(PV.listRow)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var setsPane: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Set suchen…", text: $viewModel.setQuery)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { Task { await viewModel.loadSets(force: true) } }
                Button("Laden") {
                    Task { await viewModel.loadSets(force: true) }
                }
                .buttonStyle(.borderedProminent)
                .tint(PV.primary)
                .disabled(viewModel.isLoading)
            }
            .padding()

            if viewModel.isLoading {
                ProgressView("Sets werden geladen…")
                    .tint(PV.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Sets nicht ladbar",
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
            } else if viewModel.sets.isEmpty {
                ContentUnavailableView(
                    "Keine Sets",
                    systemImage: "square.stack.3d.up",
                    description: Text("Tippe auf Laden oder suche nach einem Setnamen.")
                )
            } else {
                SetListView(sets: viewModel.sets, locale: viewModel.locale) { set in
                    selectedSet = set
                }
            }
        }
        .task {
            await viewModel.loadSets()
        }
    }

    private func openCard(id: String) async {
        do {
            previewDetail = try await TCGdexProvider.shared.fetchCard(id: id, locale: viewModel.locale)
        } catch {
            do {
                let fallback = viewModel.locale == "de" ? "en" : "de"
                previewDetail = try await TCGdexProvider.shared.fetchCard(id: id, locale: fallback)
            } catch {
                importMessage = error.localizedDescription
            }
        }
    }

    private func addHitToWishlist(_ hit: CardSearchHit) async {
        do {
            let detail = try await TCGdexProvider.shared.fetchCard(id: hit.card.id, locale: viewModel.locale)
            await prepareWishlist(from: detail)
        } catch {
            do {
                let fallback = viewModel.locale == "de" ? "en" : "de"
                let detail = try await TCGdexProvider.shared.fetchCard(id: hit.card.id, locale: fallback)
                await prepareWishlist(from: detail)
            } catch {
                importMessage = error.localizedDescription
            }
        }
    }

    private func prepareWishlist(from detail: TCGdexCardDetail) async {
        do {
            let importer = CatalogImportService()
            let entry = try importer.upsertCatalogEntry(
                from: detail,
                locale: viewModel.locale,
                in: modelContext
            )
            if let price = try await TCGdexProvider.shared.fetchPrice(for: detail.id, locale: viewModel.locale) {
                importer.storePriceSnapshot(for: entry, price: price, in: modelContext)
            }
            try modelContext.save()
            wishlistCatalog = entry
        } catch {
            importMessage = "Wunschliste: \(error.localizedDescription)"
        }
    }

    private func importDetail(_ detail: TCGdexCardDetail) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let importer = CatalogImportService()
            let entry = try importer.upsertCatalogEntry(
                from: detail,
                locale: viewModel.locale,
                in: modelContext
            )
            if let price = try await TCGdexProvider.shared.fetchPrice(for: detail.id, locale: viewModel.locale) {
                importer.storePriceSnapshot(for: entry, price: price, in: modelContext)
            }
            let owned = OwnedCard(
                catalogEntry: entry,
                quantity: 1,
                condition: .nearMint,
                language: CardLanguage(rawValue: viewModel.locale) ?? .de
            )
            if let first = entry.availableVariants.first,
               let variant = CardVariant(rawValue: first) {
                owned.variant = variant
            }
            modelContext.insert(owned)
            try modelContext.save()
            importMessage = "„\(entry.displayName)“ zur Sammlung hinzugefügt."
        } catch {
            importMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}

#Preview {
    DiscoverView()
        .modelContainer(ModelContainerFactory.previewContainer())
}
