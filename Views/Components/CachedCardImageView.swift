import SwiftUI
import UIKit

/// Kartenbild mit lokalem Disk-Cache; fällt offline auf Cache/Platzhalter zurück.
struct CachedCardImageView: View {
    let imageURL: URL?
    let title: String
    var size: CGSize = CGSize(width: 72, height: 100)

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var failed = false

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
        .accessibilityLabel(title)
        .task(id: imageURL?.absoluteString) {
            await load()
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(.tertiarySystemFill)
            Image(systemName: failed ? "photo.badge.exclamationmark" : "rectangle.portrait")
                .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func load() async {
        image = nil
        failed = false
        guard let imageURL else { return }

        if let warm = await CardImageCache.shared.cachedImage(for: imageURL) {
            image = warm
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await CardImageCache.shared.imageData(for: imageURL, allowNetwork: true)
            image = UIImage(data: data)
            if image == nil { failed = true }
        } catch {
            if let data = try? await CardImageCache.shared.imageData(for: imageURL, allowNetwork: false),
               let ui = UIImage(data: data) {
                image = ui
            } else {
                failed = true
            }
        }
    }
}
