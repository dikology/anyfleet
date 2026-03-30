import SwiftUI

struct CommunityManagerView: View {
    let apiClient: APIClientProtocol

    @State private var communities: [ManagedCommunity] = []
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            Group {
                if isLoading {
                    loadingView
                } else if let loadError {
                    errorView(message: loadError)
                } else if communities.isEmpty {
                    emptyView
                } else {
                    communityList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            DesignSystem.Gradients.subtleBackground
                .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.CommunityManager.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
        }
        .task { await reload() }
        .refreshable {
            HapticEngine.impact(.light)
            await reload()
        }
    }

    // MARK: - States

    private var loadingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                DesignSystem.SectionHeader(
                    L10n.CommunityManager.sectionTitle,
                    subtitle: L10n.CommunityManager.sectionSubtitle
                )
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)

                ForEach(0..<5, id: \.self) { _ in
                    DesignSystem.CommunitySkeletonRow()
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
        }
    }

    private var emptyView: some View {
        DesignSystem.EmptyStateView(
            icon: "person.3.fill",
            title: L10n.CommunityManager.emptyStateTitle,
            message: L10n.CommunityManager.emptyStateMessage
        )
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DesignSystem.Typography.symbolPlateXL)
                .foregroundStyle(DesignSystem.Colors.error)

            Text(message)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            Button {
                Task { await reload() }
            } label: {
                Text(L10n.Common.retry)
                    .font(DesignSystem.Typography.subheader)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.primary)
                    .cornerRadius(DesignSystem.Spacing.cornerRadiusSmall)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xl)
    }

    private var communityList: some View {
        List {
            Section {
                ForEach(communities) { community in
                    NavigationLink {
                        CommunityDetailView(community: community, apiClient: apiClient)
                    } label: {
                        ManagedCommunityCardRow(community: community)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: DesignSystem.Spacing.lg, bottom: 6, trailing: DesignSystem.Spacing.lg))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } header: {
                DesignSystem.SectionHeader(
                    L10n.CommunityManager.sectionTitle,
                    subtitle: L10n.CommunityManager.sectionSubtitle
                )
                .padding(.top, DesignSystem.Spacing.xs)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        loadError = nil
        do {
            communities = try await apiClient.getManagedCommunities()
        } catch {
            loadError = error.localizedDescription
            communities = []
        }
    }
}

// MARK: - Row

private struct ManagedCommunityCardRow: View {
    let community: ManagedCommunity

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            communityThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(community.name)
                    .font(DesignSystem.Typography.subheader)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(L10n.CommunityManager.virtualCaptainCount(community.virtualCaptainCount))
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private var communityThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusCompact, style: .continuous)
                .fill(DesignSystem.Colors.primary.opacity(0.12))

            CachedAsyncImage(url: community.iconURL) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.3.fill")
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.primary.opacity(0.85))
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusCompact, style: .continuous))
    }
}

// MARK: - Previews

private extension ManagedCommunity {
    static var previewList: [ManagedCommunity] {
        [
            ManagedCommunity(
                id: UUID(uuidString: "550E8400-E29B-41D4-A716-446655440001")!,
                name: "Bluewater Cruisers",
                slug: "bluewater",
                iconURL: nil,
                memberCount: 240,
                virtualCaptainCount: 2,
                assignedAt: Date()
            ),
            ManagedCommunity(
                id: UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8")!,
                name: "Junior Sailing",
                slug: "junior",
                iconURL: nil,
                memberCount: 89,
                virtualCaptainCount: 0,
                assignedAt: Date()
            )
        ]
    }
}

/// Minimal `APIClientProtocol` for SwiftUI previews of community manager flows.
private final class CommunityManagerPreviewAPIClient: APIClientProtocol {
    enum ManagedCommunitiesOutcome {
        case success([ManagedCommunity])
        case failure
    }

    let managedCommunities: ManagedCommunitiesOutcome

    init(managedCommunities: ManagedCommunitiesOutcome) {
        self.managedCommunities = managedCommunities
    }

    func getManagedCommunities() async throws -> [ManagedCommunity] {
        switch managedCommunities {
        case .success(let list):
            return list
        case .failure:
            throw URLError(.notConnectedToInternet)
        }
    }

    func listVirtualCaptains(communityId: UUID, limit: Int, offset: Int) async throws -> VirtualCaptainListResponse {
        VirtualCaptainListResponse(items: [], total: 0, limit: limit, offset: offset)
    }

