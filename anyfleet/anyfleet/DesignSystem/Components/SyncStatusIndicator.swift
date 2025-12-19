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
    
    var body: some View {
        Group {
            switch syncStatus {
            case .pending, .queued:
                Image(systemName: "clock.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.warning)
                    .help("Syncing...")
                
            case .synced:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.success)
                    .help("Synced")
                
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.error)
                    .help("Sync failed - tap to retry")
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

