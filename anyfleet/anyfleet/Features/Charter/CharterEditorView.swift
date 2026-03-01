import SwiftUI

struct CharterEditorView: View {
    @State private var viewModel: CharterEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies
    
    init(viewModel: CharterEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    hero
                    
                    DesignSystem.Form.Progress(progress: viewModel.completionProgress, label: L10n.charterCreateProgress)
                    
                    DesignSystem.Form.Section(title: L10n.charterCreateName, subtitle: L10n.charterCreateNameHelper) {
                        DesignSystem.Form.FormTextField(
                            placeholder: L10n.charterCreateNamePlaceholder,
                            text: $viewModel.form.name
                        )
                    }
                    
                    DesignSystem.Form.Section(title: L10n.charterCreateWhenWillYouSail, subtitle: L10n.charterCreateChooseYourVoyageDates) {
                        DateRangeSection(startDate: $viewModel.form.startDate, endDate: $viewModel.form.endDate, nights: viewModel.form.nights)
                    }
                    
                    DesignSystem.Form.Section(title: L10n.charterCreateDestination, subtitle: L10n.charterCreateChooseWhereYouWillSail) {
                        DestinationSearchField(
                            query: $viewModel.form.destinationQuery,
                            selectedPlace: $viewModel.form.selectedPlace,
                            searchService: viewModel.locationSearchService
                        )
                    }
                    
                    DesignSystem.Form.Section(title: L10n.charterCreateYourVessel, subtitle: L10n.charterCreatePickTheCharacterOfYourJourney) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            DesignSystem.Form.FieldLabel(L10n.charterCreateYourVessel)
                            TextField(L10n.charterCreateVesselNamePlaceholder, text: $viewModel.form.vessel)
                                .formFieldStyle()
                        }
                        // VesselPickerSection(selectedVessel: $viewModel.form.vessel, vessels: CharterFormState.vesselOptions)
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            DesignSystem.Form.FieldLabel(L10n.charterCreateGuests)
                            Stepper(value: $viewModel.form.guests, in: 1...12) {
                                Text("\(viewModel.form.guests) \(L10n.charterCreateGuests)")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                        }
                    }
                    
//                    DesignSystem.Form.Section(title: L10n.charterCreateCrew, subtitle: L10n.charterCreateWhoIsJoiningTheTrip) {
//                        CrewSection(
//                            captainIncluded: $viewModel.form.captainIncluded,
//                            chefIncluded: $viewModel.form.chefIncluded,
//                            deckhandIncluded: $viewModel.form.deckhandIncluded
//                        )
//                    }
                    
//                    DesignSystem.Form.Section(title: L10n.charterCreateBudget, subtitle: L10n.charterCreateOptionalBudgetRange) {
//                        BudgetSection(budget: $viewModel.form.budget, notes: $viewModel.form.notes)
//                    }
                    
                    DesignSystem.Form.Section(title: L10n.Charter.Editor.visibilityTitle, subtitle: L10n.Charter.Editor.visibilitySubtitle) {
                        visibilityPicker
                    }

                    CharterSummaryCard(form: viewModel.form, progress: viewModel.completionProgress) {
                        Task {
                            await viewModel.saveCharter()
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background.ignoresSafeArea())
        }
        .navigationTitle(viewModel.isNewCharter ? L10n.Charter.Editor.newTitle : L10n.Charter.Editor.editTitle)
        .task {
            await viewModel.loadCharter()
        }
    }
}

// MARK: - Subviews

private extension CharterEditorView {
    var hero: some View {
        DesignSystem.Form.Hero(
            title: L10n.charterCreateSetSailOnYourNextAdventure,
            subtitle: L10n.charterCreateFromDreamToRealityInAFewGuidedSteps
        )
    }

    var visibilityPicker: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            ForEach(CharterVisibility.allCases, id: \.self) { option in
                Button {
                    viewModel.form.visibility = option
                } label: {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: option.systemImage)
                            .font(.system(size: 18))
                            .foregroundColor(viewModel.form.visibility == option
                                ? DesignSystem.Colors.primary
                                : DesignSystem.Colors.textSecondary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.displayName)
                                .font(DesignSystem.Typography.body)
                                .fontWeight(viewModel.form.visibility == option ? .semibold : .regular)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text(option.description)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        Spacer()

                        if viewModel.form.visibility == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(
                        viewModel.form.visibility == option
                            ? DesignSystem.Colors.primary.opacity(0.08)
                            : DesignSystem.Colors.surface
                    )
                    .cornerRadius(DesignSystem.Spacing.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm)
                            .stroke(
                                viewModel.form.visibility == option
                                    ? DesignSystem.Colors.primary.opacity(0.3)
                                    : DesignSystem.Colors.border,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Visibility: \(option.displayName)")
                .accessibilityHint(option.description)
                .accessibilityAddTraits(viewModel.form.visibility == option ? .isSelected : [])
            }

            if viewModel.form.visibility != .private {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text(L10n.Charter.Editor.visibilityChangeNote)
                        .font(DesignSystem.Typography.caption)
                }
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.top, DesignSystem.Spacing.xs)
            }
        }
    }
}

#Preview {
    MainActor.assumeIsolated {
        let dependencies = try! AppDependencies.makeForTesting()
        return CharterEditorView(
            viewModel: CharterEditorViewModel(
                charterStore: dependencies.charterStore,
                charterID: nil,
                onDismiss: {}
            )
        )
        .environment(\.appDependencies, dependencies)
    }
}

#Preview("With Mock Form") {
    MainActor.assumeIsolated {
        let dependencies = try! AppDependencies.makeForTesting()
        return CharterEditorView(
            viewModel: CharterEditorViewModel(
                charterStore: dependencies.charterStore,
                charterID: nil,
                onDismiss: {},
                initialForm: .mock
            )
        )
        .environment(\.appDependencies, dependencies)
    }
}
