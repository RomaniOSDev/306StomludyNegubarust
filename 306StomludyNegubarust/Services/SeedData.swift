import Foundation

enum SeedData {
    static let builtInTopics: [Topic] = [
        Topic(
            title: "Active Recall",
            summary: "Retrieve knowledge from memory instead of rereading notes.",
            status: .learning,
            content: "Active recall means closing your materials and testing yourself. Ask a question, answer from memory, then check. This strengthens neural pathways more than passive review. Use flashcards, blank-page summaries, or verbal explanations. Schedule short daily sessions rather than long cram blocks.",
            category: "Methods",
            progress: 0.35,
            isBuiltIn: true
        ),
        Topic(
            title: "Spaced Repetition",
            summary: "Review at expanding intervals to lock in long-term memory.",
            status: .learning,
            content: "Spaced repetition schedules reviews just as you begin to forget. Start with a one-day gap, then three days, one week, two weeks. Tools and simple calendars both work. Pair it with active recall for durable learning. Track which items feel fragile and bring them forward.",
            category: "Methods",
            progress: 0.25,
            isBuiltIn: true
        ),
        Topic(
            title: "Mind Mapping",
            summary: "Organize ideas visually around a central concept.",
            status: .learning,
            content: "Mind maps place a core idea in the center and radiate related branches. Use short phrases, color coding, and hierarchy. They reveal connections, gaps, and priorities. Begin by selecting a subject area, then expand outward with examples and questions.",
            category: "Organization",
            progress: 0.2,
            isBuiltIn: true
        ),
        Topic(
            title: "Feynman Technique",
            summary: "Explain a topic simply to expose gaps in understanding.",
            status: .learning,
            content: "Name the concept, teach it in plain language, note where you struggle, then refine. Avoid jargon until you can justify it. Writing the explanation by hand often surfaces fuzzy edges faster than speaking alone.",
            category: "Methods",
            progress: 0.15,
            isBuiltIn: true
        ),
        Topic(
            title: "Interleaving",
            summary: "Mix related skills in one session to improve discrimination.",
            status: .learning,
            content: "Instead of blocking one topic for hours, rotate among related problems. Interleaving feels harder but builds flexible knowledge. Alternate flashcard categories or quiz themes within a single drill.",
            category: "Practice",
            progress: 0.1,
            isBuiltIn: true
        ),
        Topic(
            title: "Cornell Notes",
            summary: "Structure notes with cues, body, and a summary strip.",
            status: .known,
            content: "Divide the page into a cue column, note body, and bottom summary. During review, cover the body and answer from cues. Rewrite the summary after each session to consolidate meaning.",
            category: "Organization",
            progress: 1.0,
            isBuiltIn: true
        ),
        Topic(
            title: "Pomodoro Focus",
            summary: "Work in focused intervals with deliberate breaks.",
            status: .learning,
            content: "Set a timer for 25 minutes of single-task study, then rest briefly. After four cycles, take a longer break. Protect the interval from notifications. Use breaks to stand, hydrate, or glance at milestone progress—not social feeds.",
            category: "Focus",
            progress: 0.4,
            isBuiltIn: true
        ),
        Topic(
            title: "Elaborative Encoding",
            summary: "Link new facts to what you already know.",
            status: .learning,
            content: "Ask how a new idea connects to prior knowledge, why it matters, and where it applies. Analogies and personal examples deepen encoding. Write one connection sentence after each flashcard review.",
            category: "Memory",
            progress: 0.18,
            isBuiltIn: true
        )
    ]

    static func questions(
        from topics: [Topic],
        categories: Set<String>? = nil,
        weakOnly: Bool = false,
        limit: Int? = nil
    ) -> [QuizQuestion] {
        var pool = topics
        if let categories, !categories.isEmpty {
            pool = pool.filter { categories.contains($0.category) }
        }

        var result = buildQuestions(from: pool)

        if weakOnly {
            let weakTitles = Set(
                pool
                    .filter { $0.status == .learning || $0.progress < 0.7 || ($0.quizAttempts > 0 && $0.quizAccuracy < 0.6) }
                    .map(\.title)
            )
            let filtered = result.filter { weakTitles.contains($0.topicTitle) }
            if !filtered.isEmpty {
                result = filtered
            }
        }

        if let limit {
            return Array(result.prefix(limit))
        }
        return result
    }

