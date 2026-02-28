import Foundation
import SwiftData

@Model
final class ExerciseTemplate {
    var id: UUID
    var name: String
    var createdAt: Date
    var isArchived: Bool

    var defaultWorkoutType: WorkoutType?

    init(
        id: UUID = UUID(),
        name: String,
        defaultWorkoutType: WorkoutType? = nil,
        createdAt: Date = .now,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.defaultWorkoutType = defaultWorkoutType
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
}
