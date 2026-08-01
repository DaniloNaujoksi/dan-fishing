import SpriteKit

/// Schwimmer samt Schnur. Zeigt durch seine Bewegung an, was gerade passiert:
/// ruhiges Wippen beim Warten, kurzes Zucken beim Zupfen, Abtauchen beim Biss.
final class BobberNode: SKNode {

    private let float = SKShapeNode(circleOfRadius: 9)
    private let tip = SKShapeNode(circleOfRadius: 5)
    private let rings = SKNode()
    private let shadow = SKShapeNode(ellipseOf: CGSize(width: 18, height: 11))
    private let lure = SKNode()
    private var bobPhase: CGFloat = 0
    private var flightOffset: CGFloat = 0

    override init() {
        super.init()

        shadow.fillColor = SKColor(white: 0, alpha: 0.3)
        shadow.strokeColor = .clear
        shadow.zPosition = 0
        shadow.isHidden = true
        addChild(shadow)

        // Der Köder hängt unter dem Schwimmer und bekommt sein Aussehen aus
        // `configure(for:)`.
        lure.position = CGPoint(x: 0, y: -16)
        lure.zPosition = 1
        addChild(lure)

        float.fillColor = ColorSpec(0xF4EFE3).skColor
        float.strokeColor = ColorSpec(0x3A3630).skColor
        float.lineWidth = 1.5
        float.zPosition = 2
        addChild(float)

        tip.fillColor = Palette.vermilion.skColor
        tip.strokeColor = .clear
        tip.position = CGPoint(x: 0, y: 4)
        tip.zPosition = 3
        addChild(tip)

        rings.zPosition = 1
        addChild(rings)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) wird nicht verwendet")
    }

    func update(deltaTime: CGFloat) {
        bobPhase += deltaTime * 1.8
        let bob = sin(bobPhase) * 1.6
        float.position = CGPoint(x: 0, y: bob + flightOffset)
        tip.position = CGPoint(x: 0, y: 4 + bob + flightOffset)
    }

    /// Höhe über dem Wasser während des Flugs. Der Köder wandert nach oben und
    /// wird größer, sein Schatten bleibt am Aufschlagpunkt liegen.
    func setFlightHeight(_ height: CGFloat) {
        flightOffset = height

        if height > 0.5 {
            shadow.isHidden = false
            shadow.setScale(max(0.35, 1 - height / 220))
            shadow.alpha = max(0.1, 0.35 - height / 500)
            let scale = 1 + min(0.7, height / 160)
            float.setScale(scale)
            tip.setScale(scale)
        } else {
            shadow.isHidden = true
            float.setScale(1)
            tip.setScale(1)
        }
    }

    /// Kurzes Zupfen — ein Fisch prüft den Köder.
    func showNibble() {
        float.removeAllActions()
        float.run(.sequence([
            .moveBy(x: 0, y: -5, duration: 0.09),
            .moveBy(x: 0, y: 5, duration: 0.14)
        ]))
        emitRing(scaleTo: 1.6, duration: 1.1)
    }

    /// Biss — der Schwimmer geht deutlich unter.
    func showBite() {
        float.removeAllActions()
        float.run(.sequence([
            .moveBy(x: 0, y: -13, duration: 0.12),
            .moveBy(x: 0, y: 9, duration: 0.2),
            .moveBy(x: 0, y: -7, duration: 0.16),
            .moveBy(x: 0, y: 11, duration: 0.22)
        ]))
        emitRing(scaleTo: 2.6, duration: 1.0)
        emitRing(scaleTo: 3.4, duration: 1.5)
    }

    /// Setzt das Aussehen passend zum gewählten Köder.
    ///
    /// Jeder Köder sieht anders aus und bewegt sich anders — der Spinner
    /// dreht sich, der Gummifisch wedelt, der Wurm windet sich. Damit erkennt
    /// man auf dem Wasser, womit man gerade fischt.
    func configure(for bait: Bait) {
        lure.removeAllChildren()
        lure.removeAllActions()

        tip.fillColor = bait.color.skColor

        let shape: SKShapeNode
        switch bait.id {
        case "spinner":
            // Drehendes Blatt an einer Achse.
            shape = SKShapeNode(ellipseOf: CGSize(width: 7, height: 14))
            shape.fillColor = bait.color.skColor
            shape.strokeColor = ColorSpec(0x6E6242).skColor
            shape.run(.repeatForever(.sequence([
                .scaleX(to: 0.2, duration: 0.22),
                .scaleX(to: 1.0, duration: 0.22)
            ])))

        case "spoon":
            // Trudelndes Metall: kippt hin und her und blitzt auf.
            shape = SKShapeNode(ellipseOf: CGSize(width: 9, height: 16))
            shape.fillColor = bait.color.skColor
            shape.strokeColor = ColorSpec(0x8A939A).skColor
            shape.run(.repeatForever(.sequence([
                .group([.rotate(byAngle: .pi, duration: 0.5), .fadeAlpha(to: 0.55, duration: 0.25)]),
                .fadeAlpha(to: 1, duration: 0.25)
            ])))

        case "wobbler":
            // Länglicher Körper mit unruhigem Lauf.
            shape = SKShapeNode(ellipseOf: CGSize(width: 20, height: 9))
            shape.fillColor = bait.color.skColor
            shape.strokeColor = ColorSpec(0x5E3A2C).skColor
            shape.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.35, duration: 0.28),
                .rotate(toAngle: -0.35, duration: 0.28)
            ])))

        case "softbait":
            // Schaufelschwanz, der wedelt.
            shape = SKShapeNode(ellipseOf: CGSize(width: 18, height: 8))
            shape.fillColor = bait.color.skColor
            shape.strokeColor = .clear
            let tail = SKShapeNode(ellipseOf: CGSize(width: 7, height: 9))
            tail.fillColor = bait.color.skColor(alpha: 0.75)
            tail.strokeColor = .clear
            tail.position = CGPoint(x: -11, y: 0)
            tail.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.6, duration: 0.2),
                .rotate(toAngle: -0.6, duration: 0.2)
            ])))
            shape.addChild(tail)

        case "fly":
            // Winzig, mit zwei Flügeln.
            shape = SKShapeNode(circleOfRadius: 3.5)
            shape.fillColor = bait.color.skColor
            shape.strokeColor = .clear
            for side in [CGFloat(1), CGFloat(-1)] {
                let wing = SKShapeNode(ellipseOf: CGSize(width: 9, height: 4))
                wing.fillColor = SKColor(white: 1, alpha: 0.5)
                wing.strokeColor = .clear
                wing.position = CGPoint(x: -1, y: 3 * side)
                wing.zRotation = 0.3 * side
                shape.addChild(wing)
            }

        case "red_october":
            // Großes rotes Blech, das im Wechsel aufblitzt. Deutlich größer
            // als jeder andere Köder — man sieht ihn im Wasser stehen.
            shape = SKShapeNode(ellipseOf: CGSize(width: 13, height: 26))
            shape.fillColor = bait.color.skColor
            shape.strokeColor = Palette.gold.skColor
            shape.lineWidth = 1.5
            shape.glowWidth = 3

            let star = SKShapeNode(circleOfRadius: 3.5)
            star.fillColor = Palette.gold.skColor
            star.strokeColor = .clear
            shape.addChild(star)

            // Der Blitz: kurz hell, dann lange dunkel — wie ein Leuchtfeuer.
            shape.run(.repeatForever(.sequence([
                .group([.scaleX(to: 0.25, duration: 0.35),
                        .fadeAlpha(to: 1.0, duration: 0.35)]),
                .group([.scaleX(to: 1.0, duration: 0.35),
                        .fadeAlpha(to: 0.7, duration: 0.35)]),
                .wait(forDuration: 0.5)
            ])))

        case "moonbait":
            // Blasse Perle mit Leuchten.
            shape = SKShapeNode(circleOfRadius: 6)
            shape.fillColor = bait.color.skColor
            shape.strokeColor = SKColor(white: 1, alpha: 0.7)
            shape.glowWidth = 6
            shape.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.55, duration: 1.1),
                .fadeAlpha(to: 1.0, duration: 1.1)
            ])))

        default:
            // Naturköder: kleiner weicher Körper, der sich windet.
            shape = SKShapeNode(ellipseOf: CGSize(width: 13, height: 6))
            shape.fillColor = bait.color.skColor
            shape.strokeColor = .clear
            shape.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.5, duration: 0.6),
                .rotate(toAngle: -0.5, duration: 0.6)
            ])))
        }

        shape.alpha = 0.85
        lure.addChild(shape)
    }

    /// Ruck an der straffen Schnur, wenn das Boot am Ende der Leine zieht.
    func showTug() {
        float.removeAllActions()
        float.run(.sequence([
            .moveBy(x: 0, y: -4, duration: 0.08),
            .moveBy(x: 0, y: 4, duration: 0.12)
        ]))
        emitRing(scaleTo: 1.4, duration: 0.8)
    }

    /// Einschlag beim Auftreffen auf das Wasser.
    func showSplash() {
        emitRing(scaleTo: 3.0, duration: 1.2)
        emitRing(scaleTo: 2.0, duration: 0.8)
    }

    private func emitRing(scaleTo scale: CGFloat, duration: TimeInterval) {
        let ring = SKShapeNode(circleOfRadius: 10)
        ring.strokeColor = SKColor(white: 1, alpha: 0.5)
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.setScale(0.25)
        rings.addChild(ring)

        ring.run(.sequence([
            .group([
                .scale(to: scale, duration: duration),
                .fadeOut(withDuration: duration)
            ]),
            .removeFromParent()
        ]))
    }
}

