import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var sessionNotes: String

    var workoutType: WorkoutType?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.session)
    var entries: [ExerciseEntry] = []

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        workoutType: WorkoutType? = nil,
        sessionNotes: String = ""
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.workoutType = workoutType
        self.sessionNotes = sessionNotes
    }
}
