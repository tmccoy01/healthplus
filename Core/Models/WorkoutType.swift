import Foundation
import SwiftData

@Model
final class WorkoutType {
    var id: UUID
    var name: String
    var isSystemType: Bool
    var isArchived: Bool
    var createdAt: Date
    var sortOrder: Int
    var colorHex: String?
    var symbolName: String?

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.workoutType)
    var sessions: [WorkoutSession] = []

    @Relationship(deleteRule: .nullify, inverse: \ExerciseTemplate.defaultWorkoutType)
    var templates: [ExerciseTemplate] = []

    init(
        id: UUID = UUID(),
        name: String,
        isSystemType: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now,
        sortOrder: Int = 0,
        colorHex: String? = nil,
        symbolName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.isSystemType = isSystemType
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.colorHex = colorHex
        self.symbolName = symbolName
    }
}
