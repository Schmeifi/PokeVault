import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \OwnedCard.updatedAt, order: .reverse) private var ownedCards: [OwnedCard]
    @State private var viewModel = DashboardViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.stats.usesSampleData {
                        SampleDataBanner()
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatTile(title: "Exemplare", value: "\(viewModel.stats.totalOwnedCards)")
                        StatTile(title: "Kartenarten", value: "\(viewModel.stats.uniqueCatalogCards)")
                        StatTile(
                            title: "Aktueller Wert",
                            value: CurrencyFormat.euroOrDash(viewModel.stats.currentPortfolioValueEUR),
                            footnote: "Nur bewertete Karten"
                        )
                        StatTile(
                            title: "Ohne aktuellen Wert",
                            value: "\(viewModel.stats.cardsWithoutPrice)"
                        )
                    }

                    portfolioSection

                    if let chartData = portfolioChartPoints, chartData.count == 2 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Portfolio-Überblick")
                                .font(.headline)
                            Text("Nur Karten mit Kaufpreis und aktuellem Wert – keine erfundenen Historien.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Chart(chartData) { point in
                                BarMark(
                                    x: .value("Art", point.label),
                                    y: .value("Euro", point.value)
                                )
                                .foregroundStyle(point.label == "Kauf" ? Color.secondary : Color.accentColor)
                            }
                            .chartLegend(.hidden)
                            .frame(height: 180)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wertquellen")
                            .font(.headline)
                        Text(viewModel.stats.valueSourceSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            sourceChip("Markt", count: viewModel.stats.marketValuedCards, color: .green)
                            sourceChip("Manuell", count: viewModel.stats.manuallyValuedCards, color: .blue)
                            sourceChip("Fehlend", count: viewModel.stats.cardsWithoutPrice, color: .secondary)
                        }
                        Text("Es werden keine Marktpreise erfunden. Fehlende Preise bleiben leer und zählen nicht zum aktuellen Gesamtwert.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if ownedCards.isEmpty {
                        ContentUnavailableView(
                            "Noch keine Karten",
                            systemImage: "rectangle.stack",
                            description: Text("Füge unter „Meine Karten“ deine ersten Exemplare hinzu.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                    } else {
                        Text("Zuletzt aktualisiert")
                            .font(.headline)
                        ForEach(ownedCards.prefix(5), id: \.id) { card in
                            NavigationLink {
                                OwnedCardDetailView(card: card)
                            } label: {
                                OwnedCardRow(card: card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
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
            .onAppear { viewModel.refresh(owned: ownedCards) }
            .onChange(of: ownedCards.count) { _, _ in
                viewModel.refresh(owned: ownedCards)
            }
        }
    }

    private var portfolioSection: some View {
        let stats = viewModel.stats
        return VStack(alignment: .leading, spacing: 10) {
            Text("Portfolio / GuV")
                .font(.headline)
            LabeledContent("Gesamtkaufwert") {
                Text(CurrencyFormat.euroOrDash(stats.totalPurchaseCostEUR))
            }
            if stats.cardsWithoutPurchasePrice > 0 {
                Text("\(stats.cardsWithoutPurchasePrice) Exemplare ohne Kaufpreis – nicht in der Kaufsumme.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Aktueller Gesamtwert") {
                Text(CurrencyFormat.euroOrDash(stats.currentPortfolioValueEUR))
            }
            LabeledContent("Unrealisierter GuV") {
                Text(gainLossText(stats))
                    .foregroundStyle(gainLossColor(stats.unrealizedGainLossEUR))
            }
            Text("GuV nur über \(stats.cardsInPnL) Exemplare mit Kaufpreis und aktuellem Wert.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Balken nur aus GuV-fähigen Karten (Kaufpreis + aktueller Wert), keine Zeitreihe.
    private var portfolioChartPoints: [PortfolioChartPoint]? {
        let lines = ownedCards.map { $0.portfolioLine() }.filter { $0.hasPurchase && $0.hasCurrent }
        guard !lines.isEmpty else { return nil }
        let purchase = lines.compactMap(\.purchaseTotal).reduce(0, +)
        let current = lines.compactMap(\.currentTotal).reduce(0, +)
        return [
            PortfolioChartPoint(label: "Kauf", value: purchase),
            PortfolioChartPoint(label: "Aktuell", value: current)
        ]
    }

    private func gainLossText(_ stats: CollectionStats) -> String {
        guard let gain = stats.unrealizedGainLossEUR else { return "—" }
        let pct = stats.unrealizedGainLossPercent.map { " (\(CurrencyFormat.percent($0)))" } ?? ""
        return "\(CurrencyFormat.signedEuro(gain))\(pct)"
    }

    private func gainLossColor(_ value: Double?) -> Color {
        guard let value else { return .primary }
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .primary
    }

    private func sourceChip(_ title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PortfolioChartPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

private struct StatTile: View {
    let title: String
    let value: String
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    DashboardView()
        .modelContainer(ModelContainerFactory.previewContainer())
}
