import SwiftUI

struct GlassPillButton: View {
    let title: String
    var systemImage: String?
    var isSelected: Bool
    var action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.xSmall) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(title)
                    .font(AppTheme.Typography.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.vertical, AppTheme.Spacing.xSmall)
            .background {
                Capsule()
                    .fill(fillStyle)
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected
                                    ? AppTheme.Colors.accent.opacity(0.62)
                                    : AppTheme.Colors.hairline.opacity(0.48),
                                lineWidth: 1
                            )
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var fillStyle: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(AppTheme.Colors.accent.opacity(0.26))
        }

        return AnyShapeStyle(AppTheme.material(.chrome))
    }
}
