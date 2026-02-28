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
