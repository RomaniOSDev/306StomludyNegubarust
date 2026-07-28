import Foundation
import AudioToolbox
import UIKit
import Combine

/// Central gate for every sound and haptic in the app.
/// When sound is off, no AudioServices call is made. When haptics are off, generators stay silent.
@MainActor
final class FeedbackService: ObservableObject {
    static let shared = FeedbackService()

    /// App plays system sounds for taps / quiz results. Keep in sync: if this becomes false, hide sound toggle.
    static let hasSoundFeatures = true
    static let hasHapticFeatures = true

    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: Keys.sound) }
    }

    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: Keys.haptics) }
    }

    private enum Keys {
        static let sound = "settings.soundEnabled"
        static let haptics = "settings.hapticsEnabled"
    }

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.sound) == nil {
            soundEnabled = true
        } else {
            soundEnabled = defaults.bool(forKey: Keys.sound)
        }
        if defaults.object(forKey: Keys.haptics) == nil {
            hapticsEnabled = true
        } else {
            hapticsEnabled = defaults.bool(forKey: Keys.haptics)
        }
    }

    func tap() {
        playSound(1104)
        impact(.light)
    }

    func success() {
        playSound(1025)
        notify(.success)
    }

    func error() {
        playSound(1053)
        notify(.error)
    }

    func selection() {
        guard hapticsEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func playSound(_ id: SystemSoundID) {
        guard soundEnabled, Self.hasSoundFeatures else { return }
        AudioServicesPlaySystemSound(id)
    }

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsEnabled, Self.hasHapticFeatures else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticsEnabled, Self.hasHapticFeatures else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
