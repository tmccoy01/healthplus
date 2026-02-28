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
