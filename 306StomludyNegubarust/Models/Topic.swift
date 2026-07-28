import Foundation
import SwiftUI

enum TopicStatus: String, Codable, CaseIterable, Identifiable {
    case learning = "Learning"
    case known = "Known"

    var id: String { rawValue }
}

struct Topic: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var summary: String
    var status: TopicStatus
    var content: String
    var category: String
    var isBookmarked: Bool
    var progress: Double
    var isBuiltIn: Bool
    /// Personal study note / hint shown after quiz answers.
    var note: String
    /// SM-2 style spaced repetition state.
    var easeFactor: Double
    var intervalDays: Int
    var repetitions: Int
    var dueDate: Date?
    var quizAttempts: Int
    var quizCorrect: Int

    var quizAccuracy: Double {
        guard quizAttempts > 0 else { return 0 }
        return Double(quizCorrect) / Double(quizAttempts)
    }

    var isDue: Bool {
        guard let dueDate else { return repetitions == 0 }
        return dueDate <= Date()
    }

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        status: TopicStatus = .learning,
        content: String,
        category: String,
        isBookmarked: Bool = false,
        progress: Double = 0.15,
        isBuiltIn: Bool = false,
        note: String = "",
        easeFactor: Double = 2.5,
        intervalDays: Int = 0,
        repetitions: Int = 0,
        dueDate: Date? = nil,
        quizAttempts: Int = 0,
        quizCorrect: Int = 0
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.status = status
        self.content = content
        self.category = category
        self.isBookmarked = isBookmarked
        self.progress = progress
        self.isBuiltIn = isBuiltIn
        self.note = note
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.dueDate = dueDate ?? Date()
        self.quizAttempts = quizAttempts
        self.quizCorrect = quizCorrect
    }

    enum CodingKeys: String, CodingKey {
        case id, title, summary, status, content, category, isBookmarked, progress, isBuiltIn
        case note, easeFactor, intervalDays, repetitions, dueDate, quizAttempts, quizCorrect
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        summary = try c.decode(String.self, forKey: .summary)
        status = try c.decode(TopicStatus.self, forKey: .status)
        content = try c.decode(String.self, forKey: .content)
        category = try c.decode(String.self, forKey: .category)
        isBookmarked = try c.decode(Bool.self, forKey: .isBookmarked)
        progress = try c.decode(Double.self, forKey: .progress)
        isBuiltIn = try c.decode(Bool.self, forKey: .isBuiltIn)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        easeFactor = try c.decodeIfPresent(Double.self, forKey: .easeFactor) ?? 2.5
        intervalDays = try c.decodeIfPresent(Int.self, forKey: .intervalDays) ?? 0
        repetitions = try c.decodeIfPresent(Int.self, forKey: .repetitions) ?? 0
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate) ?? Date()
        quizAttempts = try c.decodeIfPresent(Int.self, forKey: .quizAttempts) ?? 0
        quizCorrect = try c.decodeIfPresent(Int.self, forKey: .quizCorrect) ?? 0
    }
}

enum TopicFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case due = "Due"
    case learning = "Learning"
    case known = "Known"
    case bookmarked = "Saved"

    var id: String { rawValue }
}

enum TopicSort: String, CaseIterable, Identifiable {
    case title = "Title"
    case progress = "Progress"
    case due = "Due date"
    case weak = "Weak first"

    var id: String { rawValue     }
}

enum AppColorSchemePreference: String, Codable, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

struct AppPreferences: Codable, Equatable {
    var colorScheme: AppColorSchemePreference
    var dailyGoal: Int
    var remindersEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    static let `default` = AppPreferences(
        colorScheme: .dark,
        dailyGoal: 10,
        remindersEnabled: false,
        reminderHour: 20,
        reminderMinute: 0
    )
}
