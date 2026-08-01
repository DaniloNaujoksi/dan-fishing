import CoreGraphics
import Foundation

/// Bewegung des Ruderboots. Reine Rechnung ohne SpriteKit, damit sich das
/// Fahrverhalten testen lässt und die Szene nur noch die Werte übernimmt.
struct BoatController {

    /// Radius für die Kollisionsprüfung gegen Ufer, Inseln und Steine.
    let collisionRadius: CGFloat = 34

    private(set) var position: CGPoint
    /// Blickrichtung in Bogenmaß. 0 zeigt nach rechts.
    private(set) var heading: CGFloat
    private(set) var velocity: CGVector = .zero

    /// Wie stark gerade gerudert wird (0…1) — die Szene macht daraus die
    /// Ruderbewegung und das Kielwasser.
    private(set) var rowingIntensity: CGFloat = 0

    /// Ziel für das Antippen-Rudern. Nil, wenn der Spieler selbst steuert.
    private(set) var autoTarget: CGPoint?

    init(position: CGPoint, heading: CGFloat = -.pi / 2) {
        self.position = position
        self.heading = heading
    }

    mutating func setAutoTarget(_ point: CGPoint?) {
        autoTarget = point
    }

    mutating func place(at point: CGPoint) {
        position = point
        velocity = .zero
        autoTarget = nil
    }

    /// Ein Simulationsschritt.
    /// - Parameter input: Joystickvektor, Länge 0…1.
    mutating func update(deltaTime: CGFloat,
                         input: CGVector,
                         stats: EquipmentStats,
                         map: LakeMap) {
        let dt = min(max(deltaTime, 0), 1.0 / 20.0)

        var desired = input
        let inputLength = hypot(input.dx, input.dy)

        // Antippen-Rudern: solange kein Joystick benutzt wird, steuert das Boot
        // selbst auf das Ziel zu.
        if inputLength < 0.05, let target = autoTarget {
            let delta = CGVector(dx: target.x - position.x, dy: target.y - position.y)
            let distance = hypot(delta.dx, delta.dy)
            if distance < 40 {
                autoTarget = nil
                desired = .zero
            } else {
                desired = CGVector(dx: delta.dx / distance, dy: delta.dy / distance)
            }
        } else if inputLength >= 0.05 {
            autoTarget = nil
        }

        let desiredLength = min(1, hypot(desired.dx, desired.dy))

        // Ein Ruderboot beschleunigt langsam und läuft lange aus. Deshalb wird
        // nicht direkt die Geschwindigkeit gesetzt, sondern eine Wunschfahrt
        // vorgegeben, der sich das Boot annähert — einmal beim Antreten, einmal
        // beim Ausrollen, mit unterschiedlichem Tempo.
        let maxSpeed = CGFloat(stats.boatSpeed) * BoatController.cruiseFactor
        var targetVelocity = CGVector.zero

        if desiredLength > 0.05 {
            let targetHeading = atan2(desired.dy, desired.dx)

            // Langsame Fahrt dreht enger als volle Fahrt — das fühlt sich nach
            // Wasser an und verhindert das nervöse Zappeln bei kleinen
            // Fingerbewegungen.
            let speedShare = min(1, hypot(velocity.dx, velocity.dy) / max(maxSpeed, 1))
            let turnRate = CGFloat(stats.boatTurnRate) * (1.0 - speedShare * 0.45)
            heading = BoatController.turn(from: heading, to: targetHeading, maxStep: turnRate * dt)

            // Schräg zum Ziel gibt es weniger Schub: Erst drehen, dann fahren.
            let alignment = max(0, cos(BoatController.angleDifference(heading, targetHeading)))
            let power = desiredLength * (0.25 + alignment * 0.75)
            targetVelocity = CGVector(dx: cos(heading) * maxSpeed * power,
                                      dy: sin(heading) * maxSpeed * power)

            rowingIntensity = min(1, rowingIntensity + dt * 2.2)
        } else {
            rowingIntensity = max(0, rowingIntensity - dt * 1.6)
        }

        // Anfahren spürbar träge, Ausrollen noch träger — das Boot gleitet aus,
        // statt stehen zu bleiben.
        let rate = desiredLength > 0.05 ? BoatController.accelerationRate : BoatController.dragRate
        let blend = 1 - exp(-rate * dt)
        velocity.dx += (targetVelocity.dx - velocity.dx) * blend
        velocity.dy += (targetVelocity.dy - velocity.dy) * blend

        // Ganz kleine Restbewegung wegschneiden, sonst kriecht das Boot ewig.
        if hypot(velocity.dx, velocity.dy) < 2 && desiredLength <= 0.05 {
            velocity = .zero
        }

        move(dt: dt, map: map)
    }

