import SwiftUI
import SwiftData

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
                            title: "Schätzwert",
                            value: CurrencyFormat.euroOrDash(viewModel.stats.estimatedValueEUR),
                            footnote: viewModel.stats.valueSourceSummary
                        )
                        StatTile(
                            title: "Ohne Preis",
                            value: "\(viewModel.stats.cardsWithoutPrice)"
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wertquelle")
                            .font(.headline)
                        Text(viewModel.stats.valueSourceSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Es werden keine historischen Marktpreise erfunden. Fehlende Preise bleiben leer.")
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
