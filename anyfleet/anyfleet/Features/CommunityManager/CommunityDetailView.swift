import SwiftUI

struct CommunityDetailView: View {
    let community: ManagedCommunity
    let apiClient: APIClientProtocol

    @State private var captains: [VirtualCaptain] = []
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var captainToEdit: VirtualCaptain?
    @State private var deleteError: String?
    @State private var showDeleteError = false
    @State private var captainSkeletonAnimating = false

    var body: some View {
        List {
            Section {
                HStack(spacing: DesignSystem.Spacing.md) {
                    CachedAsyncImage(url: community.iconURL) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(.white)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusMedium))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(community.name)
                            .font(DesignSystem.Typography.headline)
                        Text(L10n.CommunityManager.memberCount(community.memberCount))
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section(L10n.CommunityManager.virtualCaptainsSection) {
                if isLoading {
                    Group {
                        ForEach(0..<4, id: \.self) { _ in
                            DesignSystem.VirtualCaptainSkeletonRow(animating: captainSkeletonAnimating)
                        }
                    }
                    .onAppear {
                        withAnimation(DesignSystem.Motion.skeleton) {
                            captainSkeletonAnimating = true
                        }
                    }
                } else if captains.isEmpty {
                    Text(L10n.CommunityManager.noVirtualCaptainsYet)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                } else {
                    ForEach(captains) { vc in
                        Button {
                            captainToEdit = vc
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                CachedAsyncImage(url: vc.avatarThumbnailURL ?? vc.avatarURL) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                                Text(vc.displayName)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteCaptains)
                }
            }
        }
        .navigationTitle(community.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel(L10n.CommunityManager.addVirtualCaptain)
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                VirtualCaptainEditorView(
                    apiClient: apiClient,
                    community: community,
                    existingCaptain: nil,
                    onFinished: {
                        showCreate = false
                        Task { await loadCaptains() }
                    }
                )
            }
        }
        .animation(DesignSystem.Motion.standard, value: showCreate)
        .navigationDestination(item: $captainToEdit) { vc in
            VirtualCaptainEditorView(
                apiClient: apiClient,
                community: community,
                existingCaptain: vc,
                onFinished: {
                    captainToEdit = nil
                    Task { await loadCaptains() }
                }
            )
        }
        .alert(L10n.CommunityManager.deleteBlockedTitle, isPresented: $showDeleteError) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
        .task { await loadCaptains() }
        .refreshable {
            HapticEngine.impact(.light)
            await loadCaptains()
        }
    }

    private func loadCaptains() async {
        isLoading = true
        defer { isLoading = false }
        if let response = try? await apiClient.listVirtualCaptains(communityId: community.id, limit: 100, offset: 0) {
            captains = response.items
        } else {
            captains = []
        }
    }

    private func deleteCaptains(at offsets: IndexSet) {
        Task {
            for i in offsets {
                let vc = captains[i]
                do {
                    try await apiClient.deleteVirtualCaptain(communityId: community.id, captainId: vc.id)
                    await loadCaptains()
                } catch {
                    if let api = error as? APIError, case .conflict = api {
                        deleteError = L10n.CommunityManager.deleteBlockedMessage(vc.displayName)
                        showDeleteError = true
                    }
                }
            }
        }
    }
}
