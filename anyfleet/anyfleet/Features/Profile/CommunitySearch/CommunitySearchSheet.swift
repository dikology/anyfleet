import SwiftUI

// MARK: - Community Search Sheet

/// Sheet for searching and joining communities, or creating a new one.
/// Presented from CommunitiesSection's "+ Find Communities" button.
struct CommunitySearchSheet: View {
    @Bindable var viewModel: ProfileViewModel
    @Binding var isPresented: Bool

    @State private var searchQuery = ""
    @State private var searchResults: [CommunitySearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField

                if searchQuery.isEmpty {
                    emptyPrompt
                } else if isSearching {
                    loadingView
                } else {
                    resultsList
                }

                Spacer()
            }
            .navigationTitle(L10n.Profile.CommunitySearch.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Profile.CommunitySearch.done) { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Views

    private var searchField: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DesignSystem.Colors.textSecondary)
            TextField(L10n.Profile.CommunitySearch.placeholder, text: $searchQuery)
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .onChange(of: searchQuery) { _, newValue in
                    triggerDebouncedSearch(query: newValue)
                }
            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous))
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    private var emptyPrompt: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "person.3")
                .font(DesignSystem.Typography.symbolPlateMD)
                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.5))
            Text(L10n.Profile.CommunitySearch.emptyPrompt)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DesignSystem.Spacing.xxl)
    }

    private var loadingView: some View {
        ProgressView()
            .tint(DesignSystem.Colors.primary)
            .padding(.top, DesignSystem.Spacing.xxl)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var resultsList: some View {
        let alreadyMember = Set((viewModel.isEditingProfile ? viewModel.editedCommunities : viewModel.communities).map(\.id))
        let filteredResults = searchResults.filter { !alreadyMember.contains($0.id) }

        List {
            ForEach(filteredResults) { result in
                CommunityResultRow(result: result) {
                    handleJoin(result: result)
                }
            }

            // Create row — shown only when no matches and ≥3 chars typed
            if filteredResults.isEmpty, searchQuery.count >= 3, !isSearching {
                createCommunityRow
            }
        }
        .listStyle(.plain)
    }

    private var createCommunityRow: some View {
        Button {
            handleCreate(name: searchQuery.trimmingCharacters(in: .whitespacesAndNewlines))
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous)
                        .fill(DesignSystem.Colors.communityAccent.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(DesignSystem.Typography.subheader)
                        .foregroundColor(DesignSystem.Colors.communityAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Profile.CommunitySearch.createCommunity(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)))
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(L10n.Profile.CommunitySearch.startNew)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .listRowBackground(DesignSystem.Colors.background)
    }

    // MARK: - Actions

    private func triggerDebouncedSearch(query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            isSearching = true
            defer { isSearching = false }
            await viewModel.searchCommunities(query: query)
            searchResults = viewModel.communitySearchResults
        }
    }

    private func handleJoin(result: CommunitySearchResult) {
        Task {
            await viewModel.joinCommunity(result: result)
            isPresented = false
        }
    }

    private func handleCreate(name: String) {
        guard !name.isEmpty else { return }
        Task {
            await viewModel.createAndJoinCommunity(name: name)
            isPresented = false
        }
    }
}

// MARK: - Community Result Row

struct CommunityResultRow: View {
    let result: CommunitySearchResult
    let onJoin: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            CommunityBadge(name: result.name, iconURL: result.iconURL, style: .icon)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                HStack(spacing: 4) {
                    Text("\(result.memberCount) \(result.memberCount == 1 ? L10n.Profile.CommunitySearch.member : L10n.Profile.CommunitySearch.members)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("·")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(result.isOpen ? L10n.Profile.CommunitySearch.open : L10n.Profile.CommunitySearch.moderated)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(result.isOpen ? DesignSystem.Colors.success : DesignSystem.Colors.warning)
                }
            }

            Spacer()

            Button(action: onJoin) {
                Text(L10n.Profile.CommunitySearch.join)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.onPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(DesignSystem.Colors.primary)
                    .clipShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .listRowBackground(DesignSystem.Colors.background)
    }
}

#Preview("Result row") {
    List {
        CommunityResultRow(
            result: CommunitySearchResult(
                id: "demo",
                name: "Baltic Cruisers",
                iconURL: nil,
                memberCount: 42,
                isOpen: true
            ),
            onJoin: {}
        )
    }
    .listStyle(.plain)
}

// MARK: - Previews (sheet)

@MainActor
private struct CommunitySearchSheetPreviewContainer: View {
    @State private var presented = true
    private let deps: AppDependencies
    private let vm: ProfileViewModel

    init() {
        let d = try! AppDependencies.makeForTesting()
        d.authService.isAuthenticated = true
        deps = d
        vm = ProfileViewModel(
            authService: d.authService,
            authObserver: d.authStateObserver,
            apiClient: d.apiClient
        )
    }

    var body: some View {
        CommunitySearchSheet(viewModel: vm, isPresented: $presented)
            .environment(\.appDependencies, deps)
    }
}

#Preview("Community search sheet") {
    CommunitySearchSheetPreviewContainer()
}
