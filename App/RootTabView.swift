import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            LogRootView()
                .tabItem {
                    Label("Log", systemImage: "figure.strengthtraining.traditional")
                }

            HistoryRootView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }

            StatsRootView()
                .tabItem {
                    Label("Stats", systemImage: "chart.xyaxis.line")
                }

            WorkoutTypesSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(AppTheme.Colors.accent)
    }
}
