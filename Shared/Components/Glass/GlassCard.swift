import SwiftUI

struct GlassCard<Content: View>: View {
    enum Style: Equatable {
        case surface
        case elevated
        case chrome
    }

    private let style: Style
    private let padding: CGFloat
    private let cornerRadius: CGFloat
    private let content: Content

    init(
        style: Style = .surface,
        padding: CGFloat = AppTheme.Spacing.large,
        cornerRadius: CGFloat = AppTheme.Radius.large,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                shape
                    .fill(fillStyle)
                    .overlay(
                        shape
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .overlay {
                        if style == .chrome {
                            shape
                                .fill(AppTheme.Gradients.chromeGlow)
                        }
                    }
            )
    }

    private var fillStyle: AnyShapeStyle {
        switch style {
        case .surface:
            return AnyShapeStyle(AppTheme.Colors.surface.opacity(0.78))
        case .elevated:
            return AnyShapeStyle(AppTheme.Colors.surfaceElevated.opacity(0.82))
        case .chrome:
            return AnyShapeStyle(AppTheme.material(.card))
        }
    }

    private var borderColor: Color {
        switch style {
        case .surface:
            return AppTheme.Colors.hairline.opacity(0.55)
        case .elevated:
            return AppTheme.Colors.hairline.opacity(0.68)
        case .chrome:
            return AppTheme.Colors.accentSecondary.opacity(0.42)
        }
    }
}
