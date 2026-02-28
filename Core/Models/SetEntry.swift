import Foundation
import SwiftData

@Model
final class SetEntry {
    var id: UUID
    var setIndex: Int
    var reps: Int
    var weight: Double
    var isWarmup: Bool
    var setNotes: String
    var loggedAt: Date

    var exerciseEntry: ExerciseEntry?

    init(
        id: UUID = UUID(),
        exerciseEntry: ExerciseEntry? = nil,
        setIndex: Int,
        reps: Int,
        weight: Double,
        isWarmup: Bool = false,
        setNotes: String = "",
        loggedAt: Date = .now
    ) {
        self.id = id
        self.exerciseEntry = exerciseEntry
        self.setIndex = setIndex
        self.reps = reps
        self.weight = weight
        self.isWarmup = isWarmup
        self.setNotes = setNotes
        self.loggedAt = loggedAt
    }
}
