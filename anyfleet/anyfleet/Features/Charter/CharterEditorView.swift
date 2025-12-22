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
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            DesignSystem.Form.FieldLabel(L10n.charterCreateDestination)
                            TextField(L10n.charterCreateChooseWhereYouWillSail, text: $viewModel.form.destination)
                                .formFieldStyle()
                        }
                        // TODO: RegionPickerSection(selectedRegion: $viewModel.form.region, regions: CharterFormState.regionOptions)
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
        .navigationTitle(viewModel.isNewCharter ? "New Charter" : "Edit Charter")
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
