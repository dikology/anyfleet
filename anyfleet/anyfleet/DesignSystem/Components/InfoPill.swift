import SwiftUI

struct InfoPill: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.caption)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(DesignSystem.Colors.surfaceAlt)
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
    }
}

