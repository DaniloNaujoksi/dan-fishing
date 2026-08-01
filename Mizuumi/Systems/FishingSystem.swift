import CoreGraphics
import Foundation

/// Ablauf vom Auswerfen bis zum Anschlag.
///
/// Die Zustandsmaschine kennt weder Grafik noch Oberfläche. Sie meldet
/// Ereignisse nach oben; die Szene zeichnet daraufhin Schwimmer, Schnur und
/// Ringe, die Oberfläche zeigt Hinweise an.
final class FishingSystem {

    enum Phase: Equatable {
        case idle          // Angel eingeholt
        case charging      // Taste gedrückt, Wurfweite wächst
        case flying        // Köder ist unterwegs
        case waiting       // Köder liegt, es passiert noch nichts
        case nibble        // Fisch interessiert sich, Schwimmer zuckt
        case biteWindow    // jetzt anschlagen
        case hooked        // Fisch hängt, Drill läuft
    }

    enum Event: Equatable {
        case castLanded(CGPoint)
        case castFailed                  // auf Land geworfen
        case nibble
        case bite
        case missedStrike                // zu früh oder zu spät
        case hooked(HookedFish)
        case slippedOff                  // Fisch war dran, ist beim Anschlag ausgestiegen
        case reeledIn
    }

    private(set) var phase: Phase = .idle
    /// 0…1 während des Aufladens.
    private(set) var castPower: Double = 0
    private(set) var bobberPosition: CGPoint?
    private(set) var pendingFish: HookedFish?

    /// Zeit, die im Biss-Fenster noch bleibt (für die Anzeige).
    private(set) var biteWindowRemaining: Double = 0

    var onEvent: ((Event) -> Void)?

    private var timer: Double = 0
    private var chargeDirection: Double = 1
    private var flightProgress: Double = 0
    private var flightStart: CGPoint = .zero
    private var flightEnd: CGPoint = .zero
    private var nibbleCount = 0

    /// Wie lange das Fenster zum Anschlagen offen ist.
    private let biteWindowLength: Double = 1.1

    // MARK: - Eingaben

    func beginCharge() {
        guard phase == .idle else { return }
        phase = .charging
        castPower = 0.15
        chargeDirection = 1
    }

    /// Wirft aus. Gibt den Zielpunkt zurück, falls der Wurf gültig war.
    @discardableResult
    func releaseCast(from origin: CGPoint,
                     direction: CGVector,
                     stats: EquipmentStats,
                     map: LakeMap) -> CGPoint? {
        guard phase == .charging else { return nil }

        let length = hypot(direction.dx, direction.dy)
        let unit: CGVector = length > 0.001
            ? CGVector(dx: direction.dx / length, dy: direction.dy / length)
            : CGVector(dx: 0, dy: 1)

        let distance = CGFloat(120 + castPower * (stats.castRange - 120))
        let target = CGPoint(x: origin.x + unit.dx * distance,
                             y: origin.y + unit.dy * distance)

        guard !map.isLand(at: target) else {
            phase = .idle
            castPower = 0
            onEvent?(.castFailed)
            return nil
        }

        flightStart = origin
        flightEnd = target
        flightProgress = 0
        phase = .flying
        bobberPosition = origin
        return target
    }

    /// Anschlag. Gibt zurück, ob der Fisch hängen geblieben ist.
    @discardableResult
    func strike(stats: EquipmentStats) -> Bool {
        switch phase {
        case .biteWindow:
            guard let fish = pendingFish else {
                reset()
                return false
            }
            // Große Fische steigen häufiger aus.
            let holdChance = min(0.97, stats.hookHold - fish.trophyFactor * 0.18)
            if Double.random(in: 0..<1) < holdChance {
                phase = .hooked
                onEvent?(.hooked(fish))
                return true
            } else {
                pendingFish = nil
                reset()
                onEvent?(.slippedOff)
                return false
            }

        case .waiting, .nibble:
            // Zu früh: der Fisch ist weg.
            pendingFish = nil
            reset()
            onEvent?(.missedStrike)
            return false

        default:
            return false
        }
    }

    /// Angel einholen — auch mitten im Warten möglich.
    func reelIn() {
        guard phase != .idle else { return }
        reset()
        onEvent?(.reeledIn)
    }

    /// Wird nach dem Drill aufgerufen, egal wie er ausgegangen ist.
    func finishFight() {
        reset()
    }

    private func reset() {
        phase = .idle
        castPower = 0
        bobberPosition = nil
        pendingFish = nil
        timer = 0
        nibbleCount = 0
        biteWindowRemaining = 0
    }

    // MARK: - Schleife

    /// - Parameters:
    ///   - context: Bedingungen am Köderplatz. Nil, wenn dort kein Wasser ist.
    ///   - bait: aktuell gewählter Köder.
    func update(deltaTime: Double, context: BaitSystem.Context?, bait: Bait?) {
        let dt = min(max(deltaTime, 0), 0.05)

        switch phase {
        case .idle, .hooked:
            break

        case .charging:
            // Die Anzeige pendelt hin und her, der Spieler lässt im richtigen
            // Moment los. Das ist präziser als reines Aufladen und macht auch
            // kurze Würfe möglich.
            castPower += chargeDirection * dt * 0.85
            if castPower >= 1 {
                castPower = 1
                chargeDirection = -1
            } else if castPower <= 0.1 {
                castPower = 0.1
                chargeDirection = 1
            }

        case .flying:
            flightProgress += dt * 2.2
            if flightProgress >= 1 {
                flightProgress = 1
                bobberPosition = flightEnd
                phase = .waiting
                timer = nextBiteDelay(context: context, bait: bait)
                onEvent?(.castLanded(flightEnd))
            } else {
                let t = CGFloat(flightProgress)
                bobberPosition = CGPoint(x: flightStart.x + (flightEnd.x - flightStart.x) * t,
                                         y: flightStart.y + (flightEnd.y - flightStart.y) * t)
            }

        case .waiting:
            timer -= dt
            if timer <= 0 {
                // Vor dem Biss zupft der Fisch ein- bis zweimal.
                if nibbleCount < 1 && Double.random(in: 0..<1) < 0.7 {
                    nibbleCount += 1
                    phase = .nibble
                    timer = Double.random(in: 0.6...1.4)
                    onEvent?(.nibble)
                } else {
                    startBite(context: context, bait: bait)
                }
            }

        case .nibble:
            timer -= dt
            if timer <= 0 {
                startBite(context: context, bait: bait)
            }

        case .biteWindow:
            biteWindowRemaining -= dt
            if biteWindowRemaining <= 0 {
                // Nicht angeschlagen — der Fisch nimmt den Köder mit.
                pendingFish = nil
                phase = .waiting
                nibbleCount = 0
                timer = nextBiteDelay(context: context, bait: bait)
                onEvent?(.missedStrike)
            }
        }
    }

    private func startBite(context: BaitSystem.Context?, bait: Bait?) {
        guard let context, let bait, let fish = FishSpawner.rollFish(bait: bait, context: context) else {
            // Nichts da: weiter warten.
            phase = .waiting
            timer = nextBiteDelay(context: context, bait: bait)
            return
        }

        pendingFish = fish
        phase = .biteWindow
        biteWindowRemaining = biteWindowLength
        onEvent?(.bite)
    }

    private func nextBiteDelay(context: BaitSystem.Context?, bait: Bait?) -> Double {
        guard let context, let bait else { return 12 }
        let average = BaitSystem.averageBiteDelay(bait: bait, context: context)
        // Streuung, damit der Rhythmus nicht vorhersehbar wird.
        return average * Double.random(in: 0.55...1.45)
    }
}
