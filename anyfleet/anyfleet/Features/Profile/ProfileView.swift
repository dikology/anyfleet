import SwiftUI
import AuthenticationServices

// MARK: - View Model

@Observable
final class ProfileViewModel {
    var appError: AppError?
    var isLoading = false

    // Phase 2: Reputation metrics
    var contributionMetrics: ContributionMetrics?

    // Profile editing
    var isEditingProfile = false
    var editedUsername = ""
    var isSavingProfile = false
    
    @MainActor
    func loadReputationMetrics() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // TODO: Call API when Phase 2 backend is ready
            // self.contributionMetrics = try await authService.fetchMetrics()
        } catch {
            appError = error.toAppError()
        }
    }
    
    @MainActor
    func logout(from authService: AuthService) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.logout()
        } catch {
            appError = error.toAppError()
        }
    }

    @MainActor
    func startEditingProfile(currentUsername: String?) {
        isEditingProfile = true
        editedUsername = currentUsername ?? ""
        appError = nil
    }

    @MainActor
    func cancelEditingProfile() {
        isEditingProfile = false
        editedUsername = ""
        appError = nil
    }

    @MainActor
    func saveProfile(from authService: AuthService) async {
        guard !editedUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            appError = AppError.validationFailed(field: "username", reason: "Display name cannot be empty")
            return
        }

        isSavingProfile = true
        appError = nil
        defer { isSavingProfile = false }

        do {
            _ = try await authService.updateProfile(username: editedUsername.trimmingCharacters(in: .whitespacesAndNewlines))
            isEditingProfile = false
            editedUsername = ""
        } catch {
            appError = error.toAppError()
        }
    }
    
    @MainActor
    func handleAppleSignIn(
        result: Result<ASAuthorization, Error>,
        authService: AuthService
    ) async {
        isLoading = true
        appError = nil
        defer { isLoading = false }
        
        do {
            try await authService.handleAppleSignIn(result: result)
            // Load metrics after successful sign-in
            await loadReputationMetrics()
        } catch {
            appError = error.toAppError()
        }
    }
}

// MARK: - Models

struct ContributionMetrics: Codable, Sendable {
    let totalContributions: Int
    let totalForks: Int
    let averageRating: Double
    let verificationTier: VerificationTier
    let createdCount: Int
    let forkedCount: Int
    let importedCount: Int
}

enum VerificationTier: String, Codable, Sendable {
    case new = "new"
    case contributor = "contributor"
    case trusted = "trusted"
    case expert = "expert"

    var displayName: String {
        switch self {
        case .new: L10n.Profile.VerificationTier.new
        case .contributor: L10n.Profile.VerificationTier.contributor
        case .trusted: L10n.Profile.VerificationTier.trusted
        case .expert: L10n.Profile.VerificationTier.expert
        }
    }
    
    var icon: String {
        switch self {
        case .new: "person.crop.circle"
        case .contributor: "person.crop.circle.fill"
        case .trusted: "checkmark.seal.fill"
        case .expert: "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .new: DesignSystem.Colors.textSecondary
        case .contributor: DesignSystem.Colors.primary
        case .trusted: DesignSystem.Colors.success
        case .expert: DesignSystem.Colors.warning
        }
    }
}

// MARK: - Main View

