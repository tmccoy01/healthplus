import Foundation
import SwiftData

@Model
final class BodyMetric {
    var id: UUID
    var date: Date
    var bodyWeight: Double?
    var bodyFatPercent: Double?
    var notes: String

    init(
        id: UUID = UUID(),
        date: Date = .now,
        bodyWeight: Double? = nil,
        bodyFatPercent: Double? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.bodyWeight = bodyWeight
        self.bodyFatPercent = bodyFatPercent
        self.notes = notes
    }
}
