import SwiftUI
import AuthenticationServices
import PhotosUI

// MARK: - View Model

@MainActor
@Observable
final class ProfileViewModel: ErrorHandling {
    private let authService: AuthService
    private var imageUploadService: ImageUploadService?

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

    init(authService: AuthService) {
        self.authService = authService
        self.imageUploadService = ImageUploadService(authService: authService)
    }
    
    // @MainActor
    // func loadReputationMetrics() async {
    //     isLoading = true
    //     defer { isLoading = false }

    //     // TODO: Call API when Phase 2 backend is ready
    //     // do {
    //     //     self.contributionMetrics = try await dependencies.authService.fetchMetrics()
    //     // } catch {
    //     //     appError = error.toAppError()
    //     // }
    // }
    
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
                nationality: trimmedNationality.isEmpty ? nil : trimmedNationality
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
            return
        }
        
        isUploadingImage = true
        clearError()
        defer {
            isUploadingImage = false
            self.selectedPhotoItem = nil
        }
        
        do {
            _ = try await imageUploadService.processAndUploadImage(selectedPhotoItem)
        } catch {
            handleError(error)
        }
    }
    
    func calculateProfileCompletion(for user: UserInfo) -> Int {
        var completedFields = 0
        let totalFields = 5
        
        // Username is always filled (required)
        completedFields += 1
        
        if user.profileImageUrl != nil {
            completedFields += 1
        }
        if let bio = user.bio, !bio.isEmpty {
            completedFields += 1
        }
        if let location = user.location, !location.isEmpty {
            completedFields += 1
        }
        if let nationality = user.nationality, !nationality.isEmpty {
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
            // Load metrics after successful sign-in
            //await loadReputationMetrics()
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

@MainActor
struct ProfileView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: ProfileViewModel

    // Use the AuthStateObserver for reactive authentication state
    private var authObserver: AuthStateObserverProtocol {
        dependencies.authStateObserver
    }

    @MainActor
    init(viewModel: ProfileViewModel? = nil) {
        // Initialize with provided viewModel or create a placeholder
        let initialViewModel = viewModel ?? ProfileViewModel(authService: AuthService())
        _viewModel = State(initialValue: initialViewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                if authObserver.isSignedIn {
                    authenticatedContent(viewModel: viewModel)
                } else {
                    unauthenticatedContent(viewModel: viewModel)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Replace the placeholder viewModel with one using environment dependencies
                viewModel = ProfileViewModel(authService: dependencies.authService)
                if authObserver.isSignedIn {
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
                if let user = authObserver.currentUser {
                    profileHeader(for: user)
                    
                    if let metrics = viewModel.contributionMetrics {
                        reputationSection(metrics: metrics)
                        contentOwnershipSection(metrics: metrics)
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
    
    // MARK: - Profile Header
    
    @MainActor
    private func profileHeader(for user: UserInfo) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Hero image section
            ZStack(alignment: .bottom) {
                // Background image or gradient
                if let imageUrl = user.profileImageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                        case .failure, .empty:
                            placeholderHeroImage()
                        @unknown default:
                            placeholderHeroImage()
                        }
                    }
                } else {
                    placeholderHeroImage()
                }
                
                // Dark gradient overlay
                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
                
                // Profile image button overlay (bottom center)
                VStack {
                    Spacer()
                    
                    PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            if let imageUrl = user.profileImageThumbnailUrl, let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    case .failure, .empty:
                                        placeholderAvatar()
                                    @unknown default:
                                        placeholderAvatar()
                                    }
                                }
                            } else {
                                placeholderAvatar()
                            }
                            
                            // Camera button overlay
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(DesignSystem.Colors.primary)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .offset(x: 4, y: 4)
                            
                            // Verification badge
                            if let metrics = viewModel.contributionMetrics {
                                verificationBadge(tier: metrics.verificationTier)
                                    .frame(width: 32, height: 32)
                                    .offset(x: -4, y: 4)
                            }
                        }
                    }
                    .disabled(viewModel.isUploadingImage)
                    .onChange(of: viewModel.selectedPhotoItem) {
                        Task {
                            await viewModel.handlePhotoSelection()
                        }
                    }
                    .padding(.bottom, DesignSystem.Spacing.md)
                }
            }
            .frame(height: 200)
            .cornerRadius(DesignSystem.Spacing.md)
            .shadow(color: DesignSystem.Colors.shadowStrong, radius: 8, x: 0, y: 4)
            
            // Profile completion badge
            let completionPercentage = viewModel.calculateProfileCompletion(for: user)
            if completionPercentage < 100 {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 12))
                    Text(L10n.Profile.Completion.title(completionPercentage))
                        .font(DesignSystem.Typography.caption)
                }
                .foregroundColor(DesignSystem.Colors.warning)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.warning.opacity(0.1))
                .cornerRadius(DesignSystem.Spacing.sm)
            }

            // User info
            VStack(spacing: DesignSystem.Spacing.md) {
                if viewModel.isEditingProfile {
                    // Editing mode
                    editingProfileForm(user: user)
                } else {
                    // Display mode
                    displayProfileInfo(user: user)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.Spacing.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.lg)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
        .padding(.top, DesignSystem.Spacing.lg)
    }
    
    @MainActor
    private func placeholderHeroImage() -> some View {
        Rectangle()
            .fill(DesignSystem.Gradients.primary)
            .frame(height: 200)
    }
    
    @MainActor
    private func placeholderAvatar() -> some View {
        ZStack {
            Circle()
                .fill(DesignSystem.Gradients.primary)
                .frame(width: 100, height: 100)
            
            Circle()
                .fill(DesignSystem.Colors.onPrimary.opacity(0.2))
                .frame(width: 80, height: 80)
            
            Image(systemName: "person.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(DesignSystem.Gradients.primary)
        }
        .frame(width: 100, height: 100)
    }
    
    @MainActor
    private func editingProfileForm(user: UserInfo) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Username
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(L10n.Profile.displayNameTitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                TextField(L10n.Profile.displayNamePlaceholder, text: $viewModel.editedUsername)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.background)
                    .cornerRadius(DesignSystem.Spacing.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.words)
            }
            
            // Bio
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Text(L10n.Profile.Bio.title)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text(L10n.Profile.Bio.characterLimit(viewModel.editedBio.count))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(viewModel.editedBio.count > 2000 ? DesignSystem.Colors.error : DesignSystem.Colors.textSecondary)
                }
                
                TextEditor(text: $viewModel.editedBio)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(minHeight: 100)
                    .padding(DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.background)
                    .cornerRadius(DesignSystem.Spacing.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            }
            
            // Location
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(L10n.Profile.Location.title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                TextField(L10n.Profile.Location.placeholder, text: $viewModel.editedLocation)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.background)
                    .cornerRadius(DesignSystem.Spacing.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            }
            
            // Nationality
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(L10n.Profile.Nationality.title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                TextField(L10n.Profile.Nationality.placeholder, text: $viewModel.editedNationality)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.background)
                    .cornerRadius(DesignSystem.Spacing.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            }
            
            // Action buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: {
                    viewModel.cancelEditingProfile()
                }) {
                    Text(L10n.Common.cancel)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.surface)
                        .cornerRadius(DesignSystem.Spacing.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Spacing.md)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                }
                .disabled(viewModel.isSavingProfile)

                Button(action: {
                    Task {
                        await viewModel.saveProfile()
                    }
                }) {
                    if viewModel.isSavingProfile {
                        ProgressView()
                            .tint(DesignSystem.Colors.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                    } else {
                        Text(L10n.Common.save)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                    }
                }
                .background(DesignSystem.Gradients.primary)
                .cornerRadius(DesignSystem.Spacing.md)
                .disabled(viewModel.isSavingProfile || viewModel.editedBio.count > 2000)
            }
        }
    }
    
    @MainActor
    private func displayProfileInfo(user: UserInfo) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Username and email
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(user.username ?? user.email)
                        .font(DesignSystem.Typography.title)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(user.email)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                Button(action: {
                    viewModel.startEditingProfile(user: user)
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(width: 36, height: 36)
                        .background(DesignSystem.Colors.background)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                }
            }
            
            // Bio
            if let bio = user.bio, !bio.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(L10n.Profile.Bio.title)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text(bio)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Location and Nationality
            HStack(spacing: DesignSystem.Spacing.md) {
                if let location = user.location, !location.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text(location)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                
                if let nationality = user.nationality, !nationality.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text(nationality)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Member since
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
    ProfileView()
        .environment(AuthService())
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

    let viewModel = ProfileViewModel(authService: authService)
    viewModel.contributionMetrics = ContributionMetrics(
        totalContributions: 42,
        totalForks: 15,
        averageRating: 4.7,
        verificationTier: .expert,
        createdCount: 28,
        forkedCount: 12,
        importedCount: 2
    )

    return ProfileView(viewModel: viewModel)
}
