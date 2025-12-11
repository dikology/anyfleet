import SwiftUI

struct DateRangeSection: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let nights: Int
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                dateColumn(title: "From", date: startDate, alignment: .leading)
                
                VStack(spacing: 4) {
                    Text("\(nights)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text("nights")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                dateColumn(title: "To", date: endDate, alignment: .trailing)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surfaceAlt)
            .cornerRadius(12)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                DatePicker(
                    "Start date",
                    selection: $startDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                
                DatePicker(
                    "End date",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
            }
        }
    }
    
    private func dateColumn(title: String, date: Date, alignment: Alignment) -> some View {
        VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 4) {
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text(date, style: .date)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }
}

#Preview("Light") {
    DateRangeSection(startDate: .constant(Date()), endDate: .constant(Date().addingTimeInterval(86400 * 7)), nights: 7)
        .padding()
}

#Preview("Dark") {
    DateRangeSection(startDate: .constant(Date()), endDate: .constant(Date().addingTimeInterval(86400 * 7)), nights: 7)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XL") {
    DateRangeSection(startDate: .constant(Date()), endDate: .constant(Date().addingTimeInterval(86400 * 7)), nights: 7)
        .padding()
        .environment(\.dynamicTypeSize, .accessibility2)
}

