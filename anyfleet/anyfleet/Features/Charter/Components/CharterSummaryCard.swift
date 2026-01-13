import SwiftUI

struct CharterSummaryCard: View {
    let form: CharterFormState
    let progress: Double
    var onCreate: () -> Void
    
    private var isValid: Bool {
        !form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        form.endDate >= form.startDate
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            DesignSystem.SectionHeader(L10n.charterSummaryYourAdventureAwaits, subtitle: L10n.charterSummaryReviewYourCharterPlan)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                DesignSystem.Form.SummaryRow(icon: "📅", title: L10n.charterSummaryDates, value: form.dateSummary, detail: "\(form.nights) \(L10n.charterSummaryNights)")
                DesignSystem.Form.SummaryRow(icon: "🧭", title: L10n.charterCreateDestination, value: form.destination.isEmpty ? L10n.charterCreateChooseWhereYouWillSail : form.destination, detail: nil)
                DesignSystem.Form.SummaryRow(icon: "⛵", title: L10n.charterSummaryVessel, value: form.vessel, detail: "\(L10n.charterSummaryUpto) \(form.guests) \(L10n.charterSummaryUpToGuests)")
                
            }
            
            Button(action: onCreate) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(L10n.charterSummaryCreateCharter)
                }
            }
            .buttonStyle(DesignSystem.PrimaryButtonStyle())
            .disabled(!isValid)
            .opacity(isValid ? 1.0 : 0.6)
            
            Text("\(L10n.charterSummaryStep) \(Int(progress * 5)) \(L10n.charterSummaryOf) 5")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .sectionContainer()
    }
}

#Preview("Light") {
    CharterSummaryCard(form: .mock, progress: 0.8, onCreate: {})
        .padding()
}

#Preview("Dark") {
    CharterSummaryCard(form: .mock, progress: 0.8, onCreate: {})
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XL") {
    CharterSummaryCard(form: .mock, progress: 0.8, onCreate: {})
        .padding()
        .environment(\.dynamicTypeSize, .accessibility2)
}

