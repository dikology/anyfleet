import SwiftUI

/// Two-thumb normalized range slider (`lower` and `upper` in 0…1, `upper - lower >= minSpan`).
struct RangeSlider: View {
    @Binding var lower: Double
    @Binding var upper: Double
    var minSpan: Double = 0.05
    var trackColor: Color = DesignSystem.Colors.primary.opacity(0.2)
    var rangeColor: Color = DesignSystem.Colors.primary
    var thumbSize: CGFloat = 24
    /// Month / date captions under the track (provided by the feature layer).
    var lowerCaption: String
    var upperCaption: String

    @State private var lowerDragOrigin: Double?
    @State private var upperDragOrigin: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            GeometryReader { geo in
                let width = geo.size.width
                let trackW = max(width - thumbSize, 1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(trackColor)
                        .frame(width: trackW, height: 4)
                        .offset(x: thumbSize / 2, y: (geo.size.height - 4) / 2)

                    Capsule()
                        .fill(rangeColor)
                        .frame(width: CGFloat(upper - lower) * trackW, height: 4)
                        .offset(
                            x: thumbSize / 2 + CGFloat(lower) * trackW,
                            y: (geo.size.height - 4) / 2
                        )

                    lowerThumb(trackW: trackW, height: geo.size.height)
                    upperThumb(trackW: trackW, height: geo.size.height)
                }
                .frame(width: width, height: geo.size.height)
            }
            .frame(height: 32)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Date range")
            .accessibilityValue("\(lowerCaption) to \(upperCaption)")

            HStack {
                Text(lowerCaption)
                Spacer()
                Text(upperCaption)
            }
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }

    private func lowerThumb(trackW: CGFloat, height: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: thumbSize, height: thumbSize)
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .overlay(Circle().stroke(DesignSystem.Colors.border, lineWidth: 1))
            .offset(x: CGFloat(lower) * trackW, y: (height - thumbSize) / 2)
            .gesture(
                DragGesture()
                    .onChanged { g in
                        if lowerDragOrigin == nil { lowerDragOrigin = lower }
                        guard let start = lowerDragOrigin else { return }
                        let delta = Double(g.translation.width / trackW)
                        let next = (start + delta).clamped(to: 0...(upper - minSpan))
                        lower = next
                    }
                    .onEnded { _ in lowerDragOrigin = nil }
            )
    }

    private func upperThumb(trackW: CGFloat, height: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: thumbSize, height: thumbSize)
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .overlay(Circle().stroke(DesignSystem.Colors.border, lineWidth: 1))
            .offset(x: CGFloat(upper) * trackW, y: (height - thumbSize) / 2)
            .gesture(
                DragGesture()
                    .onChanged { g in
                        if upperDragOrigin == nil { upperDragOrigin = upper }
                        guard let start = upperDragOrigin else { return }
                        let delta = Double(g.translation.width / trackW)
                        let next = (start + delta).clamped(to: (lower + minSpan)...1)
                        upper = next
                    }
                    .onEnded { _ in upperDragOrigin = nil }
            )
    }

    /// Keeps `lower` / `upper` within bounds and minimum span (for tests and programmatic updates).
    static func clamp(lower: inout Double, upper: inout Double, minSpan: Double) {
        lower = lower.clamped(to: 0...(1 - minSpan))
        upper = upper.clamped(to: (lower + minSpan)...1)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
