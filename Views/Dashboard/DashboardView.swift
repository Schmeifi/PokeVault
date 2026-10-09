import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \OwnedCard.updatedAt, order: .reverse) private var ownedCards: [OwnedCard]
    @State private var viewModel = DashboardViewModel()
    @State private var showSettings = false
    @State private var showWishlist = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PV.spaceL) {
                    PVBrandHeader(subtitle: "Deine Sammlung · lokaler Pokédex")

                    if viewModel.stats.usesSampleData {
                        SampleDataBanner()
                    }

                    PVScreenPanel {
                        Text("Portfolio")
                            .font(PV.headline())
                            .foregroundStyle(PV.readout)
                        readoutRow("Exemplare", "\(viewModel.stats.totalOwnedCards)")
                        readoutRow("Kaufwert", CurrencyFormat.euroOrDash(viewModel.stats.totalPurchaseCostEUR))
                        readoutRow("Aktuell", CurrencyFormat.euroOrDash(viewModel.stats.currentPortfolioValueEUR))
                        HStack {
                            Text("GuV")
                                .font(PV.caption())
                                .foregroundStyle(PV.onScreenMuted)
                            Spacer()
                            Text(gainLossText(viewModel.stats))
                                .font(PV.readout(.title3))
                                .foregroundStyle(gainLossColor(viewModel.stats.unrealizedGainLossEUR))
                                .contentTransition(.numericText())
                        }
                        Text("Ohne Preis: \(viewModel.stats.cardsWithoutPrice) · Markt \(viewModel.stats.marketValuedCards) · Manuell \(viewModel.stats.manuallyValuedCards)")
                            .font(PV.caption())
                            .foregroundStyle(PV.onScreenMuted)
                    }
                    .pvDexAppear()

                    if let chart = portfolioChartPoints, chart.count == 2 {
                        PVScreenPanel {
                            Text("Kauf vs. Aktuell")
                                .font(PV.headline())
                                .foregroundStyle(PV.onScreen)
                            Text("Nur echte GuV-fähige Exemplare — keine Fake-Historie.")
                                .font(PV.caption())
                                .foregroundStyle(PV.onScreenMuted)
                            Chart(chart) { point in
                                BarMark(
                                    x: .value("Art", point.label),
                                    y: .value("Euro", point.value)
                                )
                                .foregroundStyle(point.label == "Kauf" ? PV.onScreenMuted : PV.readout)
                            }
                            .frame(height: 140)
                        }
                    }

                    if !ownedCards.isEmpty {
                        Text("Zuletzt")
                            .font(PV.title(.title3))
                            .foregroundStyle(PV.onChassis)
                        ForEach(ownedCards.prefix(5), id: \.id) { card in
                            NavigationLink {
                                OwnedCardDetailView(card: card)
                            } label: {
                                OwnedCardRow(card: card)
                                    .padding(PV.spaceM)
                                    .background(PV.screenElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: PV.radiusScreen, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        PVCreamPanel {
                            Text("Noch keine Karten — unter „Meine Karten“ oder „Entdecken“ starten.")
                                .font(PV.body())
                        }
                    }
                }
                .padding()
            }
            .pvScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showWishlist = true
                    } label: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(PV.statusWarn)
                    }
                    .accessibilityLabel("Wunschliste")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(PV.onChassis)
                    }
                    .accessibilityLabel("Einstellungen")
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            .sheet(isPresented: $showWishlist) {
                NavigationStack { WishlistView() }
            }
            .onAppear { viewModel.refresh(owned: ownedCards) }
            .onChange(of: ownedCards.count) { _, _ in
                viewModel.refresh(owned: ownedCards)
            }
        }
    }

    private func readoutRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(PV.caption())
                .foregroundStyle(PV.onScreenMuted)
            Spacer()
            Text(value)
                .font(PV.readout(.body))
                .foregroundStyle(PV.onScreen)
        }
    }

    private var portfolioChartPoints: [PortfolioChartPoint]? {
        let lines = ownedCards.map { $0.portfolioLine() }.filter { $0.hasPurchase && $0.hasCurrent }
        guard !lines.isEmpty else { return nil }
        return [
            PortfolioChartPoint(label: "Kauf", value: lines.compactMap(\.purchaseTotal).reduce(0, +)),
            PortfolioChartPoint(label: "Aktuell", value: lines.compactMap(\.currentTotal).reduce(0, +))
        ]
    }

    private func gainLossText(_ stats: CollectionStats) -> String {
        guard let gain = stats.unrealizedGainLossEUR else { return "—" }
        let pct = stats.unrealizedGainLossPercent.map { " (\(CurrencyFormat.percent($0)))" } ?? ""
        return "\(CurrencyFormat.signedEuro(gain))\(pct)"
    }

    private func gainLossColor(_ value: Double?) -> Color {
        guard let value else { return PV.onScreen }
        if value > 0 { return PV.gain }
        if value < 0 { return PV.loss }
        return PV.onScreen
    }
}

private struct PortfolioChartPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

#Preview {
    DashboardView()
        .modelContainer(ModelContainerFactory.previewContainer())
}
