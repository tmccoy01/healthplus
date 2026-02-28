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
