import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var tab = 0

    var body: some View {
        ZStack {
            TabView(selection: $tab) {
                TopicBrowserView()
                    .tabItem {
                        Label("Topics", systemImage: "rectangle.stack")
                    }
                    .tag(0)

                KnowledgeDrillView()
                    .tabItem {
                        Label("Drill", systemImage: "checkmark.circle")
                    }
                    .tag(1)

                LearningMilestonesView()
                    .tabItem {
                        Label("Stats", systemImage: "chart.xyaxis.line")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(3)
            }
            .tint(Color("AppPrimary"))

            if let achievement = store.newlyUnlockedAchievement {
                AchievementToastOverlay(achievement: achievement) {
                    withAnimation {
                        store.clearAchievementToast()
                    }
                }
                .zIndex(10)
            }
        }
        .onAppear { applyTabBarAppearance() }
        .onChange(of: colorScheme) { _ in
            applyTabBarAppearance()
        }
        .onChange(of: store.preferences.colorScheme) { _ in
            // Allow trait collection to settle after preferredColorScheme flips.
            DispatchQueue.main.async {
                applyTabBarAppearance()
            }
        }
    }

    private func applyTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "AppBackground")
        let item = UITabBarItemAppearance()
        let muted = UIColor(named: "AppTextSecondary") ?? .secondaryLabel
        let active = UIColor(named: "AppPrimary") ?? .systemPink
        item.normal.iconColor = muted
        item.normal.titleTextAttributes = [.foregroundColor: muted]
        item.selected.iconColor = active
        item.selected.titleTextAttributes = [.foregroundColor: active]
        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Force currently visible tab bars to refresh without restart.
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.rootViewController?.view.setNeedsLayout()
                refreshTabBars(in: window)
            }
        }
    }

    private func refreshTabBars(in view: UIView) {
        if let tabBar = view as? UITabBar {
            tabBar.standardAppearance = UITabBar.appearance().standardAppearance
            tabBar.scrollEdgeAppearance = UITabBar.appearance().scrollEdgeAppearance
        }
        for child in view.subviews {
            refreshTabBars(in: child)
        }
    }
}
