import SwiftUI
import Charts

struct LearningMilestonesView: View {
    @EnvironmentObject private var store: LearningStore
    var embedsNavigation: Bool = true

    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var weeklyPoints: [(day: String, count: Int)] {
        zip(dayLabels, store.stats.weeklyStats.asArray).map { ($0, $1) }
    }

    private var maxWeekly: Int {
        max(store.stats.weeklyStats.asArray.max() ?? 0, 1)
    }

    var body: some View {
        Group {
            if embedsNavigation {
                NavigationStack {
                    statsRoot
                }
            } else {
                statsRoot
                    .navigationTitle("Statistics")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var statsRoot: some View {
        ZStack {
            BackgroundView()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    BannerHeader(
                        imageName: "banner_milestones",
                        title: "Statistics",
                        subtitle: "Progress charts for mastery, accuracy, and weekly study rhythm."
                    )

                    DailyGoalCard()
                    overviewCard
                    weeklyChartCard
                    accuracyChartCard
                    statusChartCard
                    categoryChartCard
                    topicProgressSection
                    bookmarksSection
                    achievementsLink
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .dismissKeyboardOnTap()
        .navigationBarTitleDisplayMode(.inline)
    }

    private var overviewCard: some View {
        PaperCard(stackDepth: 3) {
            VStack(spacing: 16) {
                CircularMilestoneChart(
                    progress: store.overallProgress,
                    known: store.knownCount,
                    total: store.topics.count
                )
                HStack {
                    milestoneStat("Cards", "\(store.stats.cardsReviewed)")
                    Spacer()
                    milestoneStat("Quizzes", "\(store.stats.quizzesCompleted)")
                    Spacer()
                    milestoneStat("Streak", "\(store.stats.currentStreak)d")
                }
                HStack {
                    milestoneStat("Correct", "\(store.stats.quizzesCorrect)")
                    Spacer()
                    milestoneStat("Accuracy", "\(Int((store.stats.quizAccuracy * 100).rounded()))%")
                    Spacer()
                    milestoneStat("Best", "\(store.stats.longestStreak)d")
                }
            }
        }
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Weekly activity")
            PaperCard(stackDepth: 2) {
                Chart(weeklyPoints, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Activity", item.count)
                    )
                    .foregroundStyle(Color("AppAccent").gradient)
                    .cornerRadius(6)
                }
                .chartYScale(domain: 0...max(maxWeekly, 3))
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var accuracyChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Quiz accuracy")
            PaperCard(stackDepth: 2) {
                let correct = store.stats.quizzesCorrect
                let wrong = max(0, store.stats.quizzesCompleted - correct)
                if store.stats.quizzesCompleted == 0 {
                    Text("Complete drills to see accuracy breakdown.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Color("AppTextSecondary"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 20) {
                        AccuracyRingView(progress: store.stats.quizAccuracy)
                            .frame(width: 140, height: 140)

                        VStack(alignment: .leading, spacing: 12) {
                            legendDot(Color("AppAccent"), "Correct \(correct)")
                            legendDot(Color("AppPrimary").opacity(0.75), "Missed \(wrong)")
                            Text("\(store.stats.quizzesCompleted) quizzes total")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color("AppTextSecondary"))
                        }
                        Spacer(minLength: 0)
                    }

                    Chart {
                        BarMark(
                            x: .value("Result", "Correct"),
                            y: .value("Count", correct)
                        )
                        .foregroundStyle(Color("AppAccent"))
                        .cornerRadius(6)
                        BarMark(
                            x: .value("Result", "Missed"),
                            y: .value("Count", wrong)
                        )
                        .foregroundStyle(Color("AppPrimary").opacity(0.75))
                        .cornerRadius(6)
                    }
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var statusChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Topic status")
            PaperCard(stackDepth: 2) {
                Chart(store.statusBreakdown, id: \.label) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Status", item.label)
                    )
                    .foregroundStyle(by: .value("Status", item.label))
                    .cornerRadius(6)
                }
                .chartForegroundStyleScale([
                    "Known": Color("AppAccent"),
                    "Learning": Color("AppPrimary")
                ])
                .chartLegend(.hidden)
                .frame(height: 140)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var categoryChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Mastery by category")
            PaperCard(stackDepth: 2) {
                if store.categoryProgress.isEmpty {
                    Text("No categories yet.")
                        .foregroundStyle(Color("AppTextSecondary"))
                } else {
                    Chart(store.categoryProgress, id: \.category) { item in
                        BarMark(
                            x: .value("Progress", item.progress * 100),
                            y: .value("Category", item.category)
                        )
                        .foregroundStyle(Color("AppPrimary").gradient)
                        .cornerRadius(6)
                    }
                    .chartXScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let n = value.as(Double.self) {
                                    Text("\(Int(n))%")
                                }
                            }
                        }
                    }
                    .frame(height: max(120, CGFloat(store.categoryProgress.count) * 36))
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var topicProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Topic progress")
            ForEach(store.topics) { topic in
                PaperCard(stackDepth: 1) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(topic.title)
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundStyle(Color("AppTextPrimary"))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            if topic.isBookmarked {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(Color("AppAccent"))
                            }
                            Text("\(Int(topic.progress * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color("AppTextSecondary"))
                                .fixedSize()
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color("AppBackground").opacity(0.7))
                                Capsule()
                                    .fill(Color("AppPrimary"))
                                    .frame(width: max(8, geo.size.width * min(max(topic.progress, 0), 1)))
                            }
                        }
                        .frame(height: 10)
                    }
                }
            }
        }
    }

    private var bookmarksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Bookmarks")
            if store.bookmarkedTopics.isEmpty {
                PaperCard(stackDepth: 1) {
                    Text("Bookmark topics from the browser to pin them here.")
                        .foregroundStyle(Color("AppTextSecondary"))
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.bookmarkedTopics) { topic in
                            TopicChip(title: topic.title, isSelected: true) {}
                        }
                    }
                }
            }
        }
    }

    private var achievementsLink: some View {
        NavigationLink {
            AchievementsView()
        } label: {
            PaperCard(stackDepth: 1) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Achievements")
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                            .foregroundStyle(Color("AppTextPrimary"))
                        Text("\(store.achievements.filter(\.isUnlocked).count)/\(store.achievements.count) unlocked")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Color("AppTextSecondary"))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color("AppTextSecondary"))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold, design: .serif))
            .foregroundStyle(Color("AppTextPrimary"))
    }

    private func milestoneStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundStyle(Color("AppTextPrimary"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color("AppTextSecondary"))
        }
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color("AppTextSecondary"))
        }
    }
}

struct AchievementsView: View {
    @EnvironmentObject private var store: LearningStore

    var body: some View {
        ZStack {
            BackgroundView()
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.achievements) { achievement in
                        PaperCard(stackDepth: achievement.isUnlocked ? 2 : 1) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: achievement.isUnlocked ? "seal.fill" : "seal")
                                    .font(.system(size: 28))
                                    .foregroundStyle(achievement.isUnlocked ? Color("AppPrimary") : Color("AppTextSecondary"))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(achievement.title)
                                        .font(.system(size: 17, weight: .semibold, design: .serif))
                                        .foregroundStyle(Color("AppTextPrimary"))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(achievement.detail)
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundStyle(Color("AppTextSecondary"))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .opacity(achievement.isUnlocked ? 1 : 0.55)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AccuracyRingView: View {
    let progress: Double

    private var clamped: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color("AppBackground").opacity(0.7), lineWidth: 14)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(Color("AppAccent"), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int((clamped * 100).rounded()))%")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(Color("AppTextPrimary"))
                Text("accuracy")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color("AppTextSecondary"))
            }
        }
    }
}
