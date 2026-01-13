//
//  DiscoverContentReaderView.swift
//  anyfleet
//
//  Read-only view for public content from discover tab.
//

import SwiftUI

struct DiscoverContentReaderView: View {
    @State private var viewModel: DiscoverContentReaderViewModel
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.appCoordinator) private var coordinator

    init(viewModel: DiscoverContentReaderViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            Group {
                if let content = viewModel.parsedContent, let detail = viewModel.contentDetail {
                    contentView(for: content, detail: detail)
                } else if viewModel.isLoading {
                    ProgressView()
                        .tint(DesignSystem.Colors.primary)
                } else {
                    // Show loading state
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ProgressView()
                            .tint(DesignSystem.Colors.primary)
                        Text("Loading content...")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding()
                }
            }

            // Error Banner
            if viewModel.showErrorBanner, let error = viewModel.currentError {
                VStack {
                    Spacer()
                    ErrorBanner(
                        error: error,
                        onDismiss: { viewModel.clearError() },
                        onRetry: { Task { await viewModel.loadContent() } }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let title = viewModel.contentDetail?.title {
                    Text(title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                } else {
                    Text("Content")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if let detail = viewModel.contentDetail, detail.canFork {
                    Button(action: {
                        Task {
                            await forkContent(detail)
                        }
                    }) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
            }
        }
        .task {
            await viewModel.loadContent()
        }
    }

    // MARK: - Content Rendering

    @ViewBuilder
    private func contentView(for content: ParsedContent, detail: SharedContentDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Attribution header (if forked)
                if let originalAuthor = detail.originalAuthorUsername {
                    attributionView(originalAuthor: originalAuthor, originalContentID: detail.originalContentPublicID)
                }

                // Content based on type
                switch content {
                case .checklist(let checklist):
                    checklistContentView(for: checklist, detail: detail)
                case .practiceGuide(let guide):
                    practiceGuideContentView(for: guide, detail: detail)
                case .flashcardDeck:
                    // Flashcard decks not yet supported in discover
                    unsupportedContentView()
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
    }

    private func attributionView(originalAuthor: String, originalContentID: String?) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("Forked from")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Button(action: {
                // TODO: Navigate to original content or author profile
                // For now, just show author
            }) {
                Text(originalAuthor)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.primary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm)
                .fill(DesignSystem.Colors.primary.opacity(0.1))
        )
        .padding(.bottom, DesignSystem.Spacing.sm)
    }

    private func checklistContentView(for checklist: Checklist, detail: SharedContentDetail) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header
            headerView(for: checklist, detail: detail)

            // Sections
            ForEach(checklist.sections) { section in
                sectionView(for: section)
            }
        }
    }

    private func practiceGuideContentView(for guide: PracticeGuide, detail: SharedContentDetail) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(guide.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if let description = guide.description, !description.isEmpty {
                    Text(description)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Stats for practice guide
                HStack(spacing: DesignSystem.Spacing.sm) {
                    statBadge(
                        value: "\(detail.viewCount)",
                        label: detail.viewCount == 1 ? "View" : "Views"
                    )
                    statBadge(
                        value: "\(detail.forkCount)",
                        label: detail.forkCount == 1 ? "Fork" : "Forks"
                    )
                }
                .padding(.top, DesignSystem.Spacing.xs)
            }
            .padding(.bottom, DesignSystem.Spacing.md)

            // Markdown body
            markdownBody(from: guide.markdown)
        }
    }

    private func unsupportedContentView() -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("Content Type Not Supported")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("This content type is not yet supported in the discover view.")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Shared Components

    private func headerView(for checklist: Checklist, detail: SharedContentDetail) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Description
            if let description = checklist.description, !description.isEmpty {
                Text(description)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Metadata
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Type badge
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: checklist.checklistType.icon)
                        .font(.system(size: 12))
                    Text(checklist.checklistType.displayName)
                        .font(DesignSystem.Typography.caption)
                }
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.primary.opacity(0.1))
                )

                // Stats
                HStack(spacing: DesignSystem.Spacing.md) {
                    statBadge(
                        value: "\(checklist.sections.count)",
                        label: checklist.sections.count == 1 ? "Section" : "Sections"
                    )
                    statBadge(
                        value: "\(checklist.totalItems)",
                        label: checklist.totalItems == 1 ? "Item" : "Items"
                    )
                    statBadge(
                        value: "\(detail.viewCount)",
                        label: detail.viewCount == 1 ? "View" : "Views"
                    )
                    statBadge(
                        value: "\(detail.forkCount)",
                        label: detail.forkCount == 1 ? "Fork" : "Forks"
                    )
                }
            }
        }
        .padding(.bottom, DesignSystem.Spacing.md)
    }

    private func sectionView(for section: ChecklistSection) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Section header
            Text(section.title)
                .font(DesignSystem.Typography.subheader)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.bottom, DesignSystem.Spacing.xs)

            // Section items
            ForEach(section.items) { item in
                itemView(for: item)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.md)
                .fill(DesignSystem.Colors.surface)
        )
    }

    private func itemView(for item: ChecklistItem) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            // Checkbox (read-only)
            Image(systemName: "square")
                .font(.system(size: 16))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(item.title)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if let description = item.itemDescription, !description.isEmpty {
                    Text(description)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    private func statBadge(value: String, label: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(value)
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
            Text(label)
                .font(DesignSystem.Typography.caption)
        }
        .foregroundColor(DesignSystem.Colors.textSecondary)
    }

    private func markdownBody(from markdown: String) -> some View {
        let blocks = MarkdownParser.parse(markdown)

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(MarkdownParser.parseInlineFormatting(text))
                .font(headingFont(for: level))
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.top, level == 1 ? DesignSystem.Spacing.md : DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.xs)

        case .paragraph(let text):
            if !text.isEmpty {
                Text(MarkdownParser.parseInlineFormatting(text))
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, DesignSystem.Spacing.xs)
            }

        case .listItem(let text, let level):
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                Text("•")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.leading, CGFloat(level) * DesignSystem.Spacing.md)

                Text(MarkdownParser.parseInlineFormatting(text))
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, DesignSystem.Spacing.xs)
        }
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1:
            return DesignSystem.Typography.largeTitle
        case 2:
            return DesignSystem.Typography.title
        case 3:
            return DesignSystem.Typography.subheader
        default:
            return DesignSystem.Typography.headline
        }
    }

    // MARK: - Actions

    private func forkContent(_ detail: SharedContentDetail) async {
        do {
            // Fork the content using the library store
            try await dependencies.libraryStore.forkContent(from: detail)

            // Navigate to library tab to show the newly forked content
            coordinator.navigateToLibrary()

            // Show success feedback (could be improved with a toast/banner)
            AppLogger.view.info("Successfully forked content: \(detail.publicID)")

        } catch {
            AppLogger.view.error("Failed to fork content: \(detail.publicID)", error: error)
            // Handle error - could show an error banner or alert
        }
    }
}