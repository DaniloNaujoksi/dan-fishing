import CoreGraphics
import Foundation

/// Verhalten der sichtbaren Fische.
///
/// Die Fische sind nicht mehr nur Kulisse: Wer den Köder findet, entscheidet
/// selbst, ob er ihn nimmt. Der Ablauf ist bewusst lesbar — entdecken,
/// annähern, umkreisen, prüfen, zupfen, beißen oder abdrehen. Der Spieler
/// sieht den Biss dadurch kommen, statt von einem Timer überrascht zu werden.
struct FishAI {

    /// Was ein Fisch gerade tut.
    enum Behaviour: Equatable {
        /// Zieht ruhig durch sein Revier.
        case cruise
        /// Hat den Köder bemerkt und nähert sich.
        case approach
        /// Umkreist den Köder und schaut ihn sich an.
        case inspect
        /// Zupft — der Schwimmer wackelt, der Biss steht kurz bevor.
        case nibble
        /// Hat abgelehnt und sucht das Weite.
        case retreat
        /// Erschrocken: flieht schnell und ist eine Weile nicht ansprechbar.
        case spooked
    }

    /// Was ein Schritt der KI ausgelöst hat.
    enum Outcome: Equatable {
        case none
        /// Der Fisch hat gezupft.
        case nibbled
        /// Der Fisch hat zugebissen.
        case bit
        /// Der Fisch hat abgedreht.
        case rejected
    }

    /// Charakter eines einzelnen Fisches. Zwei Hechte am selben Platz
    /// verhalten sich dadurch unterschiedlich.
    struct Traits: Equatable {
        /// Wie fressbereit er ist.
        var hunger: CGFloat
        /// Wie schnell er sich für Neues interessiert.
        var curiosity: CGFloat
        /// Wie misstrauisch er den Köder prüft.
        var caution: CGFloat

        static func random(for species: FishSpecies) -> Traits {
            // Räuber sind mutiger, Friedfische vorsichtiger.
            let predator = CGFloat(species.fightStrength)
            return Traits(
                hunger: CGFloat.random(in: 0.35...1.0),
                curiosity: CGFloat.random(in: 0.3...1.0) * (0.6 + predator * 0.6),
                caution: CGFloat.random(in: 0.2...0.9) * (1.3 - predator * 0.5)
            )
        }
    }

    /// Zustand eines einzelnen Schwimmers.
    struct Swimmer {
        var position: CGPoint
        var heading: CGFloat
        var speed: CGFloat
        /// Zone, in der sich der Fisch aufhält.
        var habitat: Habitat
        var speciesID: String
        var scale: CGFloat
        /// Zeit bis zur nächsten Richtungsänderung im Streifzug.
        var turnTimer: CGFloat

        var traits: Traits
        var behaviour: Behaviour = .cruise
        /// 0…1 — wie sehr der Köder ihn gerade reizt.
        var attraction: CGFloat = 0
        /// Restzeit im aktuellen Verhalten.
        var behaviourTimer: CGFloat = 0
        /// Drehrichtung beim Umkreisen.
        var circleSign: CGFloat = 1
        /// Wie oft noch gezupft wird, bevor er zubeißt.
        var nibblesLeft: Int = 0
        /// Sperre, damit ein Fisch nicht sofort erneut anbeißt.
        var cooldown: CGFloat = 0
        /// Wie lange er schon keinen freien Weg findet. Ab einer Sekunde wird
        /// er aus der Klemme geholt.
        var stuckTimer: CGFloat = 0

        /// Ein legendärer Fisch. Er ist alt geworden, weil er misstrauisch
        /// ist: Er kommt später heran, prüft länger und dreht schneller ab.
        var isLegendary: Bool = false
    }

    /// Wie weit ein Fisch den Köder überhaupt bemerkt.
    static let detectionRadius: CGFloat = 420
    /// Abstand, in dem er den Köder umkreist.
    static let inspectRadius: CGFloat = 70

