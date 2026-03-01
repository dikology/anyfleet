import SwiftUI
import MapKit

/// A non-interactive map thumbnail showing a location pin.
/// Used inside `CharterDiscoveryRow` and `DiscoveredCharterDetailView`.
struct MapPreviewThumbnail: View {
    let coordinate: CLLocationCoordinate2D
    var height: CGFloat = 120
    var annotationTitle: String = ""

    var body: some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            )
        )) {
            Marker(annotationTitle, coordinate: coordinate)
                .tint(DesignSystem.Colors.primary)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm))
        .disabled(true)
        .allowsHitTesting(false)
        .accessibilityLabel("Map preview: \(annotationTitle)")
        .accessibilityHidden(true)
    }
}
