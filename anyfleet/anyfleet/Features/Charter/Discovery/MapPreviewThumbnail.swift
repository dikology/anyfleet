import SwiftUI
import MapKit

/// A non-interactive map thumbnail showing a location pin.
/// Used inside `CharterDiscoveryRow` and `DiscoveredCharterDetailView`.
struct MapPreviewThumbnail: View {
    let coordinate: CLLocationCoordinate2D
    var height: CGFloat = 120
    var annotationTitle: String = ""

    @State private var region: MKCoordinateRegion

    init(coordinate: CLLocationCoordinate2D, height: CGFloat = 120, annotationTitle: String = "") {
        self.coordinate = coordinate
        self.height = height
        self.annotationTitle = annotationTitle
        _region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
        ))
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: [MapPin(coordinate: coordinate, title: annotationTitle)]) { pin in
            MapMarker(coordinate: pin.coordinate, tint: DesignSystem.Colors.primary)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm))
        .disabled(true)
        .accessibilityLabel("Map preview showing destination")
        .accessibilityHidden(true)
    }
}

private struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
}
