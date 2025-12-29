import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @State private var authService = AuthService.shared
    @State private var appError: AppError?
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                if authService.isAuthenticated {
                    authenticatedContent
                } else {
                    unauthenticatedContent
                }
            }
            .navigationTitle(L10n.ProfileTab)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Authenticated Content
    
    private var authenticatedContent: some View {
        List {
            if let user = authService.currentUser {
                Section {
                    profileHeader(for: user)
                }
                
                Section {
                    Button(role: .destructive, action: {
                        Task {
                            await authService.logout()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text(L10n.Profile.signOut)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func profileHeader(for user: UserInfo) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 30))
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(user.username ?? user.email)
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(user.email)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    // MARK: - Unauthenticated Content
    
    private var unauthenticatedContent: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text(L10n.Profile.welcomeTitle)
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(L10n.Profile.welcomeSubtitle)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
            
            Spacer()
            
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
                
                if isLoading {
                    ProgressView()
                        .padding(.top, DesignSystem.Spacing.sm)
                }
                
                if let error = appError {
                    ErrorBanner(
                        error: error,
                        onDismiss: { appError = nil },
                        onRetry: nil
                    )
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }
    
    // MARK: - Actions
    
    private func handleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        appError = nil
        
        do {
            try await authService.handleAppleSignIn(result: result)
        } catch {
            appError = error.toAppError()
        }
        
        isLoading = false
    }
}

#Preview("Unauthenticated") {
    ProfileView()
}

#Preview("Authenticated") {
    let view = ProfileView()
    // Note: In a real preview, you'd need to mock AuthService
    return view
}

