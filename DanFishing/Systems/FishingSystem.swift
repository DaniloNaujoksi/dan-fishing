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
        case aiming        // Richtung und Weite in einer Bewegung
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
    /// 0…1 — wie weit der Finger gezogen wurde.
    private(set) var castPower: Double = 0
    /// Richtung, in die geworfen wird (Einheitsvektor).
    private(set) var aimDirection = CGVector(dx: 0, dy: 1)
    private(set) var bobberPosition: CGPoint?
    private(set) var pendingFish: HookedFish?

    /// Höhe des Köders über dem Wasser während des Flugs, in Punkten.
    /// Die Szene macht daraus Größe und Schattenversatz.
    private(set) var lureHeight: CGFloat = 0

    /// Zeit, die im Biss-Fenster noch bleibt (für die Anzeige).
    private(set) var biteWindowRemaining: Double = 0

    var onEvent: ((Event) -> Void)?

    private var timer: Double = 0
    private var flightProgress: Double = 0
    private var flightStart: CGPoint = .zero
    private var flightEnd: CGPoint = .zero
    private var flightDistance: CGFloat = 0
    private var nibbleCount = 0

    /// Wie lange das Fenster zum Anschlagen offen ist.
    private let biteWindowLength: Double = 1.1

    // MARK: - Eingaben

    /// Der Finger liegt auf der Wurftaste. Ab hier wird gezielt.
    func beginAim(direction: CGVector) {
        guard phase == .idle else { return }
        phase = .aiming
        castPower = 0
        aimDirection = FishingSystem.unit(direction)
    }

    /// Zielhilfe nachführen: Richtung und Weite kommen aus derselben
    /// Fingerbewegung — Richtung aus ihrer Neigung, Weite aus ihrer Länge.
    func updateAim(direction: CGVector, power: Double) {
        guard phase == .aiming else { return }
        castPower = min(1, max(0, power))
        if hypot(direction.dx, direction.dy) > 0.01 {
            aimDirection = FishingSystem.unit(direction)
        }
    }

    /// Wohin der Köder bei der aktuellen Zielhilfe fliegen würde.
    func previewTarget(from origin: CGPoint, stats: EquipmentStats) -> CGPoint {
        let distance = castDistance(stats: stats)
        return CGPoint(x: origin.x + aimDirection.dx * distance,
                       y: origin.y + aimDirection.dy * distance)
    }

    /// Wurfweite in Punkten. Der kürzeste Wurf plumpst direkt neben das Boot,
    /// der weiteste erreicht die Reichweite der Rute.
    func castDistance(stats: EquipmentStats) -> CGFloat {
        let minimum = FishingSystem.minimumCastDistance
        let maximum = max(minimum + 40, CGFloat(stats.castRange))
        return minimum + CGFloat(castPower) * (maximum - minimum)
    }

    /// Wirft aus. Gibt den Zielpunkt zurück, falls der Wurf gültig war.
    @discardableResult
    func releaseCast(from origin: CGPoint,
                     stats: EquipmentStats,
                     map: LakeMap) -> CGPoint? {
        guard phase == .aiming else { return nil }

        // Zu kurz gezogen heißt: doch nicht werfen. Sonst landet der Köder bei
        // jedem versehentlichen Antippen im Wasser.
        guard castPower > 0.06 else {
            phase = .idle
            castPower = 0
            return nil
        }

        let target = previewTarget(from: origin, stats: stats)

        guard !map.isLand(at: target) else {
            phase = .idle
            castPower = 0
            onEvent?(.castFailed)
            return nil
        }

        flightStart = origin
        flightEnd = target
        flightDistance = hypot(target.x - origin.x, target.y - origin.y)
        flightProgress = 0
        lureHeight = 0
        phase = .flying
        bobberPosition = origin
        return target
    }

    /// Kürzeste Wurfweite — direkt neben das Boot.
    static let minimumCastDistance: CGFloat = 90

    private static func unit(_ vector: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        guard length > 0.001 else { return CGVector(dx: 0, dy: 1) }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
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

    /// Ein sichtbarer Fisch zupft am Köder.
    ///
    /// Die Bisse kommen bevorzugt von Fischen, die man im Wasser sieht — der
    /// eingebaute Timer ist nur noch der Rückfall für Stellen, an denen gerade
    /// kein Schwarm in der Nähe ist.
    func reportNibble() {
        guard phase == .waiting || phase == .nibble else { return }
        phase = .nibble
        timer = max(timer, 2.5)
        onEvent?(.nibble)
    }

    /// Ein sichtbarer Fisch beißt zu.
    func reportBite(fish: HookedFish) {
        guard phase == .waiting || phase == .nibble else { return }
        pendingFish = fish
        phase = .biteWindow
        biteWindowRemaining = biteWindowLength
        onEvent?(.bite)
    }

    /// Wartet der Köder gerade auf einen Fisch?
    var isFishing: Bool {
        phase == .waiting || phase == .nibble
    }

    /// Die Strömung nimmt den liegenden Köder mit.
    ///
    /// Nur während der Köder wirklich im Wasser liegt — im Flug hat die
    /// Strömung ihn noch nicht, und im Drill bestimmt der Fisch, wo es
    /// langgeht. Am Ufer bleibt er liegen, statt an Land gespült zu werden.
    func drift(_ delta: CGVector, map: LakeMap) {
        guard phase == .waiting || phase == .nibble || phase == .biteWindow,
              let position = bobberPosition else { return }

        let target = CGPoint(x: position.x + delta.dx, y: position.y + delta.dy)
        guard !map.isLand(at: target) else { return }
        bobberPosition = target
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
        lureHeight = 0
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

        case .aiming:
            // Nichts zu rechnen: Richtung und Weite kommen vom Finger.
            break

        case .flying:
            // Die Flugzeit hängt an der Weite — ein kurzer Wurf ist sofort
            // unten, ein weiter fliegt sichtbar länger.
            let duration = Double(0.35 + flightDistance / 900)
            flightProgress += dt / max(0.2, duration)

            if flightProgress >= 1 {
                flightProgress = 1
                lureHeight = 0
                bobberPosition = flightEnd
                phase = .waiting
                timer = nextBiteDelay(context: context, bait: bait)
                onEvent?(.castLanded(flightEnd))
            } else {
                // Waagerecht gleichmäßig, senkrecht eine Wurfparabel.
                let t = CGFloat(flightProgress)
                bobberPosition = CGPoint(x: flightStart.x + (flightEnd.x - flightStart.x) * t,
                                         y: flightStart.y + (flightEnd.y - flightStart.y) * t)
                lureHeight = sin(CGFloat.pi * t) * min(120, flightDistance * 0.22)
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
        // Streuung, damit der Rhythmus nicht vorhersehbar wird. Der Faktor 1.7
        // gibt den sichtbaren Fischen den Vortritt: Sie sollen die Bisse
        // liefern, der Timer greift nur, wenn keiner in der Nähe ist.
        return average * 1.7 * Double.random(in: 0.55...1.45)
    }
}
