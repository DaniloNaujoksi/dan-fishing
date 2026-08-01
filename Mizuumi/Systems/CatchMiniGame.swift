import Foundation

/// Das Fang-Minispiel als reine Logik ohne SpriteKit oder SwiftUI.
///
/// Idee: Der Fisch wandert in einer senkrechten Bahn. Der Spieler hält den
/// Finger auf der Taste, dann steigt sein Fangbereich; lässt er los, sinkt er.
/// Deckung heißt Fortschritt, kostet aber Spannung. Zu viel Spannung reißt die
/// Schnur, zu lange keine Deckung und der Fisch schüttelt den Haken ab.
struct CatchMiniGame {

    enum Outcome: Equatable {
        case running
        case landed
        case lineSnapped
        case fishEscaped
    }

    // MARK: - Aufbau

    let fish: HookedFish
    let stats: EquipmentStats

    /// Höhe des Fangbereichs (0…1 der Bahn).
    let barHeight: Double
    /// Wie stark der Fisch zieht (0…1).
    let fightPower: Double

    // MARK: - Zustand

    private(set) var fishPosition: Double = 0.5
    private(set) var barPosition: Double = 0.25
    private(set) var barVelocity: Double = 0
    private(set) var tension: Double = 0.25
    private(set) var progress: Double = 0.12
    private(set) var outcome: Outcome = .running

    private var time: Double = 0
    private var slackTime: Double = 0
    private var fishTarget: Double = 0.5
    private var nextDecision: Double = 0
    private var randomSource: () -> Double

    /// - Parameter randomSource: Nur für Tests austauschbar; liefert 0…1.
    init(fish: HookedFish, stats: EquipmentStats, randomSource: @escaping () -> Double = { Double.random(in: 0..<1) }) {
        self.fish = fish
        self.stats = stats
        self.randomSource = randomSource

        // Große und starke Fische machen den Fangbereich kleiner und ziehen härter.
        let sizePenalty = fish.trophyFactor * 0.25
        self.barHeight = min(0.42, max(0.12, stats.control + 0.10 - sizePenalty))

        let weightFactor = min(1.0, fish.weightKg / max(1.0, stats.maxFishWeight))
        self.fightPower = min(1.0, fish.species.fightStrength * (0.75 + weightFactor * 0.5))

        self.fishTarget = 0.5
    }

    // MARK: - Abgeleitete Werte für die Anzeige

    var barLowerEdge: Double { max(0, barPosition - barHeight / 2) }
    var barUpperEdge: Double { min(1, barPosition + barHeight / 2) }
    var isFishInBar: Bool { fishPosition >= barLowerEdge && fishPosition <= barUpperEdge }
    var isTensionCritical: Bool { tension > 0.82 }
    var isFinished: Bool { outcome != .running }

    // MARK: - Schleife

    /// Einen Zeitschritt rechnen. `reeling` ist true, solange der Spieler die
    /// Taste hält.
    mutating func update(deltaTime: Double, reeling: Bool) {
        guard outcome == .running else { return }
        let dt = min(max(deltaTime, 0), 0.05)
        time += dt

        updateFish(dt: dt)
        updateBar(dt: dt, reeling: reeling)
        updateTensionAndProgress(dt: dt, reeling: reeling)
        checkOutcome()
    }

    // MARK: - Teilschritte

    private mutating func updateFish(dt: Double) {
        // Jeder Fisch sucht sich immer wieder ein neues Ziel in der Bahn. Wie
        // oft und wie weit, hängt vom Bewegungsmuster ab.
        nextDecision -= dt
        if nextDecision <= 0 {
            switch fish.species.motion {
            case .steady:
                fishTarget = clamp(fishTarget + (randomSource() - 0.5) * 0.5)
                nextDecision = 1.6 + randomSource() * 1.2
            case .darting:
                fishTarget = clamp(randomSource())
                nextDecision = 0.35 + randomSource() * 0.5
            case .circling:
                fishTarget = clamp(0.5 + sin(time * 1.4) * 0.42)
                nextDecision = 0.25
            case .diving:
                // Zieht bevorzugt nach unten und schnellt gelegentlich hoch.
                fishTarget = randomSource() < 0.72 ? clamp(randomSource() * 0.35)
                                                   : clamp(0.6 + randomSource() * 0.4)
                nextDecision = 0.8 + randomSource() * 0.9
            case .thrashing:
                fishTarget = clamp(randomSource())
                nextDecision = 0.2 + randomSource() * 0.35
            }
        }

        let speed = 0.5 + fightPower * 1.5
        let difference = fishTarget - fishPosition
        let step = difference * min(1.0, speed * dt * 2.2)
        fishPosition = clamp(fishPosition + step)
    }

    private mutating func updateBar(dt: Double, reeling: Bool) {
        // Der Fangbereich verhält sich wie ein Gewicht an einer Feder: die
        // Taste hebt ihn, ohne Taste sinkt er. Das lässt sich mit einem Finger
        // sauber dosieren.
        let lift = 1.35
        let gravity = -1.05
        barVelocity += (reeling ? lift : gravity) * dt
        barVelocity *= 1.0 - min(0.9, 3.0 * dt)   // Dämpfung
        barPosition += barVelocity * dt

        if barPosition < 0 {
            barPosition = 0
            barVelocity = max(0, barVelocity * 0.3)
        }
        if barPosition > 1 {
            barPosition = 1
            barVelocity = min(0, barVelocity * 0.3)
        }
    }

    private mutating func updateTensionAndProgress(dt: Double, reeling: Bool) {
        if isFishInBar {
            progress += dt * 0.20 * stats.reelSpeed
            slackTime = 0

            // Spannung steigt, solange der Fisch im Bereich ist und zieht.
            let pull = 0.24 + fightPower * 0.42
            tension += dt * pull / max(0.6, stats.lineStrength)
        } else {
            progress -= dt * 0.075
            slackTime += dt
            tension -= dt * (0.34 * stats.brakeControl)
        }

        // Zusätzlich zieht der Fisch an, wenn er in die entgegengesetzte
        // Richtung schwimmt — das ist der Moment zum Nachgeben.
        if isFishInBar && abs(fishTarget - barPosition) > 0.45 {
            tension += dt * 0.18 * fightPower
        }

        if reeling && !isFishInBar {
            tension += dt * 0.05
        }

        progress = min(1.0, max(0, progress))
        tension = min(1.2, max(0, tension))
    }

    private mutating func checkOutcome() {
        if tension >= 1.0 {
            outcome = .lineSnapped
        } else if progress >= 1.0 {
            outcome = .landed
        } else if slackTime > 5.0 && progress <= 0.001 {
            outcome = .fishEscaped
        }
    }

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
