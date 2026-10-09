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
                    .font(.headline)
                Text(hit.printingLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(hit.card.id)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}