    /// Ein Schritt für einen Schwimmer.
    ///
    /// - Parameters:
    ///   - lure: Position des Köders, falls einer im Wasser liegt.
    ///   - interest: 0…1 — wie gut Köder, Zone und Tageszeit zu dieser Art passen.
    ///   - biteAllowed: false, solange schon ein Fisch am Haken hängt.
    @discardableResult
    static func update(_ swimmer: inout Swimmer,
                       deltaTime: CGFloat,
                       map: LakeMap,
                       lure: CGPoint?,
                       interest: CGFloat,
                       biteAllowed: Bool) -> Outcome {
        let dt = min(max(deltaTime, 0), 1.0 / 20.0)
        var outcome = Outcome.none

        swimmer.cooldown = max(0, swimmer.cooldown - dt)
        swimmer.behaviourTimer -= dt

        // Ohne Köder im Wasser gibt es nichts zu entscheiden.
        guard let lure, biteAllowed, swimmer.cooldown <= 0 else {
            if swimmer.behaviour != .cruise && swimmer.behaviour != .spooked {
                swimmer.behaviour = .cruise
                swimmer.attraction = 0
            } else if swimmer.behaviour == .spooked && swimmer.behaviourTimer <= 0 {
                swimmer.behaviour = .cruise
            }
            swim(&swimmer, dt: dt, map: map)
            return .none
        }

        let delta = CGVector(dx: lure.x - swimmer.position.x, dy: lure.y - swimmer.position.y)
        let distance = hypot(delta.dx, delta.dy)
        let toLure = atan2(delta.dy, delta.dx)

        switch swimmer.behaviour {
        case .cruise:
            // Entdecken: je näher und je passender der Köder, desto eher.
            // Ein legendärer Fisch braucht deutlich mehr, bevor er überhaupt
            // hinsieht — deshalb steht er noch da.
            let threshold: CGFloat = swimmer.isLegendary ? 0.35 : 0.08
            if distance < detectionRadius && interest > threshold {
                let proximity = 1 - distance / detectionRadius
                var chance = interest * proximity * swimmer.traits.curiosity * dt * 1.6
                if swimmer.isLegendary { chance *= 0.3 }
                if CGFloat.random(in: 0...1) < chance {
                    swimmer.behaviour = .approach
                    swimmer.behaviourTimer = 14
                    swimmer.attraction = 0.2
                }
            }

        case .approach:
            swimmer.attraction = min(1, swimmer.attraction + dt * 0.6)
            swimmer.heading = turn(from: swimmer.heading, to: toLure, maxStep: dt * 2.4)

            if distance < inspectRadius {
                swimmer.behaviour = .inspect
                swimmer.behaviourTimer = 2.5 + swimmer.traits.caution * 4
                swimmer.circleSign = Bool.random() ? 1 : -1
            } else if swimmer.behaviourTimer <= 0 {
                // Zu lange gebraucht — Interesse verloren.
                swimmer.behaviour = .retreat
                swimmer.behaviourTimer = 4
                outcome = .rejected
            }

        case .inspect:
            // Um den Köder kreisen, statt ihn anzustarren.
            swimmer.attraction = min(1, swimmer.attraction + dt * 0.4)
            let tangent = toLure + swimmer.circleSign * (.pi / 2)
            let correction = distance > inspectRadius * 1.5 ? toLure : tangent
            swimmer.heading = turn(from: swimmer.heading, to: correction, maxStep: dt * 3.2)

            if swimmer.behaviourTimer <= 0 {
                // Entscheidung: Der Appetit muss das Misstrauen schlagen.
                // Bei einer Legende wiegt das Misstrauen deutlich schwerer;
                // man braucht mehrere Anläufe, auch wenn alles stimmt.
                let appetite = swimmer.traits.hunger * interest * (swimmer.isLegendary ? 0.9 : 1.6)
                if appetite > swimmer.traits.caution {
                    swimmer.behaviour = .nibble
                    swimmer.behaviourTimer = 0.6
                    swimmer.nibblesLeft = Int.random(in: 1...2)
                } else {
                    swimmer.behaviour = .retreat
                    swimmer.behaviourTimer = 5
                    // Nach einer Absage lässt sich eine Legende lange nicht
                    // mehr blicken. Wer sie verprellt, wartet.
                    swimmer.cooldown = swimmer.isLegendary ? 45 : 8
                    outcome = .rejected
                }
            }

        case .nibble:
            swimmer.heading = turn(from: swimmer.heading, to: toLure, maxStep: dt * 2.0)

            if swimmer.behaviourTimer <= 0 {
                if swimmer.nibblesLeft > 0 {
                    swimmer.nibblesLeft -= 1
                    swimmer.behaviourTimer = CGFloat.random(in: 0.7...1.4)
                    outcome = .nibbled
                } else {
                    outcome = .bit
                    swimmer.behaviour = .retreat
                    swimmer.behaviourTimer = 6
                    swimmer.cooldown = 25
                }
            }

        case .retreat, .spooked:
            swimmer.attraction = max(0, swimmer.attraction - dt * 0.8)
            if swimmer.behaviourTimer <= 0 {
                swimmer.behaviour = .cruise
            }
        }

        swim(&swimmer, dt: dt, map: map)
        return outcome
    }

