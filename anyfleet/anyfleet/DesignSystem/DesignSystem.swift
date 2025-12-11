import SwiftUI

enum DesignSystem {
    enum Colors {
        static let primary = Color(red: 0.126, green: 0.541, blue: 0.552) // #208A8D
        static let secondary = Color(red: 0.369, green: 0.322, blue: 0.251) // #5E5240
        static let success = Color(red: 0.133, green: 0.773, blue: 0.369) // #22C55E
        static let warning = Color(red: 0.902, green: 0.506, blue: 0.380) // #E68161
        static let error = Color(red: 1.0, green: 0.329, blue: 0.349) // #FF5459
        static let background = Color(red: 1.0, green: 0.988, blue: 0.976) // #FFFCF9
        static let surface = Color(red: 1.0, green: 1.0, blue: 0.961) // #FFFFF5
        static let textPrimary = Color(red: 0.074, green: 0.259, blue: 0.321) // #134252
        static let textSecondary = Color(red: 0.384, green: 0.459, blue: 0.427) // #62756D
        static let border = Color.black.opacity(0.06)
        static let onPrimary = Color.white
        static let onPrimaryMuted = Color.white.opacity(0.8)
        static let shadowStrong = Color.black.opacity(0.16)
    }
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    enum Typography {
        static let title = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 18, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
        static let caption = Font.system(size: 14, weight: .regular)
    }
    
    enum Gradients {
        static let primary = LinearGradient(
            colors: [
                Color(red: 0.102, green: 0.47, blue: 0.53),
                Color(red: 0.054, green: 0.32, blue: 0.45)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let subtleOverlay = LinearGradient(
            colors: [
                Color.white.opacity(0.08),
                Color.white.opacity(0.02)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    struct CardStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Colors.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Colors.border, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }
    
    struct PrimaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .background(Colors.primary)
                .foregroundColor(.white)
                .cornerRadius(10)
                .opacity(configuration.isPressed ? 0.9 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(DesignSystem.CardStyle())
    }
}

