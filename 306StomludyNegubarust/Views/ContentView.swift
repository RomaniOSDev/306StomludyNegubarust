import SwiftUI

struct ContentView: View {
    @StateObject private var store = LearningStore()

    var body: some View {
        Group {
            if store.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environmentObject(store)
        .environmentObject(FeedbackService.shared)
        .preferredColorScheme(store.preferences.colorScheme.preferredColorScheme)
        .id(store.preferences.colorScheme) // force full tree refresh when theme flips
        .onAppear {
            NotificationService.shared.resync(preferences: store.preferences)
        }
    }
}
