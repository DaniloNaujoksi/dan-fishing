import SpriteKit

/// Ruderboot mit Angler, aus Formen gezeichnet. Die Ruder bewegen sich nur,
/// wenn wirklich gerudert wird — das gibt der Fahrt Gewicht.
final class BoatNode: SKNode {

    private let hull = SKShapeNode()
    private let hullInner = SKShapeNode()
    private let leftOar = SKShapeNode()
    private let rightOar = SKShapeNode()
    private let angler = SKNode()
    private let rod = SKShapeNode()
    private let shadow = SKSpriteNode()

    private var rowPhase: CGFloat = 0

    override init() {
        super.init()
        buildShadow()
        buildHull()
        buildOars()
        buildAngler()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: - Aufbau

    private func buildShadow() {
        if let texture = TextureFactory.softDisc(color: UIColor(white: 0, alpha: 0.35)) {
            shadow.texture = texture
            shadow.size = CGSize(width: 150, height: 90)
            shadow.alpha = 0.5
            shadow.position = CGPoint(x: 0, y: -6)
            shadow.zPosition = -1
            addChild(shadow)
        }
    }

    private func buildHull() {
        // Schmaler Kahn, Spitze zeigt nach rechts (Blickrichtung 0).
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 52, y: 0))
        path.addCurve(to: CGPoint(x: -6, y: 22),
                      control1: CGPoint(x: 40, y: 16),
                      control2: CGPoint(x: 18, y: 23))
        path.addLine(to: CGPoint(x: -42, y: 16))
        path.addCurve(to: CGPoint(x: -42, y: -16),
                      control1: CGPoint(x: -52, y: 6),
                      control2: CGPoint(x: -52, y: -6))
        path.addLine(to: CGPoint(x: -6, y: -22))
        path.addCurve(to: CGPoint(x: 52, y: 0),
                      control1: CGPoint(x: 18, y: -23),
                      control2: CGPoint(x: 40, y: -16))
        path.closeSubpath()

        hull.path = path
        hull.fillColor = ColorSpec(0x8A6A46).skColor
        hull.strokeColor = ColorSpec(0x4E3823).skColor
        hull.lineWidth = 2.5
        hull.zPosition = 2
        addChild(hull)

        let innerPath = CGMutablePath()
        innerPath.addEllipse(in: CGRect(x: -34, y: -13, width: 74, height: 26))
        hullInner.path = innerPath
        hullInner.fillColor = ColorSpec(0xC49A63).skColor
        hullInner.strokeColor = .clear
        hullInner.zPosition = 3
        hull.addChild(hullInner)
    }

    private func buildOars() {
        for (oar, side) in [(leftOar, CGFloat(1)), (rightOar, CGFloat(-1))] {
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: -46, y: 0))
            // Blatt am Ende
            path.addEllipse(in: CGRect(x: -60, y: -5, width: 16, height: 10))

            oar.path = path
            oar.strokeColor = ColorSpec(0x6B4E30).skColor
            oar.fillColor = ColorSpec(0x6B4E30).skColor
            oar.lineWidth = 3
            oar.position = CGPoint(x: -4, y: 18 * side)
            oar.zRotation = side * 0.5
            oar.zPosition = 4
            addChild(oar)
        }
    }

    private func buildAngler() {
        // Körper
        let body = SKShapeNode(rectOf: CGSize(width: 16, height: 22), cornerRadius: 7)
        body.fillColor = ColorSpec(0x3C4A5A).skColor
        body.strokeColor = ColorSpec(0x27303B).skColor
        body.lineWidth = 1.5
        body.position = CGPoint(x: 2, y: 0)
        angler.addChild(body)

        // Strohhut von oben gesehen
        let hat = SKShapeNode(circleOfRadius: 13)
        hat.fillColor = ColorSpec(0xD9C48A).skColor
        hat.strokeColor = ColorSpec(0xA98F55).skColor
        hat.lineWidth = 1.5
        hat.position = CGPoint(x: 2, y: 0)
        hat.zPosition = 1
        angler.addChild(hat)

        let hatTop = SKShapeNode(circleOfRadius: 5)
        hatTop.fillColor = ColorSpec(0xC7AE74).skColor
        hatTop.strokeColor = .clear
        hatTop.position = hat.position
        hatTop.zPosition = 2
        angler.addChild(hatTop)

        // Rute: zeigt schräg nach vorn und wird beim Wurf mitbewegt.
        let rodPath = CGMutablePath()
        rodPath.move(to: .zero)
        rodPath.addLine(to: CGPoint(x: 54, y: 0))
        rod.path = rodPath
        rod.strokeColor = ColorSpec(0x7A5B34).skColor
        rod.lineWidth = 2
        rod.position = CGPoint(x: 8, y: 6)
        rod.zRotation = 0.5
        rod.zPosition = 3
        angler.addChild(rod)

        angler.position = CGPoint(x: -2, y: 0)
        angler.zPosition = 5
        addChild(angler)
    }

    // MARK: - Darstellung

    /// Spitze der Rute in Weltkoordinaten — dort beginnt die Schnur.
    var rodTipPosition: CGPoint {
        let local = CGPoint(x: rod.position.x + cos(rod.zRotation) * 54,
                            y: rod.position.y + sin(rod.zRotation) * 54)
        let inAngler = CGPoint(x: angler.position.x + local.x, y: angler.position.y + local.y)
        return convert(inAngler, to: parent ?? self)
    }

    /// Wird jeden Frame aufgerufen.
    func update(deltaTime: CGFloat, rowing: CGFloat, speed: CGFloat) {
        // Ruderschlag
        rowPhase += deltaTime * (1.6 + speed / 90)
        let swing = sin(rowPhase) * 0.5 * rowing
        leftOar.zRotation = 0.5 + swing
        rightOar.zRotation = -0.5 - swing

        // Das Boot wiegt sich leicht, auch im Stand.
        let bob = sin(rowPhase * 0.55) * 0.03
        hull.zRotation = bob
        angler.zRotation = -bob * 0.5

        shadow.alpha = 0.35 + min(0.25, speed / 400)
    }

    /// Winkel der Rute beim Auswerfen (0…1 Wurfstärke).
    func setCastPose(_ power: CGFloat?) {
        if let power {
            rod.zRotation = 0.5 + 0.8 * power
        } else {
            rod.zRotation = 0.5
        }
    }
}
