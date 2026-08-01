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

        if desiredLength > 0.05 {
            // Das Boot dreht sich zur gewünschten Richtung, statt sofort
            // seitwärts zu rutschen — daher fährt es sich träge und ruhig.
            let targetHeading = atan2(desired.dy, desired.dx)
            heading = BoatController.turn(from: heading,
                                          to: targetHeading,
                                          maxStep: CGFloat(stats.boatTurnRate) * dt)

            let alignment = max(0, cos(BoatController.angleDifference(heading, targetHeading)))
            let thrust = CGFloat(stats.boatSpeed) * desiredLength * (0.35 + alignment * 0.65)
            velocity.dx += cos(heading) * thrust * dt * 2.4
            velocity.dy += sin(heading) * thrust * dt * 2.4
            rowingIntensity = min(1, rowingIntensity + dt * 3)
        } else {
            rowingIntensity = max(0, rowingIntensity - dt * 2)
        }

        // Wasserwiderstand.
        let drag = CGFloat(1.0 - min(0.92, 1.9 * Double(dt)))
        velocity.dx *= drag
        velocity.dy *= drag

        // Tempolimit.
        let speed = hypot(velocity.dx, velocity.dy)
        let maxSpeed = CGFloat(stats.boatSpeed)
        if speed > maxSpeed {
            velocity.dx = velocity.dx / speed * maxSpeed
            velocity.dy = velocity.dy / speed * maxSpeed
        }

        move(dt: dt, map: map)
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