    /// Der Fisch erschrickt — etwa wenn der Köder direkt neben ihm einschlägt.
    static func spook(_ swimmer: inout Swimmer, awayFrom point: CGPoint) {
        swimmer.behaviour = .spooked
        swimmer.behaviourTimer = CGFloat.random(in: 2.5...5)
        swimmer.attraction = 0
        swimmer.cooldown = max(swimmer.cooldown, 6)
        swimmer.heading = atan2(swimmer.position.y - point.y, swimmer.position.x - point.x)
    }

    // MARK: - Bewegung

    private static func swim(_ swimmer: inout Swimmer, dt: CGFloat, map: LakeMap) {
        // Im Streifzug wechselt die Richtung gemächlich, auf der Flucht nicht.
        if swimmer.behaviour == .cruise {
            swimmer.turnTimer -= dt
            if swimmer.turnTimer <= 0 {
                swimmer.heading += CGFloat.random(in: -0.8...0.8)
                swimmer.turnTimer = CGFloat.random(in: 1.2...3.4)
            }

            // Im ziehenden Wasser steht ein Fisch mit dem Kopf gegen die
            // Strömung — anders bekäme er kein Wasser durch die Kiemen. Genau
            // daran erkennt man von oben, wo es zieht.
            let flow = map.current(at: swimmer.position)
            if flow.dx != 0 || flow.dy != 0 {
                let upstream = atan2(-flow.dy, -flow.dx)
                swimmer.heading = turn(from: swimmer.heading, to: upstream, maxStep: dt * 0.9)
            }
        }

        let speed: CGFloat
        switch swimmer.behaviour {
        case .cruise:   speed = swimmer.speed * 0.75
        case .approach: speed = swimmer.speed * 1.25
        case .inspect:  speed = swimmer.speed * 0.7
        case .nibble:   speed = swimmer.speed * 0.35
        case .retreat:  speed = swimmer.speed * 1.4
        case .spooked:  speed = swimmer.speed * 2.4
        }

        let reach = speed * dt

        // Erst geradeaus, dann in immer weiteren Bögen zur Seite. Die alte
        // Fassung hat bei jedem Hindernis um 180 Grad gedreht — an einer
        // Zonenkante kippte die Richtung dadurch jeden Frame hin und her und
        // der Fisch stand fest. Ein Ausweichen in kleinen Schritten löst genau
        // das, und der Fisch schwimmt am Ufer entlang statt davor zu zappeln.
        let offsets: [CGFloat] = [0, 0.4, -0.4, 0.9, -0.9, 1.5, -1.5, 2.2, -2.2, .pi]

        // Erster Durchgang: in der eigenen Zone bleiben.
        for offset in offsets {
            let heading = swimmer.heading + offset
            let step = advance(from: swimmer.position, heading: heading, reach: reach)
            guard map.habitat(at: step) == swimmer.habitat else { continue }
            commit(&swimmer, to: step, heading: heading, turned: offset != 0)
            return
        }

        // Zweiter Durchgang: raus aus der Zone ist besser als steckenbleiben.
        // Land bleibt tabu.
        for offset in offsets {
            let heading = swimmer.heading + offset
            let step = advance(from: swimmer.position, heading: heading, reach: reach)
            guard !map.isLand(at: step) else { continue }
            commit(&swimmer, to: step, heading: heading, turned: offset != 0)
            return
        }

        // Rundum blockiert — das passiert nur in einer Sackgasse aus einer
        // Zelle. Nach kurzem Zappeln wird der Fisch ins nächste offene Wasser
        // gesetzt, damit er nicht für immer dort klebt.
        swimmer.stuckTimer += dt
        if swimmer.stuckTimer > 1.0 {
            let free = map.nearestWater(from: swimmer.position)
            swimmer.heading = atan2(free.y - swimmer.position.y, free.x - swimmer.position.x)
            swimmer.position = free
            swimmer.stuckTimer = 0
            swimmer.turnTimer = CGFloat.random(in: 1.0...2.2)
        }
    }

