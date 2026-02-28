import Foundation
import SwiftData

@Model
final class ExerciseEntry {
    var id: UUID
    var exerciseName: String
    var orderIndex: Int
    var entryNotes: String

    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.exerciseEntry)
    var sets: [SetEntry] = []

    init(
        id: UUID = UUID(),
        session: WorkoutSession? = nil,
        exerciseName: String,
        orderIndex: Int = 0,
        entryNotes: String = ""
    ) {
        self.id = id
        self.session = session
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        self.entryNotes = entryNotes
    }
}
