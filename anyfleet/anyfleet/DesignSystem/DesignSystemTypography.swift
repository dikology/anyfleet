import SwiftUI

extension DesignSystem {
    enum Typography {
        // MARK: - Helpers
        /// Replace "Onder" with the actual PostScript name of ONDER-REGULAR.TTF if needed.
        private static func headerFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            Font.custom("Onder", size: size).weight(weight)
        }

        // Display / headers using custom font
        static let largeTitle = headerFont(size: 20, weight: .semibold)
        static let title = headerFont(size: 18, weight: .semibold)
        static let headline = headerFont(size: 12, weight: .semibold)
        
        // Body
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        
        // Small text
        static let caption = Font.system(size: 14, weight: .regular, design: .default)
    }
}