    private static func advance(from point: CGPoint, heading: CGFloat, reach: CGFloat) -> CGPoint {
        CGPoint(x: point.x + cos(heading) * reach,
                y: point.y + sin(heading) * reach)
    }

    /// Übernimmt einen Schritt. Nach einem Ausweichmanöver bleibt die neue
    /// Richtung eine Weile stehen, sonst dreht der Fisch sofort zurück ins
    /// Hindernis.
    private static func commit(_ swimmer: inout Swimmer,
                               to point: CGPoint,
                               heading: CGFloat,
                               turned: Bool) {
        swimmer.position = point
        swimmer.stuckTimer = 0
        if turned {
            swimmer.heading = heading
            swimmer.turnTimer = max(swimmer.turnTimer, CGFloat.random(in: 0.8...1.8))
        }
    }

    private static func turn(from current: CGFloat, to target: CGFloat, maxStep: CGFloat) -> CGFloat {
        MovementController.turn(from: current, to: target, maxStep: maxStep)
    }

    /// Sucht eine Startposition in einer Zone. Gibt nil zurück, wenn die Zone
    /// auf der Karte nicht vorkommt.
    static func randomPosition(in habitat: Habitat,
                               map: LakeMap,
                               near point: CGPoint? = nil,
                               radius: CGFloat = 900,
                               attempts: Int = 60) -> CGPoint? {
        for _ in 0..<attempts {
            let candidate: CGPoint
            if let point {
                let angle = CGFloat.random(in: 0..<(.pi * 2))
                let distance = CGFloat.random(in: 120...radius)
                candidate = CGPoint(x: point.x + cos(angle) * distance,
                                    y: point.y + sin(angle) * distance)
            } else {
                candidate = CGPoint(x: CGFloat.random(in: 0..<map.worldSize.width),
                                    y: CGFloat.random(in: 0..<map.worldSize.height))
            }
            if map.habitat(at: candidate) == habitat {
                return candidate
            }
        }

        // Zufälliges Probieren verfehlt kleine Zonen — ein Seerosenfeld aus
        // fünf Zellen findet man so praktisch nie. Deshalb wird zum Schluss
        // die Karte abgesucht und aus dem Ergebnis gezogen.
        let all = map.positions(of: habitat)
        guard !all.isEmpty else { return nil }

        if let point {
            let inRange = all.filter { hypot($0.x - point.x, $0.y - point.y) <= radius }
            if let choice = inRange.randomElement() { return choice }
        }
        return all.randomElement()
    }
}
