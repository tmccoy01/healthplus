import SwiftUI

enum AppTheme {
    enum ColorToken: String, CaseIterable {
        case bgCanvas
        case bgSurface
        case bgSurfaceElevated
        case glassChromeTint
        case textPrimary
        case textSecondary
        case textTertiary
        case borderHairline
        case accentPrimary
        case accentSecondary
        case stateSuccess
        case stateWarning
        case stateError
    }

    enum LegacyColorAlias: CaseIterable {
        case background
        case surface
        case surfaceMuted
        case textPrimary
        case textSecondary
        case accent
        case trendUp
        case trendFlat
        case trendDown
    }

    enum MaterialToken {
        case chrome
        case card
        case overlay
    }

    static func token(for alias: LegacyColorAlias) -> ColorToken {
        switch alias {
        case .background:
            return .bgCanvas
        case .surface:
            return .bgSurface
        case .surfaceMuted:
            return .bgSurfaceElevated
        case .textPrimary:
            return .textPrimary
        case .textSecondary:
            return .textSecondary
        case .accent:
            return .accentPrimary
        case .trendUp:
            return .stateSuccess
        case .trendFlat:
            return .stateWarning
        case .trendDown:
            return .stateError
        }
    }

    static func hex(for token: ColorToken) -> String {
        switch token {
        case .bgCanvas:
            return "0B0E11"
        case .bgSurface:
            return "11161C"
        case .bgSurfaceElevated:
            return "1A2330"
        case .glassChromeTint:
            return "29384A"
        case .textPrimary:
            return "F4F8FF"
        case .textSecondary:
            return "C5D0DE"
        case .textTertiary:
            return "93A0B3"
        case .borderHairline:
            return "3A4656"
        case .accentPrimary:
            return "27C0D9"
        case .accentSecondary:
            return "6ED6E6"
        case .stateSuccess:
            return "44D07D"
        case .stateWarning:
            return "F4C257"
        case .stateError:
            return "F06A5F"
        }
    }

    static func color(_ token: ColorToken) -> Color {
        guard let value = Color(hex: hex(for: token)) else {
            return .pink
        }
        return value
    }

    static func material(_ token: MaterialToken) -> Material {
        switch token {
        case .chrome:
            return .ultraThinMaterial
        case .card:
            return .thinMaterial
        case .overlay:
            return .regularMaterial
        }
    }

    enum Colors {
        static let canvas = AppTheme.color(.bgCanvas)
        static let surface = AppTheme.color(.bgSurface)
        static let surfaceElevated = AppTheme.color(.bgSurfaceElevated)
        static let chromeTint = AppTheme.color(.glassChromeTint)

        static let textPrimary = AppTheme.color(.textPrimary)
        static let textSecondary = AppTheme.color(.textSecondary)
        static let textTertiary = AppTheme.color(.textTertiary)

        static let hairline = AppTheme.color(.borderHairline)

        static let accent = AppTheme.color(.accentPrimary)
        static let accentSecondary = AppTheme.color(.accentSecondary)

        static let trendUp = AppTheme.color(.stateSuccess)
        static let trendFlat = AppTheme.color(.stateWarning)
        static let trendDown = AppTheme.color(.stateError)

        // Compatibility aliases for existing phase 0-4 views.
        static let background = canvas
        static let surfaceMuted = surfaceElevated
    }

    enum Gradients {
        static let appBackground = LinearGradient(
            colors: [
                Colors.canvas,
                Colors.surface,
                Colors.surfaceElevated
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let chromeGlow = LinearGradient(
            colors: [
                Colors.chromeTint.opacity(0.48),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let pill: CGFloat = 999
    }

    enum Metrics {
        static let minimumRowHeight: CGFloat = 56
        static let tabChromeControlHeight: CGFloat = 50
    }

    enum Typography {
        static let pageTitle = Font.system(.title2, design: .rounded).weight(.bold)
        static let sectionTitle = Font.system(.headline, design: .rounded).weight(.semibold)
        static let body = Font.system(.body, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded)
        static let metricValue = Font.system(.title3, design: .rounded).weight(.semibold).monospacedDigit()
        static let tabLabel = Font.system(.footnote, design: .rounded).weight(.semibold)
    }
}

struct AppNavigationChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(AppTheme.material(.chrome), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension View {
    func appNavigationChrome() -> some View {
        modifier(AppNavigationChromeModifier())
    }
}
