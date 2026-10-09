import SwiftUI
import UIKit

/// Kartenbild mit Kandidaten-Fallback (webp/png, de/en, TG-Hauptset) und Disk-Cache.
struct CachedCardImageView: View {
    let candidates: [URL]
    let title: String
    var size: CGSize = CGSize(width: 72, height: 100)
    var unavailableCaption: String = "Kein Bild"

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var failed = false

    init(imageURL: URL?, title: String, size: CGSize = CGSize(width: 72, height: 100)) {
        self.candidates = imageURL.map { [$0] } ?? []
        self.title = title
        self.size = size
    }

    init(candidates: [URL], title: String, size: CGSize = CGSize(width: 72, height: 100)) {
        self.candidates = candidates
        self.title = title
        self.size = size
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                placeholder.overlay { ProgressView() }
            } else {
                placeholder
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel(failed && image == nil ? "\(title), \(unavailableCaption)" : title)
        .task(id: candidates.map(\.absoluteString).joined(separator: "|")) {
            await load()
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(.tertiarySystemFill)
            VStack(spacing: 4) {
                Image(systemName: failed ? "photo.badge.exclamationmark" : "rectangle.portrait")
                    .foregroundStyle(.secondary)
                if failed || candidates.isEmpty {
                    Text(unavailableCaption)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 2)
                }
            }
        }
    }

    @MainActor
    private func load() async {
        image = nil
        failed = false
        guard !candidates.isEmpty else {
            failed = true
            return
        }

        if let first = candidates.first,
           let warm = await CardImageCache.shared.cachedImage(for: first) {
            image = warm
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await CardImageCache.shared.imageData(candidates: candidates, allowNetwork: true)
            image = UIImage(data: data)
            if image == nil { failed = true }
        } catch {
            if let data = try? await CardImageCache.shared.imageData(candidates: candidates, allowNetwork: false),
               let ui = UIImage(data: data) {
                image = ui
            } else {
                failed = true
            }
        }
    }
}
