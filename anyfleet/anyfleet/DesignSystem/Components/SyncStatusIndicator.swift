//
//  SyncStatusIndicator.swift
//  anyfleet
//
//  Component for displaying sync status of library content
//

import SwiftUI

/// Indicator component that displays the sync status of library content
/// Shows visual feedback for pending, syncing, synced, and failed states
struct SyncStatusIndicator: View {
    let syncStatus: ContentSyncStatus
    var onRetry: (() -> Void)? = nil
    
    var body: some View {
        Group {
            switch syncStatus {
            case .pending, .queued:
                Image(systemName: "clock.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.warning)
                    .help("Waiting to sync")

            case .syncing:
                ProgressView()
                    .scaleEffect(0.7)
                    .help("Syncing to server...")

            case .synced:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.success)
                    .help("Synced")
                
            case .failed:
                if let retryAction = onRetry {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.error)
                        .onTapGesture {
                            retryAction()
                        }
                        .help("Sync failed - tap to retry")
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.error)
                        .help("Sync failed")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Sync Status Indicators") {
    VStack(spacing: DesignSystem.Spacing.md) {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Text("Pending:")
            SyncStatusIndicator(syncStatus: .pending)
        }
        
        HStack(spacing: DesignSystem.Spacing.sm) {
            Text("Queued:")
            SyncStatusIndicator(syncStatus: .queued)
        }

        HStack(spacing: DesignSystem.Spacing.sm) {
            Text("Syncing:")
            SyncStatusIndicator(syncStatus: .syncing)
        }

        HStack(spacing: DesignSystem.Spacing.sm) {
            Text("Synced:")
            SyncStatusIndicator(syncStatus: .synced)
        }
        
        HStack(spacing: DesignSystem.Spacing.sm) {
            Text("Failed:")
            SyncStatusIndicator(syncStatus: .failed)
        }
    }
    .padding()
    .background(DesignSystem.Colors.background)
}

