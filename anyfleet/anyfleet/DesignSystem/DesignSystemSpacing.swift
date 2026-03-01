import SwiftUI

extension DesignSystem {
    enum Spacing {
        // MARK: - Base scale (4pt grid)
        static let xss: CGFloat = 2   // indicator dots, tight offsets
        static let xs: CGFloat  = 4   // icon–text gap, badge padding
        static let sm: CGFloat  = 8   // row padding, between badges
        static let md: CGFloat  = 12  // card inner padding, field padding
        static let lg: CGFloat  = 16  // card horizontal inset, section gap
        static let xl: CGFloat  = 20  // form section spacing
        static let xxl: CGFloat = 24  // outer padding, hero bottom padding
        static let xxxl: CGFloat = 32 // screen-level section breathing room

        // MARK: - Screen layout
        static let screenPadding: CGFloat = 20

        // MARK: - Card layout
        static let cardPadding: CGFloat = 16
        static let featuredCardHeight: CGFloat = 180

        // MARK: - Corner radii (three approved values + Capsule)
        /// Buttons, form fields, chips, small elements
        static let cornerRadiusSmall: CGFloat = 10
        /// Standard cards, list items, section containers
        static let cardCornerRadius: CGFloat = 16
        /// Sheets, modals, feature surfaces
        static let cardCornerRadiusLarge: CGFloat = 24
    }
}
