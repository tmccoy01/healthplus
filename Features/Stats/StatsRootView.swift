import Charts
import SwiftData
import SwiftUI

struct StatsRootView: View {
    struct ExerciseOption: Identifiable, Hashable {
        let id: String
        let label: String
    }

    enum DateRangePreset: String, CaseIterable, Identifiable {
        case fourWeeks = "4W"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"
        case all = "All"

        var id: String { rawValue }

        var label: String { rawValue }

        func interval(relativeTo referenceDate: Date, calendar: Calendar = .current) -> DateInterval? {
            let end = referenceDate
            let start: Date?

            switch self {
            case .fourWeeks:
                start = calendar.date(byAdding: .weekOfYear, value: -4, to: end)
            case .threeMonths:
                start = calendar.date(byAdding: .month, value: -3, to: end)
            case .sixMonths:
                start = calendar.date(byAdding: .month, value: -6, to: end)
            case .oneYear:
                start = calendar.date(byAdding: .year, value: -1, to: end)
            case .all:
                start = nil
            }

            guard let start else {
                return nil
            }
            return DateInterval(start: start, end: end)
        }
    }

    private enum DashboardState {
        case loading
        case ready(ExerciseStatsEngine.DashboardSnapshot)
        case empty
    }

    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var allSessions: [WorkoutSession]

    @State private var selectedExerciseID: String?
    @State private var selectedDateRange: DateRangePreset = .threeMonths
    @State private var dashboardState: DashboardState = .loading

    private var completedSessions: [WorkoutSession] {
        allSessions.filter { $0.endedAt != nil }
    }

