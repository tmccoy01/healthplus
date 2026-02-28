import SwiftUI

struct GlassTabChrome: View {
    struct Item: Identifiable, Hashable {
        let id: String
        let title: String
        let systemImage: String
        let accessibilityIdentifier: String
    }

    let items: [Item]
    @Binding var selectedID: String

    var body: some View {
        GlassCard(style: .chrome, padding: AppTheme.Spacing.small, cornerRadius: AppTheme.Radius.large) {
            HStack(spacing: AppTheme.Spacing.small) {
                ForEach(items) { item in
                    Button {
                        selectedID = item.id
                    } label: {
                        VStack(spacing: AppTheme.Spacing.xSmall) {
                            Image(systemName: item.systemImage)
                                .font(.system(size: 16, weight: .semibold))

                            Text(item.title)
                                .font(AppTheme.Typography.tabLabel)
                                .lineLimit(1)
                        }
                        .foregroundStyle(isSelected(item) ? AppTheme.Colors.textPrimary : AppTheme.Colors.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: AppTheme.Metrics.tabChromeControlHeight)
                        .background {
                            if isSelected(item) {
                                RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                                    .fill(AppTheme.Colors.accent.opacity(0.25))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                                            .stroke(AppTheme.Colors.accent.opacity(0.55), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(item.accessibilityIdentifier)
                    .accessibilityLabel(item.title)
                    .accessibilityHint("Opens the \(item.title) tab")
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.top, AppTheme.Spacing.xSmall)
        .padding(.bottom, AppTheme.Spacing.small)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shell.tab.chrome")
    }

    private func isSelected(_ item: Item) -> Bool {
        selectedID == item.id
    }
}
