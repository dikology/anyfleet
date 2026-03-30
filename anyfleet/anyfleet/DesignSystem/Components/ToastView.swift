//
//  ToastView.swift
//  anyfleet
//
//  Floating confirmation toasts (success, info, warning).
//

import SwiftUI

enum ToastVariant: Equatable, Sendable {
    case success
    case info
    case warning
}

struct AppToast: Equatable, Identifiable, Sendable {
    let id: UUID
    let message: String
    let variant: ToastVariant
}

struct ToastView: View {
    let message: String
    let variant: ToastVariant

    private var symbolName: String {
        switch variant {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private var accentColor: Color {
        switch variant {
        case .success: return DesignSystem.Colors.success
        case .info: return DesignSystem.Colors.info
        case .warning: return DesignSystem.Colors.gold
        }
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: symbolName)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(accentColor)
            Text(message)
                .font(DesignSystem.Typography.calloutSemibold)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(DesignSystem.Colors.border.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: DesignSystem.Colors.shadowStrong.opacity(0.12), radius: 8, y: 4)
        .accessibilityIdentifier("toast.banner")
        .accessibilityAddTraits(.isStaticText)
    }
}
