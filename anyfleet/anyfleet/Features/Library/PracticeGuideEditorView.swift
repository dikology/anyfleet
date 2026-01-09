//
//  PracticeGuideEditorView.swift
//  anyfleet
//
//  Main editor view for creating and editing practice guides (markdown).
//

import SwiftUI

struct PracticeGuideEditorView: View {
    @State private var viewModel: PracticeGuideEditorViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: PracticeGuideEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        mainContent
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task {
                await viewModel.loadGuide()
            }

            // Error Banner
            if viewModel.showErrorBanner, let error = viewModel.currentError {
                VStack {
                    Spacer()
                    ErrorBanner(
                        error: error,
                        onDismiss: { viewModel.clearError() },
                        onRetry: nil
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                headerCard
                markdownEditor
                Spacer(minLength: 80)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
    }
    
    private var navigationTitle: String {
        viewModel.isNewGuide ? "New Guide" : "Edit Guide"
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: saveAction) {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(DesignSystem.Colors.primary)
                } else {
                    Text("Save")
                        .fontWeight(.semibold)
                }
            }
            .disabled(viewModel.isSaving || viewModel.guide.title.isEmpty || viewModel.guide.markdown.isEmpty)
            .foregroundColor(saveButtonColor)
        }
        
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }
    }
    
    private var saveButtonColor: Color {
        viewModel.guide.title.isEmpty || viewModel.guide.markdown.isEmpty
            ? DesignSystem.Colors.textSecondary
            : DesignSystem.Colors.primary
    }
    
    private func saveAction() {
        Task {
            await viewModel.saveGuide()
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs + 2) {
                Text("Title")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .tracking(0.3)
                
                TextField("e.g. Heavy Weather Tactics", text: $viewModel.guide.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .textFieldStyle(.plain)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .contentShape(Rectangle())
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.md)
            .background(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.oceanDeep.opacity(0.15),
                        DesignSystem.Colors.oceanDeep.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .allowsHitTesting(false)
            )
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs + 2) {
                Text("Summary")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .tracking(0.3)
                
                TextField("Optional short description", text: Binding(
                    get: { viewModel.guide.description ?? "" },
                    set: { viewModel.guide.description = $0.isEmpty ? nil : $0 }
                ))
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .textFieldStyle(.plain)
                .lineLimit(2)
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Colors.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.border.opacity(0.6),
                            DesignSystem.Colors.border.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Markdown Editor
    
    private var markdownEditor: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Content (Markdown)")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .tracking(0.3)
            
            TextEditor(text: $viewModel.guide.markdown)
                .frame(minHeight: 280)
                .font(.body.monospaced())
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignSystem.Colors.border.opacity(0.5), lineWidth: 1)
                )
        }
    }
    
}

#Preview("New Practice Guide") {
    MainActor.assumeIsolated {
        let dependencies = try! AppDependencies.makeForTesting()
        let viewModel = PracticeGuideEditorViewModel(
            libraryStore: dependencies.libraryStore,
            guideID: nil,
            onDismiss: {}
        )
        
        return NavigationStack {
            PracticeGuideEditorView(viewModel: viewModel)
        }
        .environment(\.appDependencies, dependencies)
    }
}


