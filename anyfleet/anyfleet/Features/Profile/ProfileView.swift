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
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                if let user = authService.currentUser {
                    profileHeroCard(for: user)
                    profileActionsSection()
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
    }

    private func profileHeroCard(for user: UserInfo) -> some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Profile Avatar and Basic Info
            ZStack {
                Circle()
                    .fill(DesignSystem.Gradients.primary)
                    .frame(width: 120, height: 120)
                    .shadow(color: DesignSystem.Colors.shadowStrong, radius: 8, x: 0, y: 4)

                Circle()
                    .fill(DesignSystem.Colors.onPrimary.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(DesignSystem.Gradients.primary)
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(String(format: L10n.Profile.signedInAs, user.username ?? user.email))
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                Text(user.username ?? user.email)
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(user.email)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                if let createdAt = formatDate(user.createdAt) {
                    Text("\(L10n.Profile.memberSincePrefix) \(createdAt)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.border.opacity(0.3))
                        .cornerRadius(DesignSystem.Spacing.sm)
                }
            }
        }
        .heroCardStyle()
        .padding(.top, DesignSystem.Spacing.lg)
    }

    private func profileActionsSection() -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            DesignSystem.SectionHeader(L10n.Profile.accountTitle, subtitle: L10n.Profile.accountSubtitle)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: {
                    Task {
                        await authService.logout()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.right.square")
                            .foregroundColor(DesignSystem.Colors.error)
                        Text(L10n.Profile.signOut)
                            .foregroundColor(DesignSystem.Colors.error)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.surface)
                    .cornerRadius(DesignSystem.Spacing.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.md)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .sectionContainer()
    }

    private func formatDate(_ dateString: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return nil }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM yyyy"
        return displayFormatter.string(from: date)
    }
    
    // MARK: - Unauthenticated Content

    private var unauthenticatedContent: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xxl) {
                Spacer()

                DesignSystem.EmptyStateHero(
                    icon: "person.circle.fill",
                    title: L10n.Profile.welcomeTitle,
                    message: L10n.Profile.welcomeSubtitle,
                    accentColor: DesignSystem.Colors.primary
                )

                Spacer()

                VStack(spacing: DesignSystem.Spacing.lg) {
                    signInSection
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
        }
    }

    private var signInSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            DesignSystem.SectionHeader(L10n.Profile.getStartedTitle, subtitle: L10n.Profile.getStartedSubtitle)

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
                .frame(maxWidth: .infinity)
                .cornerRadius(DesignSystem.Spacing.md)
                .disabled(isLoading)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(DesignSystem.Colors.primary)
                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }

                if let error = appError {
                    ErrorBanner(
                        error: error,
                        onDismiss: { appError = nil },
                        onRetry: nil
                    )
                }
            }
        }
        .sectionContainer()
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

