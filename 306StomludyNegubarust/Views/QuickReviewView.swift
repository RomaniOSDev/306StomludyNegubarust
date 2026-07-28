import SwiftUI

struct QuickReviewView: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @State private var queue: [Topic] = []
    @State private var dragOffset: CGSize = .zero
    @State private var revealed = false

    var body: some View {
        ZStack {
            BackgroundView()
            VStack(spacing: 18) {
                HStack {
                    Text("\(queue.count) due")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color("AppTextSecondary"))
                    Spacer()
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color("AppPrimary"))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if let topic = queue.first {
                    card(topic)
                        .padding(.horizontal, 20)
                        .offset(x: dragOffset.width)
                        .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    if value.translation.width > 120 {
                                        grade(.good)
                                    } else if value.translation.width < -120 {
                                        grade(.again)
                                    } else {
                                        withAnimation(.spring()) { dragOffset = .zero }
                                    }
                                }
                        )

                    Text(revealed ? "Swipe right: Known · left: Again" : "Tap card to flip, then swipe")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color("AppTextSecondary"))

                    HStack(spacing: 12) {
                        Button {
                            grade(.again)
                        } label: {
                            Text("Again")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color("AppPrimary").opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(Color("AppTextPrimary"))
                        }
                        Button {
                            grade(.good)
                        } label: {
                            Text("Known")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color("AppAccent"))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(Color("AppTextPrimary"))
                        }
                    }
                    .padding(.horizontal, 20)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                } else {
                    Spacer()
                    PaperCard {
                        Text("No cards due. Come back later or review from Topics.")
                            .foregroundStyle(Color("AppTextSecondary"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    Spacer()
                }
                Spacer(minLength: 0)
            }
        }
        .navigationTitle("Quick Review")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            queue = store.dueTopics
            if queue.isEmpty { queue = store.topics.filter { $0.status == .learning } }
        }
    }

    private func card(_ topic: Topic) -> some View {
        PaperCard(stackDepth: 3) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: CategoryStyle.symbol(for: topic.category))
                        .foregroundStyle(CategoryStyle.color(for: topic.category))
                    Text(topic.category)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(CategoryStyle.color(for: topic.category))
                    Spacer()
                    if topic.isDue {
                        Text("DUE")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color("AppAccent"))
                    }
                }
                Text(topic.title)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(Color("AppTextPrimary"))
                    .fixedSize(horizontal: false, vertical: true)

                if revealed {
                    Text(topic.content)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(Color("AppTextPrimary").opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                    if !topic.note.isEmpty {
                        Text("Hint: \(topic.note)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color("AppAccent"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(topic.summary)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(Color("AppTextSecondary"))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Tap to reveal")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color("AppPrimary"))
                }
            }
            .frame(minHeight: 260, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture {
                FeedbackService.shared.selection()
                withAnimation { revealed.toggle() }
            }
        }
    }

    private func grade(_ grade: SRSGrade) {
        guard let topic = queue.first else { return }
        if grade == .again {
            FeedbackService.shared.error()
        } else {
            FeedbackService.shared.success()
        }
        store.gradeTopic(topic.id, grade: grade)
        withAnimation {
            dragOffset = .zero
            revealed = false
            if !queue.isEmpty { queue.removeFirst() }
        }
    }
}

struct FocusTimerView: View {
    @EnvironmentObject private var store: LearningStore

    @State private var isFocus = true
    @State private var remaining = 25 * 60
    @State private var running = false
    @State private var cyclesCompleted = 0
    @State private var runTask: Task<Void, Never>?

    private var focusSeconds: Int { 25 * 60 }
    private var breakSeconds: Int { 5 * 60 }

    var body: some View {
        ZStack {
            BackgroundView()
            VStack(spacing: 24) {
                Text(isFocus ? "Focus" : "Break")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(Color("AppTextPrimary"))

                Text(timeString(remaining))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(isFocus ? Color("AppPrimary") : Color("AppAccent"))
                    .monospacedDigit()

                Text("Sessions done: \(cyclesCompleted) · streak \(store.stats.focusSessionStreak)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color("AppTextSecondary"))

                HStack(spacing: 12) {
                    Button(running ? "Pause" : "Start") {
                        FeedbackService.shared.tap()
                        running ? pause() : start()
                    }
                    .buttonStyle(PrimaryActionStyle(color: Color("AppPrimary")))

                    Button("Reset") {
                        FeedbackService.shared.tap()
                        reset()
                    }
                    .buttonStyle(PrimaryActionStyle(color: Color("AppAccent")))
                }
                .padding(.horizontal, 24)

                NavigationLink {
                    QuickReviewView()
                } label: {
                    Text("Review cards during breaks")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color("AppTextSecondary"))
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.top, 40)
        }
        .navigationTitle("Focus Timer")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { pause() }
    }

    private func start() {
        running = true
        runTask?.cancel()
        runTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                tick()
            }
        }
    }

    private func pause() {
        running = false
        runTask?.cancel()
        runTask = nil
    }

    private func reset() {
        pause()
        isFocus = true
        remaining = focusSeconds
    }

    private func tick() {
        guard running else { return }
        guard remaining > 0 else {
            completePhase()
            return
        }
        remaining -= 1
    }

    private func completePhase() {
        FeedbackService.shared.success()
        if isFocus {
            cyclesCompleted += 1
            store.completeFocusSession(minutes: 25)
            isFocus = false
            remaining = breakSeconds
        } else {
            isFocus = true
            remaining = focusSeconds
        }
    }

    private func timeString(_ total: Int) -> String {
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

private struct PrimaryActionStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(Color("AppTextPrimary"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
