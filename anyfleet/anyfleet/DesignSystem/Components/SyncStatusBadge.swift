import SwiftUI

// MARK: - SyncStatus enum

extension DesignSystem {
    enum SyncStatus {
        case synced, pending, failed, privateOnly

        var label: String {
            switch self {
            case .synced:      return "Synced"
            case .pending:     return "Pending"
            case .failed:      return "Failed"
            case .privateOnly: return "Private"
            }
        }

        var icon: String {
            switch self {
            case .synced:      return "checkmark.circle.fill"
            case .pending:     return "arrow.clockwise"
            case .failed:      return "exclamationmark.triangle.fill"
            case .privateOnly: return "lock.fill"
            }
        }

        var color: Color {
            switch self {
            case .synced:      return DesignSystem.Colors.success
            case .pending:     return DesignSystem.Colors.communityAccent
            case .failed:      return DesignSystem.Colors.error
            case .privateOnly: return DesignSystem.Colors.textSecondary
            }
        }
    }

    // MARK: - Badge view

    /// Icon + label badge showing the sync state of a charter.
    struct SyncStatusBadge: View {
        let status: SyncStatus

        var body: some View {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: status.icon)
                    .font(.system(size: 11))
                Text(status.label)
                    .font(DesignSystem.Typography.micro)
                    .fontWeight(.semibold)
            }
            .foregroundColor(status.color)
            .accessibilityLabel("Sync status: \(status.label)")
        }
    }
}

// MARK: - CharterModel convenience

extension CharterModel {
    /// Derives display sync status from model fields.
    var syncStatus: DesignSystem.SyncStatus {
        guard visibility != .private else { return .privateOnly }
        if needsSync { return .pending }
        if lastSyncedAt != nil { return .synced }
        return .pending
    }
}

// MARK: - Preview

#Preview("Sync Status Badges") {
    VStack(spacing: DesignSystem.Spacing.md) {
        DesignSystem.SyncStatusBadge(status: .synced)
        DesignSystem.SyncStatusBadge(status: .pending)
        DesignSystem.SyncStatusBadge(status: .failed)
        DesignSystem.SyncStatusBadge(status: .privateOnly)
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
