import SwiftData
import SwiftUI

struct WorkoutTypesSettingsView: View {
    @Query(sort: \WorkoutType.sortOrder)
    private var allWorkoutTypes: [WorkoutType]

    private var workoutTypes: [WorkoutType] {
        allWorkoutTypes
            .filter { $0.isArchived == false }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Workout Types") {
                    if workoutTypes.isEmpty {
                        Text("No workout types yet.")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    } else {
                        ForEach(workoutTypes, id: \.id) { workoutType in
                            workoutTypeRow(workoutType)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func workoutTypeRow(_ workoutType: WorkoutType) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Circle()
                .fill(rowColor(for: workoutType))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                Text(workoutType.name)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                HStack(spacing: AppTheme.Spacing.small) {
                    if workoutType.isSystemType {
                        Label("Seeded", systemImage: "lock.fill")
                    } else {
                        Label("Custom", systemImage: "person.fill")
                    }
                }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()

            if let symbolName = workoutType.symbolName {
                Image(systemName: symbolName)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xSmall)
        .listRowBackground(AppTheme.Colors.surface)
    }

    private func rowColor(for workoutType: WorkoutType) -> Color {
        if let colorHex = workoutType.colorHex, let color = Color(hex: colorHex) {
            return color
        }
        return AppTheme.Colors.accent
    }
}
