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
                    PVBrandHeader(subtitle: "Deine Sammlung · Living Dex Vault")

                    if viewModel.stats.usesSampleData {
                        SampleDataBanner()
                    }

                    heroPortfolioCard
                        .pvDexAppear()

                    if let chart = portfolioChartPoints, chart.count == 2 {
                        PVScreenPanel {
                            Text("Kauf vs. Aktuell")
                                .font(PV.headline())
                                .foregroundStyle(PV.inkTitle)
                            Text("Nur echte GuV-fähige Exemplare — keine Fake-Historie.")
                                .font(PV.caption())
                                .foregroundStyle(PV.inkSecondary)
                            Chart(chart) { point in
                                BarMark(
                                    x: .value("Art", point.label),
                                    y: .value("Euro", point.value)
                                )
                                .foregroundStyle(point.label == "Kauf" ? PV.inkMuted : PV.primaryContainer)
                                .cornerRadius(8)
                            }
                            .frame(height: 140)
                        }
                    }

                    if !ownedCards.isEmpty {
                        Text("Zuletzt")
                            .font(PV.title(.title3))
                            .foregroundStyle(PV.inkTitle)
                        ForEach(ownedCards.prefix(5), id: \.id) { card in
                            NavigationLink {
                                OwnedCardDetailView(card: card)
                            } label: {
                                OwnedCardRow(card: card)
                                    .padding(PV.spaceM)
                                    .background(
                                        RoundedRectangle(cornerRadius: PV.radiusDefault, style: .continuous)
                                            .fill(PV.sheet)
                                            .shadow(color: PV.ink.opacity(0.05), radius: 10, y: 4)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        PVCreamPanel {
                            Text("Noch keine Karten — unter „Meine Karten“ oder „Entdecken“ starten.")
                                .font(PV.body())
                                .foregroundStyle(PV.inkSecondary)
                        }
                    }
                }
                .padding(.horizontal, PV.margin)
                .padding(.vertical, PV.spaceM)
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
                    }
                    .accessibilityLabel("Einstellungen")
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
                    .pvThemedSheet()
            }
            .sheet(isPresented: $showWishlist) {
                NavigationStack { WishlistView() }
                    .pvThemedSheet()
            }
            .onAppear { viewModel.refresh(owned: ownedCards) }
            .onChange(of: ownedCards.count) { _, _ in
                viewModel.refresh(owned: ownedCards)
            }
        }
    }

    private var heroPortfolioCard: some View {
        ZStack(alignment: .topTrailing) {
            PVPokeballWatermark(opacity: 0.18, color: .white)
                .frame(width: 140, height: 140)
                .offset(x: 28, y: -20)

            VStack(alignment: .leading, spacing: PV.spaceM) {
                HStack {
                    Text("COMPENDIUM")
                        .font(PV.labelBadge())
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.28)))
                    Spacer()
                }

                Text("Portfolio")
                    .font(PV.title())
                    .foregroundStyle(.white)

                readoutRow("Exemplare", "\(viewModel.stats.totalOwnedCards)")
                readoutRow("Kaufwert", CurrencyFormat.euroOrDash(viewModel.stats.totalPurchaseCostEUR))
                readoutRow("Aktuell", CurrencyFormat.euroOrDash(viewModel.stats.currentPortfolioValueEUR))

                HStack {
                    Text("GuV")
                        .font(PV.caption())
                        .foregroundStyle(Color.white.opacity(0.85))
                    Spacer()
                    Text(gainLossText(viewModel.stats))
                        .font(PV.readout(.title3))
                        .foregroundStyle(gainLossHeroColor(viewModel.stats.unrealizedGainLossEUR))
                        .contentTransition(.numericText())
                }

                Text("Ohne Preis: \(viewModel.stats.cardsWithoutPrice) · Markt \(viewModel.stats.marketValuedCards) · Manuell \(viewModel.stats.manuallyValuedCards)")
                    .font(PV.caption())
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            .padding(PV.spaceL)
        }
        .background(
            RoundedRectangle(cornerRadius: PV.radiusCard, style: .continuous)
                .fill(PV.primaryContainer)
                .shadow(color: PV.primaryContainer.opacity(0.35), radius: 16, y: 8)
        )
        .clipShape(RoundedRectangle(cornerRadius: PV.radiusCard, style: .continuous))
    }

    private func readoutRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(PV.caption())
                .foregroundStyle(Color.white.opacity(0.85))
            Spacer()
            Text(value)
                .font(PV.readout(.body))
                .foregroundStyle(.white)
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

    private func gainLossHeroColor(_ value: Double?) -> Color {
        guard let value else { return .white }
        if value > 0 { return Color(hex: 0x005545) }
        if value < 0 { return Color(hex: 0x6D0011) }
        return .white
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
