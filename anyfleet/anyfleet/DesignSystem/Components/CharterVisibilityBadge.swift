import SwiftUI

// MARK: - CharterVisibility design tokens

extension CharterVisibility {
    /// Foreground + tint color for the visibility badge.
    var accentColor: Color {
        switch self {
        case .public:    return DesignSystem.Colors.primary
        case .community: return DesignSystem.Colors.communityAccent
        case .private:   return DesignSystem.Colors.textSecondary
        }
    }

    /// Ambient corner-glow color on the charter card.
    var glowColor: Color {
        switch self {
        case .public:    return DesignSystem.Colors.primary
        case .community: return DesignSystem.Colors.communityAccent
        case .private:   return DesignSystem.Colors.error
        }
    }
}

// MARK: - Badge component

extension DesignSystem {
    /// Capsule badge showing a charter's visibility level with an icon and label.
    struct CharterVisibilityBadge: View {
        let visibility: CharterVisibility

        var body: some View {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: visibility.systemImage)
                    .font(.system(size: 11, weight: .medium))
                Text(visibility.displayName)
                    .font(DesignSystem.Typography.micro)
                    .fontWeight(.semibold)
            }
            .foregroundColor(visibility.accentColor)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(visibility.accentColor.opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(visibility.accentColor.opacity(0.3), lineWidth: 1))
            .accessibilityLabel("Visibility: \(visibility.displayName)")
        }
    }
}

// MARK: - Preview

#Preview("Visibility Badges") {
    VStack(spacing: DesignSystem.Spacing.md) {
        DesignSystem.CharterVisibilityBadge(visibility: .public)
        DesignSystem.CharterVisibilityBadge(visibility: .community)
        DesignSystem.CharterVisibilityBadge(visibility: .private)
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
