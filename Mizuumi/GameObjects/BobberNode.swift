import SpriteKit

/// Schwimmer samt Schnur. Zeigt durch seine Bewegung an, was gerade passiert:
/// ruhiges Wippen beim Warten, kurzes Zucken beim Zupfen, Abtauchen beim Biss.
final class BobberNode: SKNode {

    private let float = SKShapeNode(circleOfRadius: 9)
    private let tip = SKShapeNode(circleOfRadius: 5)
    private let rings = SKNode()
    private var bobPhase: CGFloat = 0

    override init() {
        super.init()

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
        float.position = CGPoint(x: 0, y: sin(bobPhase) * 1.6)
        tip.position = CGPoint(x: 0, y: 4 + sin(bobPhase) * 1.6)
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

        let sag = 26 * (1 - min(1, tension))
        let control = CGPoint(x: (start.x + end.x) / 2,
                              y: (start.y + end.y) / 2 - sag)
        path.addQuadCurve(to: end, control: control)

        line.path = path
        if tension > 0.8 {
            line.strokeColor = Palette.vermilion.skColor(alpha: 0.85)
            line.lineWidth = 2.0
        } else {
            line.strokeColor = SKColor(white: 1, alpha: 0.55)
            line.lineWidth = 1.4
        }
    }

    func clear() {
        line.path = nil
    }
}
