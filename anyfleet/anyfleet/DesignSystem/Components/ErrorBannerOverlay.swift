import SwiftUI

/// Full-screen overlay that pins an `ErrorBanner` above the floating tab bar.
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
            .padding(.bottom, FloatingTabBar.safeAreaInset)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
