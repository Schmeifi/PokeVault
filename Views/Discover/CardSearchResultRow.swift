import SwiftUI

struct CardSearchResultRow: View {
    let hit: CardSearchHit
    var actionTitle: String = "Details"
    var action: (() -> Void)?

    init(hit: CardSearchHit, actionTitle: String = "Details", action: (() -> Void)? = nil) {
        self.hit = hit
        self.actionTitle = actionTitle
        self.action = action
    }

    /// Rückwärtskompatibel für Stellen mit nur Summary.
    init(card: TCGdexCardSummary, subtitle: String? = nil, actionTitle: String = "Details", action: (() -> Void)? = nil) {
        self.hit = CardSearchHit(
            card: card,
            setId: card.inferredSetId,
            setName: subtitle,
            localeUsed: "de"
        )
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(spacing: 12) {
            CachedCardImageView(
                candidates: hit.card.imageCandidatesLow,
                title: hit.card.name
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(hit.card.name)
                    .font(PV.headline())
                    .foregroundStyle(PV.onScreen)
                Text(hit.printingLabel)
                    .font(PV.caption())
                    .foregroundStyle(PV.onScreenMuted)
                Text(hit.card.id)
                    .font(PV.monoCaption())
                    .foregroundStyle(PV.tertiaryLabel)
                if let confidence = hit.matchConfidence {
                    Text(String(format: "Match %.0f %%", confidence * 100))
                        .font(PV.monoCaption())
                        .foregroundStyle(confidence >= 0.72 ? PV.statusOK : PV.statusWarn)
                }
                Text(hit.displayPriceLine)
                    .font(PV.monoCaption())
                    .foregroundStyle(hit.priceEUR == nil ? PV.statusWarn : PV.readout)
            }
            Spacer(minLength: 0)
            if let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .tint(PV.readout)
            }
        }
        .padding(.vertical, 4)
    }
}
