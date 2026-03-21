import SwiftUI

struct VirtualCaptainPickerSheet: View {
    let apiClient: APIClientProtocol?
    let currentUser: UserInfo?
    let managedCommunities: [ManagedCommunity]
    @Binding var selectedCaptain: VirtualCaptain?

    @Environment(\.dismiss) private var dismiss
    @State private var loadedCaptains: [VirtualCaptain] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedCaptain = nil
                        dismiss()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            if let thumb = currentUser?.profileImageThumbnailUrl.flatMap(URL.init(string:)) {
                                CachedAsyncImage(url: thumb) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.fill")
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.Charter.Editor.PublishingAs.yourself)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text(L10n.Charter.Editor.PublishingAs.yourselfSubtitle)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }

                ForEach(managedCommunities) { community in
                    Section(community.name) {
                        let captains = loadedCaptains.filter { $0.communityId == community.id }
                        if captains.isEmpty {
                            Text(L10n.CommunityManager.noVirtualCaptainsYet)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        } else {
                            ForEach(captains) { vc in
                                Button {
                                    selectedCaptain = vc
                                    dismiss()
                                } label: {
                                    HStack(spacing: DesignSystem.Spacing.md) {
                                        CachedAsyncImage(url: vc.avatarThumbnailURL ?? vc.avatarURL) { img in
                                            img.resizable().scaledToFill()
                                        } placeholder: {
                                            Image(systemName: "person.fill")
                                                .foregroundStyle(.white)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .background(DesignSystem.Colors.communityAccent.opacity(0.4))
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())

                                        Text(vc.displayName)
                                            .foregroundColor(DesignSystem.Colors.textPrimary)
                                        Spacer()
                                        if selectedCaptain?.id == vc.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(DesignSystem.Colors.primary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.Charter.Editor.PublishingAs.pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
            }
            .task { await loadAllCaptains() }
        }
    }

    private func loadAllCaptains() async {
        guard let apiClient else { return }
        var acc: [VirtualCaptain] = []
        for c in managedCommunities {
            if let response = try? await apiClient.listVirtualCaptains(communityId: c.id, limit: 100, offset: 0) {
                acc.append(contentsOf: response.items)
            }
        }
        loadedCaptains = acc
    }
}
