import SwiftUI
import UIKit

private enum ImageURLCache {
    static let shared: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 200
        return c
    }()
}

/// Lightweight `AsyncImage` wrapper with an in-memory `NSCache` for decoded images.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var task: Task<Void, Never>?

    var body: some View {
        Group {
            if let ui = loadedImage {
                content(Image(uiImage: ui))
            } else {
                placeholder()
            }
        }
        .onAppear { loadIfNeeded() }
        .onChange(of: url?.absoluteString) { _, _ in
            task?.cancel()
            loadedImage = nil
            loadIfNeeded()
        }
        .onDisappear { task?.cancel() }
    }

    private func loadIfNeeded() {
        guard let url else { return }
        if let cached = ImageURLCache.shared.object(forKey: url as NSURL) {
            loadedImage = cached
            return
        }
        task = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled,
                      let image = UIImage(data: data) else { return }
                ImageURLCache.shared.setObject(image, forKey: url as NSURL)
                await MainActor.run { loadedImage = image }
            } catch {
                // Keep placeholder
            }
        }
    }

}
