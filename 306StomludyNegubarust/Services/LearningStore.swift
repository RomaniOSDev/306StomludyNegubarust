import Foundation
import Combine

@MainActor
final class LearningStore: ObservableObject {
    @Published var topics: [Topic]
    @Published var stats: UserStats
    @Published var achievements: [Achievement]
    @Published var preferences: AppPreferences
    @Published var hasCompletedOnboarding: Bool
    @Published var expandedTopicID: UUID?
    @Published var newlyUnlockedAchievement: Achievement?

    private let topicsKey = "learning.topics"
    private let statsKey = "learning.stats"
    private let achievementsKey = "learning.achievements"
    private let onboardingKey = "learning.onboarding"
    private let preferencesKey = "learning.preferences"

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: topicsKey),
           let decoded = try? JSONDecoder().decode([Topic].self, from: data),
           !decoded.isEmpty {
            topics = decoded
        } else {
            topics = SeedData.builtInTopics
        }
        if let data = defaults.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(UserStats.self, from: data) {
            stats = decoded
        } else {
            stats = .empty
        }
        if let data = defaults.data(forKey: achievementsKey),
           let decoded = try? JSONDecoder().decode([Achievement].self, from: data) {
            achievements = SeedData.mergedAchievements(existing: decoded)
        } else {
            achievements = SeedData.defaultAchievements()
        }
        if let data = defaults.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = .default
        }
        hasCompletedOnboarding = defaults.bool(forKey: onboardingKey)
        refreshDailyCountersIfNeeded()
        evaluateAchievements()
    }

    var categories: [String] {
        Array(Set(topics.map(\.category))).sorted()
    }

    var bookmarkedTopics: [Topic] {
        topics.filter(\.isBookmarked)
    }

    var dueTopics: [Topic] {
        topics.filter(\.isDue).sorted {
            ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast)
        }
    }

    var weakTopics: [Topic] {
        topics
            .filter { $0.status == .learning || $0.progress < 0.7 || ($0.quizAttempts > 0 && $0.quizAccuracy < 0.6) }
            .sorted {
                let scoreL = $0.progress + $0.quizAccuracy
                let scoreR = $1.progress + $1.quizAccuracy
                return scoreL < scoreR
            }
    }

    var knownCount: Int {
        topics.filter { $0.status == .known }.count
    }

    var overallProgress: Double {
        guard !topics.isEmpty else { return 0 }
        let sum = topics.reduce(0.0) { $0 + min(max($1.progress, 0), 1) }
        return sum / Double(topics.count)
    }

    var dailyGoalProgress: Double {
        guard preferences.dailyGoal > 0 else { return 0 }
        return min(1, Double(stats.cardsReviewedToday) / Double(preferences.dailyGoal))
    }

    var statusBreakdown: [(label: String, count: Int)] {
        let known = topics.filter { $0.status == .known }.count
        let learning = topics.filter { $0.status == .learning }.count
        return [
            ("Known", known),
            ("Learning", learning)
        ]
    }

    var categoryProgress: [(category: String, progress: Double)] {
        Dictionary(grouping: topics, by: \.category)
            .map { key, value in
                let avg = value.isEmpty ? 0 : value.reduce(0.0) { $0 + min(max($1.progress, 0), 1) } / Double(value.count)
                return (key, avg)
            }
            .sorted { $0.category < $1.category }
    }

    func filteredTopics(
        search: String,
        category: String,
        filter: TopicFilter,
        sort: TopicSort
    ) -> [Topic] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = topics.filter { topic in
            let matchesCategory = category == "All" || topic.category == category
            let matchesSearch = q.isEmpty
                || topic.title.localizedCaseInsensitiveContains(q)
                || topic.summary.localizedCaseInsensitiveContains(q)
                || topic.note.localizedCaseInsensitiveContains(q)
            let matchesFilter: Bool = {
                switch filter {
                case .all: return true
                case .due: return topic.isDue
                case .learning: return topic.status == .learning
                case .known: return topic.status == .known
                case .bookmarked: return topic.isBookmarked
                }
            }()
            return matchesCategory && matchesSearch && matchesFilter
        }
        switch sort {
        case .title:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .progress:
            result.sort { $0.progress > $1.progress }
        case .due:
            result.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .weak:
            result.sort {
                let l = $0.progress + ($0.quizAttempts > 0 ? $0.quizAccuracy : 0.5)
                let r = $1.progress + ($1.quizAttempts > 0 ? $1.quizAccuracy : 0.5)
                return l < r
            }
        }
        return result
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingKey)
    }

    func applyOnboardingPlacement(correctCount: Int, total: Int) {
        let ratio = total > 0 ? Double(correctCount) / Double(total) : 0
        for index in topics.indices where topics[index].isBuiltIn {
            if ratio >= 0.8 {
                topics[index].progress = min(1, max(topics[index].progress, 0.55))
                if topics[index].progress >= 0.95 {
                    topics[index].status = .known
                }
            } else if ratio >= 0.4 {
                topics[index].progress = min(1, max(topics[index].progress, 0.3))
            } else {
                topics[index].progress = min(topics[index].progress, 0.15)
                topics[index].dueDate = Date()
            }
        }
        persist()
    }

    func persist() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(topics) {
            defaults.set(data, forKey: topicsKey)
        }
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: statsKey)
        }
        if let data = try? JSONEncoder().encode(achievements) {
            defaults.set(data, forKey: achievementsKey)
        }
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: preferencesKey)
        }
    }

    func updatePreferences(_ update: (inout AppPreferences) -> Void) {
        update(&preferences)
        persist()
        NotificationService.shared.resync(preferences: preferences)
    }

    func toggleExpand(_ id: UUID) {
        expandedTopicID = expandedTopicID == id ? nil : id
    }

    func markKnown(_ id: UUID) {
        applySRS(id, grade: .easy)
    }

    func markLearning(_ id: UUID) {
        guard let index = topics.firstIndex(where: { $0.id == id }) else { return }
        topics[index].status = .learning
        if topics[index].progress >= 1 {
            topics[index].progress = 0.6
        }
        topics[index].dueDate = Date()
        persist()
    }

    func reviewTopic(_ id: UUID) {
        applySRS(id, grade: .good)
    }

    func gradeTopic(_ id: UUID, grade: SRSGrade) {
        applySRS(id, grade: grade)
    }

    func updateNote(for id: UUID, note: String) {
        guard let index = topics.firstIndex(where: { $0.id == id }) else { return }
        topics[index].note = note
        persist()
    }

    func addTopic(title: String, summary: String, content: String, category: String, note: String = "") {
        let topic = Topic(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom" : category,
            progress: 0.05,
            isBuiltIn: false,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: Date()
        )
        topics.insert(topic, at: 0)
        persist()
    }

    func deleteTopic(_ id: UUID) {
        topics.removeAll { $0.id == id }
        if expandedTopicID == id { expandedTopicID = nil }
        persist()
    }

    func toggleBookmark(_ id: UUID) {
        guard let index = topics.firstIndex(where: { $0.id == id }) else { return }
        topics[index].isBookmarked.toggle()
        persist()
    }

    func completeQuiz(correct: Bool, topicTitle: String? = nil) {
        stats.quizzesCompleted += 1
        if correct {
            stats.quizzesCorrect += 1
            stats.weeklyStats.incrementToday()
        }
        if let topicTitle,
           let index = topics.firstIndex(where: { $0.title == topicTitle }) {
            topics[index].quizAttempts += 1
            if correct {
                topics[index].quizCorrect += 1
                topics[index].progress = min(1, topics[index].progress + 0.05)
            } else {
                topics[index].progress = max(0.05, topics[index].progress - 0.04)
                topics[index].status = .learning
                topics[index].dueDate = Date()
            }
        }
        touchStreak()
        evaluateAchievements()
        persist()
    }

    func completeFocusSession(minutes: Int) {
        stats.pomodoroSessions += 1
        stats.focusMinutes += minutes
        stats.focusSessionStreak += 1
        touchStreak()
        evaluateAchievements()
        persist()
        FeedbackService.shared.success()
    }

    func registerCardReview() {
        refreshDailyCountersIfNeeded()
        stats.cardsReviewed += 1
        stats.cardsReviewedToday += 1
        stats.weeklyStats.incrementToday()
        touchStreak()
        evaluateAchievements()
    }

    /// Simplified SM-2 scheduling.
    private func applySRS(_ id: UUID, grade: SRSGrade) {
        guard let index = topics.firstIndex(where: { $0.id == id }) else { return }
        var topic = topics[index]
        let q = grade.rawValue

        if q < 3 {
            topic.repetitions = 0
            topic.intervalDays = 1
            topic.progress = max(0.05, topic.progress - 0.08)
            topic.status = .learning
        } else {
            if topic.repetitions == 0 {
                topic.intervalDays = 1
            } else if topic.repetitions == 1 {
                topic.intervalDays = 3
            } else {
                topic.intervalDays = max(1, Int((Double(topic.intervalDays) * topic.easeFactor).rounded()))
            }
            topic.repetitions += 1
            topic.progress = min(1, topic.progress + (q >= 5 ? 0.18 : 0.12))
            if topic.progress >= 1 {
                topic.status = .known
            }
        }

        let ef = topic.easeFactor + (0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02))
        topic.easeFactor = min(2.8, max(1.3, ef))
        topic.dueDate = Calendar.current.date(byAdding: .day, value: topic.intervalDays, to: Date()) ?? Date()
        topics[index] = topic
        registerCardReview()
        persist()
    }

    private func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func refreshDailyCountersIfNeeded() {
        let today = dayKey()
        if stats.dailyGoalDay != today {
            stats.dailyGoalDay = today
            stats.cardsReviewedToday = 0
        }
    }

    private func touchStreak() {
        let today = dayKey()
        if stats.lastActiveDay == today {
            return
        }
        if let last = stats.lastActiveDay,
           let lastDate = dateFromKey(last),
           let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()),
           dayKey(yesterday) == last || Calendar.current.isDate(lastDate, inSameDayAs: yesterday) {
            stats.currentStreak += 1
        } else if stats.lastActiveDay == nil {
            stats.currentStreak = 1
        } else {
            stats.currentStreak = 1
        }
        stats.longestStreak = max(stats.longestStreak, stats.currentStreak)
        stats.lastActiveDay = today
    }

    private func dateFromKey(_ key: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key)
    }

    func evaluateAchievements() {
        unlock("first_review", when: stats.cardsReviewed >= 1)
        unlock("quiz_novice", when: stats.quizzesCompleted >= 5)
        unlock("getting_going", when: stats.cardsReviewed >= 10)
        unlock("power_user", when: stats.cardsReviewed >= 50)
        unlock("active_user", when: stats.quizzesCompleted >= 10)
        unlock("dedicated_user", when: stats.quizzesCompleted >= 50)
        unlock("three_day", when: stats.currentStreak >= 3)
        unlock("week_habit", when: stats.currentStreak >= 7)
        unlock("daily_goal", when: stats.cardsReviewedToday >= preferences.dailyGoal && preferences.dailyGoal > 0)
        unlock("focus_starter", when: stats.pomodoroSessions >= 1)
        unlock("focus_five", when: stats.pomodoroSessions >= 5)
    }

    private func unlock(_ id: String, when condition: Bool) {
        guard condition,
              let index = achievements.firstIndex(where: { $0.id == id }),
              !achievements[index].isUnlocked else { return }
        achievements[index].isUnlocked = true
        achievements[index].unlockedAt = Date()
        newlyUnlockedAchievement = achievements[index]
        FeedbackService.shared.success()
    }

    func clearAchievementToast() {
        newlyUnlockedAchievement = nil
    }

    func resetAll() {
        topics = SeedData.builtInTopics
        stats = .empty
        achievements = SeedData.defaultAchievements()
        preferences = .default
        expandedTopicID = nil
        newlyUnlockedAchievement = nil
        hasCompletedOnboarding = false
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: topicsKey)
        defaults.removeObject(forKey: statsKey)
        defaults.removeObject(forKey: achievementsKey)
        defaults.removeObject(forKey: preferencesKey)
        defaults.set(false, forKey: onboardingKey)
        persist()
        NotificationService.shared.resync(preferences: preferences)
    }
}
