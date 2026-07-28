import SwiftUI

enum DrillMode: String, CaseIterable, Identifiable {
    case all = "All topics"
    case weak = "Weak topics"
    case custom = "Custom categories"

    var id: String { rawValue }
}

struct KnowledgeDrillView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var questions: [QuizQuestion] = []
    @State private var index = 0
    @State private var selected: Int?
    @State private var submitted = false
    @State private var showConfetti = false
    @State private var showSetup = true
    @State private var mode: DrillMode = .all
    @State private var selectedCategories: Set<String> = []
    @State private var questionLimit = 8

    private var current: QuizQuestion? {
        guard questions.indices.contains(index) else { return nil }
        return questions[index]
    }

    private var relatedNote: String? {
        guard let current else { return nil }
        return store.topics.first(where: { $0.title == current.topicTitle })?.note
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        BannerHeader(
                            imageName: "banner_drill",
                            title: "Knowledge Drill",
                            subtitle: "Build a session: all, weak topics, or chosen categories."
                        )

                        if showSetup || questions.isEmpty {
                            setupCard
                        } else if let question = current {
                            quizCard(question)
                        } else {
                            PaperCard {
                                Text("No questions available for this setup.")
                                    .foregroundStyle(Color("AppTextSecondary"))
                            }
                        }

                        Text("Quizzes completed: \(store.stats.quizzesCompleted)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color("AppTextSecondary"))
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Setup") {
                        FeedbackService.shared.tap()
                        showSetup = true
                    }
                    .foregroundStyle(Color("AppPrimary"))
                }
            }
        }
    }

    private var setupCard: some View {
        PaperCard(stackDepth: 2) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Session setup")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("AppTextPrimary"))

                Picker("Mode", selection: $mode) {
                    ForEach(DrillMode.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if mode == .custom {
                    Text("Categories")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color("AppTextSecondary"))
                    FlexibleChipWrap {
                        ForEach(store.categories, id: \.self) { category in
                            TopicChip(title: category, isSelected: selectedCategories.contains(category)) {
                                FeedbackService.shared.selection()
                                if selectedCategories.contains(category) {
                                    selectedCategories.remove(category)
                                } else {
                                    selectedCategories.insert(category)
                                }
                            }
                        }
                    }
                }

                if mode == .weak {
                    Text("\(store.weakTopics.count) weak topics queued")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color("AppTextSecondary"))
                }

                Stepper("Questions: \(questionLimit)", value: $questionLimit, in: 3...20)

                Button {
                    FeedbackService.shared.tap()
                    startSession()
                } label: {
                    Text("Start Drill")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color("AppTextPrimary"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color("AppPrimary"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(mode == .custom && selectedCategories.isEmpty)
                .opacity(mode == .custom && selectedCategories.isEmpty ? 0.5 : 1)
            }
        }
    }

    private func quizCard(_ question: QuizQuestion) -> some View {
        PaperCard(stackDepth: 3) {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(index + 1)/\(questions.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color("AppTextSecondary"))

                Text(question.topicTitle.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color("AppAccent"))
                    .tracking(1.1)
                    .fixedSize(horizontal: false, vertical: true)

                Text(question.prompt)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("AppTextPrimary"))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(question.choices.indices, id: \.self) { choiceIndex in
                    choiceButton(question: question, choiceIndex: choiceIndex)
                }

                if submitted {
                    let correct = selected == question.correctIndex
                    Text(correct ? "Correct — well reasoned." : "Not quite — review the topic and try the next one.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(correct ? Color("AppAccent") : Color("AppTextSecondary"))
                        .padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)

                    if let note = relatedNote, !note.isEmpty {
                        Text("Hint: \(note)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color("AppPrimary"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack {
                    if !submitted {
                        Button {
                            guard selected != nil else { return }
                            submitted = true
                            let correct = selected == question.correctIndex
                            store.completeQuiz(correct: correct, topicTitle: question.topicTitle)
                            if correct {
                                FeedbackService.shared.success()
                                showConfetti = true
                            } else {
                                FeedbackService.shared.error()
                            }
                        } label: {
                            Text("Submit")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color("AppTextPrimary"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color("AppPrimary"))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(selected == nil)
                        .opacity(selected == nil ? 0.5 : 1)
                    } else {
                        Button {
                            FeedbackService.shared.tap()
                            advance()
                        } label: {
                            Text(index + 1 < questions.count ? "Next Question" : "Finish")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color("AppTextPrimary"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color("AppAccent"))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
            }
        }
        .overlay {
            if showConfetti {
                SoftConfettiView()
                    .id(index)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func choiceButton(question: QuizQuestion, choiceIndex: Int) -> some View {
        let isSelected = selected == choiceIndex
        let isCorrect = choiceIndex == question.correctIndex
        Button {
            guard !submitted else { return }
            FeedbackService.shared.selection()
            selected = choiceIndex
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .strokeBorder(Color("AppTextSecondary"), lineWidth: 1.5)
                    .background(
                        Circle().fill(isSelected ? Color("AppPrimary") : Color.clear)
                    )
                    .frame(width: 20, height: 20)
                    .padding(.top, 2)
                Text(question.choices[choiceIndex])
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color("AppTextPrimary"))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color("AppBackground").opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        submitted && isCorrect
                            ? Color("AppAccent")
                            : (isSelected ? Color("AppPrimary") : Color("AppTextSecondary").opacity(0.2)),
                        lineWidth: submitted && isCorrect ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(submitted)
    }

    private func startSession() {
        let cats: Set<String>? = mode == .custom ? selectedCategories : nil
        questions = SeedData.questions(
            from: store.topics,
            categories: cats,
            weakOnly: mode == .weak,
            limit: questionLimit
        )
        index = 0
        selected = nil
        submitted = false
        showConfetti = false
        showSetup = false
    }

    private func advance() {
        showConfetti = false
        selected = nil
        submitted = false
        if index + 1 < questions.count {
            index += 1
        } else {
            showSetup = true
            questions = []
        }
    }
}
