import SwiftUI
import SwiftData

struct DiscoverView: View {
    @State private var viewModel = DiscoverViewModel()
    @State private var showSettings = false
    @State private var selectedSet: TCGdexSetSummary?
    @State private var previewDetail: TCGdexCardDetail?
    @State private var importMessage: String?
    @State private var isImporting = false
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
                }

                if let importMessage {
                    Text(importMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(8)
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
                    CatalogCardPreviewSheet(detail: detail, locale: viewModel.locale) { chosen in
                        Task { await importDetail(chosen) }
                        previewDetail = nil
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .onChange(of: viewModel.mode) { _, mode in
                if mode == .sets {
                    Task { await viewModel.loadSets() }
                }
            }
        }
    }

    private var searchPane: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Kostenlose TCGdex-Suche nach Name, Set-ID und Kartennummer (DE/EN).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("Pokémon-Name", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { Task { await viewModel.search() } }
                HStack {
                    TextField("Set-ID (z. B. swsh3)", text: $viewModel.setFilter)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Nr.", text: $viewModel.numberFilter)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 80)
                }
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
                    .disabled(viewModel.isLoading || isImporting)
                }
            }
            .padding()

            searchResults
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if viewModel.isLoading || isImporting {
            ProgressView(isImporting ? "Übernehme Karte…" : "Suche bei TCGdex…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView(
                "Suche fehlgeschlagen",
                systemImage: "wifi.exclamationmark",
                description: Text(errorMessage)
            )
        } else if viewModel.hasSearched && viewModel.results.isEmpty {
            ContentUnavailableView(
                "Keine Treffer",
                systemImage: "magnifyingglass",
                description: Text("Name, Set oder Nummer anpassen – oder Sprache wechseln.")
            )
        } else if !viewModel.hasSearched {
            ContentUnavailableView(
                "Entdecken",
                systemImage: "sparkle.magnifyingglass",
                description: Text("Suche im kostenlosen TCGdex-Katalog oder durchstöbere Sets.")
            )
        } else {
            List(viewModel.results) { card in
                CardSearchResultRow(card: card, actionTitle: "Öffnen") {
                    Task { await openCard(id: card.id) }
                }
            }
            .listStyle(.plain)
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
                .disabled(viewModel.isLoading)
            }
            .padding()

            if viewModel.isLoading {
                ProgressView("Sets werden geladen…")
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
