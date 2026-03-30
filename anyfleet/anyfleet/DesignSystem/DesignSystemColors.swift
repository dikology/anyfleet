import SwiftUI

extension DesignSystem {
    enum Colors {
        // Teal primary: slightly more saturated in dark mode to compensate for low-contrast environment
        static let primary = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.146, green: 0.621, blue: 0.635, alpha: 1) // #259FA2 — vivid teal
                : UIColor(red: 0.126, green: 0.541, blue: 0.552, alpha: 1) // #208A8D
        })
        static let secondary = Color(red: 0.369, green: 0.322, blue: 0.251) // #5E5240
        static let success = Color(red: 0.133, green: 0.773, blue: 0.369) // #22C55E
        static let warning = Color(red: 0.902, green: 0.506, blue: 0.380) // #E68161
        static let error = Color(red: 1.0, green: 0.329, blue: 0.349) // #FF5459
        static let info = Color(red: 0.192, green: 0.463, blue: 0.776) // #3176C6
        // Gold: more saturated in dark mode to compensate for low-contrast environment
        static let gold = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.0, green: 0.855, blue: 0.36, alpha: 1)  // vivid warm gold
                : UIColor(red: 0.98, green: 0.82, blue: 0.45, alpha: 1)
        })
        static let oceanDeep = Color(red: 0.02, green: 0.28, blue: 0.36)

        // MARK: - Semantic gold aliases
        /// Community badge, pending sync state
        static let communityAccent  = gold
        /// Duration pills, form progress fill
        static let highlightAccent  = gold
        /// Vessel label decoration
        static let vesselAccent     = gold

        // MARK: - Visibility semantic colors
        static let visibilityPublic    = primary
        static let visibilityCommunity = communityAccent
        static let visibilityPrivate   = textSecondary

        // MARK: - Dynamic surfaces for light/dark
        // Dark mode surfaces blend systemGroupedBackground with a 10% oceanDeep tint,
        // giving the app a designed feel rather than flat system gray.
        static let background = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.101, green: 0.127, blue: 0.142, alpha: 1) // #1A2024 — oceanDeep-tinted dark
                : UIColor.systemGroupedBackground
        })
        static let backgroundSecondary = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.157, green: 0.184, blue: 0.198, alpha: 1) // #282F32
                : UIColor.secondarySystemGroupedBackground
        })
        static let surface = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.157, green: 0.184, blue: 0.198, alpha: 1) // #282F32
                : UIColor.secondarySystemGroupedBackground
        })
        static let surfaceAlt = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.209, green: 0.232, blue: 0.247, alpha: 1) // #353B3F
                : UIColor.tertiarySystemGroupedBackground
        })

        // MARK: - Text
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)

        static let border = Color(.separator).opacity(0.4)
        static let onPrimary = Color.white
        static let onPrimaryMuted = Color.white.opacity(0.9)
        static let shadowStrong = Color.black.opacity(0.18)

        /// Deterministic accent for avatar monogram backgrounds (seed with stable ids, not display names).
        static func hashColor(for seed: String) -> Color {
            let palette: [Color] = [
                primary,
                Color(red: 0.8, green: 0.5, blue: 0.3),
                Color(red: 0.3, green: 0.7, blue: 0.8),
                Color(red: 0.7, green: 0.3, blue: 0.6),
                Color(red: 0.5, green: 0.7, blue: 0.3)
            ]
            let hash = seed.utf8.reduce(0) { $0 &+ Int($1) }
            return palette[abs(hash) % palette.count]
        }
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

        /// Filled CTA button gradient.
        static let primaryButton = LinearGradient(
            colors: [Colors.primary, Color(red: 0.054, green: 0.32, blue: 0.45)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Ambient gold highlight behind a focused row or card.
        static let focalGold = LinearGradient(
            colors: [Colors.gold.opacity(0.15), Colors.gold.opacity(0.05), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Subtle tinted background for list scroll areas.
        static let subtleBackground = LinearGradient(
            colors: [Colors.background, Colors.oceanDeep.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )

        static let subtleOverlay = LinearGradient(
            colors: [
                Color.white.opacity(0.08),
                Color.white.opacity(0.02)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Dark overlay for hero cards with photo backgrounds to ensure text readability.
        static let heroImageOverlay = LinearGradient(
            colors: [
                Color.black.opacity(0.15),
                Color.black.opacity(0.5),
                Color.black.opacity(0.75)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Focal gold radial gradient for form hero headers.
        static let focalGoldRadial = RadialGradient(
            colors: [
                Colors.gold.opacity(0.15),
                Color.clear
            ],
            center: .init(x: 0.5, y: 1),
            startRadius: 0,
            endRadius: 200
        )
    }
}
