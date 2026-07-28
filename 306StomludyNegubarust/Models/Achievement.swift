import Foundation

struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let detail: String
    var isUnlocked: Bool
    var unlockedAt: Date?

    init(id: String, title: String, detail: String, isUnlocked: Bool = false, unlockedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isUnlocked = isUnlocked
        self.unlockedAt = unlockedAt
    }
}

struct WeeklyStats: Codable, Equatable {
    var monday: Int
    var tuesday: Int
    var wednesday: Int
    var thursday: Int
    var friday: Int
    var saturday: Int
    var sunday: Int

    static let zero = WeeklyStats(
        monday: 0, tuesday: 0, wednesday: 0,
        thursday: 0, friday: 0, saturday: 0, sunday: 0
    )

    var total: Int {
        monday + tuesday + wednesday + thursday + friday + saturday + sunday
    }

    var asArray: [Int] {
        [monday, tuesday, wednesday, thursday, friday, saturday, sunday]
    }

    mutating func incrementToday() {
        let weekday = Calendar.current.component(.weekday, from: Date())
        switch weekday {
        case 1: sunday += 1
        case 2: monday += 1
        case 3: tuesday += 1
        case 4: wednesday += 1
        case 5: thursday += 1
        case 6: friday += 1
        case 7: saturday += 1
        default: break
        }
    }
}

struct UserStats: Codable, Equatable {
    var cardsReviewed: Int
    var quizzesCompleted: Int
    var quizzesCorrect: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDay: String?
    var weeklyStats: WeeklyStats
    var cardsReviewedToday: Int
    var dailyGoalDay: String?
    var pomodoroSessions: Int
    var focusMinutes: Int
    var focusSessionStreak: Int

    static let empty = UserStats(
        cardsReviewed: 0,
        quizzesCompleted: 0,
        quizzesCorrect: 0,
        currentStreak: 0,
        longestStreak: 0,
        lastActiveDay: nil,
        weeklyStats: .zero,
        cardsReviewedToday: 0,
        dailyGoalDay: nil,
        pomodoroSessions: 0,
        focusMinutes: 0,
        focusSessionStreak: 0
    )

    var quizAccuracy: Double {
        guard quizzesCompleted > 0 else { return 0 }
        return Double(quizzesCorrect) / Double(quizzesCompleted)
    }

    enum CodingKeys: String, CodingKey {
        case cardsReviewed, quizzesCompleted, quizzesCorrect
        case currentStreak, longestStreak, lastActiveDay, weeklyStats
        case cardsReviewedToday, dailyGoalDay, pomodoroSessions, focusMinutes, focusSessionStreak
    }

    init(
        cardsReviewed: Int,
        quizzesCompleted: Int,
        quizzesCorrect: Int,
        currentStreak: Int,
        longestStreak: Int,
        lastActiveDay: String?,
        weeklyStats: WeeklyStats,
        cardsReviewedToday: Int = 0,
        dailyGoalDay: String? = nil,
        pomodoroSessions: Int = 0,
        focusMinutes: Int = 0,
        focusSessionStreak: Int = 0
    ) {
        self.cardsReviewed = cardsReviewed
        self.quizzesCompleted = quizzesCompleted
        self.quizzesCorrect = quizzesCorrect
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActiveDay = lastActiveDay
        self.weeklyStats = weeklyStats
        self.cardsReviewedToday = cardsReviewedToday
        self.dailyGoalDay = dailyGoalDay
        self.pomodoroSessions = pomodoroSessions
        self.focusMinutes = focusMinutes
        self.focusSessionStreak = focusSessionStreak
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cardsReviewed = try c.decode(Int.self, forKey: .cardsReviewed)
        quizzesCompleted = try c.decode(Int.self, forKey: .quizzesCompleted)
        quizzesCorrect = try c.decodeIfPresent(Int.self, forKey: .quizzesCorrect) ?? 0
        currentStreak = try c.decode(Int.self, forKey: .currentStreak)
        longestStreak = try c.decode(Int.self, forKey: .longestStreak)
        lastActiveDay = try c.decodeIfPresent(String.self, forKey: .lastActiveDay)
        weeklyStats = try c.decode(WeeklyStats.self, forKey: .weeklyStats)
        cardsReviewedToday = try c.decodeIfPresent(Int.self, forKey: .cardsReviewedToday) ?? 0
        dailyGoalDay = try c.decodeIfPresent(String.self, forKey: .dailyGoalDay)
        pomodoroSessions = try c.decodeIfPresent(Int.self, forKey: .pomodoroSessions) ?? 0
        focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 0
        focusSessionStreak = try c.decodeIfPresent(Int.self, forKey: .focusSessionStreak) ?? 0
    }
}

/// SM-2 quality grades used by quick review and review buttons.
enum SRSGrade: Int {
    case again = 1
    case hard = 3
    case good = 4
    case easy = 5
}
