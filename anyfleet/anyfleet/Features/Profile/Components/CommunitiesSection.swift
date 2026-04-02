import SwiftUI

// MARK: - Communities Section

/// Displays the user's community memberships as identity card rows.
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
                DesignSystem.SectionLabel(L10n.Profile.Communities.title)
                Spacer()
                if !memberships.isEmpty {
                    Text("\(memberships.count)")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.communityAccent)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xss + 1)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.communityAccent.opacity(0.15))
                        )
                }
            }

            if memberships.isEmpty {
                emptyState
            } else {
                membershipList
            }

            findCommunitiesButton
        }
    }

    private var emptyState: some View {
        Text(L10n.Profile.Communities.emptyState)
            .font(DesignSystem.Typography.caption)
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .padding(.vertical, DesignSystem.Spacing.xs)
    }

    private var membershipList: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(memberships) { membership in
                CommunityMembershipRow(
                    membership: membership,
                    onSetPrimary: { onSetPrimary(membership.id) },
                    onLeave: { onLeave(membership.id) }
                )
            }
        }
    }

    private var findCommunitiesButton: some View {
        Button(action: onAddTapped) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "plus.circle.fill")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
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

// MARK: - Community Membership Row

/// Identity card row for a single community membership.
/// Shows a leading accent bar, community icon, name, role badge, and a trailing action control.
struct CommunityMembershipRow: View {
    let membership: CommunityMembership
    let onSetPrimary: () -> Void
    let onLeave: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            accentBar

            communityIcon
                .padding(.leading, DesignSystem.Spacing.md)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xss) {
                Text(membership.name)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                if membership.role != .member {
                    roleBadge
                }
            }
            .padding(.leading, DesignSystem.Spacing.md)

            Spacer(minLength: DesignSystem.Spacing.sm)

            trailingControl
                .padding(.trailing, DesignSystem.Spacing.md)
        }
        .frame(minHeight: 60)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius, style: .continuous)
                .fill(DesignSystem.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                )
        )
        .contextMenu {
            if membership.isPrimary {
                Button(role: .destructive) { onLeave() } label: {
                    Label(L10n.Profile.Communities.leave, systemImage: "person.fill.xmark")
                }
            }
        }
    }

    private var accentBar: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(membership.isPrimary ? DesignSystem.Colors.communityAccent : Color.clear)
            .frame(width: 3)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .padding(.leading, DesignSystem.Spacing.xs)
    }

    private var communityIcon: some View {
        CachedAsyncImage(url: membership.iconURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                DesignSystem.Colors.hashColor(for: membership.id)
                Text(String(membership.name.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private var roleBadge: some View {
        Text(membership.role == .moderator
             ? L10n.Profile.Communities.roleModerator
             : L10n.Profile.Communities.roleFounder)
            .font(DesignSystem.Typography.caption)
            .fontWeight(.medium)
            .foregroundColor(DesignSystem.Colors.communityAccent)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xss)
            .background(Capsule().fill(DesignSystem.Colors.communityAccent.opacity(0.15)))
    }

    @ViewBuilder
    private var trailingControl: some View {
        if membership.isPrimary {
            Image(systemName: "star.fill")
                .font(DesignSystem.Typography.captionSemibold)
                .foregroundColor(DesignSystem.Colors.communityAccent)
        } else {
            Menu {
                Button { onSetPrimary() } label: {
                    Label(L10n.Profile.Communities.setAsPrimary, systemImage: "anchor")
                }
                Button(role: .destructive) { onLeave() } label: {
                    Label(L10n.Profile.Communities.leave, systemImage: "person.fill.xmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
    }
}

// MARK: - Flow Layout

/// Simple wrapping horizontal layout for community chips
struct FlowLayout: Layout {
    var spacing: CGFloat = DesignSystem.Spacing.sm

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

#Preview("Display") {
    CommunitiesSection(
        memberships: [
            CommunityMembership(id: "1", name: "Med Sailors", iconURL: nil, role: .member, isPrimary: true),
            CommunityMembership(id: "2", name: "Women Sailors", iconURL: nil, role: .moderator, isPrimary: false),
            CommunityMembership(id: "3", name: "RBYC Racing School", iconURL: nil, role: .founder, isPrimary: false)
        ],
        isEditing: false,
        onSetPrimary: { _ in },
        onLeave: { _ in },
        onAddTapped: {}
    )
    .padding()
    .background(DesignSystem.Colors.background)
}

#Preview("Empty") {
    CommunitiesSection(
        memberships: [],
        isEditing: false,
        onSetPrimary: { _ in },
        onLeave: { _ in },
        onAddTapped: {}
    )
    .padding()
    .background(DesignSystem.Colors.background)
}

#Preview("Edit mode") {
    CommunitiesSection(
        memberships: [
            CommunityMembership(id: "1", name: "Med Sailors", iconURL: nil, role: .member, isPrimary: true)
        ],
        isEditing: true,
        onSetPrimary: { _ in },
        onLeave: { _ in },
        onAddTapped: {}
    )
    .padding()
    .background(DesignSystem.Colors.background)
}
