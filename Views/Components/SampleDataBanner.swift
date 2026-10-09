import SwiftUI

struct SampleDataBanner: View {
    var message: String = SampleDataSeeder.sampleBannerText

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(PV.secondary)
            Text(message)
                .font(PV.caption())
                .foregroundStyle(PV.inkTitle)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(PV.secondaryContainer.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: PV.radiusDefault, style: .continuous))
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
                .font(PV.caption())
                .foregroundStyle(isSample || source == .sample ? PV.secondary : PV.inkSecondary)
            if let metric {
                Text("Kennzahl: \(metric)")
                    .font(PV.caption())
                    .foregroundStyle(PV.inkMuted)
            }
            if let updatedAt {
                Text("Stand: \(DateFormat.medium(updatedAt))")
                    .font(PV.caption())
                    .foregroundStyle(PV.inkMuted)
            }
        }
    }
}
