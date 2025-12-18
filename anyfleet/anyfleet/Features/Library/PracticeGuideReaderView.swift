//
//  PracticeGuideReaderView.swift
//  anyfleet
//
//  Read-only view for practice guides rendered from markdown.
//

import SwiftUI

struct PracticeGuideReaderView: View {
    @State private var viewModel: PracticeGuideReaderViewModel
    
    init(viewModel: PracticeGuideReaderViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            Group {
                if let guide = viewModel.guide {
                    contentView(for: guide)
                } else if viewModel.isLoading {
                    ProgressView()
                        .tint(DesignSystem.Colors.primary)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding()
                } else {
                    // Show loading state instead of empty view
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ProgressView()
                            .tint(DesignSystem.Colors.primary)
                        Text("Loading guide...")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(viewModel.guide?.title ?? "Guide")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadGuide()
        }
    }
    
    // MARK: - Content
    
    private func contentView(for guide: PracticeGuide) -> some View {
        ScrollView {
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
                }
                .padding(.bottom, DesignSystem.Spacing.md)
                
                // Markdown body
                markdownBody(from: guide.markdown)
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
    }
    
    private func markdownBody(from markdown: String) -> some View {
        let blocks = MarkdownParser.parse(markdown)
        
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }
    
    // MARK: - Markdown Rendering
    
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
}

// MARK: - Preview

private func makePreviewView() -> some View {
    return MainActor.assumeIsolated {
        let dependencies = try! AppDependencies.makeForTesting()
        
        // Create a sample guide for the preview
        let sampleGuide = PracticeGuide(
            title: "Heavy Weather Tactics",
            description: "Step‑by‑step guide for reefing, heaving‑to, and staying safe when the wind picks up.",
            markdown: """
            # Heavy Weather Tactics
            
            When the wind builds, your goal is to **slow the boat down** and keep her under control.
            
            ## 1. Reef Early
            - Put the first reef in before you think you need it.
            - Secure loose lines on deck.
            
            ## 2. Heave-To
            Heaving-to is one of the most powerful heavy-weather tools:
            
            - Back the jib slightly.
            - Lock the helm to leeward.
            - Ease the mainsheet until the boat settles.
            """,
            tags: ["heavy weather", "safety"]
        )
        
        let viewModel = PracticeGuideReaderViewModel(
            libraryStore: dependencies.libraryStore,
            guideID: sampleGuide.id
        )
        // Set the guide directly in the viewModel for preview
        viewModel.guide = sampleGuide
        
        return NavigationStack {
            PracticeGuideReaderView(viewModel: viewModel)
        }
        .environment(\.appDependencies, dependencies)
    }
}

#Preview("Practice Guide Reader") {
    makePreviewView()
}
