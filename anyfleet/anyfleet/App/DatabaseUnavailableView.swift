//
//  DatabaseUnavailableView.swift
//  anyfleet
//
//  Shown when the SQLite database cannot be opened on launch.
//  Lets the user retry without forcing a hard crash.
//

import SwiftUI

struct DatabaseUnavailableView: View {
    let error: Error
    let onRetry: () -> Void

    @State private var isRetrying = false
    @State private var showDetails = false

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.error.opacity(0.12))
                        .frame(width: 96, height: 96)
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.error)
                }

                // Text block
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Something went wrong")
                        .font(DesignSystem.Typography.title)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("The local database could not be opened.\nThis can happen if your device is low on storage.")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Retry button
                Button {
                    guard !isRetrying else { return }
                    isRetrying = true
                    onRetry()
                    isRetrying = false
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if isRetrying {
                            ProgressView()
                                .tint(DesignSystem.Colors.onPrimary)
                        }
                        Text(isRetrying ? "Trying…" : "Try Again")
                            .font(DesignSystem.Typography.bodyMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.primary)
                    .foregroundStyle(DesignSystem.Colors.onPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusMedium, style: .continuous))
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .disabled(isRetrying)

                // Collapsible error details
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Button {
                        withAnimation(DesignSystem.Motion.standard) {
                            showDetails.toggle()
                        }
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text("Error details")
                                .font(DesignSystem.Typography.caption)
                            Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }

                    if showDetails {
                        Text(error.localizedDescription)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous))
                            .padding(.horizontal, DesignSystem.Spacing.xl)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }
}

#Preview {
    DatabaseUnavailableView(
        error: NSError(
            domain: "GRDB",
            code: 14,
            userInfo: [NSLocalizedDescriptionKey: "unable to open database file (code: 14)"]
        ),
        onRetry: {}
    )
}
