//
//  PublishConfirmationModal.swift
//  anyfleet
//
//  Modal for confirming content publication
//

import SwiftUI

/// Modal for confirming content publication with clear explanation
struct PublishConfirmationModal: View {
    let item: LibraryModel
    let isLoading: Bool
    let error: Error?
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onRetry: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Icon
                Image(systemName: "globe")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .padding(.top, DesignSystem.Spacing.xl)
                
                // Title
                Text("Share \"\(item.title)\"?")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                
                // Explanation
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Others can see and fork this content. You'll be credited as the author.")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                
                // Info box
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.primary)
                    
                    Text("This is permanent. Everyone will be able to find your content.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.primary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                
                Spacer()
                
                // Error display
                if let error = error {
                    ErrorBanner(
                        error: error.toAppError(),
                        onDismiss: { },
                        onRetry: onRetry
                    )
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
                
                // Buttons
                VStack(spacing: DesignSystem.Spacing.md) {
                    Button(action: onConfirm) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Share Publicly")
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                    }
                    .disabled(isLoading)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Publish Confirmation") {
    PublishConfirmationModal(
        item: LibraryModel(
            title: "Racing Tips",
            type: .practiceGuide,
            creatorID: UUID()
        ),
        isLoading: false,
        error: nil,
        onConfirm: {},
        onCancel: {},
        onRetry: nil
    )
}

