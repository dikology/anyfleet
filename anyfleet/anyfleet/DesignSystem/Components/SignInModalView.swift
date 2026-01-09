//
//  SignInModalView.swift
//  anyfleet
//
//  Modal for signing in to enable publishing
//

import SwiftUI
import AuthenticationServices

/// Modal view for signing in with Apple to enable publishing
struct SignInModalView: View {
    @Environment(AuthService.self) private var authService
    @State private var appError: AppError?
    @State private var isLoading = false
    
    let onSuccess: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()
                
                // Icon
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                // Title
                Text("Sign In to Publish")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                // Message
                Text("Share your content with the sailing community. Sign in to get started.")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                
                Spacer()
                
                // Error display
                if let error = appError {
                    ErrorBanner(
                        error: error,
                        onDismiss: { appError = nil },
                        onRetry: nil
                    )
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
                
                // Sign in button
                VStack(spacing: DesignSystem.Spacing.md) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.email, .fullName]
                        },
                        onCompletion: { result in
                            Task {
                                await handleSignIn(result: result)
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .frame(maxWidth: 375)
                    .disabled(isLoading)
                    .cornerRadius(12)
                    
                    if isLoading {
                        ProgressView()
                            .padding(.top, DesignSystem.Spacing.sm)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        appError = nil
        
        do {
            try await authService.handleAppleSignIn(result: result)
            // Success - call callback and dismiss
            onSuccess()
            onDismiss()
        } catch {
            appError = error.toAppError()
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview("Sign In Modal") {
    SignInModalView(
        onSuccess: {},
        onDismiss: {}
    )
}

