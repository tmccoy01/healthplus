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
