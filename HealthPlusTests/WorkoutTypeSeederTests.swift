import SwiftData
import XCTest
@testable import HealthPlus

@MainActor
final class WorkoutTypeSeederTests: XCTestCase {
    func testSeedIfNeededInsertsDefaultsIntoEmptyStore() throws {
        let store = try makeInMemoryStore()
        let context = store.context

        try WorkoutTypeSeeder.seedIfNeeded(context: context)
        let workoutTypes = try context.fetch(FetchDescriptor<WorkoutType>())

        XCTAssertEqual(workoutTypes.count, WorkoutTypeSeeder.defaults.count)
        XCTAssertEqual(Set(workoutTypes.map(\.name)).count, WorkoutTypeSeeder.defaults.count)
    }

    func testSeedIfNeededIsIdempotent() throws {
        let store = try makeInMemoryStore()
        let context = store.context

        try WorkoutTypeSeeder.seedIfNeeded(context: context)
        try WorkoutTypeSeeder.seedIfNeeded(context: context)

        let workoutTypes = try context.fetch(FetchDescriptor<WorkoutType>())
        XCTAssertEqual(workoutTypes.count, WorkoutTypeSeeder.defaults.count)
    }

    func testSeedIfNeededSkipsNamesThatAlreadyExistWithDifferentCasingAndWhitespace() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        context.insert(WorkoutType(name: "  back  ", isSystemType: false, sortOrder: 300))
        try context.save()

        try WorkoutTypeSeeder.seedIfNeeded(context: context)

        let workoutTypes = try context.fetch(FetchDescriptor<WorkoutType>())
        let backLikeTypes = workoutTypes.filter { WorkoutTypeSeeder.normalize($0.name) == "back" }

