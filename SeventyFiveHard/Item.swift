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

@Model
final class WeeklyPrize {
    @Attribute(.unique) var weekNumber: Int
    var prize: String

    init(weekNumber: Int, prize: String = "") {
        self.weekNumber = weekNumber
        self.prize = prize
    }

    /// 75 Hard breaks into 10 full 7-day weeks (1–10) plus a final 5-day stretch (week 11, days 71–75).
    static let totalWeeks = 11

    static func dayRange(for week: Int) -> ClosedRange<Int> {
        let start = (week - 1) * 7 + 1
        let end = week == totalWeeks ? 75 : week * 7
        return start...end
    }

    /// The day number on which this week's prize unlocks (the last day of the week).
    static func unlockDay(for week: Int) -> Int {
        dayRange(for: week).upperBound
    }
}
