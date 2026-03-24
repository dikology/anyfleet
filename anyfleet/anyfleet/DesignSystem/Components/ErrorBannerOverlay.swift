import SwiftUI

/// Full-screen overlay that pins an `ErrorBanner` above the bottom safe area.
struct ErrorBannerOverlay: View {
    let error: AppError
    let onDismiss: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack {
            Spacer()
            ErrorBanner(
                error: error,
                onDismiss: onDismiss,
                onRetry: onRetry
            )
            .padding(.horizontal)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
