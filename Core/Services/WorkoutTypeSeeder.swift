import Foundation
import SwiftData

struct WorkoutTypeSeeder {
    struct Definition {
        let name: String
        let colorHex: String
        let symbolName: String
    }

    static let defaults: [Definition] = [
        .init(name: "Back", colorHex: "4A5A66", symbolName: "figure.rower"),
        .init(name: "Triceps", colorHex: "6A7077", symbolName: "bolt.arm"),
        .init(name: "Biceps", colorHex: "7C6A5A", symbolName: "dumbbell"),
        .init(name: "Chest", colorHex: "8A5A4A", symbolName: "figure.strengthtraining.traditional"),
        .init(name: "Shoulders", colorHex: "5D667F", symbolName: "figure.flexibility"),
        .init(name: "Legs", colorHex: "5E6C5A", symbolName: "figure.run"),
        .init(name: "Core", colorHex: "7D5C50", symbolName: "figure.core.training"),
        .init(name: "Cardio", colorHex: "8C6B3A", symbolName: "heart.circle")
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext) throws {
        let existingTypes = try context.fetch(FetchDescriptor<WorkoutType>())
        let normalizedExistingNames = Set(existingTypes.map { normalize($0.name) })

        var nextSortOrder = (existingTypes.map(\.sortOrder).max() ?? -1) + 1
        for definition in defaults where normalizedExistingNames.contains(normalize(definition.name)) == false {
            context.insert(
                WorkoutType(
                    name: definition.name,
                    isSystemType: true,
                    sortOrder: nextSortOrder,
                    colorHex: definition.colorHex,
                    symbolName: definition.symbolName
                )
            )
            nextSortOrder += 1
        }

        if context.hasChanges {
            try context.save()
        }
    }

