import SwiftUI

/// Reusable action card suited for hero/CTA placements.
struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let buttonTitle: String
    var badge: String? = nil
    var onTap: () -> Void = {}
    var onButtonTap: () -> Void = {}
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            header
            content
            cta
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            DesignSystem.Gradients.primary
                .overlay(DesignSystem.Gradients.subtleOverlay)
        )
        .cornerRadius(16)
        .shadow(color: DesignSystem.Colors.shadowStrong, radius: 12, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .accessibilityElement(children: .combine)
    }
    
    private var header: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.onPrimary)
            }
            
            Spacer()
            
            if let badge {
                Text(badge)
                    .font(DesignSystem.Typography.caption.weight(.semibold))
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(Color.white.opacity(0.14))
                    .foregroundColor(DesignSystem.Colors.onPrimary)
                    .cornerRadius(10)
            }
        }
    }
    
    private var content: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.onPrimary)
            
            Text(subtitle)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.onPrimaryMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var cta: some View {
        Button(action: onButtonTap) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(buttonTitle)
                    .font(.system(size: 16, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .background(Color.white.opacity(0.16))
            .foregroundColor(DesignSystem.Colors.onPrimary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

