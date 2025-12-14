import SwiftUI

struct CharterListView: View {
    @State private var charterStore = CharterStore()
    
    var body: some View {
        Group {
            if charterStore.charters.isEmpty {
                emptyState
            } else {
                charterList
            }
        }
        .navigationTitle("Charters")
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .task {
            await charterStore.loadCharters()
        }
        .onAppear {
            Task {
                await charterStore.loadCharters()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "sailboat")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Text("No charters yet")
                .font(DesignSystem.Typography.title)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text("Create your first charter to get started")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var charterList: some View {
        List {
            ForEach(charterStore.charters) { charter in
                CharterRowView(charter: charter)
                    .listRowInsets(EdgeInsets(
                        top: DesignSystem.Spacing.sm,
                        leading: DesignSystem.Spacing.lg,
                        bottom: DesignSystem.Spacing.sm,
                        trailing: DesignSystem.Spacing.lg
                    ))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct CharterRowView: View {
    let charter: CharterModel
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(charter.name)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                if let boatName = charter.boatName {
                    Text(boatName)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.surfaceAlt)
                        .cornerRadius(8)
                }
            }
            
            HStack(spacing: DesignSystem.Spacing.md) {
                Label {
                    Text(dateFormatter.string(from: charter.startDate))
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Text("→")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Label {
                    Text(dateFormatter.string(from: charter.endDate))
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Text("\(charter.durationDays) days")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            if let location = charter.location {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(location)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(12)
    }
}

#Preview {
    CharterListView()
}
