import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var store: LearningStore
    @ObservedObject private var feedback = FeedbackService.shared
    @State private var showResetConfirm = false
    @State private var reminderDate = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                ScrollView {
                    VStack(spacing: 12) {
                        NavigationLink {
                            LearningMilestonesView(embedsNavigation: false)
                        } label: {
                            rowLabel(
                                title: "Statistics",
                                subtitle: "\(store.stats.cardsReviewed) cards · \(store.stats.quizzesCompleted) quizzes · streak \(store.stats.currentStreak)"
                            )
                        }
                        .buttonStyle(.plain)

                        appearanceCard
                        goalsCard

                        if FeedbackService.hasSoundFeatures || FeedbackService.hasHapticFeatures {
                            feedbackCard
                        }

                        Button {
                            FeedbackService.shared.tap()
                            requestReview()
                        } label: {
                            rowLabel(title: "Rate Us", subtitle: "Share feedback on the App Store")
                        }
                        .buttonStyle(.plain)

                        Button {
                            FeedbackService.shared.tap()
                            openURL(AppLinks.privacyPolicy)
                        } label: {
                            rowLabel(title: "Privacy Policy", subtitle: "How local data is handled")
                        }
                        .buttonStyle(.plain)

                        Button {
                            FeedbackService.shared.tap()
                            openURL(AppLinks.termsOfUse)
                        } label: {
                            rowLabel(title: "Terms of Use", subtitle: "Terms of use")
                        }
                        .buttonStyle(.plain)

                        Button {
                            FeedbackService.shared.tap()
                            showResetConfirm = true
                        } label: {
                            rowLabel(title: "Reset All Data", subtitle: "Clear progress and start fresh", destructive: true)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .dismissKeyboardOnTap()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                var components = DateComponents()
                components.hour = store.preferences.reminderHour
                components.minute = store.preferences.reminderMinute
                reminderDate = Calendar.current.date(from: components) ?? reminderDate
            }
            .confirmationDialog("Reset all learning data?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    store.resetAll()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var appearanceCard: some View {
        PaperCard(stackDepth: 1) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("AppTextPrimary"))
                Picker("Theme", selection: Binding(
                    get: { store.preferences.colorScheme },
                    set: { value in
                        FeedbackService.shared.selection()
                        store.updatePreferences { $0.colorScheme = value }
                    }
                )) {
                    ForEach(AppColorSchemePreference.allCases) { scheme in
                        Text(scheme.title).tag(scheme)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var goalsCard: some View {
        PaperCard(stackDepth: 1) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Study goals")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("AppTextPrimary"))

                Stepper(
                    "Daily cards: \(store.preferences.dailyGoal)",
                    value: Binding(
                        get: { store.preferences.dailyGoal },
                        set: { value in
                            store.updatePreferences { $0.dailyGoal = value }
                        }
                    ),
                    in: 3...40
                )
                .foregroundStyle(Color("AppTextPrimary"))

                Toggle(isOn: Binding(
                    get: { store.preferences.remindersEnabled },
                    set: { enabled in
                        Task {
                            if enabled {
                                let ok = await NotificationService.shared.requestAuthorizationIfNeeded()
                                store.updatePreferences { $0.remindersEnabled = ok }
                            } else {
                                store.updatePreferences { $0.remindersEnabled = false }
                            }
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily reminder")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Color("AppTextPrimary"))
                        Text("Soft local notification for your goal")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color("AppTextSecondary"))
                    }
                }
                .tint(Color("AppPrimary"))

                if store.preferences.remindersEnabled {
                    DatePicker(
                        "Reminder time",
                        selection: $reminderDate,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: reminderDate) { newValue in
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                        store.updatePreferences {
                            $0.reminderHour = comps.hour ?? 20
                            $0.reminderMinute = comps.minute ?? 0
                        }
                    }
                }

                Text("Focus sessions: \(store.stats.pomodoroSessions) · \(store.stats.focusMinutes) min")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color("AppTextSecondary"))
            }
        }
    }

    private var feedbackCard: some View {
        PaperCard(stackDepth: 1) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Feedback")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("AppTextPrimary"))

                if FeedbackService.hasSoundFeatures {
                    Toggle(isOn: $feedback.soundEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sound")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color("AppTextPrimary"))
                            Text("Mutes every sound in the app")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color("AppTextSecondary"))
                        }
                    }
                    .tint(Color("AppPrimary"))
                    .onChange(of: feedback.soundEnabled) { enabled in
                        if enabled { FeedbackService.shared.tap() }
                    }
                }

                if FeedbackService.hasHapticFeatures {
                    Toggle(isOn: $feedback.hapticsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Haptic Feedback")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color("AppTextPrimary"))
                            Text("Vibration for taps and quiz results")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color("AppTextSecondary"))
                        }
                    }
                    .tint(Color("AppPrimary"))
                    .onChange(of: feedback.hapticsEnabled) { enabled in
                        if enabled { FeedbackService.shared.selection() }
                    }
                }
            }
        }
    }

    private func rowLabel(title: String, subtitle: String, destructive: Bool = false) -> some View {
        PaperCard(stackDepth: 1) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(destructive ? Color("AppPrimary") : Color("AppTextPrimary"))
                    Text(subtitle)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color("AppTextSecondary"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color("AppTextSecondary"))
                    .padding(.top, 4)
            }
        }
    }

    private func openURL(_ string: String) {
        if let url = URL(string: string) {
            UIApplication.shared.open(url)
        }
    }

    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}
