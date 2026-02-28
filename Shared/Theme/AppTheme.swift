import SwiftUI

enum AppTheme {
    enum Colors {
        static let background = Color(red: 0.09, green: 0.10, blue: 0.11)
        static let surface = Color(red: 0.14, green: 0.15, blue: 0.17)
        static let surfaceMuted = Color(red: 0.18, green: 0.19, blue: 0.22)
        static let textPrimary = Color.white
        static let textSecondary = Color(red: 0.77, green: 0.79, blue: 0.82)

        static let accent = Color(red: 0.93, green: 0.46, blue: 0.17)
        static let trendUp = Color(red: 0.22, green: 0.73, blue: 0.34)
        static let trendFlat = Color(red: 0.89, green: 0.66, blue: 0.12)
        static let trendDown = Color(red: 0.86, green: 0.25, blue: 0.22)
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    enum Typography {
        static let pageTitle = Font.system(.title2, design: .rounded).weight(.semibold)
        static let sectionTitle = Font.system(.headline, design: .rounded).weight(.semibold)
        static let body = Font.system(.body, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded)
    }
}
