import SwiftUI
import SwiftData

struct DiscoverView: View {
    @State private var viewModel = DiscoverViewModel()
    @State private var showSettings = false
    @Environment(\.modelContext) private var modelContext
    @State private var importMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kostenlose TCGdex-Suche (de/en). Kein API-Schlüssel nötig.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("Kartenname suchen…", text: $viewModel.query)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await viewModel.search() }
                            }
                        Button("Suchen") {
                            Task { await viewModel.search() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isLoading)
                    }
                    Picker("Sprache", selection: $viewModel.locale) {
                        Text("Deutsch").tag("de")
                        Text("Englisch").tag("en")
                    }
                    .pickerStyle(.segmented)
                }
                .padding()

                if viewModel.isLoading {
                    ProgressView("Suche bei TCGdex…")
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
                        description: Text("Versuche einen anderen Namen oder wechsle die Sprache.")
                    )
                } else if !viewModel.hasSearched {
                    ContentUnavailableView(
                        "Entdecken",
                        systemImage: "sparkle.magnifyingglass",
                        description: Text("Suche im kostenlosen TCGdex-Katalog und übernimm Karten in deine Sammlung.")
                    )
                } else {
                    List(viewModel.results) { card in
                        HStack(spacing: 12) {
                            CardThumbnailView(
                                imageURL: card.image.flatMap { raw in
                                    if raw.hasSuffix(".png") || raw.hasSuffix(".webp") || raw.hasSuffix(".jpg") {
                                        return URL(string: raw)
                                    }
                                    return URL(string: "\(raw)/high.webp")
                                },
                                title: card.name
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.name)
                                    .font(.headline)
                                Text(card.id)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Übernehmen") {
                                Task { await importCard(id: card.id) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
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
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }

    private func importCard(id: String) async {
        do {
            let detail = try await TCGdexProvider.shared.fetchCard(id: id, locale: viewModel.locale)
            let importer = CatalogImportService()
            let entry = try importer.upsertCatalogEntry(from: detail, locale: viewModel.locale, in: modelContext)
            if let price = try await TCGdexProvider.shared.fetchPrice(for: id, locale: viewModel.locale) {
                importer.storePriceSnapshot(for: entry, price: price, in: modelContext)
            }
            let owned = OwnedCard(
                catalogEntry: entry,
                quantity: 1,
                condition: .nearMint,
                language: CardLanguage(rawValue: viewModel.locale) ?? .de
            )
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
