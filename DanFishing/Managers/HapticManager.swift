import Foundation
import UIKit

/// Haptik. Absichtlich über die einfachen Feedback-Generatoren statt über
/// CoreHaptics: Die Muster hier sind kurz und punktuell, dafür ist der
/// zusätzliche Aufwand einer eigenen Haptik-Engine nicht gerechtfertigt.
final class HapticManager {

    static let shared = HapticManager()

    private(set) var enabled = true

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    /// Damit das Warnsignal bei kritischer Spannung nicht durchgehend rattert.
    private var lastWarning = Date.distantPast

    private init() {}

    func apply(settings: GameSettings) {
        enabled = settings.haptics
        if enabled { prepare() }
    }

    func prepare() {
        guard enabled else { return }
        light.prepare()
        medium.prepare()
        heavy.prepare()
        notification.prepare()
    }

    /// Ein Fisch hat gebissen.
    func bite() {
        guard enabled else { return }
        medium.impactOccurred(intensity: 0.9)
    }

    /// Kurzes Ticken beim Einholen.
    func reelTick() {
        guard enabled else { return }
        light.impactOccurred(intensity: 0.4)
    }

    /// Die Schnur steht kurz vor dem Reißen — höchstens dreimal pro Sekunde.
    func tensionWarning() {
        guard enabled else { return }
        let now = Date()
        guard now.timeIntervalSince(lastWarning) > 0.33 else { return }
        lastWarning = now
        heavy.impactOccurred(intensity: 0.7)
    }

    func success() {
        guard enabled else { return }
        notification.notificationOccurred(.success)
    }

    func failure() {
        guard enabled else { return }
        notification.notificationOccurred(.error)
    }

    func selection() {
        guard enabled else { return }
        light.impactOccurred(intensity: 0.5)
    }
}
