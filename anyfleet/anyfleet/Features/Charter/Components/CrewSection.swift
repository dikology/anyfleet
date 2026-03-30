import SwiftUI

struct CrewSection: View {
    @Binding var captainIncluded: Bool
    @Binding var chefIncluded: Bool
    @Binding var deckhandIncluded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Toggle("Captain included", isOn: $captainIncluded)
            Toggle("Chef", isOn: $chefIncluded)
            Toggle("Deckhand", isOn: $deckhandIncluded)
        }
        .onChange(of: captainIncluded) { _, _ in HapticEngine.selection() }
        .onChange(of: chefIncluded) { _, _ in HapticEngine.selection() }
        .onChange(of: deckhandIncluded) { _, _ in HapticEngine.selection() }
    }
}

#Preview("Light") {
    CrewSection(captainIncluded: .constant(true), chefIncluded: .constant(false), deckhandIncluded: .constant(true))
        .padding()
}

#Preview("Dark") {
    CrewSection(captainIncluded: .constant(true), chefIncluded: .constant(false), deckhandIncluded: .constant(true))
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XL") {
    CrewSection(captainIncluded: .constant(true), chefIncluded: .constant(false), deckhandIncluded: .constant(true))
        .padding()
        .environment(\.dynamicTypeSize, .accessibility2)
}

