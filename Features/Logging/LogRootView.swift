import SwiftUI

struct LogRootView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                PlaceholderCard(
                    title: "Log",
                    message: "Phase 2 will add fast session start and set-by-set logging."
                )
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
