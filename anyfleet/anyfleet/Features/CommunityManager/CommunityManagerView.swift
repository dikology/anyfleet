import SwiftUI

struct CommunityManagerView: View {
    let apiClient: APIClientProtocol

    @State private var communities: [ManagedCommunity] = []
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError {
                Text(loadError)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if communities.isEmpty {
                Text(L10n.CommunityManager.emptyManaged)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                List(communities) { community in
                    NavigationLink {
                        CommunityDetailView(community: community, apiClient: apiClient)
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            CachedAsyncImage(url: community.iconURL) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.3.fill")
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusCompact))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(community.name)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text(L10n.CommunityManager.virtualCaptainCount(community.virtualCaptainCount))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.CommunityManager.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
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
