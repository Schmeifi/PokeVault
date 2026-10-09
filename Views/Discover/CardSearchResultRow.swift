import SwiftUI

struct CardSearchResultRow: View {
    let card: TCGdexCardSummary
    var subtitle: String? = nil
    var actionTitle: String = "Details"
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            CachedCardImageView(
                imageURL: card.imageURLLow,
                title: card.name
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                Text(subtitle ?? defaultSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(card.id)
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

    private var defaultSubtitle: String {
        let number = card.localId.map { "#\($0)" } ?? ""
        return [number, "TCGdex"].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
