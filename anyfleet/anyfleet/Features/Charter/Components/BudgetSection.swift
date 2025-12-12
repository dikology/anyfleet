import SwiftUI

struct BudgetSection: View {
    @Binding var budget: Double
    @Binding var notes: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                DesignSystem.Form.FieldLabel("Total budget (USD)")
                TextField("24000", value: $budget, format: .currency(code: "USD"))
                    .keyboardType(.numberPad)
                    .formFieldStyle()
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                DesignSystem.Form.FieldLabel("Notes (optional)")
                TextField("Special requests, constraints, etc.", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .formFieldStyle()
            }
        }
    }
}

#Preview("Light") {
    BudgetSection(budget: .constant(24000), notes: .constant("Include snorkeling gear and child vests."))
        .padding()
}

#Preview("Dark") {
    BudgetSection(budget: .constant(24000), notes: .constant("Include snorkeling gear and child vests."))
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XL") {
    BudgetSection(budget: .constant(24000), notes: .constant("Include snorkeling gear and child vests."))
        .padding()
        .environment(\.dynamicTypeSize, .accessibility2)
}

