import SwiftUI
import AuthenticationServices
import PhotosUI

// MARK: - View Model

@Observable
final class ProfileViewModel: ErrorHandling {
    private let authService: AuthServiceProtocol
    private var imageUploadService: ImageUploadService?
    let authObserver: AuthStateObserverProtocol

    var currentError: AppError?
    var showErrorBanner: Bool = false
    var isLoading = false

    // Phase 2: Reputation metrics
    var contributionMetrics: ContributionMetrics?

    // Profile editing
    var isEditingProfile = false
    var editedUsername = ""
    var editedBio = ""
    var editedLocation = ""
    var editedNationality = ""
    var isSavingProfile = false

    // Profile image
    var selectedPhotoItem: PhotosPickerItem?
    var isUploadingImage = false

    // Auth state (exposed through viewModel for proper observation)
    var isSignedIn: Bool {
        authObserver.isSignedIn
    }

    var currentUser: UserInfo? {
        authObserver.currentUser
    }

    init(authService: AuthServiceProtocol, authObserver: AuthStateObserverProtocol? = nil) {
        self.authService = authService
        self.authObserver = authObserver ?? AuthStateObserver(authService: authService)
        self.imageUploadService = ImageUploadService(authService: authService)
    }
    
    @MainActor
    func logout() async {
        isLoading = true
        defer { isLoading = false }

        await authService.logout()
    }

    @MainActor
    func startEditingProfile(user: UserInfo) {
        isEditingProfile = true
        editedUsername = user.username ?? ""
        editedBio = user.bio ?? ""
        editedLocation = user.location ?? ""
        editedNationality = user.nationality ?? ""
        clearError()
    }

    @MainActor
    func cancelEditingProfile() {
        isEditingProfile = false
        editedUsername = ""
        editedBio = ""
        editedLocation = ""
        editedNationality = ""
        selectedPhotoItem = nil
        clearError()
    }

    @MainActor
    func saveProfile() async {
        guard !editedUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            handleError(AppError.validationFailed(field: "username", reason: "Display name cannot be empty"))
            return
        }

        isSavingProfile = true
        clearError()
        defer { isSavingProfile = false }

        do {
            let trimmedUsername = editedUsername.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBio = editedBio.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLocation = editedLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNationality = editedNationality.trimmingCharacters(in: .whitespacesAndNewlines)
            
            _ = try await authService.updateProfile(
                username: trimmedUsername,
                bio: trimmedBio.isEmpty ? nil : trimmedBio,
                location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                nationality: trimmedNationality.isEmpty ? nil : trimmedNationality,
                profileVisibility: nil
            )
            isEditingProfile = false
            editedUsername = ""
            editedBio = ""
            editedLocation = ""
            editedNationality = ""
        } catch {
            handleError(error)
        }
    }
    
    @MainActor
    func handlePhotoSelection() async {
        guard let selectedPhotoItem = selectedPhotoItem,
              let imageUploadService = imageUploadService else {
            AppLogger.services.warning("No photo item or image upload service available")
            return
        }

        AppLogger.services.info("Starting photo upload process")
        isUploadingImage = true
        clearError()
        defer {
            isUploadingImage = false
            self.selectedPhotoItem = nil
            AppLogger.services.debug("Photo upload process completed")
        }

        do {
            _ = try await imageUploadService.processAndUploadImage(selectedPhotoItem)
            AppLogger.services.info("Photo uploaded successfully")
        } catch {
            AppLogger.services.error("Photo upload failed", error: error)
            handleError(error)
        }
    }
    
    func calculateProfileCompletion(for user: UserInfo) -> Int {
        var completedFields = 0
        let totalFields = 3
        
        // Username is always filled (required)
        completedFields += 1
        
        if user.profileImageUrl != nil {
            completedFields += 1
        }
        if let bio = user.bio, !bio.isEmpty {
            completedFields += 1
        }
        
        return Int((Double(completedFields) / Double(totalFields)) * 100)
    }
    
    @MainActor
    func handleAppleSignIn(
        result: Result<ASAuthorization, Error>
    ) async {
        isLoading = true
        clearError()
        defer { isLoading = false }

        do {
            try await authService.handleAppleSignIn(result: result)
        } catch {
            handleError(error)
        }
    }
}

// MARK: - Models

struct ContributionMetrics: Codable, Sendable {
    let totalContributions: Int
    let totalForks: Int
    let averageRating: Double
    let verificationTier: DesignSystem.Profile.VerificationTier
    let createdCount: Int
    let forkedCount: Int
    let importedCount: Int
}

// MARK: - Main View

