import Foundation
import SwiftUI
import AuthenticationServices
import PhotosUI

// MARK: - Profile View Model

@MainActor
@Observable
final class ProfileViewModel: ErrorHandling {
    private let authService: AuthServiceProtocol
    private let apiClient: APIClientProtocol?
    private var imageUploadService: ImageUploadService?
    let authObserver: AuthStateObserverProtocol
    /// Clears local GRDB data and reloads stores after successful server-side account deletion.
    private let clearLocalDataAfterAccountDeletion: (@MainActor () async throws -> Void)?

    var currentError: AppError?
    var showErrorBanner: Bool = false
    var isLoading = false
    var isDeletingAccount = false

    // Captain stats (Phase 2)
    var captainStats: CaptainStats?

    // Phase 2: Reputation metrics (kept for existing MetricsCard)
    var contributionMetrics: ContributionMetrics?

    // Profile editing
    var isEditingProfile = false
    var editedUsername = ""
    var editedBio = ""
    var editedLocation = ""
    var editedNationality = ""
    var isSavingProfile = false

    // Social links editing
    var editedSocialLinks: [SocialLink] = []

    /// Communities the user manages (virtual captain / publish-on-behalf).
    var managedCommunities: [ManagedCommunity] = []

    // Community state
    var communities: [CommunityMembership] { currentUser?.communities ?? [] }
    var editedCommunities: [CommunityMembership] = []
    var communitySearchResults: [CommunitySearchResult] = []
    var isSearchingCommunities: Bool = false
    var showCommunitySearch: Bool = false

    // Profile image
    var selectedPhotoItem: PhotosPickerItem?
    var isUploadingImage = false

    var isSignedIn: Bool { authObserver.isSignedIn }
    var currentUser: UserInfo? { authObserver.currentUser }

    init(
        authService: AuthServiceProtocol,
        authObserver: AuthStateObserverProtocol? = nil,
        apiClient: APIClientProtocol? = nil,
        clearLocalDataAfterAccountDeletion: (@MainActor () async throws -> Void)? = nil
    ) {
        self.authService = authService
        self.authObserver = authObserver ?? AuthStateObserver(authService: authService)
        self.apiClient = apiClient
        self.clearLocalDataAfterAccountDeletion = clearLocalDataAfterAccountDeletion
        self.imageUploadService = ImageUploadService(authService: authService)
    }

    // MARK: - Auth

    func loadManagedCommunities() async {
        guard let apiClient, isSignedIn else {
            managedCommunities = []
            return
        }
        do {
            managedCommunities = try await apiClient.getManagedCommunities()
        } catch {
            managedCommunities = []
        }
    }

    func logout() async {
        isLoading = true
        defer { isLoading = false }
        await authService.logout()
    }

    func deleteAccount() async {
        isDeletingAccount = true
        clearError()
        defer { isDeletingAccount = false }
        do {
            try await authService.deleteAccount()
            if let clearLocalDataAfterAccountDeletion {
                try await clearLocalDataAfterAccountDeletion()
            }
            managedCommunities = []
            captainStats = nil
            contributionMetrics = nil
            cancelEditingProfile()
        } catch {
            handleError(error)
        }
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        clearError()
        defer { isLoading = false }
        do {
            try await authService.handleAppleSignIn(result: result)
        } catch {
            handleError(error)
        }
    }

    // MARK: - Profile Editing

    func startEditingProfile(user: UserInfo) {
        isEditingProfile = true
        editedUsername = user.username ?? ""
        editedBio = user.bio ?? ""
        editedLocation = user.location ?? ""
        editedNationality = user.nationality ?? ""
        editedSocialLinks = user.socialLinks ?? []
        editedCommunities = user.communities ?? []
        clearError()
    }

    func cancelEditingProfile() {
        isEditingProfile = false
        editedUsername = ""
        editedBio = ""
        editedLocation = ""
        editedNationality = ""
        editedSocialLinks = []
        editedCommunities = []
        selectedPhotoItem = nil
        clearError()
    }

    func saveProfile() async {
        guard !editedUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            handleError(AppError.validationFailed(field: "username", reason: L10n.Profile.displayNameEmpty))
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

            // Only send social links with non-empty handles
            let linksToSend = editedSocialLinks.filter { !$0.handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            _ = try await authService.updateProfile(
                username: trimmedUsername,
                bio: trimmedBio.isEmpty ? nil : trimmedBio,
                location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                nationality: trimmedNationality.isEmpty ? nil : trimmedNationality,
                profileVisibility: nil,
                socialLinks: linksToSend,
                communityMemberships: editedCommunities
            )
            isEditingProfile = false
            editedUsername = ""
            editedBio = ""
            editedLocation = ""
            editedNationality = ""
            editedSocialLinks = []
            editedCommunities = []
        } catch {
            handleError(error)
        }
    }

    // MARK: - Photo

