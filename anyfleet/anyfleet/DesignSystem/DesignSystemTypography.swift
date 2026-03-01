import SwiftUI

extension DesignSystem {
    enum Typography {
        // MARK: - Display — Onder custom font, only for hero/title contexts
        static let display    = Font.custom("Onder", size: 28).weight(.semibold)
        static let largeTitle = Font.custom("Onder", size: 22).weight(.semibold)

        // MARK: - UI Labels — system font for legibility and Dynamic Type
        static let title      = Font.system(size: 20, weight: .semibold)
        static let headline   = Font.system(size: 17, weight: .semibold)
        static let subheader  = Font.system(size: 16, weight: .semibold)
        static let body       = Font.system(size: 16, weight: .regular)
        static let caption    = Font.system(size: 14, weight: .regular)
        static let micro      = Font.system(size: 11, weight: .medium)
    }
}
