import SwiftUI

struct HistoryRootView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                PlaceholderCard(
                    title: "History",
                    message: "Phase 2 will add session timeline and filter chips."
                )
                .padding(AppTheme.Spacing.large)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
