import SwiftUI
import AuthenticationServices
import PhotosUI

// MARK: - Main View

@MainActor
struct ProfileView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: ProfileViewModel

    @MainActor
    init(viewModel: ProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                if viewModel.isSignedIn {
                    authenticatedContent
                } else {
                    unauthenticatedContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L10n.ProfileTab)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            .task {
                guard viewModel.isSignedIn else { return }
                async let stats = viewModel.loadProfileStats()
                async let managed = viewModel.loadManagedCommunities()
                _ = await (stats, managed)
            }
        }
        .sheet(isPresented: $viewModel.showCommunitySearch) {
            CommunitySearchSheet(viewModel: viewModel, isPresented: $viewModel.showCommunitySearch)
        }
    }

    // MARK: - Authenticated Content

    @ViewBuilder
    private var authenticatedContent: some View {
        if let user = viewModel.currentUser {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xxl) {
                    heroSection(user: user)
                    headerContentSection(user: user)
                    mainContent(user: user)
                    accountManagementSection
                        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                        .padding(.top, DesignSystem.Spacing.lg)
                }
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
        }
    }

    private func heroSection(user: UserInfo) -> some View {
        DesignSystem.Profile.Hero(
            user: user,
            onEditTap: { viewModel.startEditingProfile(user: user) }
        )
    }

    private func headerContentSection(user: UserInfo) -> some View {
        DesignSystem.Profile.HeaderContent(
            user: user,
            verificationTier: viewModel.contributionMetrics?.verificationTier,
            primaryCommunity: viewModel.communities.first(where: \.isPrimary),
            memberSince: formatDate(user.createdAt).map { L10n.Profile.memberSincePrefix + " " + $0 },
            onPhotoSelect: { item in
                viewModel.selectedPhotoItem = item
                Task { await viewModel.handlePhotoSelection() }
            },
            isUploadingImage: viewModel.isUploadingImage
        )
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.top, -48)
        .padding(.bottom, DesignSystem.Spacing.xl)
    }

    @ViewBuilder
    private func mainContent(user: UserInfo) -> some View {
        Group {
            if viewModel.isEditingProfile {
                editingContent
            } else {
                displayContent(user: user)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.top, DesignSystem.Spacing.md)
    }

    // MARK: - Edit Mode

    private var editingContent: some View {
        ProfileEditForm(
            username: $viewModel.editedUsername,
            bio: $viewModel.editedBio,
            location: $viewModel.editedLocation,
            nationality: $viewModel.editedNationality,
            socialLinks: $viewModel.editedSocialLinks,
            communities: $viewModel.editedCommunities,
            onSave: { Task { await viewModel.saveProfile() } },
            onCancel: { viewModel.cancelEditingProfile() },
            onAddCommunityTapped: { viewModel.showCommunitySearch = true },
            isSaving: viewModel.isSavingProfile
        )
    }

    // MARK: - Display Mode

    @ViewBuilder
    private func displayContent(user: UserInfo) -> some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            // Stats bar
            if let stats = viewModel.captainStats {
                ProfileStatsBar(stats: stats)
            }

            // Communities
            CommunitiesSection(
                memberships: viewModel.communities,
                isEditing: false,
                onSetPrimary: { id in Task { await viewModel.setPrimaryCommunity(id: id) } },
                onLeave: { id in Task { await viewModel.leaveCommunity(id: id) } },
                onAddTapped: { viewModel.showCommunitySearch = true }
            )

            if !viewModel.managedCommunities.isEmpty {
                NavigationLink(value: AppRoute.communityManager) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "person.3.sequence.fill")
                            .foregroundColor(DesignSystem.Colors.communityAccent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.CommunityManager.sectionTitle)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text(L10n.CommunityManager.sectionSubtitle)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.surface)
                    .cornerRadius(DesignSystem.Spacing.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.md)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            // Social links (bio and member since are in header)
            if let links = user.socialLinks {
                SocialLinksDisplaySection(links: links)
            }
        }

        if viewModel.showErrorBanner, let error = viewModel.currentError {
            ErrorBanner(error: error, onDismiss: { viewModel.clearError() }, onRetry: nil)
        }
    }

    // MARK: - Account Management

    private var accountManagementSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            DesignSystem.SectionLabel(L10n.Profile.accountTitle)
            Text(L10n.Profile.accountSubtitle)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: DesignSystem.Spacing.md) {
                accountActionButton(
                    icon: "trash.fill",
                    label: L10n.Profile.deleteAccount,
                    iconColor: DesignSystem.Colors.error,
                    action: {}
                )

                Divider().padding(.vertical, DesignSystem.Spacing.md)

                Button {
                    Task { await viewModel.logout() }
                } label: {
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
                    .padding(.vertical, DesignSystem.Spacing.md)
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
    }

    private func accountActionButton(
        icon: String,
        label: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).foregroundColor(iconColor).frame(width: 20)
                Text(label).foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .font(.system(size: 14))
            }
            .padding(.vertical, DesignSystem.Spacing.md)
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

    // MARK: - Unauthenticated

    private var unauthenticatedContent: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()
            VStack(spacing: DesignSystem.Spacing.xxxl) {
                Spacer()
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Text(L10n.Profile.welcomeTitle)
                        .font(DesignSystem.Typography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(L10n.Profile.welcomeSubtitle)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)

                Spacer()

                signInSection
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
            }
        }
    }

    private var signInSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            DesignSystem.SectionHeader(
                L10n.Profile.getStartedTitle,
                subtitle: L10n.Profile.getStartedSubtitle
            )

            VStack(spacing: DesignSystem.Spacing.lg) {
                SignInWithAppleButton(
                    onRequest: { $0.requestedScopes = [.email, .fullName] },
                    onCompletion: { result in
                        Task { await viewModel.handleAppleSignIn(result: result) }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .cornerRadius(DesignSystem.Spacing.md)
                .disabled(viewModel.isLoading)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .accessibilityIdentifier("sign_in_apple_button")

                if viewModel.isLoading {
                    ProgressView().tint(DesignSystem.Colors.primary)
                }

                if viewModel.showErrorBanner, let error = viewModel.currentError {
                    ErrorBanner(error: error, onDismiss: { viewModel.clearError() }, onRetry: nil)
                }
            }
        }
        .sectionContainer()
    }

    // MARK: - Utilities

    private func formatDate(_ dateString: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return nil }
        let display = DateFormatter()
        display.dateFormat = "MMMM yyyy"
        return display.string(from: date)
    }
}