/// Die Schnur zwischen Rutenspitze und Schwimmer. Hängt leicht durch und
/// spannt sich im Drill.
final class FishingLineNode: SKNode {

    private let line = SKShapeNode()

    override init() {
        super.init()
        line.strokeColor = SKColor(white: 1, alpha: 0.55)
        line.lineWidth = 1.4
        addChild(line)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) wird nicht verwendet")
    }

    /// - Parameter tension: 0…1. Bei hoher Spannung wird die Schnur gerade und rot.
    func update(from start: CGPoint, to end: CGPoint, tension: CGFloat) {
        let path = CGMutablePath()
        path.move(to: start)

        // Der Durchhang liegt quer zur Schnur, nicht stur nach unten: So bleibt
        // der Bogen bei jeder Wurfrichtung gleich glaubwürdig. Lange Schnur
        // hängt tiefer durch, straffe Schnur wird zur Geraden.
        let delta = CGVector(dx: end.x - start.x, dy: end.y - start.y)
        let length = hypot(delta.dx, delta.dy)
        let slack = 1 - min(1, tension)
        let sag = min(46, length * 0.16) * slack

        if length > 1 {
            let normal = CGVector(dx: -delta.dy / length, dy: delta.dx / length)
            let control = CGPoint(x: (start.x + end.x) / 2 + normal.dx * sag,
                                  y: (start.y + end.y) / 2 + normal.dy * sag - sag * 0.5)
            path.addQuadCurve(to: end, control: control)
        } else {
            path.addLine(to: end)
        }

        line.path = path

        // Straffe Schnur wird heller, dünner und bekommt einen warmen Ton —
        // sichtbar, ohne dass es nach Fehler aussieht.
        if tension > 0.8 {
            line.strokeColor = Palette.vermilion.skColor(alpha: 0.9)
            line.lineWidth = 2.2
        } else if tension > 0.45 {
            line.strokeColor = ColorSpec(0xF0D9A8).skColor(alpha: 0.8)
            line.lineWidth = 1.8
        } else {
            line.strokeColor = SKColor(white: 1, alpha: 0.5)
            line.lineWidth = 1.4
        }
    }

    func clear() {
        line.path = nil
    }
}
