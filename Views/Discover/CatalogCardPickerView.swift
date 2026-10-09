import SwiftUI
import SwiftData

/// Katalogsuche zur Übernahme in den „Karte hinzufügen“-Flow.
struct CatalogCardPickerView: View {
    var onSelect: (TCGdexCardDetail, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = DiscoverViewModel()
    @State private var selectedDetail: TCGdexCardDetail?
    @State private var detailError: String?
    @State private var isLoadingDetail = false

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            resultsList
        }
        .navigationTitle("Katalog suchen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schließen") { dismiss() }
            }
        }
        .sheet(item: $selectedDetail) { detail in
            NavigationStack {
                CatalogCardPreviewSheet(
                    detail: detail,
                    locale: viewModel.locale,
                    onConfirm: { chosen in
                        onSelect(chosen, viewModel.locale)
                        selectedDetail = nil
                        dismiss()
                    }
                )
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    .frame(width: 72)
                    .keyboardType(.numbersAndPunctuation)
            }
            HStack {
                Picker("Sprache", selection: $viewModel.locale) {
                    Text("DE").tag("de")
                    Text("EN").tag("en")
                }
                .pickerStyle(.segmented)
                Toggle("DE+EN", isOn: $viewModel.bilingual)
                    .labelsHidden()
                    .accessibilityLabel("Zweisprachig suchen")
                Button("Suchen") {
                    Task { await viewModel.search() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var resultsList: some View {
        if viewModel.isLoading || isLoadingDetail {
            ProgressView("Lade…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage ?? detailError {
            ContentUnavailableView(
                "Suche fehlgeschlagen",
                systemImage: "wifi.exclamationmark",
                description: Text(errorMessage)
            )
        } else if viewModel.hasSearched && viewModel.results.isEmpty {
            ContentUnavailableView(
                "Keine Treffer",
                systemImage: "magnifyingglass",
                description: Text("Name, Set-ID oder Kartennummer anpassen.")
            )
        } else if !viewModel.hasSearched {
            ContentUnavailableView(
                "Katalog",
                systemImage: "rectangle.stack.badge.plus",
                description: Text("Suche eine Druckvariante und übernimm Metadaten inkl. Vorschau.")
            )
        } else {
            List(viewModel.results) { card in
                Button {
                    Task { await openDetail(id: card.id) }
                } label: {
                    CardSearchResultRow(card: card, actionTitle: "")
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private func openDetail(id: String) async {
        isLoadingDetail = true
        detailError = nil
        defer { isLoadingDetail = false }
        do {
            selectedDetail = try await TCGdexProvider.shared.fetchCard(id: id, locale: viewModel.locale)
        } catch {
            // Fallback EN
            do {
                let fallback = viewModel.locale == "de" ? "en" : "de"
                selectedDetail = try await TCGdexProvider.shared.fetchCard(id: id, locale: fallback)
            } catch {
                detailError = error.localizedDescription
            }
        }
    }
}

struct CatalogCardPreviewSheet: View {
    let detail: TCGdexCardDetail
    let locale: String
    var onConfirm: (TCGdexCardDetail) -> Void

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    CachedCardImageView(
                        imageURL: detail.imageURLHigh,
                        title: detail.name,
                        size: CGSize(width: 140, height: 196)
                    )
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            Section("Metadaten") {
                LabeledContent("Name", value: detail.name)
                LabeledContent("Set", value: detail.set?.name ?? "—")
                LabeledContent("Nummer", value: detail.localId ?? "—")
                LabeledContent("Seltenheit", value: detail.rarity ?? "—")
                LabeledContent("Illustrator", value: detail.illustrator ?? "—")
                LabeledContent("Typen", value: (detail.types ?? []).joined(separator: ", ").nilIfEmpty ?? "—")
                LabeledContent("TCGdex-ID", value: detail.id)
            }
            Section("Druckvarianten") {
                let labels = detail.availableVariantLabels
                if labels.isEmpty {
                    Text("Keine Variantenangabe in der API")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(labels, id: \.self) { label in
                        Text(displayVariant(label))
                    }
                }
                Text(detail.printingSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if detail.pricing?.cardmarket != nil {
                Section("Preis (TCGdex)") {
                    Text("Cardmarket-Referenz vorhanden — wird beim Übernehmen als Snapshot gespeichert, falls EUR.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Vorschau")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Übernehmen") { onConfirm(detail) }
            }
        }
    }

    private func displayVariant(_ raw: String) -> String {
        CardVariant(rawValue: raw)?.displayNameDE ?? raw
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