// MARK: - Previews

#Preview("Unauthenticated") { @MainActor in
    let deps = try! AppDependencies.makeForTesting()
    let vm = ProfileViewModel(
        authService: deps.authService,
        authObserver: deps.authStateObserver,
        apiClient: deps.apiClient
    )
    return ProfileView(viewModel: vm)
        .environment(\.appDependencies, deps)
}

#Preview("Authenticated") { @MainActor in
    let deps = try! AppDependencies.makeForTesting()
    deps.authService.isAuthenticated = true
    deps.authService.currentUser = UserInfo(
        id: "user-123",
        email: "john.doe@example.com",
        username: "John Doe",
        createdAt: "2024-01-15T10:30:00Z",
        profileImageUrl: nil,
        profileImageThumbnailUrl: nil,
        bio: "Experienced sailor with 15 years on the water. Passionate about teaching newcomers the art of sailing.",
        location: "Cork, Ireland",
        nationality: "Irish",
        profileVisibility: "public",
        socialLinks: [
            SocialLink(platform: .instagram, handle: "john_sailor")
        ],
        communities: [
            CommunityMembership(id: "c1", name: "Med Sailors", iconURL: nil, role: .member, isPrimary: true),
            CommunityMembership(id: "c2", name: "Racing Crew", iconURL: nil, role: .member, isPrimary: false)
        ]
    )

    let vm = ProfileViewModel(
        authService: deps.authService,
        authObserver: deps.authStateObserver,
        apiClient: deps.apiClient
    )
    vm.captainStats = CaptainStats(
        chartersCompleted: 12,
        nauticalMiles: 0,
        daysAtSea: 34,
        communitiesJoined: 2,
        regionsVisited: 0,
        contentPublished: 8
    )

    return ProfileView(viewModel: vm)
        .environment(\.appDependencies, deps)
}
