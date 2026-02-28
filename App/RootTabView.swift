import SwiftUI

struct RootTabView: View {
    private enum AppShellTab: String, CaseIterable {
        case log
        case history
        case stats
        case settings

        var title: String {
            switch self {
            case .log:
                return "Log"
            case .history:
                return "History"
            case .stats:
                return "Stats"
            case .settings:
                return "Settings"
            }
        }

        var symbol: String {
            switch self {
            case .log:
                return "figure.strengthtraining.traditional"
            case .history:
                return "clock.arrow.trianglehead.counterclockwise.rotate.90"
            case .stats:
                return "chart.xyaxis.line"
            case .settings:
                return "gearshape"
            }
        }

        var shellItem: GlassTabChrome.Item {
            GlassTabChrome.Item(
                id: rawValue,
                title: title,
                systemImage: symbol,
                accessibilityIdentifier: "shell.tab.\(rawValue)"
            )
        }
    }

    @State private var selectedTab: AppShellTab = .log

    var body: some View {
        TabView(selection: $selectedTab) {
            LogRootView()
                .tag(AppShellTab.log)

            HistoryRootView()
                .tag(AppShellTab.history)

            StatsRootView()
                .tag(AppShellTab.stats)

            WorkoutTypesSettingsView()
                .tag(AppShellTab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            GlassTabChrome(
                items: AppShellTab.allCases.map(\.shellItem),
                selectedID: selectedTabID
            )
        }
        .background(AppTheme.Gradients.appBackground.ignoresSafeArea())
        .tint(AppTheme.Colors.accent)
        .accessibilityIdentifier("shell.root")
    }

    private var selectedTabID: Binding<String> {
        Binding(
            get: { selectedTab.rawValue },
            set: { rawValue in
                guard let tab = AppShellTab(rawValue: rawValue) else {
                    return
                }
                selectedTab = tab
            }
        )
    }
}
