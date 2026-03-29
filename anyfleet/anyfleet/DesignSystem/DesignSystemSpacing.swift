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

        // MARK: - Corner radii (use these — not `Spacing.sm` / `.md` for radius)
        /// Map pins, micro tags (4pt).
        static let cornerRadiusMini: CGFloat = 4
        /// Section icon wells, checkbox tiles (6pt).
        static let cornerRadiusInset: CGFloat = 6
        /// Metadata strips, small panels, checklist chrome (8pt).
        static let cornerRadiusCompact: CGFloat = 8
        /// Buttons, form fields, chips (10pt).
        static let cornerRadiusSmall: CGFloat = 10
        /// Modals, nested cards, visibility shells (12pt).
        static let cornerRadiusMedium: CGFloat = 12
        /// Dense grids, selectable tiles (14pt).
        static let cornerRadiusControl: CGFloat = 14
        /// Primary cards, hero rows (16pt).
        static let cardCornerRadius: CGFloat = 16
        /// KPI / date pills, capsule buttons (20pt).
        static let cornerRadiusPill: CGFloat = 20
        /// Sheets, large feature surfaces (24pt).
        static let cardCornerRadiusLarge: CGFloat = 24
    }
}
