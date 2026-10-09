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
            TextField("Name oder Nummer (z. B. TG22)", text: $viewModel.query)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
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
        } else if viewModel.hasSearched && viewModel.hits.isEmpty {
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
            List(viewModel.hits) { hit in
                Button {
                    Task { await openDetail(id: hit.card.id) }
                } label: {
                    CardSearchResultRow(hit: hit, actionTitle: "")
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
                        candidates: detail.imageCandidatesHigh,
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
            .listRowBackground(PV.listRow)
            .foregroundStyle(PV.onScreen)
            Section("Druckvarianten") {
                let labels = detail.availableVariantLabels
                if labels.isEmpty {
                    Text("Keine Variantenangabe in der API")
                        .foregroundStyle(PV.onScreenMuted)
                } else {
                    ForEach(labels, id: \.self) { label in
                        Text(displayVariant(label))
                            .foregroundStyle(PV.onScreen)
                    }
                }
                Text(detail.printingSummary)
                    .font(PV.caption())
                    .foregroundStyle(PV.onScreenMuted)
            }
            .listRowBackground(PV.listRow)
            Section("Preis (TCGdex)") {
                if let line = Self.priceLines(from: detail.pricing?.cardmarket) {
                    ForEach(line, id: \.0) { row in
                        LabeledContent(row.0, value: row.1)
                    }
                    Text("Cardmarket-Referenz über TCGdex — nicht zustandsgenau. Fehlt EUR → „Kein Marktpreis verfügbar“.")
                        .font(PV.caption())
                        .foregroundStyle(PV.onScreenMuted)
                } else {
                    Text(PriceSource.unavailable.displayNameDE)
                        .foregroundStyle(PV.statusWarn)
                }
            }
            .listRowBackground(PV.listRow)
            .foregroundStyle(PV.onScreen)
        }
        .scrollContentBackground(.hidden)
        .pvScreenBackground()
        .navigationTitle("Vorschau")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Übernehmen") { onConfirm(detail) }
                    .foregroundStyle(PV.readout)
            }
        }
    }

    private func displayVariant(_ raw: String) -> String {
        CardVariant(rawValue: raw)?.displayNameDE ?? raw
    }

    static func priceLines(from cm: TCGdexCardmarketPricing?) -> [(String, String)]? {
        guard let cm else { return nil }
        let unit = (cm.unit ?? "EUR").uppercased()
        guard unit == "EUR" else {
            return [("Hinweis", "Preis in \(unit) – nicht als EUR übernommen")]
        }
        var rows: [(String, String)] = []
        if let trend = cm.trend { rows.append(("Trend", CurrencyFormat.euro(trend))) }
        if let avg = cm.avg { rows.append(("Ø", CurrencyFormat.euro(avg))) }
        if let low = cm.low { rows.append(("Low", CurrencyFormat.euro(low))) }
        if let avg7 = cm.avg7 { rows.append(("Ø7", CurrencyFormat.euro(avg7))) }
        if rows.isEmpty { return nil }
        if let updated = cm.updated {
            rows.append(("Stand", updated))
        }
        return rows
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
