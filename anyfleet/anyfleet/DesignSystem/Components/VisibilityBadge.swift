//
//  VisibilityBadge.swift
//  anyfleet
//
//  Badge component for displaying content visibility state
//

import SwiftUI

/// Badge component that displays the visibility state of library content
struct VisibilityBadge: View {
    let visibility: ContentVisibility
    let authorUsername: String?
    
    init(
        visibility: ContentVisibility,
        authorUsername: String? = nil
    ) {
        self.visibility = visibility
        self.authorUsername = authorUsername
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: visibility.icon)
                .font(.system(size: 12, weight: .medium))
            
            Text(visibility.displayName.lowercased())
                .font(DesignSystem.Typography.caption)
            
            if visibility == .public {
                Text("·")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(12)
    }
    
    // MARK: - Styling
    
    private var backgroundColor: Color {
        switch visibility {
        case .private:
            return DesignSystem.Colors.border.opacity(0.3)
        case .unlisted:
            return DesignSystem.Colors.primary.opacity(0.1)
        case .public:
            return DesignSystem.Colors.success.opacity(0.15)
        }
    }
    
    private var foregroundColor: Color {
        switch visibility {
        case .private:
            return DesignSystem.Colors.textSecondary
        case .unlisted:
            return DesignSystem.Colors.primary
        case .public:
            return DesignSystem.Colors.success
        }
    }
}

// MARK: - Preview

#Preview("Visibility Badges") {
    VStack(spacing: DesignSystem.Spacing.md) {
        VisibilityBadge(visibility: .private)
        VisibilityBadge(visibility: .unlisted)
        VisibilityBadge(visibility: .public)
        VisibilityBadge(visibility: .public, authorUsername: "SailorMaria")
    }
    .padding()
    .background(DesignSystem.Colors.background)
}

