import Foundation
import SwiftData

@Model
final class DayEntry {
    @Attribute(.unique) var date: Date

    var crossfit: Bool = false
    var inBedBy1145: Bool = false
    var reading: Bool = false
    var noCheating: Bool = false

    // Water is derived from HealthKit, progressPhoto is derived from PhotoStore.
    // Legacy fields kept on disk for old records but never read.
    var water: Bool = false
    var progressPhoto: Bool = false

    var meal1: Bool = false
    var meal2: Bool = false
    var fruit1: Bool = false
    var fruit2: Bool = false
    var shake1: Bool = false
    var shake2: Bool = false

    init(date: Date) {
        self.date = date
    }

    var dietComplete: Bool {
        meal1 && meal2 && fruit1 && fruit2 && shake1 && shake2
    }

    func allComplete(waterMetGoal: Bool, photoTaken: Bool) -> Bool {
        crossfit && inBedBy1145 && reading && noCheating && waterMetGoal && photoTaken && dietComplete
    }
}

@Model
final class ChallengeState {
    var startDate: Date

    init(startDate: Date) {
        self.startDate = startDate
    }
}