    func handlePhotoSelection() async {
        guard let selectedPhotoItem,
              let imageUploadService else {
            AppLogger.services.warning("No photo item or image upload service available")
            return
        }

        AppLogger.services.info("Starting photo upload process")
        isUploadingImage = true
        clearError()
        defer {
            isUploadingImage = false
            self.selectedPhotoItem = nil
        }

        do {
            _ = try await imageUploadService.processAndUploadImage(selectedPhotoItem)
            AppLogger.services.info("Photo uploaded successfully")
        } catch {
            AppLogger.services.error("Photo upload failed", error: error)
            handleError(error)
        }
    }

    // MARK: - Profile Stats

    func loadProfileStats() async {
        guard let apiClient else { return }
        do {
            let stats = try await apiClient.fetchProfileStats()
            captainStats = buildStats(from: stats, communities: communities)
        } catch {
            AppLogger.services.warning("Failed to load profile stats: \(error.localizedDescription)")
        }
    }

    func buildStats(from stats: ProfileStatsAPIResponse, communities: [CommunityMembership]) -> CaptainStats {
        CaptainStats(
            chartersCompleted: stats.totalContributions,
            nauticalMiles: 0,
            daysAtSea: stats.daysAtSea,
            communitiesJoined: communities.count,
            regionsVisited: 0,
            contentPublished: stats.totalContributions
        )
    }

    // MARK: - Community Actions

    /// Searches communities with 300ms debounce — callers should call this after debouncing.
    func searchCommunities(query: String) async {
        guard let apiClient, query.count >= 2 else {
            communitySearchResults = []
            return
        }
        isSearchingCommunities = true
        defer { isSearchingCommunities = false }
        do {
            communitySearchResults = try await apiClient.searchCommunities(query: query, limit: 10)
        } catch {
            communitySearchResults = []
        }
    }

    /// Joins an existing community. Adds to `editedCommunities` in edit mode; calls API + reloads otherwise.
    func joinCommunity(result: CommunitySearchResult) async {
        guard let apiClient else { return }
        do {
            try await apiClient.joinCommunity(id: result.id)
            let isPrimary = communities.isEmpty && editedCommunities.isEmpty
            let membership = CommunityMembership(
                id: result.id,
                name: result.name,
                iconURL: result.iconURL,
                role: .member,
                isPrimary: isPrimary
            )
            if isEditingProfile {
                guard !editedCommunities.contains(where: { $0.id == result.id }) else { return }
                editedCommunities.append(membership)
            } else {
                await authService.loadCurrentUser()
            }
        } catch {
            handleError(error)
        }
    }

    /// Creates a new community and joins it atomically via the create-and-join endpoint.
    func createAndJoinCommunity(name: String) async {
        guard let apiClient else { return }
        do {
            let response = try await apiClient.createCommunity(name: name)
            let isPrimary = communities.isEmpty && editedCommunities.isEmpty
            let membership = CommunityMembership(
                id: response.communityId,
                name: response.communityName,
                iconURL: nil,
                role: response.role,
                isPrimary: isPrimary
            )
            if isEditingProfile {
                guard !editedCommunities.contains(where: { $0.id == response.communityId }) else { return }
                editedCommunities.append(membership)
            } else {
                await authService.loadCurrentUser()
            }
        } catch {
            handleError(error)
        }
    }

    /// Leaves a community. In edit mode, removes from local list; otherwise calls API + reloads.
    func leaveCommunity(id: String) async {
        if isEditingProfile {
            editedCommunities.removeAll { $0.id == id }
            promoteFirstCommunityIfNeeded(in: &editedCommunities)
        } else {
            guard let apiClient else { return }
            do {
                try await apiClient.leaveCommunity(id: id)
                await authService.loadCurrentUser()
            } catch {
                handleError(error)
            }
        }
    }

    /// Sets a community as primary. In edit mode, updates local list; otherwise calls profile update.
    func setPrimaryCommunity(id: String) async {
        if isEditingProfile {
            for i in editedCommunities.indices {
                editedCommunities[i].isPrimary = (editedCommunities[i].id == id)
            }
        } else {
            var updated = communities
            for i in updated.indices {
                updated[i].isPrimary = (updated[i].id == id)
            }
            do {
                _ = try await authService.updateProfile(
                    username: nil, bio: nil, location: nil, nationality: nil,
                    profileVisibility: nil, socialLinks: nil,
                    communityMemberships: updated
                )
            } catch {
                handleError(error)
            }
        }
    }

    // MARK: - Utilities

    func calculateProfileCompletion(for user: UserInfo) -> Int {
        var completedFields = 0
        let totalFields = 3
        completedFields += 1 // username always counted
        if user.profileImageUrl != nil { completedFields += 1 }
        if let bio = user.bio, !bio.isEmpty { completedFields += 1 }
        return Int((Double(completedFields) / Double(totalFields)) * 100)
    }

    // MARK: - Private Helpers

    private func promoteFirstCommunityIfNeeded(in list: inout [CommunityMembership]) {
        guard !list.isEmpty, !list.contains(where: \.isPrimary) else { return }
        list[0].isPrimary = true
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
