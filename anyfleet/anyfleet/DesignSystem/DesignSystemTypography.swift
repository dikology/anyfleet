import SwiftUI

extension DesignSystem {
    enum Typography {
        // MARK: - Display — Onder custom font, only for hero/title contexts
        static let display    = Font.custom("Onder", size: 28).weight(.semibold)
        static let largeTitle = Font.custom("Onder", size: 22).weight(.semibold)

        // MARK: - UI Labels — system font for legibility and Dynamic Type
        static let title      = Font.system(size: 20, weight: .semibold)
        static let titleBold  = Font.system(size: 20, weight: .bold)
        static let titleRegular = Font.system(size: 20, weight: .regular)
        static let headline   = Font.system(size: 17, weight: .semibold)
        static let headlineRegular = Font.system(size: 17, weight: .regular)
        static let subheader  = Font.system(size: 16, weight: .semibold)
        /// Detail / execution screen main heading (system 24pt bold).
        static let pageTitle  = Font.system(size: 24, weight: .bold)
        static let pageTitleSemibold = Font.system(size: 24, weight: .semibold)
        static let pageTitleRegular = Font.system(size: 24, weight: .regular)
        /// List date gutter (e.g. charter timeline day numeral) — bold rounded, 28pt.
        static let dateDisplay = Font.system(size: 28, weight: .bold, design: .rounded)
        /// Profile header display name (28pt bold rounded).
        static let profileName = Font.system(size: 28, weight: .bold, design: .rounded)
        /// Large toolbar / modal dismiss SF Symbol (e.g. 28pt regular).
        static let toolbarGlyphLarge = Font.system(size: 28, weight: .regular)
        static let body       = Font.system(size: 16, weight: .regular)
        static let bodyMedium = Font.system(size: 16, weight: .medium)
        static let callout    = Font.system(size: 15, weight: .regular)
        static let calloutSemibold = Font.system(size: 15, weight: .semibold)
        static let caption    = Font.system(size: 14, weight: .regular)
        static let captionMedium = Font.system(size: 14, weight: .medium)
        static let captionSemibold = Font.system(size: 14, weight: .semibold)
        static let captionBold = Font.system(size: 14, weight: .bold)
        static let footnote   = Font.system(size: 12, weight: .regular)
        static let footnoteMedium = Font.system(size: 12, weight: .medium)
        static let footnoteSemibold = Font.system(size: 12, weight: .semibold)
        static let compact    = Font.system(size: 13, weight: .regular)
        static let compactMedium = Font.system(size: 13, weight: .medium)
        static let compactSemibold = Font.system(size: 13, weight: .semibold)
        static let lead       = Font.system(size: 18, weight: .regular)
        static let leadMedium = Font.system(size: 18, weight: .medium)
        static let leadSemibold = Font.system(size: 18, weight: .semibold)
        static let leadBold   = Font.system(size: 18, weight: .bold)
        /// Empty list / section titles (system 22pt regular).
        static let insetHeadline = Font.system(size: 22, weight: .regular)
        static let emptyStateHeadline = Font.system(size: 26, weight: .bold)
        static let emptyStateTitleSemibold = Font.system(size: 26, weight: .semibold)
        static let micro      = Font.system(size: 11, weight: .medium)
        static let microRegular = Font.system(size: 11, weight: .regular)
        static let microBold  = Font.system(size: 11, weight: .bold)
        static let microBoldMonospaced = Font.system(size: 11, weight: .bold, design: .monospaced)
        static let nano       = Font.system(size: 10, weight: .regular)
        static let nanoMedium = Font.system(size: 10, weight: .medium)
        static let nanoSemibold = Font.system(size: 10, weight: .semibold)
        static let nanoBold   = Font.system(size: 10, weight: .bold)

        // MARK: - Symbol plates (empty states, modals, avatars)
        static let symbolPlateSM = Font.system(size: 32, weight: .medium)
        static let symbolPlateSMRegular = Font.system(size: 32, weight: .regular)
        static let symbolPlateMD = Font.system(size: 40, weight: .regular)
        static let symbolPlateMDEmphasis = Font.system(size: 40, weight: .medium)
        static let symbolPlateLG = Font.system(size: 44, weight: .medium)
        static let symbolPlateLGRegular = Font.system(size: 44, weight: .regular)
        static let symbolPlateXL = Font.system(size: 48, weight: .medium)
        static let symbolPlateXLRegular = Font.system(size: 48, weight: .regular)
        static let symbolPlateXXL = Font.system(size: 56, weight: .light)
        static let symbolPlateHero = Font.system(size: 64, weight: .regular)
        static let symbolPlateHeroLight = Font.system(size: 64, weight: .light)

        // MARK: - Scaled circles (initials, badges)
        static func avatarInitial(inCircleDiameter d: CGFloat) -> Font {
            Font.system(size: d * 0.5, weight: .semibold)
        }

        static func avatarAnonymousGlyph(inCircleDiameter d: CGFloat) -> Font {
            Font.system(size: d * 0.5)
        }

        static func communityBadgeInitial(forDiameter d: CGFloat) -> Font {
            Font.system(size: max(10, d * 0.5), weight: .bold, design: .rounded)
        }
    }
}
