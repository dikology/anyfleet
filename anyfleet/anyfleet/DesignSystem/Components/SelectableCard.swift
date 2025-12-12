import SwiftUI

/// A generic selectable card with custom background, header, and content.
struct SelectableCard<Background: View, Content: View>: View {
    let isSelected: Bool
    let accessibilityLabel: String?
    let onSelect: () -> Void
    @ViewBuilder let background: Background
    @ViewBuilder let content: Content
    
    init(
        isSelected: Bool,
        accessibilityLabel: String? = nil,
        onSelect: @escaping () -> Void,
        @ViewBuilder background: () -> Background,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.accessibilityLabel = accessibilityLabel
        self.onSelect = onSelect
        self.background = background()
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            background
            content
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.SelectableCardStyle.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.SelectableCardStyle.cornerRadius)
                .stroke(
                    isSelected ? DesignSystem.SelectableCardStyle.selectedBorderColor : DesignSystem.Colors.border,
                    lineWidth: isSelected ? DesignSystem.SelectableCardStyle.selectedBorderWidth : DesignSystem.SelectableCardStyle.borderWidth
                )
        )
        .shadow(
            color: DesignSystem.SelectableCardStyle.shadowColor.opacity(isSelected ? 0.12 : 0.04),
            radius: isSelected ? DesignSystem.SelectableCardStyle.shadowRadiusSelected : DesignSystem.SelectableCardStyle.shadowRadius,
            x: 0,
            y: isSelected ? DesignSystem.SelectableCardStyle.shadowYOffsetSelected : DesignSystem.SelectableCardStyle.shadowYOffset
        )
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel ?? "Option")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

