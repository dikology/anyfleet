import SwiftUI

struct VirtualCaptainEditorView: View {
    let apiClient: APIClientProtocol
    let community: ManagedCommunity
    let existingCaptain: VirtualCaptain?
    var onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var socialLinks: [SocialLink] = []
    @State private var isSaving = false
    @State private var saveError: String?

    private var isEditing: Bool { existingCaptain != nil }

    var body: some View {
        Form {
            Section(L10n.CommunityManager.displayNameLabel) {
                TextField(L10n.CommunityManager.displayNameLabel, text: $displayName)
                    .textInputAutocapitalization(.words)
            }

            Section {
                SocialLinksSection(links: $socialLinks)
            }

            if let saveError {
                Section {
                    Text(saveError)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.error)
                }
            }
        }
        .navigationTitle(isEditing ? L10n.CommunityManager.editorTitleEdit : L10n.CommunityManager.editorTitleNew)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.Common.cancel) {
                    onFinished()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.Common.save) {
                    Task { await save() }
                }
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
        }
        .onAppear {
            if let vc = existingCaptain {
                displayName = vc.displayName
                socialLinks = vc.socialLinks
            }
        }
    }

    private func save() async {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        let linksToSend = socialLinks.filter { !$0.handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        do {
            if let existing = existingCaptain {
                _ = try await apiClient.updateVirtualCaptain(
                    communityId: community.id,
                    captainId: existing.id,
                    displayName: name,
                    socialLinks: linksToSend
                )
            } else {
                _ = try await apiClient.createVirtualCaptain(
                    communityId: community.id,
                    displayName: name,
                    socialLinks: linksToSend
                )
            }
            onFinished()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
