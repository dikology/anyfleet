import SwiftUI

// MARK: - SyncStatus enum (charter display)

extension DesignSystem {
    enum SyncStatus {
        case synced, syncing, pending, failed, privateOnly

        var label: String {
            switch self {
            case .synced:      return "Synced"
            case .syncing:    return "Syncing..."
            case .pending:    return "Pending"
            case .failed:     return "Failed"
            case .privateOnly: return "Private"
            }
        }

        var icon: String {
            switch self {
            case .synced:      return "checkmark.circle.fill"
            case .syncing:    return "arrow.triangle.2.circlepath"
            case .pending:    return "clock.fill"
            case .failed:     return "exclamationmark.triangle.fill"
            case .privateOnly: return "lock.fill"
            }
        }

        var color: Color {
            switch self {
            case .synced:      return DesignSystem.Colors.success
            case .syncing:    return DesignSystem.Colors.gold
            case .pending:    return DesignSystem.Colors.communityAccent
            case .failed:     return DesignSystem.Colors.error
            case .privateOnly: return DesignSystem.Colors.textSecondary
            }
        }
    }

    // MARK: - Unified Sync Status Badge

    /// Unified sync status indicator for both library content and charters.
    /// - Synced: green lantern (dot with ping), no label
    /// - Syncing: yellow rotating arrows + "Syncing..." label
    /// - Pending: yellow clock (library only)
    /// - Failed: red icon with retry
    /// - Private: not shown (visibility badges handle it)
    struct SyncStatusBadge: View {
        let status: SyncStatus
        var onRetry: (() -> Void)? = nil

        var body: some View {
            Group {
                switch status {
                case .privateOnly:
                    EmptyView()

                case .synced:
                    syncedLantern
                        .accessibilityLabel("Synced")

                case .syncing:
                    SyncingBadgeContent()

                case .pending:
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                        Text("Pending")
                            .font(DesignSystem.Typography.micro)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(DesignSystem.Colors.communityAccent)
                    .accessibilityLabel("Pending sync")

                case .failed:
                    failedView
                }
            }
        }

        private var syncedLantern: some View {
            SyncedLanternView()
        }

        private var failedView: some View {
            Group {
                if let retry = onRetry {
                    Button(action: retry) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text("Failed")
                                .font(DesignSystem.Typography.micro)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(DesignSystem.Colors.error)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sync failed - tap to retry")
                } else {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                        Text("Failed")
                            .font(DesignSystem.Typography.micro)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(DesignSystem.Colors.error)
                    .accessibilityLabel("Sync failed")
                }
            }
        }
    }
}

// MARK: - ContentSyncStatus initializer

extension DesignSystem.SyncStatusBadge {
    /// Creates a badge from library content sync status.
    init(contentStatus: ContentSyncStatus, onRetry: (() -> Void)? = nil) {
        self.status = Self.statusFromContent(contentStatus)
        self.onRetry = onRetry
    }

    private static func statusFromContent(_ s: ContentSyncStatus) -> DesignSystem.SyncStatus {
        switch s {
        case .pending, .queued: return .pending
        case .syncing: return .syncing
        case .synced: return .synced
        case .failed: return .failed
        }
    }
}

// MARK: - CharterModel convenience

extension CharterModel {
    /// Derives display sync status from model fields.
    /// Returns .privateOnly when visibility is private (caller should hide badge).
    var syncStatus: DesignSystem.SyncStatus {
        guard visibility != .private else { return .privateOnly }
        if needsSync { return .pending }
        if lastSyncedAt != nil { return .synced }
        return .pending
    }
}

// MARK: - Synced lantern (green dot with ping)

private struct SyncedLanternView: View {
    @State private var pingScale: CGFloat = 1

    var body: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.Colors.success.opacity(0.75))
                .frame(width: 10, height: 10)
                .scaleEffect(pingScale)
                .opacity(max(0, 2 - pingScale))
            Circle()
                .fill(DesignSystem.Colors.success)
                .frame(width: 10, height: 10)
        }
        .frame(width: 10, height: 10)
        .onAppear {
            withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: true)) {
                pingScale = 1.8
            }
        }
    }
}

// MARK: - Syncing badge (rotating arrows)

private struct SyncingBadgeContent: View {
    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignSystem.Colors.gold)
                .rotationEffect(.degrees(rotation))
            Text("Syncing...")
                .font(DesignSystem.Typography.micro)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.gold)
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .accessibilityLabel("Syncing")
    }
}

// MARK: - Preview

#Preview("Sync Status Badges") {
    VStack(spacing: DesignSystem.Spacing.md) {
        HStack(spacing: DesignSystem.Spacing.lg) {
            DesignSystem.SyncStatusBadge(status: .synced)
            Text("Synced (icon only)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        DesignSystem.SyncStatusBadge(status: .syncing)
        DesignSystem.SyncStatusBadge(status: .pending)
        DesignSystem.SyncStatusBadge(status: .failed)
        DesignSystem.SyncStatusBadge(status: .failed, onRetry: {})
        DesignSystem.SyncStatusBadge(status: .privateOnly)
        HStack {
            DesignSystem.SyncStatusBadge(contentStatus: .synced)
            DesignSystem.SyncStatusBadge(contentStatus: .syncing)
        }
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