struct ProfileView: View {
    @Environment(\.authService) private var authService
    @State private var viewModel = ProfileViewModel()
    
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
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if authService.isAuthenticated {
                    await viewModel.loadReputationMetrics()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.ProfileTab)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
        }
    }
    
    // MARK: - Authenticated Content
    
    @MainActor
    private var authenticatedContent: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                if let user = authService.currentUser {
                    profileHeader(for: user)
                    
                    if let metrics = viewModel.contributionMetrics {
                        reputationSection(metrics: metrics)
                        contentOwnershipSection(metrics: metrics)
                    }
                    
                    accountManagementSection(user: user)
                }
                
                if let error = viewModel.appError {
                    ErrorBanner(
                        error: error,
                        onDismiss: { viewModel.appError = nil },
                        onRetry: nil
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
    }
    
    // MARK: - Profile Header (Redesigned)
    
    @MainActor
    private func profileHeader(for user: UserInfo) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Avatar with verification badge
            ZStack(alignment: .bottomTrailing) {
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

                // Verification badge overlay
                if let metrics = viewModel.contributionMetrics {
                    verificationBadge(tier: metrics.verificationTier)
                        .frame(width: 36, height: 36)
                        .offset(x: -8, y: -8)
                }
            }
            .padding(.top, DesignSystem.Spacing.md)

            // User info
            VStack(spacing: DesignSystem.Spacing.xs) {
                if viewModel.isEditingProfile {
                    // Editing mode
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text(L10n.Profile.displayNameTitle)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        TextField(L10n.Profile.displayNamePlaceholder, text: $viewModel.editedUsername)
                            .font(DesignSystem.Typography.largeTitle)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.surface.opacity(0.5))
                            .cornerRadius(DesignSystem.Spacing.sm)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.words)

                        HStack(spacing: DesignSystem.Spacing.md) {
                            Button(action: {
                                viewModel.cancelEditingProfile()
                            }) {
                                Text(L10n.Common.cancel)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DesignSystem.Spacing.sm)
                                    .background(DesignSystem.Colors.surface)
                                    .cornerRadius(DesignSystem.Spacing.sm)
                            }
                            .disabled(viewModel.isSavingProfile)

                            Button(action: {
                                Task {
                                    await viewModel.saveProfile(from: authService)
                                }
                            }) {
                                if viewModel.isSavingProfile {
                                    ProgressView()
                                        .tint(DesignSystem.Colors.onPrimary)
                                } else {
                                    Text(L10n.Common.save)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(DesignSystem.Colors.onPrimary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(DesignSystem.Gradients.primary)
                            .cornerRadius(DesignSystem.Spacing.sm)
                            .disabled(viewModel.isSavingProfile)
                        }
                    }
                } else {
                    // Display mode
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(user.username ?? user.email)
                                .font(DesignSystem.Typography.largeTitle)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .lineSpacing(1.0)

                            Text(user.email)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        Spacer()

                        Button(action: {
                            viewModel.startEditingProfile(currentUsername: user.username)
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.primary)
                                .frame(width: 32, height: 32)
                                .background(DesignSystem.Colors.surface)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                }

                if let createdAt = formatDate(user.createdAt) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .medium))
                        Text(L10n.Profile.memberSincePrefix + " " + createdAt)
                            .font(DesignSystem.Typography.caption)
                    }
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
    
    // MARK: - Verification Badge
    
    @MainActor
    private func verificationBadge(tier: VerificationTier) -> some View {
        ZStack {
            Circle()
                .fill(DesignSystem.Colors.surface)
                .shadow(color: DesignSystem.Colors.shadowStrong, radius: 4, x: 0, y: 2)
            
            Image(systemName: tier.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tier.color)
        }
    }
    
    // MARK: - Reputation Section (NEW)
    
    @MainActor
    private func reputationSection(metrics: ContributionMetrics) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            DesignSystem.SectionHeader(
                L10n.Profile.reputationTitle,
                subtitle: L10n.Profile.reputationSubtitle
            )
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Tier display
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: metrics.verificationTier.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(metrics.verificationTier.color)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.Profile.VerificationTier.verificationTierLabel)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text(metrics.verificationTier.displayName)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    Text(metrics.verificationTier.rawValue)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(metrics.verificationTier.color)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(metrics.verificationTier.color.opacity(0.1))
                        .cornerRadius(DesignSystem.Spacing.sm)
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surface)
                .cornerRadius(DesignSystem.Spacing.md)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.md)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
                
                // Metrics grid
                VStack(spacing: DesignSystem.Spacing.sm) {
                    metricRow(
                        icon: "doc.text.fill",
                        label: L10n.Profile.contributions,
                        value: "\(metrics.totalContributions)"
                    )

                    metricRow(
                        icon: "star.fill",
                        label: L10n.Profile.communityRating,
                        value: String(format: "%.1f/5.0", metrics.averageRating)
                    )

                    metricRow(
                        icon: "arrow.triangle.branch",
                        label: L10n.Profile.totalForks,
                        value: "\(metrics.totalForks)"
                    )
                }
            }
        }
        .sectionContainer()
    }
    
    // MARK: - Content Ownership Section (NEW)
    
    @MainActor
    private func contentOwnershipSection(metrics: ContributionMetrics) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            DesignSystem.SectionHeader(
                L10n.Profile.contentOwnershipTitle,
                subtitle: L10n.Profile.contentOwnershipSubtitle
            )
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                contentTypeRow(
                    icon: "pencil.circle.fill",
                    label: L10n.Profile.created,
                    count: metrics.createdCount,
                    color: DesignSystem.Colors.primary
                )

                contentTypeRow(
                    icon: "arrow.triangle.branch",
                    label: L10n.Profile.forked,
                    count: metrics.forkedCount,
                    color: DesignSystem.Colors.warning
                )

                contentTypeRow(
                    icon: "arrow.down.circle.fill",
                    label: L10n.Profile.imported,
                    count: metrics.importedCount,
                    color: DesignSystem.Colors.info
                )
            }
        }
        .sectionContainer()
    }
    
    // MARK: - Account Management Section
    
    @MainActor
    private func accountManagementSection(user: UserInfo) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            DesignSystem.SectionHeader(
                L10n.Profile.accountTitle,
                subtitle: L10n.Profile.accountSubtitle
            )
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Privacy settings button
//                accountActionButton(
//                    icon: "lock.fill",
//                    label: L10n.Profile.privacySettings,
//                    iconColor: DesignSystem.Colors.primary,
//                    action: { } // TODO: Navigate to privacy settings
//                )
                
                // Export data button
