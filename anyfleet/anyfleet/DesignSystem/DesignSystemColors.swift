import SwiftUI

extension DesignSystem {
    enum Colors {
        static let primary = Color(red: 0.126, green: 0.541, blue: 0.552) // #208A8D
        static let secondary = Color(red: 0.369, green: 0.322, blue: 0.251) // #5E5240
        static let success = Color(red: 0.133, green: 0.773, blue: 0.369) // #22C55E
        static let warning = Color(red: 0.902, green: 0.506, blue: 0.380) // #E68161
        static let error = Color(red: 1.0, green: 0.329, blue: 0.349) // #FF5459
        static let info = Color(red: 0.192, green: 0.463, blue: 0.776) // #3176C6
        static let gold = Color(red: 0.98, green: 0.82, blue: 0.45) // accent for highlights
        static let oceanDeep = Color(red: 0.02, green: 0.28, blue: 0.36)
        
        // Dynamic surfaces for light/dark
        static let background = Color(.systemGroupedBackground)
        static let surface = Color(.secondarySystemGroupedBackground)
        static let surfaceAlt = Color(.tertiarySystemGroupedBackground)
        
        // Text
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        
        static let border = Color(.separator).opacity(0.4)
        static let onPrimary = Color.white
        static let onPrimaryMuted = Color.white.opacity(0.9)
        static let shadowStrong = Color.black.opacity(0.18)
    }
    
    enum Gradients {
        /// Primary brand ocean gradient for hero/CTA cards.
        static let primary = LinearGradient(
            colors: [
                Color(red: 0.102, green: 0.47, blue: 0.53),
                Color(red: 0.054, green: 0.32, blue: 0.45)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// Convenience alias specifically for ocean-themed hero cards.
        static let ocean = primary
        
        static let subtleOverlay = LinearGradient(
            colors: [
                Color.white.opacity(0.08),
                Color.white.opacity(0.02)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}