    private static func buildQuestions(from topics: [Topic]) -> [QuizQuestion] {
        var result: [QuizQuestion] = []
        let bank: [(String, [String], Int, String)] = [
            ("What is the core idea of active recall?", ["Reread notes repeatedly", "Retrieve answers from memory", "Highlight every paragraph", "Listen to lectures only"], 1, "Active Recall"),
            ("Spaced repetition reviews material:", ["Only once before exams", "At expanding intervals", "Every hour forever", "Never after day one"], 1, "Spaced Repetition"),
            ("A mind map usually starts with:", ["A dense paragraph", "A central concept", "A quiz score", "A random quote"], 1, "Mind Mapping"),
            ("The Feynman Technique emphasizes:", ["Complex jargon", "Simple explanations", "Speed reading", "Silent highlighting"], 1, "Feynman Technique"),
            ("Interleaving means you:", ["Study one topic for days", "Mix related skills in a session", "Skip difficult items", "Avoid quizzes"], 1, "Interleaving"),
            ("Cornell Notes include:", ["Cue column and summary", "Only doodles", "Audio only", "No structure"], 0, "Cornell Notes"),
            ("A classic Pomodoro interval is:", ["5 minutes", "25 minutes", "3 hours", "45 seconds"], 1, "Pomodoro Focus"),
            ("Elaborative encoding works by:", ["Ignoring prior knowledge", "Linking new facts to known ideas", "Deleting notes", "Memorizing fonts"], 1, "Elaborative Encoding"),
            ("Which practice strengthens long-term memory most?", ["Passive rereading", "Active recall with spacing", "Skipping review", "Copying slides verbatim"], 1, "Active Recall"),
            ("When mapping thoughts, first:", ["Select a subject area", "Buy new stationery", "Clear all bookmarks", "Finish every quiz"], 0, "Mind Mapping")
        ]
        let titles = Set(topics.map(\.title))
        for item in bank where titles.contains(item.3) {
            result.append(QuizQuestion(prompt: item.0, choices: item.1, correctIndex: item.2, topicTitle: item.3))
        }
        for topic in topics where !topic.isBuiltIn {
            let words = topic.title.split(separator: " ")
            let hint = words.first.map(String.init) ?? topic.title
            result.append(QuizQuestion(
                prompt: "Which statement best matches \"\(topic.title)\"?",
                choices: [
                    topic.summary,
                    "A method that ignores \(hint)",
                    "An unrelated sports rule",
                    "A random calendar tip"
                ],
                correctIndex: 0,
                topicTitle: topic.title
            ))
            let snippet = String(topic.content.prefix(80))
            result.append(QuizQuestion(
                prompt: "Content from \(topic.title) focuses on:",
                choices: [
                    snippet + (topic.content.count > 80 ? "…" : ""),
                    "Avoiding all practice",
                    "Deleting weekly stats",
                    "Hiding milestones"
                ],
                correctIndex: 0,
                topicTitle: topic.title
            ))
        }
        return result.shuffled()
    }

    static func defaultAchievements() -> [Achievement] {
        [
            Achievement(id: "first_review", title: "First Review", detail: "Complete your first card review."),
            Achievement(id: "quiz_novice", title: "Quiz Novice", detail: "Finish at least 5 quizzes."),
            Achievement(id: "getting_going", title: "Getting Going", detail: "Review 10 or more cards."),
            Achievement(id: "power_user", title: "Power User", detail: "Review 50 or more cards."),
            Achievement(id: "active_user", title: "Active User", detail: "Complete 10 or more quizzes."),
            Achievement(id: "dedicated_user", title: "Dedicated User", detail: "Complete 50 or more quizzes."),
            Achievement(id: "three_day", title: "Three-Day Streak", detail: "Stay active three days in a row."),
            Achievement(id: "week_habit", title: "Week-Long Habit", detail: "Keep a seven-day streak."),
            Achievement(id: "daily_goal", title: "Daily Goal", detail: "Hit your daily review goal."),
            Achievement(id: "focus_starter", title: "Focus Starter", detail: "Finish your first Pomodoro session."),
            Achievement(id: "focus_five", title: "Deep Focus", detail: "Complete five Pomodoro sessions.")
        ]
    }

    static func mergedAchievements(existing: [Achievement]) -> [Achievement] {
        let defaults = defaultAchievements()
        let map = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        return defaults.map { base in
            if let saved = map[base.id] {
                return Achievement(
                    id: base.id,
                    title: base.title,
                    detail: base.detail,
                    isUnlocked: saved.isUnlocked,
                    unlockedAt: saved.unlockedAt
                )
            }
            return base
        }
    }

    static let onboardingQuiz: [QuizQuestion] = [
        QuizQuestion(
            prompt: "Active recall mainly means:",
            choices: ["Rereading quietly", "Retrieving answers from memory", "Highlighting everything", "Skipping review"],
            correctIndex: 1,
            topicTitle: "Active Recall"
        ),
        QuizQuestion(
            prompt: "Spaced repetition helps by reviewing:",
            choices: ["Only on exam day", "At expanding intervals", "Once forever", "Never"],
            correctIndex: 1,
            topicTitle: "Spaced Repetition"
        ),
        QuizQuestion(
            prompt: "A Pomodoro focus block is typically:",
            choices: ["5 minutes", "25 minutes", "2 hours", "45 seconds"],
            correctIndex: 1,
            topicTitle: "Pomodoro Focus"
        )
    ]
}
