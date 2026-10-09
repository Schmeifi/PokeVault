import SwiftUI
import SwiftData

struct SetProgressView: View {
    let setId: String
    var locale: String = "de"

    @Query private var ownedCards: [OwnedCard]
    @State private var detail: TCGdexSetDetail?
    @State private var rule: CompletionRule = .officialCount
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Set wird geladen…")
                    .tint(PV.readout)
            } else if let errorMessage {
                ContentUnavailableView("Fehler", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else if let detail {
                let progress = SetProgressService.progress(for: detail, owned: ownedCards, rule: rule)
                ScrollView {
                    VStack(alignment: .leading, spacing: PV.spaceL) {
                        PVScreenPanel {
                            Text(detail.name)
                                .font(PV.title())
                                .foregroundStyle(PV.onScreen)
                            Text("\(progress.ownedDistinct) / \(progress.totalOfficial) · \(progress.percentLabel)")
                                .font(PV.readout())
                                .foregroundStyle(PV.readout)
                                .contentTransition(.numericText())
                            ProgressView(value: progress.fraction)
                                .tint(PV.statusOK)
                            Picker("Vollständigkeit", selection: $rule) {
                                ForEach(CompletionRule.allCases) { item in
                                    Text(item.displayNameDE).tag(item)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        PVScreenPanel {
                            Text("Fehlende Karten")
                                .font(PV.headline())
                                .foregroundStyle(PV.onScreen)
                            if progress.missingLocalIds.isEmpty {
                                Text("Set vollständig nach gewählter Regel.")
                                    .foregroundStyle(PV.statusOK)
                                    .font(PV.body())
                            } else {
                                ForEach(progress.missingLocalIds.prefix(80), id: \.self) { localId in
                                    let card = detail.cards?.first(where: { $0.localId == localId })
                                    HStack {
                                        Text("#\(localId)")
                                            .font(PV.monoCaption())
                                            .foregroundStyle(PV.readout)
                                        Text(card?.name ?? "—")
                                            .font(PV.caption())
                                            .foregroundStyle(PV.onScreenMuted)
                                        Spacer()
                                    }
                                }
                                if progress.missingLocalIds.count > 80 {
                                    Text("… und \(progress.missingLocalIds.count - 80) weitere")
                                        .font(PV.caption())
                                        .foregroundStyle(PV.onScreenMuted)
                                }
                            }
                        }
                    }
                    .padding()
                    .pvDexAppear()
                }
            }
        }
        .pvScreenBackground()
        .navigationTitle("Set-Fortschritt")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await TCGdexProvider.shared.fetchSetDetail(id: setId, locale: locale)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
