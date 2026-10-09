import SwiftUI

struct SampleDataBanner: View {
    var message: String = SampleDataSeeder.sampleBannerText

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hinweis: \(message)")
    }
}

struct PriceSourceLabel: View {
    let source: PriceSource
    let metric: String?
    let updatedAt: Date?
    let isSample: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(source.displayNameDE)
                .font(.caption)
                .foregroundStyle(isSample || source == .sample ? .orange : .secondary)
            if let metric {
                Text("Kennzahl: \(metric)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let updatedAt {
                Text("Stand: \(DateFormat.medium(updatedAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
