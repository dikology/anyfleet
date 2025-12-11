import SwiftUI

struct VesselPickerSection: View {
    @Binding var selectedVessel: String
    let vessels: [CharterFormState.Vessel]
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ForEach(vessels) { vessel in
                SelectableCard(
                    isSelected: selectedVessel == vessel.name,
                    accessibilityLabel: vessel.name,
                    onSelect: { selectedVessel = vessel.name }
                ) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: vessel.colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 140)
                        .overlay(
                            Image(systemName: "sailboat")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(Color.white.opacity(0.18)),
                            alignment: .center
                        )
                } content: {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vessel.name)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text("\(vessel.length)ft • \(vessel.berths) berths")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                            ratingStars(vessel.rating)
                        }
                        
                        Text(vessel.pricePerNight, format: .currency(code: "USD"))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        ForEach(vessel.highlights, id: \.self) { highlight in
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.success)
                                Text(highlight)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func ratingStars(_ rating: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < rating ? "star.fill" : "star")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.gold)
            }
        }
    }
}

#Preview("Light") {
    VesselPickerSection(selectedVessel: .constant(CharterFormState.vesselOptions.first?.name ?? ""), vessels: CharterFormState.vesselOptions)
        .padding()
}

#Preview("Dark") {
    VesselPickerSection(selectedVessel: .constant(CharterFormState.vesselOptions.first?.name ?? ""), vessels: CharterFormState.vesselOptions)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XL") {
    VesselPickerSection(selectedVessel: .constant(CharterFormState.vesselOptions.first?.name ?? ""), vessels: CharterFormState.vesselOptions)
        .padding()
        .environment(\.dynamicTypeSize, .accessibility2)
}