    func createVirtualCaptain(communityId: UUID, displayName: String, socialLinks: [SocialLink]) async throws -> VirtualCaptain {
        VirtualCaptain(
            id: UUID(),
            communityId: communityId,
            displayName: displayName,
            avatarURL: nil,
            avatarThumbnailURL: nil,
            socialLinks: socialLinks,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func updateVirtualCaptain(communityId: UUID, captainId: UUID, displayName: String?, socialLinks: [SocialLink]?) async throws -> VirtualCaptain {
        VirtualCaptain(
            id: captainId,
            communityId: communityId,
            displayName: displayName ?? "Captain",
            avatarURL: nil,
            avatarThumbnailURL: nil,
            socialLinks: socialLinks ?? [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func deleteVirtualCaptain(communityId: UUID, captainId: UUID) async throws {}

    func uploadVirtualCaptainAvatar(communityId: UUID, captainId: UUID, imageData: Data, filename: String) async throws -> VirtualCaptain {
        try await updateVirtualCaptain(communityId: communityId, captainId: captainId, displayName: nil, socialLinks: nil)
    }

    func uploadCommunityIcon(communityId: UUID, imageData: Data, filename: String) async throws -> CommunityAPIResponse {
        CommunityAPIResponse(
            id: communityId,
            name: "",
            slug: "",
            description: nil,
            iconURL: nil,
            communityType: "open",
            memberCount: 0,
            createdAt: Date()
        )
    }

    func publishContent(
        title: String,
        description: String?,
        contentType: String,
        contentData: [String: Any],
        tags: [String],
        language: String,
        publicID: String,
        canFork: Bool,
        forkedFromID: UUID?
    ) async throws -> PublishContentResponse {
        PublishContentResponse(id: UUID(), publicID: publicID, publishedAt: Date(), authorUsername: "preview", authorUserId: nil, canFork: canFork)
    }

    func unpublishContent(publicID: String) async throws {}

    func fetchPublicContent() async throws -> [SharedContentSummary] { [] }

    func fetchPublicContent(publicID: String) async throws -> SharedContentDetail {
        SharedContentDetail(
            id: UUID(),
            title: "Preview",
            description: nil,
            contentType: "checklist",
            contentData: [:],
            tags: [],
            publicID: publicID,
            canFork: true,
            authorUsername: "preview",
            authorUserId: nil,
            viewCount: 0,
            forkCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func incrementForkCount(publicID: String) async throws {}

    func updatePublishedContent(
        publicID: String,
        title: String,
        description: String?,
        contentType: String,
        contentData: [String: Any],
        tags: [String],
        language: String
    ) async throws -> UpdateContentResponse {
        UpdateContentResponse(id: UUID(), publicID: publicID, updatedAt: Date())
    }

    func fetchPublicProfile(username: String) async throws -> PublicProfileResponse {
        PublicProfileResponse(
            id: UUID(),
            username: username,
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            isVerified: false,
            verificationTier: nil,
            createdAt: Date(),
            stats: PublicProfileStatsResponse(totalContributions: 0, averageRating: nil, totalForks: 0),
            socialLinks: nil,
            primaryCommunity: nil
        )
    }

    func fetchPublicProfileByUserId(_ userId: UUID) async throws -> PublicProfileResponse {
        try await fetchPublicProfile(username: "user-\(userId.uuidString.prefix(8))")
    }

    func fetchProfileStats() async throws -> ProfileStatsAPIResponse {
        ProfileStatsAPIResponse(totalContributions: 0, averageRating: nil, totalForks: 0, communitiesJoined: 0, daysAtSea: 0)
    }

    func searchCommunities(query: String, limit: Int) async throws -> [CommunitySearchResult] { [] }

    func createCommunity(name: String) async throws -> CreateAndJoinCommunityResponse {
        CreateAndJoinCommunityResponse(communityId: UUID().uuidString, communityName: name, role: .member, message: "Joined community")
    }

    func joinCommunity(id: String) async throws {}
    func leaveCommunity(id: String) async throws {}

    func createCharter(_ request: CharterCreateRequest) async throws -> CharterAPIResponse {
        CharterAPIResponse(
            id: UUID(),
            userId: UUID(),
            name: request.name,
            boatName: nil,
            locationText: nil,
            startDate: request.startDate,
            endDate: request.endDate,
            latitude: nil,
            longitude: nil,
            locationPlaceId: nil,
            visibility: "private",
            createdAt: Date(),
            updatedAt: Date(),
            virtualCaptainId: nil
        )
    }

    func fetchMyCharters() async throws -> CharterListAPIResponse {
        CharterListAPIResponse(items: [], total: 0, limit: 20, offset: 0)
    }

    func fetchCharter(id: UUID) async throws -> CharterAPIResponse {
        CharterAPIResponse(
            id: id,
            userId: UUID(),
            name: "Preview",
            boatName: nil,
            locationText: nil,
            startDate: Date(),
            endDate: Date(),
            latitude: nil,
            longitude: nil,
            locationPlaceId: nil,
            visibility: "private",
            createdAt: Date(),
            updatedAt: Date(),
            virtualCaptainId: nil
        )
    }

    func updateCharter(id: UUID, request: CharterUpdateRequest) async throws -> CharterAPIResponse {
        try await fetchCharter(id: id)
    }

    func deleteCharter(id: UUID) async throws {}

    func discoverCharters(
        dateFrom: Date?,
        dateTo: Date?,
        nearLat: Double?,
        nearLon: Double?,
        radiusKm: Double,
        sortBy: String,
        limit: Int,
        offset: Int
    ) async throws -> CharterDiscoveryAPIResponse {
        CharterDiscoveryAPIResponse(items: [], total: 0, limit: limit, offset: offset)
    }
}

#Preview("With communities") { @MainActor in
    NavigationStack {
        CommunityManagerView(apiClient: CommunityManagerPreviewAPIClient(managedCommunities: .success(ManagedCommunity.previewList)))
    }
}

#Preview("Empty") { @MainActor in
    NavigationStack {
        CommunityManagerView(apiClient: CommunityManagerPreviewAPIClient(managedCommunities: .success([])))
    }
}

#Preview("Load error") { @MainActor in
    NavigationStack {
        CommunityManagerView(apiClient: CommunityManagerPreviewAPIClient(managedCommunities: .failure))
    }
}
