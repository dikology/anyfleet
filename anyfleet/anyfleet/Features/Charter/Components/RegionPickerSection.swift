import SwiftUI

struct RegionPickerSection: View {
    @Binding var selectedRegion: String
    let regions: [CharterFormState.Region]
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ForEach(regions) { region in
                SelectableCard(
                    isSelected: selectedRegion == region.name,
                    accessibilityLabel: region.name,
                    onSelect: { selectedRegion = region.name }
                ) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: region.colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 120)
                        .overlay(
                            Text(region.icon)
                                .font(.system(size: 32))
                                .padding(DesignSystem.Spacing.md),
                            alignment: .topLeading
                        )
                } content: {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text(region.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Spacer()
                            if selectedRegion == region.name {
                                InfoPill(text: "Selected")
                            }
                        }
                        
                        Text(region.subregions)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text(region.description)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

#Preview("Light") {
    RegionPickerSection(selectedRegion: .constant(CharterFormState.regionOptions.first?.name ?? ""), regions: CharterFormState.regionOptions)
        .padding()
}

#Preview("Dark") {
    RegionPickerSection(selectedRegion: .constant(CharterFormState.regionOptions.first?.name ?? ""), regions: CharterFormState.regionOptions)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XL") {
    RegionPickerSection(selectedRegion: .constant(CharterFormState.regionOptions.first?.name ?? ""), regions: CharterFormState.regionOptions)
        .padding()
        .environment(\.dynamicTypeSize, .accessibility2)
}

