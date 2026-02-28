import SwiftUI

struct StatsRootView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                PlaceholderCard(
                    title: "Stats",
                    message: "Phase 3 will add charts and trend indicators."
                )
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