//                accountActionButton(
//                    icon: "icloud.and.arrow.down",
//                    label: L10n.Profile.exportData,
//                    iconColor: DesignSystem.Colors.success,
//                    action: { } // TODO: Implement data export
//                )
                
                // Activity log button
//                accountActionButton(
//                    icon: "clock.fill",
//                    label: L10n.Profile.activityLog,
//                    iconColor: DesignSystem.Colors.info,
//                    action: { } // TODO: Navigate to activity log
//                )
                
                // Danger zone: Delete account
                accountActionButton(
                    icon: "trash.fill",
                    label: L10n.Profile.deleteAccount,
                    iconColor: DesignSystem.Colors.error,
                    action: { } // TODO: Delete account flow
                )
                
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.sm)
                
                // Sign out button
                Button(action: {
                    Task {
                        await viewModel.logout(from: authService)
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
                .disabled(viewModel.isLoading)
            }
        }
        .sectionContainer()
    }
    
    // MARK: - Helper Components
    
    @MainActor
    private func metricRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 20)
            
            Text(label)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(DesignSystem.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }
    
    @MainActor
    private func contentTypeRow(
        icon: String,
        label: String,
        count: Int,
        color: Color
    ) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(label)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Spacer()
            
            Text("\(count)")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }
    
    @MainActor
    private func accountActionButton(
        icon: String,
        label: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 20)
                
                Text(label)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
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
    
    // MARK: - Unauthenticated Content
    
    @MainActor
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
    
    @MainActor
    private var signInSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            DesignSystem.SectionHeader(
                L10n.Profile.getStartedTitle,
                subtitle: L10n.Profile.getStartedSubtitle
            )
            
            VStack(spacing: DesignSystem.Spacing.md) {
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.email, .fullName]
                    },
                    onCompletion: { result in
                        Task {
                            await viewModel.handleAppleSignIn(result: result, authService: authService)
                        }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .cornerRadius(DesignSystem.Spacing.md)
                .disabled(viewModel.isLoading)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(DesignSystem.Colors.primary)
                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
                
                if let error = viewModel.appError {
                    ErrorBanner(
                        error: error,
                        onDismiss: { viewModel.appError = nil },
                        onRetry: nil
                    )
                }
            }
        }
        .sectionContainer()
    }
    
    // MARK: - Utilities
    
    @MainActor
    private func formatDate(_ dateString: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return nil }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM yyyy"
        return displayFormatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Unauthenticated") {
    ProfileView()
        .environment(\.authService, AuthService.shared)
}

#Preview("Authenticated") {
    ProfileView()
        .environment(\.authService, AuthService.shared)
}
