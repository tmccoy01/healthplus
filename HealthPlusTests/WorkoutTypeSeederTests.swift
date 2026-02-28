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
final class LogFeedTimelineServiceTests: XCTestCase {
    func testGroupSessionsByDaySortsByDayAndSessionStartDescending() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))

        let dayOneMorning = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))
        )
        let dayOneEvening = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 18, minute: 30))
        )
        let dayZero = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 2, day: 23, hour: 20, minute: 15))
        )

        let first = WorkoutSession(startedAt: dayOneMorning, endedAt: dayOneMorning.addingTimeInterval(3600))
        let second = WorkoutSession(startedAt: dayOneEvening, endedAt: dayOneEvening.addingTimeInterval(3600))
        let third = WorkoutSession(startedAt: dayZero, endedAt: dayZero.addingTimeInterval(3600))

        let groups = LogFeedTimelineService.groupSessionsByDay([first, third, second], calendar: calendar)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].dayStart, calendar.startOfDay(for: dayOneMorning))
        XCTAssertEqual(groups[0].sessions.map(\.id), [second.id, first.id])
        XCTAssertEqual(groups[1].dayStart, calendar.startOfDay(for: dayZero))
        XCTAssertEqual(groups[1].sessions.map(\.id), [third.id])
    }

    func testSummaryLinesIncludesSetCountAndOverflowIndicator() {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_760_000_000),
            endedAt: Date(timeIntervalSince1970: 1_760_003_600)
        )

        let cableRow = ExerciseEntry(session: session, exerciseName: "Cable Row", orderIndex: 0)
        cableRow.sets = [
            makeSet(for: cableRow, index: 1),
            makeSet(for: cableRow, index: 2),
            makeSet(for: cableRow, index: 3),
            makeSet(for: cableRow, index: 4)
        ]

        let facePull = ExerciseEntry(session: session, exerciseName: "Face Pull", orderIndex: 1)
        facePull.sets = [
            makeSet(for: facePull, index: 1),
            makeSet(for: facePull, index: 2)
        ]

        let curls = ExerciseEntry(session: session, exerciseName: "Curls", orderIndex: 2)
        curls.sets = [makeSet(for: curls, index: 1)]

        let rearDelt = ExerciseEntry(session: session, exerciseName: "Rear Delt Fly", orderIndex: 3)
        rearDelt.sets = [makeSet(for: rearDelt, index: 1)]

        session.entries = [rearDelt, curls, facePull, cableRow]

        let lines = LogFeedTimelineService.summaryLines(for: session, maxLineCount: 3)

        XCTAssertEqual(lines, ["4x Cable Row", "2x Face Pull", "+2 more"])
    }

    func testSummaryLinesUsesFallbackWhenSessionHasNoExercises() {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_760_000_000),
            endedAt: Date(timeIntervalSince1970: 1_760_003_600)
        )

        XCTAssertEqual(
            LogFeedTimelineService.summaryLines(for: session),
            ["No exercises logged"]
        )
    }

    func testDurationLabelHandlesSubMinuteAndHourMinuteFormats() {
        let shortSession = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_760_000_000),
            endedAt: Date(timeIntervalSince1970: 1_760_000_030)
        )
        XCTAssertEqual(LogFeedTimelineService.durationLabel(for: shortSession), "<1m")

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]

        let longSession = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_760_000_000),
            endedAt: Date(timeIntervalSince1970: 1_760_005_400)
        )

        let longLabel = LogFeedTimelineService.durationLabel(for: longSession, formatter: formatter)
        XCTAssertTrue(longLabel == "1:30" || longLabel == "01:30")
    }

    private func makeSet(for entry: ExerciseEntry, index: Int) -> SetEntry {
        SetEntry(exerciseEntry: entry, setIndex: index, reps: 8, weight: 135)
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
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let session = try WorkoutSessionManager.startSession(
            workoutType: nil,
            context: context,
            startedAt: startedAt
        )
        let endedAt = startedAt.addingTimeInterval(100)

        try WorkoutSessionManager.finishSession(session, context: context, endedAt: endedAt)

        XCTAssertEqual(session.endedAt, endedAt)
    }

    func testFinishSessionClampsEndDateWhenProvidedDateIsBeforeStart() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        let startedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let session = try WorkoutSessionManager.startSession(
            workoutType: nil,
            context: context,
            startedAt: startedAt
        )

        try WorkoutSessionManager.finishSession(
            session,
            context: context,
            endedAt: startedAt.addingTimeInterval(-300)
        )

        XCTAssertEqual(session.endedAt, startedAt)
    }

    func testAddSetSanitizesNegativeAndNonFiniteValues() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        let session = try WorkoutSessionManager.startSession(workoutType: nil, context: context)
        let entry = try WorkoutSessionManager.addExercise(to: session, name: "Row", context: context)

        let set = try WorkoutSessionManager.addSet(
            to: entry,
            reps: -8,
            weight: .infinity,
            context: context
        )

        XCTAssertEqual(set.reps, 0)
        XCTAssertEqual(set.weight, 0)
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
final class Phase4DataIntegrityServiceTests: XCTestCase {
    func testRepairNormalizesCorruptedSessionEntryAndSetData() throws {
        let store = try makeInMemoryStore()
        let context = store.context

        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let session = WorkoutSession(
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(-120),
            workoutType: nil,
            sessionNotes: "  Heavy day  "
        )
        context.insert(session)

        let entry = ExerciseEntry(
            session: session,
            exerciseName: "   ",
            orderIndex: 9,
            entryNotes: "  Keep elbows tight  "
        )
        context.insert(entry)
        session.entries.append(entry)

        let setA = SetEntry(
            exerciseEntry: nil,
            setIndex: 7,
            reps: -5,
            weight: -135,
            isWarmup: true,
            setNotes: "  Warmup set  ",
            loggedAt: startedAt.addingTimeInterval(10)
        )
        let setB = SetEntry(
            exerciseEntry: nil,
            setIndex: 7,
            reps: 6,
            weight: 185,
            isWarmup: false,
            setNotes: "  Working set  ",
            loggedAt: startedAt.addingTimeInterval(20)
        )
        context.insert(setA)
        context.insert(setB)
        entry.sets.append(setA)
        entry.sets.append(setB)
        try context.save()

        let report = try Phase4DataIntegrityService.repair(context: context)
        let orderedSets = WorkoutSessionManager.orderedSets(for: entry)

        XCTAssertTrue(report.hasFixes)
        XCTAssertEqual(session.sessionNotes, "Heavy day")
        XCTAssertEqual(session.endedAt, startedAt)
        XCTAssertEqual(entry.orderIndex, 0)
        XCTAssertEqual(entry.exerciseName, "Untitled Exercise")
        XCTAssertEqual(entry.entryNotes, "Keep elbows tight")

        XCTAssertEqual(orderedSets.count, 2)
        XCTAssertEqual(orderedSets[0].setIndex, 1)
        XCTAssertEqual(orderedSets[0].reps, 0)
        XCTAssertEqual(orderedSets[0].weight, 0)
        XCTAssertEqual(orderedSets[0].setNotes, "Warmup set")
        XCTAssertEqual(orderedSets[1].setIndex, 2)
        XCTAssertEqual(orderedSets[1].setNotes, "Working set")
    }

