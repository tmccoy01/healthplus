import SwiftData
import SwiftUI

struct HistoryRootView: View {
    struct ExerciseFilter: Identifiable {
        let id: String
        let label: String
    }

    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var allSessions: [WorkoutSession]

    @State private var selectedWorkoutTypeID: UUID?
    @State private var selectedExerciseFilterID: String?

    private var completedSessions: [WorkoutSession] {
        allSessions.filter { $0.endedAt != nil }
    }

    private var workoutTypeFilters: [(id: UUID, name: String)] {
        let unique = Dictionary(
            completedSessions.compactMap { session -> (UUID, String)? in
                guard let workoutType = session.workoutType else {
                    return nil
                }
                return (workoutType.id, workoutType.name)
            },
            uniquingKeysWith: { lhs, _ in lhs }
        )

        return unique
            .map { (id: $0.key, name: $0.value) }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var exerciseFilters: [ExerciseFilter] {
        var mapping: [String: String] = [:]
        for session in completedSessions {
            for entry in session.entries {
                let normalized = PreviousWeightLookupService.normalizeExerciseName(entry.exerciseName)
                if normalized.isEmpty {
                    continue
                }

                if mapping[normalized] == nil {
                    mapping[normalized] = entry.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        return mapping
            .map { ExerciseFilter(id: $0.key, label: $0.value) }
            .sorted { lhs, rhs in
                lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
    }

    private var filteredSessions: [WorkoutSession] {
        completedSessions.filter { session in
            if let selectedWorkoutTypeID, session.workoutType?.id != selectedWorkoutTypeID {
                return false
            }

            if let selectedExerciseFilterID {
                let hasMatchingExercise = session.entries.contains { entry in
                    PreviousWeightLookupService.normalizeExerciseName(entry.exerciseName) == selectedExerciseFilterID
                }

                if hasMatchingExercise == false {
                    return false
                }
            }

            return true
        }
    }

    private var groupedSessions: [(weekStart: Date, sessions: [WorkoutSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredSessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.startedAt)?.start ?? session.startedAt
        }

        return grouped
            .map { (weekStart: $0.key, sessions: $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { lhs, rhs in
                lhs.weekStart > rhs.weekStart
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Filters") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.Spacing.small) {
                            filterChip(
                                title: "All Types",
                                isSelected: selectedWorkoutTypeID == nil
                            ) {
                                selectedWorkoutTypeID = nil
                            }

                            ForEach(workoutTypeFilters, id: \.id) { filter in
                                filterChip(
                                    title: filter.name,
                                    isSelected: selectedWorkoutTypeID == filter.id
                                ) {
                                    selectedWorkoutTypeID = filter.id
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.Spacing.small) {
                            filterChip(
                                title: "All Exercises",
                                isSelected: selectedExerciseFilterID == nil
                            ) {
                                selectedExerciseFilterID = nil
                            }

                            ForEach(exerciseFilters) { filter in
                                filterChip(
                                    title: filter.label,
                                    isSelected: selectedExerciseFilterID == filter.id
                                ) {
                                    selectedExerciseFilterID = filter.id
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listRowBackground(AppTheme.Colors.surface.opacity(0.72))

                if groupedSessions.isEmpty {
                    Section("Sessions") {
                        PlaceholderCard(
                            title: completedSessions.isEmpty ? "No Sessions Yet" : "No Matches",
                            message: completedSessions.isEmpty
                                ? "Save your first workout in Log to build your history."
                                : "No sessions match your selected filters."
                        )
                        .accessibilityIdentifier("history.empty.sessions")
                        .listRowInsets(EdgeInsets())
                    }
                    .listRowBackground(AppTheme.Colors.surface.opacity(0.72))
                } else {
                    ForEach(groupedSessions, id: \.weekStart) { group in
                        Section(weekLabel(for: group.weekStart)) {
                            ForEach(group.sessions, id: \.id) { session in
                                NavigationLink {
                                    HistorySessionDetailView(session: session)
                                } label: {
                                    sessionCard(session)
                                }
                                .accessibilityIdentifier("history.session.link")
                            }
                        }
                        .listRowBackground(AppTheme.Colors.surface.opacity(0.72))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(backgroundGradient.ignoresSafeArea())
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .appNavigationChrome()
        }
    }

    private func weekLabel(for weekStart: Date) -> String {
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return weekStart.formatted(.dateTime.month().day().year())
        }

        return "\(weekStart.formatted(.dateTime.month().day())) - \(weekEnd.formatted(.dateTime.month().day()))"
    }

    @ViewBuilder
    private func sessionCard(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack {
                Text(session.workoutType?.name ?? "Unassigned")
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer()

                Text(session.startedAt, format: .dateTime.month().day().hour().minute())
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Text(
                "\(session.entries.count) exercises • \(SessionVolumeCalculator.setCount(for: session)) sets • \(formattedVolume(SessionVolumeCalculator.totalVolume(for: session))) volume"
            )
            .font(AppTheme.Typography.caption)
            .foregroundStyle(AppTheme.Colors.textSecondary)

            if session.sessionNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Text(session.sessionNotes)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xSmall)
    }

    private func filterChip(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        GlassPillButton(title: title, isSelected: isSelected, action: action)
    }

    private var backgroundGradient: LinearGradient {
        AppTheme.Gradients.appBackground
    }

    private func formattedVolume(_ value: Double) -> String {
        Self.volumeFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    private static let volumeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

private struct HistorySessionDetailView: View {
    @Bindable var session: WorkoutSession

    var body: some View {
        SessionEditorView(
            session: session,
            title: "Session Detail",
            showFinishButton: false,
            finishButtonTitle: ""
        )
        .navigationTitle(session.workoutType?.name ?? "Session")
        .navigationBarTitleDisplayMode(.inline)
        .appNavigationChrome()
    }
}
