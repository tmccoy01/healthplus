import SwiftData
import SwiftUI

@main
struct HealthPlusApp: App {
    private let modelContainer: ModelContainer = {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITestingInMemory = arguments.contains("-ui-testing-in-memory")

        let schema = Schema([
            WorkoutType.self,
            ExerciseTemplate.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetEntry.self,
            BodyMetric.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isUITestingInMemory
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }()

    @State private var didSeedWorkoutTypes = false

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)
                .task {
                    guard didSeedWorkoutTypes == false else {
                        return
                    }

                    didSeedWorkoutTypes = true

                    do {
                        try WorkoutTypeSeeder.seedIfNeeded(context: modelContainer.mainContext)
                        _ = try Phase4DataIntegrityService.repair(context: modelContainer.mainContext)
                    } catch {
                        assertionFailure("App startup data preparation failed: \(error)")
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