@MainActor
struct ProfileView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: ProfileViewModel

    @MainActor
    init(viewModel: ProfileViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            // Create a placeholder for previews and testing
            let deps = AppDependencies()
            _viewModel = State(initialValue: ProfileViewModel(authService: deps.authService, authObserver: deps.authStateObserver))
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                if viewModel.isSignedIn {
                    authenticatedContent(viewModel: viewModel)
                } else {
                    unauthenticatedContent(viewModel: viewModel)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if viewModel.isSignedIn {
                    // TODO: Load reputation metrics when Phase 2 backend is ready
                    // await loadReputationMetrics()
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
    private func authenticatedContent(viewModel: ProfileViewModel) -> some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                if let user = viewModel.currentUser {
                    DesignSystem.Profile.Hero(
                        user: user,
                        verificationTier: viewModel.contributionMetrics?.verificationTier,
                        completionPercentage: viewModel.calculateProfileCompletion(for: user),
                        onEditTap: { viewModel.startEditingProfile(user: user) },
                        onPhotoSelect: { item in
                            viewModel.selectedPhotoItem = item
                            Task { await viewModel.handlePhotoSelection() }
                        },
                        isUploadingImage: viewModel.isUploadingImage
                    )
                    .sectionContainer()

                    // Profile editing/display section
                    if viewModel.isEditingProfile {
                        // Editing mode
                        DesignSystem.Profile.EditForm(
                            username: $viewModel.editedUsername,
                            bio: $viewModel.editedBio,
                            location: $viewModel.editedLocation,
                            nationality: $viewModel.editedNationality,
                            onSave: {
                                Task { await viewModel.saveProfile() }
                            },
                            onCancel: {
                                viewModel.cancelEditingProfile()
                            },
                            isSaving: viewModel.isSavingProfile
                        )
                        .sectionContainer()
                    } else {
                        // Display mode
                        displayProfileInfo(user: user)
                    }
                    
                    if let metrics = viewModel.contributionMetrics {
                        DesignSystem.Profile.MetricsCard(
                            title: L10n.Profile.reputationTitle,
                            subtitle: L10n.Profile.reputationSubtitle,
                            metrics: [
                                .init(
                                    icon: "doc.text.fill",
                                    label: L10n.Profile.contributions,
                                    value: "\(metrics.totalContributions)",
                                    color: DesignSystem.Colors.primary
                                ),
                                .init(
                                    icon: "star.fill",
                                    label: L10n.Profile.communityRating,
                                    value: String(format: "%.1f/5.0", metrics.averageRating),
                                    color: DesignSystem.Colors.warning
                                ),
                                .init(
                                    icon: "arrow.triangle.branch",
                                    label: L10n.Profile.totalForks,
                                    value: "\(metrics.totalForks)",
                                    color: DesignSystem.Colors.info
                                )
                            ]
                        )
                        DesignSystem.Profile.MetricsCard(
                            title: L10n.Profile.contentOwnershipTitle,
                            subtitle: L10n.Profile.contentOwnershipSubtitle,
                            metrics: [
                                .init(
                                    icon: "pencil.circle.fill",
                                    label: L10n.Profile.created,
                                    value: "\(metrics.createdCount)",
                                    color: DesignSystem.Colors.primary
                                ),
                                .init(
                                    icon: "arrow.triangle.branch",
                                    label: L10n.Profile.forked,
                                    value: "\(metrics.forkedCount)",
                                    color: DesignSystem.Colors.warning
                                ),
                                .init(
                                    icon: "arrow.down.circle.fill",
                                    label: L10n.Profile.imported,
                                    value: "\(metrics.importedCount)",
                                    color: DesignSystem.Colors.info
                                )
                            ]
                        )
                    }
                    
                    accountManagementSection(user: user)
                }
                
                if viewModel.showErrorBanner, let error = viewModel.currentError {
                    ErrorBanner(
                        error: error,
                        onDismiss: { viewModel.clearError() },
                        onRetry: nil
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
    }
    
    @MainActor
    private func displayProfileInfo(user: UserInfo) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            
            // Bio Card
            if let bio = user.bio, !bio.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text(L10n.Profile.Bio.title)
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    Text(bio)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surfaceAlt)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignSystem.Colors.border.opacity(0.5), lineWidth: 1)
                )
            }

            // Member since badge
            if let createdAt = formatDate(user.createdAt) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.info)
                    Text(L10n.Profile.memberSincePrefix + " " + createdAt)
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.md)
                        .fill(DesignSystem.Colors.info.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Spacing.md)
                                .stroke(DesignSystem.Colors.info.opacity(0.3), lineWidth: 1)
                        )
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Maritime-themed decorative element
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(0..<3) { _ in
                    Image(systemName: "waveform.path")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.primary.opacity(0.3))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, DesignSystem.Spacing.sm)
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
                        await viewModel.logout()
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
    private func unauthenticatedContent(viewModel: ProfileViewModel) -> some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.xxl) {
                Spacer()
                
                // Typography-focused welcome message
                VStack(spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text(L10n.Profile.welcomeTitle)
                            .font(DesignSystem.Typography.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                        
                        Text(L10n.Profile.welcomeSubtitle)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                
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
                            await viewModel.handleAppleSignIn(result: result)
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
                
                if viewModel.showErrorBanner, let error = viewModel.currentError {
                    ErrorBanner(
                        error: error,
                        onDismiss: { viewModel.clearError() },
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

#Preview("Unauthenticated") { @MainActor in
    let authService = AuthService()
    let authObserver = AuthStateObserver(authService: authService)
    let viewModel = ProfileViewModel(authService: authService, authObserver: authObserver)
    return ProfileView(viewModel: viewModel)
}

#Preview("Authenticated") { @MainActor in
    let authService = AuthService()
    authService.isAuthenticated = true
    authService.currentUser = UserInfo(
        id: "user-123",
        email: "john.doe@example.com",
        username: "John Doe",
        createdAt: "2024-01-15T10:30:00Z",
        profileImageUrl: nil,
        profileImageThumbnailUrl: nil,
        bio: "Experienced sailor with 15 years on the water. Passionate about teaching newcomers the art of sailing and exploring the Mediterranean coast.",
        location: "Cork, Ireland",
        nationality: "Irish",
        profileVisibility: "public"
    )

    let authObserver = AuthStateObserver(authService: authService)
    let viewModel = ProfileViewModel(authService: authService, authObserver: authObserver)
    viewModel.contributionMetrics = ContributionMetrics(
        totalContributions: 42,
        totalForks: 15,
        averageRating: 4.7,
        verificationTier: DesignSystem.Profile.VerificationTier.expert,
        createdCount: 28,
        forkedCount: 12,
        importedCount: 2
    )

    return ProfileView(viewModel: viewModel)
}
