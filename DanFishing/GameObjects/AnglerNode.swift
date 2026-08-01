import SpriteKit

/// Dan zu Fuß, von oben gesehen — für den Gebirgsbach, wo kein Boot hinkommt.
///
/// Am Ufer sieht man Schritte im Gras, im Wasser stehen die Beine in der
/// Strömung und es zieht eine Bugwelle um die Hüfte. Beides zusammen ist der
/// Unterschied zum Boot: Man merkt, dass man selbst im Bach steht.
final class AnglerNode: SKNode, ActorNode {

    private let shadow = SKSpriteNode()
    private let legs = SKNode()
    private let leftLeg = SKShapeNode()
    private let rightLeg = SKShapeNode()
    private let body = SKShapeNode()
    private let pack = SKShapeNode()
    private let hat = SKShapeNode()
    private let rod = SKShapeNode()

    /// Wellenring um die Hüfte, sobald er im Wasser steht.
    private let bowWave = SKShapeNode(circleOfRadius: 20)

    /// Am Bach hängt dieselbe Laterne am Rucksack.
    private let lantern = LanternNode()

    private var stepPhase: CGFloat = 0
    private var idlePhase: CGFloat = 0
    private var splashTimer: CGFloat = 0

    /// Steht die Figur gerade im Wasser? Setzt die Szene aus der Karte.
    var isWading: Bool = false

    private var appliedUpgradeLevel = -1

    override init() {
        super.init()
        buildShadow()
        buildWave()
        buildLegs()
        buildBody()
        buildRod()

        // Sie baumelt hinten am Rucksack, damit sie die Rutenhand frei lässt.
        lantern.position = CGPoint(x: -14, y: -10)
        lantern.zRotation = -1.4
        lantern.zPosition = 6
        addChild(lantern)
    }

