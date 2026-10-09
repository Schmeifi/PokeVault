import SwiftUI

/// Schnellfilter für TG / GG / SV / Illustration Rares u. a.
struct CategoryBrowseView: View {
    @Bindable var viewModel: DiscoverViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PV.spaceL) {
                PVScreenPanel {
                    Text("Kategorien")
                        .font(PV.title())
                        .foregroundStyle(PV.onScreen)
                    Text("Teilmengen über Nummern-Präfix oder TCGdex-Seltenheit — keine erfundenen Daten.")
                        .font(PV.caption())
                        .foregroundStyle(PV.onScreenMuted)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: PV.spaceM
                ) {
                    ForEach(DiscoverCategory.allCases) { category in
                        Button {
                            Task { await viewModel.browseCategory(category) }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(category.shortTitleDE)
                                    .font(PV.headline())
                                    .foregroundStyle(PV.primary)
                                Text(category.titleDE)
                                    .font(PV.caption())
                                    .foregroundStyle(PV.onScreen)
                                    .lineLimit(2)
                                Text(category.subtitleDE)
                                    .font(PV.caption())
                                    .foregroundStyle(PV.onScreenMuted)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(PV.spaceM)
                            .background(PV.surfaceContainerLow)
                            .clipShape(RoundedRectangle(cornerRadius: PV.radiusDefault, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .pvDexAppear()
                    }
                }
            }
            .padding()
        }
        .pvScreenBackground()
    }
}
