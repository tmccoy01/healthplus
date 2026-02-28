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