    func setLantern(level: Int) {
        lantern.configure(level: level)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: - Aufbau

    private func buildShadow() {
        if let texture = TextureFactory.softDisc(color: UIColor(white: 0, alpha: 0.35)) {
            shadow.texture = texture
            shadow.size = CGSize(width: 54, height: 44)
            shadow.alpha = 0.45
            shadow.position = CGPoint(x: -4, y: -5)
            shadow.zPosition = -1
            addChild(shadow)
        }
    }

    private func buildWave() {
        bowWave.strokeColor = SKColor(white: 1, alpha: 0.55)
        bowWave.fillColor = .clear
        bowWave.lineWidth = 2
        bowWave.alpha = 0
        bowWave.zPosition = 0
        addChild(bowWave)
    }

    /// Zwei Beine, die beim Gehen gegengleich ausschlagen. Blickrichtung ist
    /// wie beim Boot die x-Achse.
    private func buildLegs() {
        for (leg, side) in [(leftLeg, CGFloat(1)), (rightLeg, CGFloat(-1))] {
            leg.path = CGPath(roundedRect: CGRect(x: -5, y: -4, width: 17, height: 8),
                              cornerWidth: 4, cornerHeight: 4, transform: nil)
            leg.fillColor = ColorSpec(0x4A5B52).skColor
            leg.strokeColor = ColorSpec(0x2E3A34).skColor
            leg.lineWidth = 1.2
            leg.position = CGPoint(x: 0, y: 6 * side)
            legs.addChild(leg)
        }
        legs.zPosition = 1
        addChild(legs)
    }

    private func buildBody() {
        body.path = CGPath(roundedRect: CGRect(x: -9, y: -12, width: 18, height: 24),
                           cornerWidth: 8, cornerHeight: 8, transform: nil)
        body.fillColor = ColorSpec(0x3C4A5A).skColor
        body.strokeColor = ColorSpec(0x27303B).skColor
        body.lineWidth = 1.5
        body.zPosition = 2
        addChild(body)

        // Rucksack auf dem Rücken — von oben das, was man am ehesten sieht.
        pack.path = CGPath(roundedRect: CGRect(x: -16, y: -8, width: 11, height: 16),
                           cornerWidth: 4, cornerHeight: 4, transform: nil)
        pack.fillColor = ColorSpec(0x7A5B34).skColor
        pack.strokeColor = ColorSpec(0x4E3823).skColor
        pack.lineWidth = 1.2
        pack.zPosition = 3
        addChild(pack)

        // Strohhut wie im Boot, damit man dieselbe Figur wiedererkennt.
        hat.path = CGPath(ellipseIn: CGRect(x: -13, y: -13, width: 26, height: 26), transform: nil)
        hat.fillColor = ColorSpec(0xD9C48A).skColor
        hat.strokeColor = ColorSpec(0xA98F55).skColor
        hat.lineWidth = 1.5
        hat.zPosition = 4
        addChild(hat)

        for index in 0..<3 {
            let ring = SKShapeNode(circleOfRadius: CGFloat(4 + index * 4))
            ring.strokeColor = ColorSpec(0xB59A62).skColor(alpha: 0.55)
            ring.lineWidth = 1
            ring.fillColor = .clear
            hat.addChild(ring)
        }

        let hatTop = SKShapeNode(circleOfRadius: 5)
        hatTop.fillColor = ColorSpec(0xC7AE74).skColor
        hatTop.strokeColor = .clear
        hatTop.zPosition = 1
        hat.addChild(hatTop)
    }

    private func buildRod() {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 54, y: 0))
        rod.path = path
        rod.strokeColor = ColorSpec(0x7A5B34).skColor
        rod.lineWidth = 2
        rod.position = CGPoint(x: 6, y: 5)
        rod.zRotation = 0.5
        rod.zPosition = 5
        addChild(rod)
    }

    // MARK: - Darstellung

    var rodTipPosition: CGPoint {
        let local = CGPoint(x: rod.position.x + cos(rod.zRotation) * 54,
                            y: rod.position.y + sin(rod.zRotation) * 54)
        return convert(local, to: parent ?? self)
    }

    /// Stufe der Wathose: Stiefel, Wathose, Brustwathose. Man sieht sie an den
    /// Beinen — dunkles Gummi statt Hose, und ab der Brustwathose auch am Rumpf.
    func applyUpgrade(level: Int) {
        guard level != appliedUpgradeLevel else { return }
        appliedUpgradeLevel = level

        let legColor: ColorSpec
        switch level {
        case 0: legColor = ColorSpec(0x4A5B52)   // nur Hose
        case 1: legColor = ColorSpec(0x2F3A36)   // Gummistiefel
        case 2: legColor = ColorSpec(0x384A44)   // Wathose
        default: legColor = ColorSpec(0x2B3D3A)  // Brustwathose
        }
        leftLeg.fillColor = legColor.skColor
        rightLeg.fillColor = legColor.skColor

        // Die Brustwathose geht bis über den Bauch.
        body.fillColor = level >= 3
            ? ColorSpec(0x33453F).skColor
            : ColorSpec(0x3C4A5A).skColor
    }

    func update(deltaTime: CGFloat, effort: CGFloat, speed: CGFloat, night: CGFloat) {
        idlePhase += deltaTime

        // Schritttempo hängt an der Geschwindigkeit; im Wasser geht es zäher.
        let drag: CGFloat = isWading ? 0.6 : 1.0
        stepPhase += deltaTime * (2.2 + speed / 26) * drag

        let swing = sin(stepPhase) * 7 * effort * drag
        leftLeg.position = CGPoint(x: swing, y: 6)
        rightLeg.position = CGPoint(x: -swing, y: -6)

        // Beim Gehen wiegt sich der Oberkörper leicht.
        let sway = sin(stepPhase) * 0.06 * effort
        body.zRotation = sway
        pack.zRotation = sway
        hat.zRotation = sway * 0.5
        hat.position = CGPoint(x: sin(stepPhase - 0.6) * 0.8 * effort,
                               y: sin(idlePhase * 1.3) * 0.5)

        // Atmen im Stand.
        let breath = 1 + sin(idlePhase * 1.6) * 0.015
        body.yScale = breath
        body.xScale = 2 - breath

        if isWading {
            // Im Wasser verschwinden die Beine, dafür steht eine Welle um die
            // Hüfte — und beim Waten schwappt es sichtbar.
            legs.alpha = 0.35
            shadow.alpha = 0.2
            bowWave.alpha = 0.35 + min(0.4, speed / 90)
            bowWave.xScale = 1 + sin(idlePhase * 2.4) * 0.05

            splashTimer -= deltaTime * (0.4 + speed / 40)
            if splashTimer <= 0 && effort > 0.15 {
                splashTimer = 0.45
                spawnSplash()
            }
        } else {
            legs.alpha = 1
            shadow.alpha = 0.45
            bowWave.alpha = 0
        }
    }

    func setCastPose(_ power: CGFloat?, direction: CGVector?, heading: CGFloat) {
        let target: CGFloat
        if let direction, hypot(direction.dx, direction.dy) > 0.001 {
            let worldAngle = atan2(direction.dy, direction.dx)
            target = worldAngle - heading - 0.9 * (power ?? 0)
        } else {
            target = 0.5
        }
        rod.zRotation += MovementController.angleDifference(rod.zRotation, target) * 0.35
    }

    /// Ein Spritzer, der zur Seite wegläuft und verblasst.
    private func spawnSplash() {
        let ring = SKShapeNode(circleOfRadius: 9)
        ring.strokeColor = SKColor(white: 1, alpha: 0.5)
        ring.fillColor = .clear
        ring.lineWidth = 1.6
        ring.position = CGPoint(x: CGFloat.random(in: -10...10),
                                y: CGFloat.random(in: -14...14))
        ring.zPosition = 0
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 2.4, duration: 0.8), .fadeOut(withDuration: 0.8)]),
            .removeFromParent()
        ]))
    }
}
