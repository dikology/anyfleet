import Foundation
@testable import anyfleet

/// Default community-manager API stubs so lightweight `APIClientProtocol` test mocks
/// do not need to implement every charter/community endpoint.
extension APIClientProtocol {
    func getManagedCommunities() async throws -> [ManagedCommunity] { [] }

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
        VirtualCaptain(
            id: captainId,
            communityId: communityId,
            displayName: "Captain",
            avatarURL: nil,
            avatarThumbnailURL: nil,
            socialLinks: [],
            createdAt: Date(),
            updatedAt: Date()
        )
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
}
