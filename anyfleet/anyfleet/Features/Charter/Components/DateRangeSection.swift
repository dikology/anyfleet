import SwiftUI

struct DateRangeSection: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let nights: Int

    @State private var showingStartPicker = false
    @State private var showingEndPicker = false

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                Button {
                    showingStartPicker = true
                } label: {
                    dateColumn(title: L10n.charterCreateFrom, date: startDate, alignment: .leading)
                }
                .buttonStyle(.plain)

                VStack(spacing: 4) {
                    Text("\(nights)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text(L10n.charterCreateNights)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Button {
                    showingEndPicker = true
                } label: {
                    dateColumn(title: L10n.charterCreateTo, date: endDate, alignment: .trailing)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surfaceAlt)
            .cornerRadius(12)

        }
        .sheet(isPresented: $showingStartPicker) {
            DatePickerModal(
                title: "Select Departure Date",
                selectedDate: $startDate
            )
        }
        .sheet(isPresented: $showingEndPicker) {
            DatePickerModal(
                title: "Select Return Date", 
                selectedDate: $endDate
            )
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

struct DatePickerModal: View {
    let title: String
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .background(DesignSystem.Colors.background)
        }
        .presentationDetents([.medium])
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