    /// Anteil der Höchstgeschwindigkeit, den das Boot im Alltag fährt. Die alte
    /// Fahrt war für einen Ruderkahn deutlich zu hektisch.
    private static let cruiseFactor: CGFloat = 0.62
    /// Wie schnell das Boot Fahrt aufnimmt (je größer, desto direkter).
    private static let accelerationRate: CGFloat = 1.9
    /// Wie schnell es ohne Ruderschlag ausläuft.
    private static let dragRate: CGFloat = 0.85

    /// Hält das Boot im Umkreis der ausgeworfenen Schnur.
    ///
    /// Ohne diese Grenze fährt man einfach davon, während der Schwimmer im
    /// Wasser liegt — die Schnur wäre dann ein Gummiband über den halben See.
    /// Am Ende der Schnur wird das Boot sanft gebremst und zurückgeholt, statt
    /// hart zu stoppen.
    /// - Returns: Spannung 0…1 auf der letzten Strecke vor dem Anschlag.
    @discardableResult
    mutating func applyLineTether(anchor: CGPoint, maxLength: CGFloat, deltaTime: CGFloat) -> CGFloat {
        let delta = CGVector(dx: position.x - anchor.x, dy: position.y - anchor.y)
        let distance = hypot(delta.dx, delta.dy)
        guard distance > 1 else { return 0 }

        // Die letzten 25 Prozent gelten als „Schnur wird stramm“.
        let slackLimit = maxLength * 0.75
        guard distance > slackLimit else { return 0 }

        let tension = min(1, (distance - slackLimit) / max(maxLength - slackLimit, 1))
        let unit = CGVector(dx: delta.dx / distance, dy: delta.dy / distance)

        // Anteil der Fahrt, der vom Anker wegzeigt, wird zunehmend geschluckt.
        let outward = velocity.dx * unit.dx + velocity.dy * unit.dy
        if outward > 0 {
            let damping = tension * tension
            velocity.dx -= unit.dx * outward * damping
            velocity.dy -= unit.dy * outward * damping
        }

        // Über die volle Länge hinaus zieht die Schnur das Boot zurück.
        if distance > maxLength {
            let pull = min(1, (distance - maxLength) / 60)
            let correction = (distance - maxLength) * min(1, deltaTime * 6) + pull * 12 * deltaTime
            position.x -= unit.dx * correction
            position.y -= unit.dy * correction
            autoTarget = nil
        }

        return tension
    }

    /// Bewegt das Boot und lässt es an Hindernissen entlanggleiten, statt
    /// hart stehen zu bleiben.
    private mutating func move(dt: CGFloat, map: LakeMap) {
        let step = CGPoint(x: position.x + velocity.dx * dt,
                           y: position.y + velocity.dy * dt)

        if !map.isBlocked(circleAt: step, radius: collisionRadius) {
            position = step
            return
        }

        // Nur in X bewegen …
        let stepX = CGPoint(x: step.x, y: position.y)
        if !map.isBlocked(circleAt: stepX, radius: collisionRadius) {
            position = stepX
            velocity.dy *= 0.2
            return
        }

        // … oder nur in Y.
        let stepY = CGPoint(x: position.x, y: step.y)
        if !map.isBlocked(circleAt: stepY, radius: collisionRadius) {
            position = stepY
            velocity.dx *= 0.2
            return
        }

        // Ganz blockiert: abbremsen und Ziel verwerfen.
        velocity = CGVector(dx: velocity.dx * 0.1, dy: velocity.dy * 0.1)
        autoTarget = nil
    }

    var speed: CGFloat {
        hypot(velocity.dx, velocity.dy)
    }

    // MARK: - Winkelhilfen

    static func angleDifference(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        var difference = b - a
        while difference > .pi { difference -= .pi * 2 }
        while difference < -.pi { difference += .pi * 2 }
        return difference
    }

    static func turn(from current: CGFloat, to target: CGFloat, maxStep: CGFloat) -> CGFloat {
        let difference = angleDifference(current, target)
        if abs(difference) <= maxStep { return target }
        return current + (difference > 0 ? maxStep : -maxStep)
    }
}
