import SpriteKit

/// Ruderboot mit Angler, aus Formen gezeichnet. Die Ruder bewegen sich nur,
/// wenn wirklich gerudert wird — das gibt der Fahrt Gewicht.
final class BoatNode: SKNode {

    private let hull = SKShapeNode()
    private let hullInner = SKShapeNode()
    private let leftOar = SKShapeNode()
    private let rightOar = SKShapeNode()
    private let angler = SKNode()
    private let anglerBody = SKShapeNode()
    private let hat = SKShapeNode()
    private let rod = SKShapeNode()
    private let shadow = SKSpriteNode()

    private var rowPhase: CGFloat = 0
    private var idlePhase: CGFloat = 0

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
        hull.strokeColor = ColorSpec(0x4E3823).skColor
        hull.lineWidth = 2.5
        hull.zPosition = 2

        // Holzmaserung statt einfarbiger Fläche.
        if let wood = TextureFactory.woodGrain(base: ColorSpec(0x8A6A46).skColor,
                                               dark: ColorSpec(0x3E2C1B).skColor) {
            hull.fillTexture = wood
            hull.fillColor = .white
        } else {
            hull.fillColor = ColorSpec(0x8A6A46).skColor
        }
        addChild(hull)

        let innerPath = CGMutablePath()
        innerPath.addEllipse(in: CGRect(x: -34, y: -13, width: 74, height: 26))
        hullInner.path = innerPath
        hullInner.fillColor = ColorSpec(0xC49A63).skColor
        hullInner.strokeColor = .clear
        hullInner.zPosition = 3
        hull.addChild(hullInner)
    }

    /// Die Riemen sitzen mittschiffs in den Dollen und ragen quer über die
    /// Bordwand — vorher lagen sie am Heck, was am Ruderboot falsch aussieht.
    /// Gezeichnet wird in Bootskoordinaten: x ist längs (Bug rechts), y quer.
    private func buildOars() {
        for (oar, side) in [(leftOar, CGFloat(1)), (rightOar, CGFloat(-1))] {
            let path = CGMutablePath()

            // Griff im Boot, Schaft nach außen über die Bordwand.
            path.move(to: CGPoint(x: 10, y: 0))
            path.addLine(to: CGPoint(x: -6, y: 42 * side))

            // Blatt am äußeren Ende, quer zum Schaft.
            let blade = CGMutablePath()
            blade.addEllipse(in: CGRect(x: -13, y: 40 * side - (side > 0 ? 0 : 14),
                                        width: 15, height: 14))
            path.addPath(blade)

            oar.path = path
            oar.strokeColor = ColorSpec(0x6B4E30).skColor
            oar.fillColor = ColorSpec(0x8A6A46).skColor
            oar.lineWidth = 3.5
            oar.lineCap = .round

            // Drehpunkt ist die Dolle mittschiffs.
            oar.position = CGPoint(x: 0, y: 16 * side)
            oar.zPosition = 4
            addChild(oar)
        }
    }

    private func buildAngler() {
        // Körper
        anglerBody.path = CGPath(roundedRect: CGRect(x: -8, y: -11, width: 16, height: 22),
                                 cornerWidth: 7, cornerHeight: 7, transform: nil)
        anglerBody.fillColor = ColorSpec(0x3C4A5A).skColor
        anglerBody.strokeColor = ColorSpec(0x27303B).skColor
        anglerBody.lineWidth = 1.5
        anglerBody.position = CGPoint(x: 2, y: 0)
        angler.addChild(anglerBody)

        // Strohhut von oben gesehen
        hat.path = CGPath(ellipseIn: CGRect(x: -13, y: -13, width: 26, height: 26), transform: nil)
        hat.fillColor = ColorSpec(0xD9C48A).skColor
        hat.strokeColor = ColorSpec(0xA98F55).skColor
        hat.lineWidth = 1.5
        hat.position = CGPoint(x: 2, y: 0)
        hat.zPosition = 1
        angler.addChild(hat)

        // Geflecht des Strohhuts
        for index in 0..<3 {
            let radius = CGFloat(4 + index * 4)
            let ring = SKShapeNode(circleOfRadius: radius)
            ring.strokeColor = ColorSpec(0xB59A62).skColor(alpha: 0.55)
            ring.lineWidth = 1
            ring.fillColor = .clear
            ring.zPosition = 2
            hat.addChild(ring)
        }

        let hatTop = SKShapeNode(circleOfRadius: 5)
        hatTop.fillColor = ColorSpec(0xC7AE74).skColor
        hatTop.strokeColor = .clear
        hatTop.zPosition = 3
        hat.addChild(hatTop)

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
        idlePhase += deltaTime

        // Ruderschlag: Die Blätter fahren nach vorn, tauchen ein und ziehen
        // nach achtern durch. Beide Riemen laufen gegengleich um ihre Dolle.
        rowPhase += deltaTime * (1.6 + speed / 90)
        let swing = sin(rowPhase) * 0.55 * rowing
        leftOar.zRotation = swing
        rightOar.zRotation = -swing

        // Im Durchzug rutschen die Griffe leicht nach achtern.
        let reach = cos(rowPhase) * 3 * rowing
        leftOar.position = CGPoint(x: -reach, y: 16)
        rightOar.position = CGPoint(x: -reach, y: -16)

        // Das Boot wiegt sich, im Stand ruhig, in Fahrt stärker.
        let bob = sin(rowPhase * 0.55) * (0.025 + rowing * 0.02)
        hull.zRotation = bob
        angler.zRotation = -bob * 0.5

        // Dan atmet und lehnt sich beim Rudern in den Schlag.
        let breath = 1 + sin(idlePhase * 1.6) * 0.015
        anglerBody.yScale = breath
        anglerBody.xScale = 2 - breath
        angler.position = CGPoint(x: -2 - rowing * 2.5 + sin(rowPhase) * 1.6 * rowing, y: 0)

        // Der Hut wippt der Bewegung leicht hinterher.
        hat.position = CGPoint(x: 2 + sin(rowPhase - 0.6) * 0.9 * rowing,
                               y: sin(idlePhase * 1.3) * 0.5)

        shadow.alpha = 0.35 + min(0.25, speed / 400)
    }

    /// Haltung der Rute.
    ///
    /// - Parameters:
    ///   - direction: Wohin die Rute zeigen soll, in Weltkoordinaten. Beim
    ///     Zielen ist das die Wurfrichtung, danach der Schwimmer im Wasser.
    ///     Nil bedeutet Ruhestellung.
    ///   - power: Wurfstärke 0…1; die Rute lädt sich sichtbar nach hinten auf.
    ///
    /// Wichtig ist das Nachführen nach dem Wurf: Sonst schnappt die Rute in
    /// ihre Ruhelage zurück und zeigt plötzlich auf die andere Seite des
    /// Bootes, während die Schnur nach vorn läuft.
    func setCastPose(_ power: CGFloat?, direction: CGVector?, boatHeading: CGFloat) {
        let target: CGFloat

        if let direction, hypot(direction.dx, direction.dy) > 0.001 {
            // Die Rute steckt im Boot, also wird die Richtung in dessen
            // Drehung umgerechnet.
            let worldAngle = atan2(direction.dy, direction.dx)
            target = worldAngle - boatHeading - 0.9 * (power ?? 0)
        } else {
            target = 0.5   // Ruhestellung, schräg nach vorn
        }

        rod.zRotation += BoatController.angleDifference(rod.zRotation, target) * 0.35
    }
}
