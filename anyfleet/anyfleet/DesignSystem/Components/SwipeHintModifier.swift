import SwiftUI

/// Peek-and-return horizontal offset to hint that trailing swipe actions exist.
///
/// This only translates the row’s **content**; it does not open UIKit’s swipe-actions
/// tray, so the real Edit/Delete (etc.) buttons stay hidden until the user swipes. That
/// matches a lightweight “nudge” pattern; the paired `SwipeActionTipChip` names the actions.
struct SwipeHintModifier: ViewModifier {
    @Binding var isPlaying: Bool
    let peekOffset: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        Group {
            if reduceMotion {
                content
            } else {
                content
                    .offset(x: isPlaying ? -peekOffset : 0)
                    .animation(
                        isPlaying
                            ? .spring(response: 0.35, dampingFraction: 0.8)
                                .delay(0.2)
                                .repeatCount(1, autoreverses: true)
                            : .default,
                        value: isPlaying
                    )
            }
        }
    }
}

extension View {
    func swipeHint(isPlaying: Binding<Bool>, peekOffset: CGFloat = 60) -> some View {
        modifier(SwipeHintModifier(isPlaying: isPlaying, peekOffset: peekOffset))
    }
}
