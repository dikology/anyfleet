import SwiftUI

struct CreateCharterView: View {
    @State private var form: CharterFormState
    @State private var charterStore = CharterStore()
    @State private var isSaving = false
    @State private var saveError: Error?
    @Environment(\.dismiss) private var dismiss
    
    init(form: CharterFormState = .init()) {
        _form = State(initialValue: form)
    }
    
    private var completionProgress: Double {
        let total = 6.0
        var count = 0.0
        if !form.name.isEmpty { count += 1 }
        if form.startDate != .now { count += 1 }
        if form.endDate != .now { count += 1 }
        if !form.region.isEmpty { count += 1 }
        if !form.vessel.isEmpty { count += 1 }
        if form.guests > 0 { count += 1 }
        return count / total
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    hero
                    
                    DesignSystem.Form.Progress(progress: completionProgress, label: L10n.charterCreateProgress)
                    
                    DesignSystem.Form.Section(title: L10n.charterCreateName, subtitle: L10n.charterCreateNameHelper) {
                        DesignSystem.Form.FormTextField(
                            placeholder: L10n.charterCreateNamePlaceholder,
                            text: $form.name
                        )
                    }
                    
                    DesignSystem.Form.Section(title: L10n.charterCreateWhenWillYouSail, subtitle: L10n.charterCreateChooseYourVoyageDates) {
                        DateRangeSection(startDate: $form.startDate, endDate: $form.endDate, nights: form.nights)
                    }
                    
                    DesignSystem.Form.Section(title: L10n.charterCreateDestination, subtitle: L10n.charterCreateChooseWhereYouWillSail) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            DesignSystem.Form.FieldLabel(L10n.charterCreateDestination)
                            TextField(L10n.charterCreateChooseWhereYouWillSail, text: $form.destination)
                                .formFieldStyle()
                        }
                        // TODO: RegionPickerSection(selectedRegion: $form.region, regions: CharterFormState.regionOptions)
                    }
                    
                    DesignSystem.Form.Section(title: L10n.charterCreateYourVessel, subtitle: L10n.charterCreatePickTheCharacterOfYourJourney) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            DesignSystem.Form.FieldLabel(L10n.charterCreateYourVessel)
                            TextField(L10n.charterCreateVesselNamePlaceholder, text: $form.vessel)
                                .formFieldStyle()
                        }
                        // VesselPickerSection(selectedVessel: $form.vessel, vessels: CharterFormState.vesselOptions)
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            DesignSystem.Form.FieldLabel(L10n.charterCreateGuests)
                            Stepper(value: $form.guests, in: 1...12) {
                                Text("\(form.guests) \(L10n.charterCreateGuests)")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                        }
                    }
                    
//                    DesignSystem.Form.Section(title: L10n.charterCreateCrew, subtitle: L10n.charterCreateWhoIsJoiningTheTrip) {
//                        CrewSection(
//                            captainIncluded: $form.captainIncluded,
//                            chefIncluded: $form.chefIncluded,
//                            deckhandIncluded: $form.deckhandIncluded
//                        )
//                    }
                    
//                    DesignSystem.Form.Section(title: L10n.charterCreateBudget, subtitle: L10n.charterCreateOptionalBudgetRange) {
//                        BudgetSection(budget: $form.budget, notes: $form.notes)
//                    }
                    
                    CharterSummaryCard(form: form, progress: completionProgress) {
                        saveCharter()
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background.ignoresSafeArea())
        }
    }
}

#Preview {
    CreateCharterView()
}

// MARK: - Subviews

private extension CreateCharterView {
    var hero: some View {
        DesignSystem.Form.Hero(
            title: L10n.charterCreateSetSailOnYourNextAdventure,
            subtitle: L10n.charterCreateFromDreamToRealityInAFewGuidedSteps
        )
    }
    
    func saveCharter() {
        AppLogger.view.startOperation("Save Charter")
        
        guard !isSaving else {
            AppLogger.view.warning("Save already in progress, ignoring duplicate request")
            return
        }
        
        isSaving = true
        saveError = nil
        
        Task {
            do {
                // Generate a name if not provided
                let charterName = form.name.isEmpty 
                    ? "\(form.destination.isEmpty ? "Charter" : form.destination) - \(form.dateSummary)"
                    : form.name
                
                AppLogger.view.info("Creating charter with name: '\(charterName)'")
                AppLogger.view.debug("Charter details - boatName: \(form.vessel.isEmpty ? "nil" : form.vessel), location: \(form.destination.isEmpty ? "nil" : form.destination), startDate: \(form.startDate), endDate: \(form.endDate)")
                
                let charter = try await charterStore.createCharter(
                    name: charterName,
                    boatName: form.vessel.isEmpty ? nil : form.vessel,
                    location: form.destination.isEmpty ? nil : form.destination,
                    startDate: form.startDate,
                    endDate: form.endDate,
                    checkInChecklistID: nil
                )
                
                AppLogger.view.info("Charter created successfully with ID: \(charter.id.uuidString)")
                AppLogger.view.completeOperation("Save Charter")
                
                dismiss()
            } catch {
                AppLogger.view.failOperation("Save Charter", error: error)
                saveError = error
                isSaving = false
            }
        }
    }
}

// private struct SummaryCard: View {
//     let form: CharterFormState
//     let progress: Double
//     var onCreate: () -> Void
    
//     private var isValid: Bool {
//         !form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
//         form.endDate >= form.startDate
//     }
    
//     var body: some View {
//         VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
//             DesignSystem.SectionHeader(L10n.charterCreateYourAdventureAwaits, subtitle: L10n.charterCreateReviewYourCharterPlan)
            
//             VStack(spacing: DesignSystem.Spacing.md) {
//                 DesignSystem.Form.SummaryRow(icon: "📅", title: L10n.charterCreateDates, value: form.dateSummary, detail: "\(form.nights) \(L10n.charterCreateNights)")
//                 DesignSystem.Form.SummaryRow(icon: "🧭", title: L10n.charterCreateRegion, value: form.destination, detail: form.regionDetails ?? L10n.charterCreateSelectARegion)
//                 DesignSystem.Form.SummaryRow(icon: "⛵", title: L10n.charterCreateVessel, value: form.vessel, detail: "Up to \(form.guests) \(L10n.charterCreateUpToGuests    )")
//             }
            
//             Button(action: onCreate) {
//                 HStack(spacing: DesignSystem.Spacing.sm) {
//                     Image(systemName: "checkmark.circle.fill")
//                     Text(L10n.charterCreateCreateCharter)
//                 }
//             }
//             .buttonStyle(DesignSystem.PrimaryButtonStyle())
//             .disabled(!isValid)
//             .opacity(isValid ? 1.0 : 0.6)
            
//             Text("\(L10n.charterCreateStep) \(Int(progress * 6)) of 6")
//                 .font(DesignSystem.Typography.caption)
//                 .foregroundColor(DesignSystem.Colors.textSecondary)
//         }
//         .sectionContainer()
//     }
// }

#Preview {
    CreateCharterView(form: .mock)
}

