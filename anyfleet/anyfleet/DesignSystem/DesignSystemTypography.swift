import SwiftUI
import UIKit

extension DesignSystem {
    enum Typography {
        // MARK: - Display — Onder custom font scales with Dynamic Type via relativeTo

        static let display = Font.custom("Onder", size: 28, relativeTo: .largeTitle).weight(.semibold)
        static let largeTitle = Font.custom("Onder", size: 22, relativeTo: .title).weight(.semibold)

        // MARK: - UI Labels — system text styles scale with Dynamic Type

        static let title = Font.system(.title3, weight: .semibold)
        static let titleBold = Font.system(.title3, weight: .bold)
        static let titleRegular = Font.system(.title3, weight: .regular)
        static let headline = Font.system(.headline)
        static let headlineRegular = Font.system(.headline, weight: .regular)
        static let subheader = Font.system(.callout, weight: .semibold)
        /// Detail / execution screen main heading.
        static let pageTitle = Font.system(.title2, weight: .bold)
        static let pageTitleSemibold = Font.system(.title2, weight: .semibold)
        static let pageTitleRegular = Font.system(.title2, weight: .regular)
        /// List date gutter (e.g. charter timeline day numeral).
        static let dateDisplay = Font.system(.title2, design: .rounded, weight: .bold)
        /// Profile header display name.
        static let profileName = Font.system(.title2, design: .rounded, weight: .bold)
        /// Large toolbar / modal dismiss SF Symbol.
        static let toolbarGlyphLarge = Font.system(.title2, weight: .regular)
        static let body = Font.system(.body, weight: .regular)
        static let bodyMedium = Font.system(.body, weight: .medium)
        static let bodySemibold = Font.system(.body, weight: .semibold)
        static let callout = Font.system(.subheadline, weight: .regular)
        static let calloutSemibold = Font.system(.subheadline, weight: .semibold)
        static let caption = Font.system(.caption, weight: .regular)
        static let captionMedium = Font.system(.caption, weight: .medium)
        static let captionSemibold = Font.system(.caption, weight: .semibold)
        static let captionBold = Font.system(.caption, weight: .bold)
        static let footnote = Font.system(.footnote, weight: .regular)
        static let footnoteMedium = Font.system(.footnote, weight: .medium)
        static let footnoteSemibold = Font.system(.footnote, weight: .semibold)
        static let compact = Font.system(.footnote, weight: .regular)
        static let compactMedium = Font.system(.footnote, weight: .medium)
        static let compactSemibold = Font.system(.footnote, weight: .semibold)
        /// Between body and title3 at default size; scales with body text metrics.
        static let lead = metricsScaledSystem(defaultSize: 18, weight: .regular, textStyle: .body)
        static let leadMedium = metricsScaledSystem(defaultSize: 18, weight: .medium, textStyle: .body)
        static let leadSemibold = metricsScaledSystem(defaultSize: 18, weight: .semibold, textStyle: .body)
        static let leadBold = metricsScaledSystem(defaultSize: 18, weight: .bold, textStyle: .body)
        static let insetHeadline = Font.system(.title2, weight: .regular)
        static let emptyStateHeadline = metricsScaledSystem(defaultSize: 26, weight: .bold, textStyle: .title2)
        static let emptyStateTitleSemibold = metricsScaledSystem(defaultSize: 26, weight: .semibold, textStyle: .title2)
        static let micro = Font.system(.caption2, weight: .medium)
        static let microRegular = Font.system(.caption2, weight: .regular)
        static let microBold = Font.system(.caption2, weight: .bold)
        static let microBoldMonospaced = Font.system(.caption2, design: .monospaced, weight: .bold)
        static let nano = Font.system(.caption2, weight: .regular)
        static let nanoMedium = Font.system(.caption2, weight: .medium)
        static let nanoSemibold = Font.system(.caption2, weight: .semibold)
        static let nanoBold = Font.system(.caption2, weight: .bold)

        // MARK: - Symbol plates (empty states, modals, avatars)

        static let symbolPlateSM = metricsScaledSystem(defaultSize: 32, weight: .medium, textStyle: .largeTitle)
        static let symbolPlateSMRegular = metricsScaledSystem(defaultSize: 32, weight: .regular, textStyle: .largeTitle)
        static let symbolPlateMD = metricsScaledSystem(defaultSize: 40, weight: .regular, textStyle: .largeTitle)
        static let symbolPlateMDEmphasis = metricsScaledSystem(defaultSize: 40, weight: .medium, textStyle: .largeTitle)
        static let symbolPlateLG = metricsScaledSystem(defaultSize: 44, weight: .medium, textStyle: .largeTitle)
        static let symbolPlateLGRegular = metricsScaledSystem(defaultSize: 44, weight: .regular, textStyle: .largeTitle)
        static let symbolPlateXL = metricsScaledSystem(defaultSize: 48, weight: .medium, textStyle: .largeTitle)
        static let symbolPlateXLRegular = metricsScaledSystem(defaultSize: 48, weight: .regular, textStyle: .largeTitle)
        static let symbolPlateXXL = metricsScaledSystem(defaultSize: 56, weight: .light, textStyle: .largeTitle)
        static let symbolPlateHero = metricsScaledSystem(defaultSize: 64, weight: .regular, textStyle: .largeTitle)
        static let symbolPlateHeroLight = metricsScaledSystem(defaultSize: 64, weight: .light, textStyle: .largeTitle)

        // MARK: - Scaled circles (initials, badges)

        static func avatarInitial(inCircleDiameter d: CGFloat) -> Font {
            metricsScaledSystem(defaultSize: d * 0.5, weight: .semibold, textStyle: .body)
        }

        static func avatarAnonymousGlyph(inCircleDiameter d: CGFloat) -> Font {
            metricsScaledSystem(defaultSize: d * 0.5, weight: .regular, textStyle: .body)
        }

        static func communityBadgeInitial(forDiameter d: CGFloat) -> Font {
            let defaultSize = max(10, d * 0.5)
            let scaled = UIFontMetrics(forTextStyle: .caption1).scaledValue(for: defaultSize)
            let base = UIFont.systemFont(ofSize: scaled, weight: .bold)
            guard let rounded = base.fontDescriptor.withDesign(.rounded) else {
                return Font(base)
            }
            return Font(UIFont(descriptor: rounded, size: scaled))
        }

        // MARK: - Private

        /// Fixed point size at default content size, scaled using the given UIKit text style curve (Dynamic Type).
        private static func metricsScaledSystem(
            defaultSize: CGFloat,
            weight: UIFont.Weight,
            textStyle: UIFont.TextStyle
        ) -> Font {
            let scaled = UIFontMetrics(forTextStyle: textStyle).scaledValue(for: defaultSize)
            return Font(UIFont.systemFont(ofSize: scaled, weight: weight))
        }
    }
}
