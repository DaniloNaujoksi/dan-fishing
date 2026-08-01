import CoreGraphics
import Foundation

/// Bewegung der sichtbaren Fische im See. Diese Fische sind Kulisse und
/// Hinweis zugleich: Wo sich viel bewegt, beißt es auch. Sie sind bewusst
/// getrennt vom Fisch am Haken, der erst beim Biss ausgewürfelt wird.
struct FishAI {

    /// Zustand eines einzelnen Schwimmers.
    struct Swimmer {
        var position: CGPoint
        var heading: CGFloat
        var speed: CGFloat
        /// Zone, in der sich der Fisch aufhält — er verlässt sie nicht.
        var habitat: Habitat
        var speciesID: String
        var scale: CGFloat
        /// Zeit bis zur nächsten Richtungsänderung.
        var turnTimer: CGFloat
        /// Wie stark der Fisch gerade zum Köder gezogen wird (0…1).
        var attraction: CGFloat = 0
    }

    /// Ein Schritt für einen Schwimmer.
    ///
    /// - Parameters:
    ///   - lure: Position des Köders, falls einer im Wasser liegt.
    ///   - interest: 0…1 — wie attraktiv der Köder für diesen Fisch ist.
    static func update(_ swimmer: inout Swimmer,
                       deltaTime: CGFloat,
                       map: LakeMap,
                       lure: CGPoint?,
                       interest: CGFloat) {
        let dt = min(max(deltaTime, 0), 1.0 / 20.0)

        swimmer.turnTimer -= dt
        if swimmer.turnTimer <= 0 {
            swimmer.heading += CGFloat.random(in: -0.9...0.9)
            swimmer.turnTimer = CGFloat.random(in: 0.8...2.6)
        }

        // Köder in der Nähe: der Fisch dreht langsam bei und wird schneller.
        if let lure {
            let delta = CGVector(dx: lure.x - swimmer.position.x, dy: lure.y - swimmer.position.y)
            let distance = hypot(delta.dx, delta.dy)
            if distance < 340 && interest > 0.1 {
                let target = atan2(delta.dy, delta.dx)
                let pull = interest * (1 - distance / 340) * 2.2 * dt
                swimmer.heading = BoatController.turn(from: swimmer.heading,
                                                      to: target,
                                                      maxStep: pull)
                swimmer.attraction = min(1, swimmer.attraction + dt)
            } else {
                swimmer.attraction = max(0, swimmer.attraction - dt * 0.5)
            }
        } else {
            swimmer.attraction = max(0, swimmer.attraction - dt * 0.5)
        }

        let speed = swimmer.speed * (1 + swimmer.attraction * 0.6)
        let step = CGPoint(x: swimmer.position.x + cos(swimmer.heading) * speed * dt,
                           y: swimmer.position.y + sin(swimmer.heading) * speed * dt)

        // Fische bleiben in ihrer Zone. Passt der nächste Schritt nicht, wird
        // umgekehrt statt gestoppt — sonst kleben sie an Kanten fest.
        if map.habitat(at: step) == swimmer.habitat {
            swimmer.position = step
        } else {
            swimmer.heading += .pi * CGFloat.random(in: 0.6...1.4)
            swimmer.turnTimer = CGFloat.random(in: 0.6...1.4)
        }
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
        return nil
    }
}