    private var exerciseOptions: [ExerciseOption] {
        var mapping: [String: String] = [:]

        for session in completedSessions {
            for entry in session.entries where entry.sets.isEmpty == false {
                let normalized = PreviousWeightLookupService.normalizeExerciseName(entry.exerciseName)
                guard normalized.isEmpty == false else {
                    continue
                }

                if mapping[normalized] == nil {
                    let trimmed = entry.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                    mapping[normalized] = trimmed.isEmpty ? normalized.capitalized : trimmed
                }
            }
        }

        return mapping
            .map { ExerciseOption(id: $0.key, label: $0.value) }
            .sorted { lhs, rhs in
                lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
    }

    private var dashboardTaskID: String {
        [
            selectedExerciseID ?? "none",
            selectedDateRange.id,
            sessionRevisionSignature
        ].joined(separator: "|")
    }

    private var sessionRevisionSignature: String {
        completedSessions
            .sorted { lhs, rhs in
                lhs.id.uuidString < rhs.id.uuidString
            }
            .map { session in
                let entryRevision = session.entries
                    .sorted { lhs, rhs in
                        lhs.id.uuidString < rhs.id.uuidString
                    }
                    .map { entry in
                        let setRevision = entry.sets
                            .sorted { lhs, rhs in
                                lhs.id.uuidString < rhs.id.uuidString
                            }
                            .map { set in
                                [
                                    set.id.uuidString,
                                    String(set.reps),
                                    String(format: "%.2f", set.weight),
                                    String(Int(set.loggedAt.timeIntervalSince1970))
                                ].joined(separator: ":")
                            }
                            .joined(separator: ",")

                        return [
                            PreviousWeightLookupService.normalizeExerciseName(entry.exerciseName),
                            setRevision
                        ].joined(separator: "#")
                    }
                    .joined(separator: "|")

                return [
                    session.id.uuidString,
                    String(Int(session.startedAt.timeIntervalSince1970)),
                    entryRevision
                ].joined(separator: "~")
            }
            .joined(separator: ";")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.large) {
                    filtersCard
                    content
                }
                .padding(AppTheme.Spacing.large)
            }
            .scrollIndicators(.hidden)
            .background(backgroundGradient.ignoresSafeArea())
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .appNavigationChrome()
        }
        .task(id: dashboardTaskID) {
            await rebuildDashboard()
        }
    }

    @ViewBuilder
    private var content: some View {
        if completedSessions.isEmpty {
            PlaceholderCard(
                title: "No Completed Sessions Yet",
                message: "Save your first workout in Log to unlock progress charts."
            )
            .accessibilityIdentifier("stats.placeholder.noSessions")
        } else {
            switch dashboardState {
            case .loading:
                loadingCard
            case .empty:
                PlaceholderCard(
                    title: "No Exercise Data",
                    message: "Add at least one set to an exercise to generate charts."
                )
                .accessibilityIdentifier("stats.placeholder.noExerciseData")
            case .ready(let snapshot):
                if snapshot.performancePoints.isEmpty {
                    PlaceholderCard(
                        title: "No Data In Range",
                        message: "Try a longer date range or choose a different exercise."
                    )
                    .accessibilityIdentifier("stats.placeholder.noDataInRange")
                } else {
                    metricsSection(snapshot: snapshot)
                    topSetChart(snapshot: snapshot)
                    weeklyVolumeChart(snapshot: snapshot)
                }
            }
        }
    }

    private var filtersCard: some View {
        GlassCard(style: .surface, padding: AppTheme.Spacing.large, cornerRadius: AppTheme.Radius.large) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text("Filters")
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    Text("Exercise")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    Picker("Exercise", selection: Binding(
                        get: { selectedExerciseID ?? "" },
                        set: { selectedExerciseID = $0.isEmpty ? nil : $0 }
                    )) {
                        if exerciseOptions.isEmpty {
                            Text("No exercises").tag("")
                        } else {
                            ForEach(exerciseOptions) { option in
                                Text(option.label).tag(option.id)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.Colors.textPrimary)
                    .accessibilityIdentifier("stats.exercise.picker")
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    Text("Date Range")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    Picker("Date Range", selection: $selectedDateRange) {
                        ForEach(DateRangePreset.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("stats.range.picker")
                }
            }
        }
        .accessibilityIdentifier("stats.filters.card")
    }

    private var loadingCard: some View {
        GlassCard(style: .surface, padding: AppTheme.Spacing.xLarge, cornerRadius: AppTheme.Radius.large) {
            VStack(spacing: AppTheme.Spacing.small) {
                ProgressView()
                    .tint(AppTheme.Colors.accent)

                Text("Loading chart data...")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("stats.loading")
    }

    private func metricsSection(snapshot: ExerciseStatsEngine.DashboardSnapshot) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: AppTheme.Spacing.medium),
                GridItem(.flexible(), spacing: AppTheme.Spacing.medium)
            ],
            spacing: AppTheme.Spacing.medium
        ) {
            metricCard(
                title: "Last Workout",
                value: formattedDate(snapshot.lastWorkoutDate),
                subtitle: selectedExerciseLabel
            )
            .accessibilityIdentifier("stats.metric.lastWorkout")

            metricCard(
                title: "Best Weight",
                value: formattedWeight(snapshot.bestWeight),
                subtitle: "Top set"
            )
            .accessibilityIdentifier("stats.metric.bestWeight")

            metricCard(
                title: "Best 1RM",
                value: formattedWeight(snapshot.bestEstimatedOneRepMax),
                subtitle: "Epley estimate"
            )
            .accessibilityIdentifier("stats.metric.bestOneRM")

            metricCard(
                title: "Trend",
                value: trendTitle(snapshot.trend),
                subtitle: trendSubtitle(snapshot),
                accentColor: trendColor(snapshot.trend),
                iconName: trendIcon(snapshot.trend)
            )
            .accessibilityIdentifier("stats.metric.trend")
        }
    }

    private func metricCard(
        title: String,
        value: String,
        subtitle: String,
        accentColor: Color = AppTheme.Colors.accent,
        iconName: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            HStack(spacing: AppTheme.Spacing.xSmall) {
                if let iconName {
                    Image(systemName: iconName)
                        .foregroundStyle(accentColor)
                }
                Text(value)
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }

            Text(subtitle)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .modifier(StatsCardStyleModifier())
    }

    private func topSetChart(snapshot: ExerciseStatsEngine.DashboardSnapshot) -> some View {
        GlassCard(style: .surface, padding: AppTheme.Spacing.large, cornerRadius: AppTheme.Radius.large) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text("Top Set Weight")
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Chart(snapshot.performancePoints) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.topSetWeight)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.Colors.accent.opacity(0.25), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.topSetWeight)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(.init(lineWidth: 3))
                    .foregroundStyle(AppTheme.Colors.accent)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.topSetWeight)
                    )
                    .symbolSize(42)
                    .foregroundStyle(AppTheme.Colors.accent)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                            .foregroundStyle(AppTheme.Colors.surfaceMuted.opacity(0.45))
                        AxisTick()
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.6))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month().day())
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                            .foregroundStyle(AppTheme.Colors.surfaceMuted.opacity(0.45))
                        AxisTick()
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.6))
                        AxisValueLabel {
                            if let weight = value.as(Double.self) {
                                Text(formattedCompact(weight))
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .accessibilityIdentifier("stats.chart.topSet")
    }

    private func weeklyVolumeChart(snapshot: ExerciseStatsEngine.DashboardSnapshot) -> some View {
        GlassCard(style: .surface, padding: AppTheme.Spacing.large, cornerRadius: AppTheme.Radius.large) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text("Weekly Volume")
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Chart(snapshot.weeklyVolumePoints) { point in
                    BarMark(
                        x: .value("Week", point.weekStart),
                        y: .value("Volume", point.volume)
                    )
                    .cornerRadius(6)
                    .foregroundStyle(AppTheme.Colors.surfaceMuted.gradient)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                            .foregroundStyle(AppTheme.Colors.surfaceMuted.opacity(0.35))
                        AxisTick()
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.6))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month().day())
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                            .foregroundStyle(AppTheme.Colors.surfaceMuted.opacity(0.35))
                        AxisTick()
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.6))
                        AxisValueLabel {
                            if let volume = value.as(Double.self) {
                                Text(formattedCompact(volume))
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .accessibilityIdentifier("stats.chart.weeklyVolume")
    }

    @MainActor
    private func rebuildDashboard() async {
        ensureValidSelection()

        guard completedSessions.isEmpty == false else {
            dashboardState = .empty
            return
        }

        guard let selectedExerciseID, exerciseOptions.isEmpty == false else {
            dashboardState = .empty
            return
        }

        dashboardState = .loading
        await Task.yield()

        let snapshot = ExerciseStatsEngine.makeSnapshot(
            sessions: completedSessions,
            normalizedExerciseName: selectedExerciseID,
            interval: selectedDateRange.interval(relativeTo: .now)
        )

        dashboardState = .ready(snapshot)
    }

    @MainActor
    private func ensureValidSelection() {
        if let selectedExerciseID,
           exerciseOptions.contains(where: { $0.id == selectedExerciseID }) {
            return
        }

        selectedExerciseID = exerciseOptions.first?.id
    }

    private var selectedExerciseLabel: String {
        exerciseOptions.first(where: { $0.id == selectedExerciseID })?.label ?? "Exercise"
    }

    private struct StatsCardStyleModifier: ViewModifier {
        func body(content: Content) -> some View {
            GlassCard(
                style: .surface,
                padding: AppTheme.Spacing.medium,
                cornerRadius: AppTheme.Radius.medium
            ) {
                content
            }
        }
    }

    private func trendTitle(_ trend: ExerciseStatsEngine.TrendDirection) -> String {
        switch trend {
        case .up:
            return "Up"
        case .flat:
            return "Flat"
        case .down:
            return "Down"
        case .insufficientData:
            return "Needs Data"
        }
    }

    private func trendSubtitle(_ snapshot: ExerciseStatsEngine.DashboardSnapshot) -> String {
        guard let recent = snapshot.recentAverageTopSet,
              let previous = snapshot.previousAverageTopSet else {
            return "At least 3 sessions needed"
        }

        let delta = recent - previous
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(formattedCompact(delta)) vs prior block"
    }

    private func trendColor(_ trend: ExerciseStatsEngine.TrendDirection) -> Color {
        switch trend {
        case .up:
            return AppTheme.Colors.trendUp
        case .flat, .insufficientData:
            return AppTheme.Colors.trendFlat
        case .down:
            return AppTheme.Colors.trendDown
        }
    }

    private func trendIcon(_ trend: ExerciseStatsEngine.TrendDirection) -> String {
        switch trend {
        case .up:
            return "arrow.up.right"
        case .flat:
            return "arrow.right"
        case .down:
            return "arrow.down.right"
        case .insufficientData:
            return "ellipsis"
        }
    }

    private var backgroundGradient: LinearGradient {
        AppTheme.Gradients.appBackground
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return "--"
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private func formattedWeight(_ value: Double?) -> String {
        guard let value else {
            return "--"
        }
        return "\(formattedCompact(value)) lb"
    }

    private func formattedCompact(_ value: Double) -> String {
        Self.numberFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}