        XCTAssertEqual(backLikeTypes.count, 1)
        XCTAssertEqual(workoutTypes.count, WorkoutTypeSeeder.defaults.count)
    }

    func testNormalizeTrimsAndCaseFolds() {
        XCTAssertEqual(WorkoutTypeSeeder.normalize("  TrÍCePs "), "triceps")
    }

    private struct InMemoryStore {
        let container: ModelContainer
        let context: ModelContext
    }

    private func makeInMemoryStore() throws -> InMemoryStore {
        let schema = Schema([
            WorkoutType.self,
            ExerciseTemplate.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetEntry.self,
            BodyMetric.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return InMemoryStore(container: container, context: container.mainContext)
    }
}

@MainActor
final class WorkoutTypeManagerTests: XCTestCase {
    func testCreateAddsWorkoutTypeWithTrimmedNameAndNextSortOrder() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        context.insert(WorkoutType(name: "Back", sortOrder: 1))
        context.insert(WorkoutType(name: "Chest", sortOrder: 4))
        try context.save()

        let created = try WorkoutTypeManager.create(name: "  Arms  ", context: context)
        let fetchedTypes = try context.fetch(FetchDescriptor<WorkoutType>())

        XCTAssertEqual(created.name, "Arms")
        XCTAssertEqual(created.sortOrder, 5)
        XCTAssertTrue(fetchedTypes.contains { $0.id == created.id })
    }

    func testCreateRejectsEmptyName() throws {
        let store = try makeInMemoryStore()
        let context = store.context

        XCTAssertThrowsError(try WorkoutTypeManager.create(name: "   \n", context: context)) { error in
            XCTAssertEqual(error as? WorkoutTypeManager.ValidationError, .emptyName)
        }
    }

    func testCreateRejectsDuplicateNameIgnoringCaseAndWhitespace() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        context.insert(WorkoutType(name: "Back"))
        try context.save()

        XCTAssertThrowsError(try WorkoutTypeManager.create(name: "  bAcK  ", context: context)) { error in
            XCTAssertEqual(error as? WorkoutTypeManager.ValidationError, .duplicateName)
        }
    }

    func testRenameRejectsDuplicateNameIgnoringCaseAndWhitespace() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        let back = WorkoutType(name: "Back")
        let chest = WorkoutType(name: "Chest")
        context.insert(back)
        context.insert(chest)
        try context.save()

        XCTAssertThrowsError(try WorkoutTypeManager.rename(chest, to: "  back ", context: context)) { error in
            XCTAssertEqual(error as? WorkoutTypeManager.ValidationError, .duplicateName)
        }
    }

    func testRenameAllowsSameWorkoutTypeWithDifferentCaseAndWhitespace() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        let back = WorkoutType(name: "Back")
        context.insert(back)
        try context.save()

        try WorkoutTypeManager.rename(back, to: "  BACK  ", context: context)

        XCTAssertEqual(back.name, "BACK")
    }

    func testArchiveMarksWorkoutTypeArchivedAndPreservesSessionReference() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        let workoutType = WorkoutType(name: "Legs")
        let session = WorkoutSession(workoutType: workoutType)
        context.insert(workoutType)
        context.insert(session)
        try context.save()

        try WorkoutTypeManager.archive(workoutType, context: context)
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())

        XCTAssertTrue(workoutType.isArchived)
        XCTAssertEqual(sessions.first?.workoutType?.id, workoutType.id)
    }

    private struct InMemoryStore {
        let container: ModelContainer
        let context: ModelContext
    }

    private func makeInMemoryStore() throws -> InMemoryStore {
        let schema = Schema([
            WorkoutType.self,
            ExerciseTemplate.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetEntry.self,
            BodyMetric.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return InMemoryStore(container: container, context: container.mainContext)
    }
}

@MainActor
final class WorkoutSessionManagerTests: XCTestCase {
    func testStartSessionPersistsWorkoutTypeAndBlocksSecondActiveSession() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        let workoutType = WorkoutType(name: "Back")
        context.insert(workoutType)
        try context.save()

        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let session = try WorkoutSessionManager.startSession(
            workoutType: workoutType,
            notes: "  Heavy pull day  ",
            context: context,
            startedAt: startedAt
        )

        XCTAssertEqual(session.workoutType?.id, workoutType.id)
        XCTAssertEqual(session.startedAt, startedAt)
        XCTAssertEqual(session.sessionNotes, "Heavy pull day")

        XCTAssertThrowsError(try WorkoutSessionManager.startSession(workoutType: workoutType, context: context)) { error in
            XCTAssertEqual(error as? WorkoutSessionManager.ValidationError, .activeSessionAlreadyExists)
        }
    }

    func testAddExerciseTrimsNameAndAssignsOrder() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        let session = try WorkoutSessionManager.startSession(workoutType: nil, context: context)

        let first = try WorkoutSessionManager.addExercise(to: session, name: "  Bench Press ", context: context)
        let second = try WorkoutSessionManager.addExercise(to: session, name: "Incline DB Press", context: context)

        XCTAssertEqual(first.exerciseName, "Bench Press")
        XCTAssertEqual(first.orderIndex, 0)
        XCTAssertEqual(second.orderIndex, 1)
    }

    func testSetOperationsRepeatAndRenumber() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        let session = try WorkoutSessionManager.startSession(workoutType: nil, context: context)
        let entry = try WorkoutSessionManager.addExercise(to: session, name: "Deadlift", context: context)

        let first = try WorkoutSessionManager.addSet(to: entry, reps: 5, weight: 225, context: context)
        let second = try WorkoutSessionManager.addSet(to: entry, reps: 3, weight: 275, context: context)
        let repeated = try XCTUnwrap(WorkoutSessionManager.repeatLastSet(for: entry, context: context))

        XCTAssertEqual(first.setIndex, 1)
        XCTAssertEqual(second.setIndex, 2)
        XCTAssertEqual(repeated.setIndex, 3)
        XCTAssertEqual(repeated.reps, 3)
        XCTAssertEqual(repeated.weight, 275)

        try WorkoutSessionManager.removeSet(second, from: entry, context: context)
        let ordered = WorkoutSessionManager.orderedSets(for: entry)

        XCTAssertEqual(ordered.count, 2)
        XCTAssertEqual(ordered[0].setIndex, 1)
        XCTAssertEqual(ordered[1].setIndex, 2)
        XCTAssertEqual(ordered[1].reps, 3)
    }

    func testFinishSessionSetsEndDate() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        let session = try WorkoutSessionManager.startSession(workoutType: nil, context: context)
        let endedAt = Date(timeIntervalSince1970: 1_700_000_100)

        try WorkoutSessionManager.finishSession(session, context: context, endedAt: endedAt)

        XCTAssertEqual(session.endedAt, endedAt)
    }

    private struct InMemoryStore {
        let container: ModelContainer
        let context: ModelContext
    }

    private func makeInMemoryStore() throws -> InMemoryStore {
        let schema = Schema([
            WorkoutType.self,
            ExerciseTemplate.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetEntry.self,
            BodyMetric.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return InMemoryStore(container: container, context: container.mainContext)
    }
}

@MainActor
final class PreviousWeightLookupServiceTests: XCTestCase {
    func testLatestReferenceMatchesByNormalizedNameAndUsesMostRecentSet() throws {
        let store = try makeInMemoryStore()
        let context = store.context

        let oldSession = try WorkoutSessionManager.startSession(
            workoutType: nil,
            context: context,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let oldEntry = try WorkoutSessionManager.addExercise(to: oldSession, name: "Bench Press", context: context)
        _ = try WorkoutSessionManager.addSet(
            to: oldEntry,
            reps: 8,
            weight: 155,
            context: context,
            loggedAt: Date(timeIntervalSince1970: 1_700_000_010)
        )
        try WorkoutSessionManager.finishSession(oldSession, context: context)

        let newSession = try WorkoutSessionManager.startSession(
            workoutType: nil,
            context: context,
            startedAt: Date(timeIntervalSince1970: 1_700_010_000)
        )
        let newEntry = try WorkoutSessionManager.addExercise(to: newSession, name: "  bench press  ", context: context)
        _ = try WorkoutSessionManager.addSet(
            to: newEntry,
            reps: 5,
            weight: 185,
            context: context,
            loggedAt: Date(timeIntervalSince1970: 1_700_010_010)
        )
        try WorkoutSessionManager.finishSession(newSession, context: context)

        let reference = try PreviousWeightLookupService.latestReference(
            for: "BENCH PRESS",
            context: context
        )

        XCTAssertEqual(reference?.weight, 185)
        XCTAssertEqual(reference?.reps, 5)
    }

    func testLatestReferenceCanExcludeCurrentSession() throws {
        let store = try makeInMemoryStore()
        let context = store.context

        let priorSession = try WorkoutSessionManager.startSession(workoutType: nil, context: context)
        let priorEntry = try WorkoutSessionManager.addExercise(to: priorSession, name: "Squat", context: context)
        _ = try WorkoutSessionManager.addSet(
            to: priorEntry,
            reps: 5,
            weight: 225,
            context: context,
            loggedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )
        try WorkoutSessionManager.finishSession(priorSession, context: context)

        let currentSession = try WorkoutSessionManager.startSession(workoutType: nil, context: context)
        let currentEntry = try WorkoutSessionManager.addExercise(to: currentSession, name: "squat", context: context)
        _ = try WorkoutSessionManager.addSet(
            to: currentEntry,
            reps: 3,
            weight: 245,
            context: context,
            loggedAt: Date(timeIntervalSince1970: 1_700_000_002)
        )

        let reference = try PreviousWeightLookupService.latestReference(
            for: "  squat ",
            excludingSessionID: currentSession.id,
            context: context
        )

        XCTAssertEqual(reference?.weight, 225)
        XCTAssertEqual(reference?.reps, 5)
    }

    func testLatestReferenceReturnsNilWhenNoMatch() throws {
        let store = try makeInMemoryStore()
        let context = store.context

        let reference = try PreviousWeightLookupService.latestReference(for: "Row", context: context)
        XCTAssertNil(reference)
    }

    private struct InMemoryStore {
        let container: ModelContainer
        let context: ModelContext
    }

    private func makeInMemoryStore() throws -> InMemoryStore {
        let schema = Schema([
            WorkoutType.self,
            ExerciseTemplate.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetEntry.self,
            BodyMetric.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return InMemoryStore(container: container, context: container.mainContext)
    }
}

@MainActor
final class ExerciseStatsEngineTests: XCTestCase {
    func testEstimatedOneRepMaxUsesEpleyFormula() {
        let oneRepMax = ExerciseStatsEngine.estimatedOneRepMax(weight: 200, reps: 5)
        XCTAssertEqual(oneRepMax, 233.3333, accuracy: 0.0001)
    }

    func testSnapshotBuildsPerformanceAndWeeklyVolumeAndUpTrend() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        let exerciseName = "Bench Press"
        let normalized = PreviousWeightLookupService.normalizeExerciseName(exerciseName)

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        try addCompletedSession(
            startedAt: t0,
            exerciseName: exerciseName,
            sets: [(8, 185), (6, 195)],
            context: context
        )
        try addCompletedSession(
            startedAt: t0.addingTimeInterval(7 * 24 * 60 * 60),
            exerciseName: exerciseName,
            sets: [(5, 205)],
            context: context
        )
        try addCompletedSession(
            startedAt: t0.addingTimeInterval(14 * 24 * 60 * 60),
            exerciseName: exerciseName,
            sets: [(3, 225)],
            context: context
        )

        let snapshot = ExerciseStatsEngine.makeSnapshot(
            sessions: try context.fetch(FetchDescriptor<WorkoutSession>()),
            normalizedExerciseName: normalized,
            interval: nil
        )

        XCTAssertEqual(snapshot.performancePoints.count, 3)
        XCTAssertEqual(snapshot.weeklyVolumePoints.count, 3)
        XCTAssertEqual(try XCTUnwrap(snapshot.bestWeight), 225, accuracy: 0.001)
        XCTAssertEqual(snapshot.trend, .up)
        XCTAssertEqual(snapshot.performancePoints.map(\.topSetWeight), [195, 205, 225])
    }

    func testSnapshotRespectsDateInterval() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        let normalized = PreviousWeightLookupService.normalizeExerciseName("Squat")
        let calendar = Calendar(identifier: .gregorian)

        let referenceDate = Date(timeIntervalSince1970: 1_710_000_000)
        let oldDate = calendar.date(byAdding: .month, value: -8, to: referenceDate) ?? referenceDate
        let recentDate = calendar.date(byAdding: .day, value: -20, to: referenceDate) ?? referenceDate

        try addCompletedSession(
            startedAt: oldDate,
            exerciseName: "Squat",
            sets: [(5, 225)],
            context: context
        )
        try addCompletedSession(
            startedAt: recentDate,
            exerciseName: "Squat",
            sets: [(5, 255)],
            context: context
        )

        let interval = DateInterval(
            start: calendar.date(byAdding: .month, value: -3, to: referenceDate) ?? referenceDate,
            end: referenceDate
        )

        let snapshot = ExerciseStatsEngine.makeSnapshot(
            sessions: try context.fetch(FetchDescriptor<WorkoutSession>()),
            normalizedExerciseName: normalized,
            interval: interval,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.performancePoints.count, 1)
        XCTAssertEqual(try XCTUnwrap(snapshot.performancePoints.first?.topSetWeight), 255, accuracy: 0.001)
    }

    func testClassifyTrendHandlesInsufficientFlatAndDown() {
        XCTAssertEqual(
            ExerciseStatsEngine.classifyTrend(weights: [135, 145]),
            .insufficientData
        )
        XCTAssertEqual(
            ExerciseStatsEngine.classifyTrend(weights: [200, 200.3, 199.8, 200.2]),
            .flat
        )
        XCTAssertEqual(
            ExerciseStatsEngine.classifyTrend(weights: [245, 235, 225, 215]),
            .down
        )
    }

    func testTrendClassificationUpdatesWhenNewSessionIsAdded() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        let normalized = PreviousWeightLookupService.normalizeExerciseName("Deadlift")
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        try addCompletedSession(
            startedAt: t0,
            exerciseName: "Deadlift",
            sets: [(5, 315)],
            context: context
        )
        try addCompletedSession(
            startedAt: t0.addingTimeInterval(7 * 24 * 60 * 60),
            exerciseName: "Deadlift",
            sets: [(5, 305)],
            context: context
        )
        try addCompletedSession(
            startedAt: t0.addingTimeInterval(14 * 24 * 60 * 60),
            exerciseName: "Deadlift",
            sets: [(5, 295)],
            context: context
        )

        let baseline = ExerciseStatsEngine.makeSnapshot(
            sessions: try context.fetch(FetchDescriptor<WorkoutSession>()),
            normalizedExerciseName: normalized,
            interval: nil
        )
        XCTAssertEqual(baseline.trend, .down)

        try addCompletedSession(
            startedAt: t0.addingTimeInterval(21 * 24 * 60 * 60),
            exerciseName: "Deadlift",
            sets: [(4, 355)],
            context: context
        )

        let updated = ExerciseStatsEngine.makeSnapshot(
            sessions: try context.fetch(FetchDescriptor<WorkoutSession>()),
            normalizedExerciseName: normalized,
            interval: nil
        )
        XCTAssertEqual(updated.trend, .up)
    }

    private func addCompletedSession(
        startedAt: Date,
        exerciseName: String,
        sets: [(reps: Int, weight: Double)],
        context: ModelContext
    ) throws {
        let session = try WorkoutSessionManager.startSession(
            workoutType: nil,
            context: context,
            startedAt: startedAt
        )
        let entry = try WorkoutSessionManager.addExercise(
            to: session,
            name: exerciseName,
            context: context
        )

        for (index, set) in sets.enumerated() {
            _ = try WorkoutSessionManager.addSet(
                to: entry,
                reps: set.reps,
                weight: set.weight,
                context: context,
                loggedAt: startedAt.addingTimeInterval(Double(index) * 60)
            )
        }

        try WorkoutSessionManager.finishSession(
            session,
            context: context,
            endedAt: startedAt.addingTimeInterval(60 * 60)
        )
    }

    private struct InMemoryStore {
        let container: ModelContainer
        let context: ModelContext
    }

    private func makeInMemoryStore() throws -> InMemoryStore {
        let schema = Schema([
            WorkoutType.self,
            ExerciseTemplate.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetEntry.self,
            BodyMetric.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return InMemoryStore(container: container, context: container.mainContext)
    }
}
