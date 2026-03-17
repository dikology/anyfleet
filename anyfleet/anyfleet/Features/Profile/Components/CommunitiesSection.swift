import SwiftUI

// MARK: - Communities Section

/// Displays the user's community memberships as chips in a flow layout.
/// Shown in both display and edit mode. In edit mode the `isEditing` flag is true.
struct CommunitiesSection: View {
    let memberships: [CommunityMembership]
    let isEditing: Bool
    let onSetPrimary: (String) -> Void
    let onLeave: (String) -> Void
    let onAddTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.communityAccent)
                    Text(L10n.Profile.Communities.title)
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                Spacer()
                if !memberships.isEmpty {
                    Text("\(memberships.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.communityAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.communityAccent.opacity(0.15))
                        )
                }
            }

            if memberships.isEmpty {
                emptyState
            } else {
                chipsFlow
            }

            findCommunitiesButton
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Colors.border.opacity(0.5), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        Text(L10n.Profile.Communities.emptyState)
            .font(DesignSystem.Typography.caption)
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .padding(.vertical, DesignSystem.Spacing.xs)
    }

    private var chipsFlow: some View {
        FlowLayout(spacing: 8) {
            ForEach(memberships) { membership in
                communityChip(membership)
            }
        }
    }

    private func communityChip(_ membership: CommunityMembership) -> some View {
        Group {
            if membership.isPrimary {
                HStack(spacing: 4) {
                    Text("⚓")
                        .font(.system(size: 10))
                    CommunityBadge(name: membership.name, iconURL: membership.iconURL, style: .pill)
                }
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(DesignSystem.Colors.communityAccent, lineWidth: 1.5)
                )
            } else {
                CommunityBadge(name: membership.name, iconURL: membership.iconURL, style: .pill)
            }
        }
        .contextMenu {
            if !membership.isPrimary {
                Button {
                    onSetPrimary(membership.id)
                } label: {
                    Label(L10n.Profile.Communities.setAsPrimary, systemImage: "anchor")
                }
            }
            Button(role: .destructive) {
                onLeave(membership.id)
            } label: {
                Label(L10n.Profile.Communities.leave, systemImage: "person.fill.xmark")
            }
        }
    }

    private var findCommunitiesButton: some View {
        Button(action: onAddTapped) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(L10n.Profile.Communities.find)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(DesignSystem.Colors.primary)
        }
        .buttonStyle(.plain)
        .padding(.top, DesignSystem.Spacing.xs)
    }
}

// MARK: - Flow Layout

/// Simple wrapping horizontal layout for community chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > containerWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: containerWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview {
    CommunitiesSection(
        memberships: [
            CommunityMembership(id: "1", name: "Med Sailors", iconURL: nil, role: .member, isPrimary: true),
            CommunityMembership(id: "2", name: "Women Sailors", iconURL: nil, role: .member, isPrimary: false),
            CommunityMembership(id: "3", name: "Racing Crew", iconURL: nil, role: .moderator, isPrimary: false)
        ],
        isEditing: false,
        onSetPrimary: { _ in },
        onLeave: { _ in },
        onAddTapped: {}
    )
    .padding()
}