    func testRepairDoesNothingForAlreadyCleanData() throws {
        let store = try makeInMemoryStore()
        let context = store.context

        let session = try WorkoutSessionManager.startSession(workoutType: nil, context: context)
        let entry = try WorkoutSessionManager.addExercise(to: session, name: "Bench Press", context: context)
        _ = try WorkoutSessionManager.addSet(to: entry, reps: 8, weight: 185, context: context)
        try WorkoutSessionManager.finishSession(session, context: context)

        let report = try Phase4DataIntegrityService.repair(context: context)

        XCTAssertFalse(report.hasFixes)
        XCTAssertEqual(report.sessionsTouched, 0)
        XCTAssertEqual(report.totalFixes, 0)
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

    func testSnapshotPerformanceBaseline() throws {
        let store = try makeInMemoryStore()
        let context = store.context
        let exerciseName = "Bench Press"
        let normalized = PreviousWeightLookupService.normalizeExerciseName(exerciseName)
        let start = Date(timeIntervalSince1970: 1_680_000_000)

        for index in 0..<80 {
            let startedAt = start.addingTimeInterval(Double(index) * 3 * 24 * 60 * 60)
            let baseWeight = 165 + Double(index % 12) * 2.5
            try addCompletedSession(
                startedAt: startedAt,
                exerciseName: exerciseName,
                sets: [(8, baseWeight), (6, baseWeight + 15)],
                context: context
            )
        }

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let baseline = ExerciseStatsEngine.makeSnapshot(
            sessions: sessions,
            normalizedExerciseName: normalized,
            interval: nil
        )
        XCTAssertEqual(baseline.performancePoints.count, 80)

        measure {
            _ = ExerciseStatsEngine.makeSnapshot(
                sessions: sessions,
                normalizedExerciseName: normalized,
                interval: nil
            )
        }
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
