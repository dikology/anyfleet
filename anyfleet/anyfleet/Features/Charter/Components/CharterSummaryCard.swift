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

