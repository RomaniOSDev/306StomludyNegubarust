import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var page = 0
    @State private var quizIndex = 0
    @State private var selected: Int?
    @State private var correctCount = 0
    @State private var answered = false

    private let pages: [(title: String, body: String, symbol: String)] = [
        (
            "Start Mapping",
            "Discover how to organize your thoughts effectively.",
            "map"
        ),
        (
            "Create Mind Maps",
            "Build detailed visual representations of complex topics and ideas.",
            "square.stack.3d.up"
        ),
        (
            "Explore Topics",
            "Begin by selecting a subject area that interests you most.",
            "books.vertical"
        )
    ]

    private var showingQuiz: Bool { page >= pages.count }
    private var quizFinished: Bool { quizIndex >= SeedData.onboardingQuiz.count }

    var body: some View {
        ZStack {
            BackgroundView()
            VStack(spacing: 0) {
                if showingQuiz {
                    quizContent
                } else {
                    introPages
                }

                Button {
                    advance()
                } label: {
                    Text(buttonTitle)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color("AppTextPrimary"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color("AppPrimary"))
                        )
                }
                .disabled(showingQuiz && !quizFinished && (!answered || selected == nil))
                .opacity(showingQuiz && !quizFinished && (!answered || selected == nil) ? 0.5 : 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
    }

    private var introPages: some View {
        TabView(selection: $page) {
            ForEach(pages.indices, id: \.self) { index in
                VStack(spacing: 28) {
                    Spacer()
                    ZStack {
                        ForEach(0..<3, id: \.self) { layer in
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color("AppSurface").opacity(0.5 + Double(layer) * 0.15))
                                .frame(width: 160 - CGFloat(layer * 8), height: 160 - CGFloat(layer * 8))
                                .offset(y: CGFloat(layer) * 6)
                        }
                        Image(systemName: pages[index].symbol)
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(Color("AppPrimary"))
                    }
                    .frame(height: 180)

                    Text(pages[index].title)
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundStyle(Color("AppTextPrimary"))
                        .multilineTextAlignment(.center)

                    Text(pages[index].body)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundStyle(Color("AppTextSecondary"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    Spacer()
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
    }

    @ViewBuilder
    private var quizContent: some View {
        if quizFinished {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color("AppAccent"))
                Text("Placement complete")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(Color("AppTextPrimary"))
                Text("You scored \(correctCount)/\(SeedData.onboardingQuiz.count). Starting progress is adjusted to match.")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(Color("AppTextSecondary"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Spacer()
            }
        } else {
            let question = SeedData.onboardingQuiz[quizIndex]
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Placement quiz \(quizIndex + 1)/\(SeedData.onboardingQuiz.count)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("AppAccent"))
                        .padding(.top, 24)

                    Text(question.prompt)
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundStyle(Color("AppTextPrimary"))
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(question.choices.indices, id: \.self) { idx in
                        Button {
                            guard !answered else { return }
                            FeedbackService.shared.selection()
                            selected = idx
                            answered = true
                            if idx == question.correctIndex {
                                correctCount += 1
                                FeedbackService.shared.success()
                            } else {
                                FeedbackService.shared.error()
                            }
                        } label: {
                            HStack {
                                Text(question.choices[idx])
                                    .foregroundStyle(Color("AppTextPrimary"))
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(14)
                            .background(Color("AppSurface"))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        answered && idx == question.correctIndex
                                            ? Color("AppAccent")
                                            : (selected == idx ? Color("AppPrimary") : Color.clear),
                                        lineWidth: 2
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
        }
    }

    private var buttonTitle: String {
        if !showingQuiz {
            return page < pages.count - 1 ? "Continue" : "Take placement quiz"
        }
        if quizFinished {
            return "Begin"
        }
        return "Next"
    }

    private func advance() {
        FeedbackService.shared.tap()
        if !showingQuiz {
            if page < pages.count - 1 {
                withAnimation { page += 1 }
            } else {
                withAnimation { page = pages.count }
            }
            return
        }
        if quizFinished {
            store.applyOnboardingPlacement(correctCount: correctCount, total: SeedData.onboardingQuiz.count)
            store.completeOnboarding()
            return
        }
        guard answered else { return }
        quizIndex += 1
        selected = nil
        answered = false
    }
}
