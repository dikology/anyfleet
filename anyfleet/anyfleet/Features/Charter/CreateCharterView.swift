import SwiftUI

struct CreateCharterView: View {
    @State private var form: CharterFormState
    
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
                    
                    DesignSystem.Form.Progress(progress: completionProgress, label: "Progress")
                    
                    DesignSystem.Form.Section(title: "When will you sail?", subtitle: "Choose your voyage dates") {
                        DateRangeSection(startDate: $form.startDate, endDate: $form.endDate, nights: form.nights)
                    }
                    
                    DesignSystem.Form.Section(title: "Destination", subtitle: "Choose where you will sail") {
                        RegionPickerSection(selectedRegion: $form.region, regions: CharterFormState.regionOptions)
                    }
                    
                    DesignSystem.Form.Section(title: "Your vessel", subtitle: "Pick the character of your journey") {
                        VesselPickerSection(selectedVessel: $form.vessel, vessels: CharterFormState.vesselOptions)
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            DesignSystem.Form.FieldLabel("Guests")
                            Stepper(value: $form.guests, in: 1...12) {
                                Text("\(form.guests) guests")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                        }
                    }
                    
                    DesignSystem.Form.Section(title: "Crew", subtitle: "Who is joining the trip") {
                        CrewSection(
                            captainIncluded: $form.captainIncluded,
                            chefIncluded: $form.chefIncluded,
                            deckhandIncluded: $form.deckhandIncluded
                        )
                    }
                    
                    DesignSystem.Form.Section(title: "Budget", subtitle: "Optional budget range") {
                        BudgetSection(budget: $form.budget, notes: $form.notes)
                    }
                    
                    CharterSummaryCard(form: form, progress: completionProgress) {
                        // Action placeholder; integrate with coordinator when available.
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
            title: "Set sail on your next adventure",
            subtitle: "From dream to reality in a few guided steps."
        )
    }
}

private struct SummaryCard: View {
    let form: CharterFormState
    let progress: Double
    var onCreate: () -> Void
    
    private var isValid: Bool {
        !form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        form.endDate >= form.startDate
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            DesignSystem.SectionHeader("Your adventure awaits", subtitle: "Review your charter plan")
            
            VStack(spacing: DesignSystem.Spacing.md) {
                DesignSystem.Form.SummaryRow(icon: "📅", title: "Dates", value: form.dateSummary, detail: "\(form.nights) nights")
                DesignSystem.Form.SummaryRow(icon: "🧭", title: "Region", value: form.region, detail: form.regionDetails ?? "Select a region")
                DesignSystem.Form.SummaryRow(icon: "⛵", title: "Vessel", value: form.vessel, detail: "Up to \(form.guests) guests")
                DesignSystem.Form.SummaryRow(icon: "👥", title: "Crew", value: form.crewSummary, detail: "Captain + options selected")
                if form.budget > 0 {
                    DesignSystem.Form.SummaryRow(
                        icon: "💰",
                        title: "Budget",
                        value: form.budget.formatted(.currency(code: "USD")),
                        detail: "Ready to lock in your plan"
                    )
                }
            }
            
            Button(action: onCreate) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Create charter")
                }
            }
            .buttonStyle(DesignSystem.PrimaryButtonStyle())
            .disabled(!isValid)
            .opacity(isValid ? 1.0 : 0.6)
            
            Text("Step \(Int(progress * 6)) of 6")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .sectionContainer()
    }
}

#Preview {
    CreateCharterView(form: .mock)
}