    static func normalize(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

struct WorkoutTypeManager {
    enum ValidationError: Error, Equatable, LocalizedError {
        case emptyName
        case duplicateName

        var errorDescription: String? {
            switch self {
            case .emptyName:
                return "Workout type name cannot be empty."
            case .duplicateName:
                return "A workout type with this name already exists."
            }
        }
    }

    @MainActor
    static func create(name: String, context: ModelContext) throws -> WorkoutType {
        let sanitizedName = try validate(name: name, excludingWorkoutTypeID: nil, context: context)
        let existingTypes = try context.fetch(FetchDescriptor<WorkoutType>())
        let nextSortOrder = (existingTypes.map(\.sortOrder).max() ?? -1) + 1

        let workoutType = WorkoutType(
            name: sanitizedName,
            sortOrder: nextSortOrder
        )
        context.insert(workoutType)
        try context.save()

        return workoutType
    }

    @MainActor
    static func rename(_ workoutType: WorkoutType, to name: String, context: ModelContext) throws {
        let sanitizedName = try validate(name: name, excludingWorkoutTypeID: workoutType.id, context: context)
        workoutType.name = sanitizedName

        if context.hasChanges {
            try context.save()
        }
    }

    @MainActor
    static func archive(_ workoutType: WorkoutType, context: ModelContext) throws {
        guard workoutType.isArchived == false else {
            return
        }

        workoutType.isArchived = true
        try context.save()
    }

    private static func validate(
        name: String,
        excludingWorkoutTypeID: UUID?,
        context: ModelContext
    ) throws -> String {
        let sanitizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCandidate = WorkoutTypeSeeder.normalize(sanitizedName)

        guard normalizedCandidate.isEmpty == false else {
            throw ValidationError.emptyName
        }

        let existingTypes = try context.fetch(FetchDescriptor<WorkoutType>())
        let hasDuplicate = existingTypes.contains { existingType in
            if let excludingWorkoutTypeID, existingType.id == excludingWorkoutTypeID {
                return false
            }

            return WorkoutTypeSeeder.normalize(existingType.name) == normalizedCandidate
        }

        guard hasDuplicate == false else {
            throw ValidationError.duplicateName
        }

        return sanitizedName
    }
}

struct WorkoutSessionManager {
    enum ValidationError: Error, Equatable, LocalizedError {
        case emptyExerciseName
        case activeSessionAlreadyExists

        var errorDescription: String? {
            switch self {
            case .emptyExerciseName:
                return "Exercise name cannot be empty."
            case .activeSessionAlreadyExists:
                return "Finish the active session before starting a new one."
            }
        }
    }

    @MainActor
    static func startSession(
        workoutType: WorkoutType?,
        notes: String = "",
        context: ModelContext,
        startedAt: Date = .now
    ) throws -> WorkoutSession {
        let activeSessions = try context.fetch(
            FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { session in
                    session.endedAt == nil
                }
            )
        )

        guard activeSessions.isEmpty else {
            throw ValidationError.activeSessionAlreadyExists
        }

        let session = WorkoutSession(
            startedAt: startedAt,
            endedAt: nil,
            workoutType: workoutType,
            sessionNotes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(session)
        try context.save()

        return session
    }

    @MainActor
    static func finishSession(
        _ session: WorkoutSession,
        context: ModelContext,
        endedAt: Date = .now
    ) throws {
        session.endedAt = endedAt
        try saveIfNeeded(context)
    }

    @MainActor
    static func addExercise(
        to session: WorkoutSession,
        name: String,
        notes: String = "",
        context: ModelContext
    ) throws -> ExerciseEntry {
        let sanitizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sanitizedName.isEmpty == false else {
            throw ValidationError.emptyExerciseName
        }

        let nextOrderIndex = (session.entries.map(\.orderIndex).max() ?? -1) + 1
        let entry = ExerciseEntry(
            session: session,
            exerciseName: sanitizedName,
            orderIndex: nextOrderIndex,
            entryNotes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(entry)
        if session.entries.contains(where: { $0.id == entry.id }) == false {
            session.entries.append(entry)
        }
        try saveIfNeeded(context)

        return entry
    }

    @MainActor
    static func removeExercise(
        _ entry: ExerciseEntry,
        from session: WorkoutSession,
        context: ModelContext
    ) throws {
        session.entries.removeAll { $0.id == entry.id }
        context.delete(entry)
        reindexExercises(in: session)
        try saveIfNeeded(context)
    }

    @MainActor
    static func reindexExercises(in session: WorkoutSession) {
        let orderedEntries = session.entries.sorted { lhs, rhs in
            if lhs.orderIndex == rhs.orderIndex {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.orderIndex < rhs.orderIndex
        }

        for (index, entry) in orderedEntries.enumerated() {
            entry.orderIndex = index
        }
    }

    @MainActor
    static func addSet(
        to entry: ExerciseEntry,
        reps: Int = 0,
        weight: Double = 0,
        isWarmup: Bool = false,
        notes: String = "",
        context: ModelContext,
        loggedAt: Date = .now
    ) throws -> SetEntry {
        let nextSetIndex = (entry.sets.map(\.setIndex).max() ?? 0) + 1
        let set = SetEntry(
            exerciseEntry: entry,
            setIndex: nextSetIndex,
            reps: max(0, reps),
            weight: max(0, weight),
            isWarmup: isWarmup,
            setNotes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            loggedAt: loggedAt
        )
        context.insert(set)
        if entry.sets.contains(where: { $0.id == set.id }) == false {
            entry.sets.append(set)
        }
        try saveIfNeeded(context)

        return set
    }

    @MainActor
    static func repeatLastSet(for entry: ExerciseEntry, context: ModelContext) throws -> SetEntry? {
        let orderedSets = orderedSets(for: entry)
        guard let lastSet = orderedSets.last else {
            return nil
        }

        return try addSet(
            to: entry,
            reps: lastSet.reps,
            weight: lastSet.weight,
            isWarmup: lastSet.isWarmup,
            notes: lastSet.setNotes,
            context: context
        )
    }

    @MainActor
    static func removeSet(
        _ set: SetEntry,
        from entry: ExerciseEntry,
        context: ModelContext
    ) throws {
        entry.sets.removeAll { $0.id == set.id }
        context.delete(set)
        reindexSets(in: entry)
        try saveIfNeeded(context)
    }

    @MainActor
    static func reindexSets(in entry: ExerciseEntry) {
        let ordered = orderedSets(for: entry)
        for (index, set) in ordered.enumerated() {
            set.setIndex = index + 1
        }
    }

    @MainActor
    static func orderedSets(for entry: ExerciseEntry) -> [SetEntry] {
        entry.sets.sorted { lhs, rhs in
            if lhs.setIndex == rhs.setIndex {
                return lhs.loggedAt < rhs.loggedAt
            }
            return lhs.setIndex < rhs.setIndex
        }
    }

    @MainActor
    static func saveIfNeeded(_ context: ModelContext) throws {
        if context.hasChanges {
            try context.save()
        }
    }
}

struct PreviousWeightLookupService {
    struct Reference: Equatable {
        let weight: Double
        let reps: Int
        let loggedAt: Date
        let exerciseName: String
        let sessionID: UUID?
    }

    @MainActor
    static func latestReference(
        for exerciseName: String,
        excludingSessionID: UUID? = nil,
        context: ModelContext
    ) throws -> Reference? {
        let normalizedName = normalizeExerciseName(exerciseName)
        guard normalizedName.isEmpty == false else {
            return nil
        }

        let entries = try context.fetch(FetchDescriptor<ExerciseEntry>())
        var bestMatch: Reference?

        for entry in entries {
            guard normalizeExerciseName(entry.exerciseName) == normalizedName else {
                continue
            }

            let sessionID = entry.session?.id
            if let excludingSessionID, sessionID == excludingSessionID {
                continue
            }

            for set in entry.sets {
                let candidate = Reference(
                    weight: set.weight,
                    reps: set.reps,
                    loggedAt: set.loggedAt,
                    exerciseName: entry.exerciseName,
                    sessionID: sessionID
                )

                if let currentBest = bestMatch {
                    if candidate.loggedAt > currentBest.loggedAt {
                        bestMatch = candidate
                    }
                } else {
                    bestMatch = candidate
                }
            }
        }

        return bestMatch
    }

    static func normalizeExerciseName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

struct SessionVolumeCalculator {
    static func totalVolume(for session: WorkoutSession) -> Double {
        session.entries.reduce(0) { subtotal, entry in
            subtotal + entry.sets.reduce(0) { setSubtotal, set in
                setSubtotal + (set.weight * Double(set.reps))
            }
        }
    }

    static func setCount(for session: WorkoutSession) -> Int {
        session.entries.reduce(0) { $0 + $1.sets.count }
    }
}

struct ExerciseStatsEngine {
    enum TrendDirection: Equatable {
        case up
        case flat
        case down
        case insufficientData
    }

    struct PerformancePoint: Identifiable, Equatable {
        let sessionID: UUID
        let date: Date
        let topSetWeight: Double
        let estimatedOneRepMax: Double
        let totalVolume: Double
        let setCount: Int

        var id: UUID { sessionID }
    }

    struct WeeklyVolumePoint: Identifiable, Equatable {
        let weekStart: Date
        let volume: Double

        var id: Date { weekStart }
    }

    struct DashboardSnapshot: Equatable {
        let performancePoints: [PerformancePoint]
        let weeklyVolumePoints: [WeeklyVolumePoint]
        let trend: TrendDirection
        let lastWorkoutDate: Date?
        let bestWeight: Double?
        let bestEstimatedOneRepMax: Double?
        let recentAverageTopSet: Double?
        let previousAverageTopSet: Double?
    }

    static func makeSnapshot(
        sessions: [WorkoutSession],
        normalizedExerciseName: String,
        interval: DateInterval?,
        calendar: Calendar = .current
    ) -> DashboardSnapshot {
        let normalizedName = PreviousWeightLookupService.normalizeExerciseName(normalizedExerciseName)
        guard normalizedName.isEmpty == false else {
            return DashboardSnapshot(
                performancePoints: [],
                weeklyVolumePoints: [],
                trend: .insufficientData,
                lastWorkoutDate: nil,
                bestWeight: nil,
                bestEstimatedOneRepMax: nil,
                recentAverageTopSet: nil,
                previousAverageTopSet: nil
            )
        }

        let completedSessions = sessions
            .filter { $0.endedAt != nil }
            .sorted { lhs, rhs in
                lhs.startedAt < rhs.startedAt
            }

        var performancePoints: [PerformancePoint] = []
        for session in completedSessions {
            if let interval, interval.contains(session.startedAt) == false {
                continue
            }

            var matchingSets: [SetEntry] = []
            for entry in session.entries {
                let normalizedEntryName = PreviousWeightLookupService.normalizeExerciseName(entry.exerciseName)
                if normalizedEntryName == normalizedName {
                    matchingSets.append(contentsOf: entry.sets)
                }
            }

            guard matchingSets.isEmpty == false else {
                continue
            }

            let topSetWeight = matchingSets.map(\.weight).max() ?? 0
            let topOneRepMax = matchingSets
                .map { estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }
                .max() ?? 0
            let totalVolume = matchingSets.reduce(0) { subtotal, set in
                subtotal + (set.weight * Double(set.reps))
            }

            performancePoints.append(
                PerformancePoint(
                    sessionID: session.id,
                    date: session.startedAt,
                    topSetWeight: topSetWeight,
                    estimatedOneRepMax: topOneRepMax,
                    totalVolume: totalVolume,
                    setCount: matchingSets.count
                )
            )
        }

        let groupedByWeek = Dictionary(grouping: performancePoints) { point in
            calendar.dateInterval(of: .weekOfYear, for: point.date)?.start
                ?? calendar.startOfDay(for: point.date)
        }

        let weeklyVolumePoints = groupedByWeek
            .map { weekStart, points in
                WeeklyVolumePoint(
                    weekStart: weekStart,
                    volume: points.reduce(0) { $0 + $1.totalVolume }
                )
            }
            .sorted { lhs, rhs in
                lhs.weekStart < rhs.weekStart
            }

        let topSetWeights = performancePoints.map(\.topSetWeight)
        let recentWeights = Array(topSetWeights.suffix(4))
        let previousWeights = Array(topSetWeights.dropLast(recentWeights.count).suffix(4))

        return DashboardSnapshot(
            performancePoints: performancePoints,
            weeklyVolumePoints: weeklyVolumePoints,
            trend: classifyTrend(weights: topSetWeights),
            lastWorkoutDate: performancePoints.last?.date,
            bestWeight: performancePoints.map(\.topSetWeight).max(),
            bestEstimatedOneRepMax: performancePoints.map(\.estimatedOneRepMax).max(),
            recentAverageTopSet: average(recentWeights),
            previousAverageTopSet: average(previousWeights)
        )
    }

    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        let safeWeight = max(0, weight)
        let safeReps = max(0, reps)
        return safeWeight * (1 + (Double(safeReps) / 30))
    }

    static func classifyTrend(
        weights: [Double],
        minimumSampleCount: Int = 3,
        relativeThreshold: Double = 0.005,
        absoluteThreshold: Double = 1
    ) -> TrendDirection {
        guard weights.count >= minimumSampleCount else {
            return .insufficientData
        }

        let values = weights.map { max(0, $0) }
        let n = Double(values.count)
        let xSum = (n - 1) * n / 2
        let xSquaredSum = (n - 1) * n * (2 * n - 1) / 6

        var xySum = 0.0
        var ySum = 0.0
        for (index, value) in values.enumerated() {
            let x = Double(index)
            xySum += x * value
            ySum += value
        }

        let denominator = (n * xSquaredSum) - (xSum * xSum)
        guard denominator != 0 else {
            return .flat
        }

        let slope = ((n * xySum) - (xSum * ySum)) / denominator
        let averageWeight = ySum / n
        let threshold = max(absoluteThreshold, abs(averageWeight) * relativeThreshold)

        if slope > threshold {
            return .up
        }
        if slope < -threshold {
            return .down
        }
        return .flat
    }

    private static func average(_ values: [Double]) -> Double? {
        guard values.isEmpty == false else {
            return nil
        }
        return values.reduce(0, +) / Double(values.count)
    }
}
