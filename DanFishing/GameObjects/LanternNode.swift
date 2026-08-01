import SpriteKit

/// Papierlaterne am Boot.
///
/// Sie hängt an einem kurzen Bambusstab über der Bordwand und brennt nur
/// nachts. Das Licht ist bewusst warm und unruhig: eine Kerze hinter Papier
/// flackert, und genau dieses Zittern auf dem Wasser macht die Nachtfahrt aus.
/// Die zweite Ausbaustufe ist eine deutlich größere Laterne — sie leuchtet
/// weiter und hängt tiefer über dem Wasser.
final class LanternNode: SKNode {

    private let pole = SKShapeNode()
    private let body = SKShapeNode()
    private let ribs = SKNode()
    private let flame = SKShapeNode(circleOfRadius: 3)
    private let halo = SKSpriteNode()

    private var flickerPhase: CGFloat = 0
    private var appliedLevel = -1

    /// 0 = nicht gekauft, 1 = kleine Laterne, 2 = große Laterne.
    private(set) var level = 0

    override init() {
        super.init()
        build()
        alpha = 0
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: - Aufbau

    private func build() {
        let polePath = CGMutablePath()
        polePath.move(to: .zero)
        polePath.addLine(to: CGPoint(x: 16, y: 0))
        pole.path = polePath
        pole.strokeColor = ColorSpec(0x6B4E30).skColor
        pole.lineWidth = 2
        pole.lineCap = .round
        pole.zPosition = 1
        addChild(pole)

        // Von oben sieht man den Papierbauch als Kreis mit hellem Kern.
        body.strokeColor = ColorSpec(0x8E3B2A).skColor
        body.lineWidth = 1.5
        body.fillColor = ColorSpec(0xE9C382).skColor
        body.position = CGPoint(x: 16, y: 0)
        body.zPosition = 3
        addChild(body)

        ribs.zPosition = 4
        body.addChild(ribs)

        flame.fillColor = ColorSpec(0xFFF3CE).skColor
        flame.strokeColor = .clear
        flame.zPosition = 5
        flame.blendMode = .add
        body.addChild(flame)

        if let texture = TextureFactory.softDisc(color: UIColor(red: 1.0, green: 0.82, blue: 0.52, alpha: 0.85)) {
            halo.texture = texture
            halo.blendMode = .add
            halo.zPosition = 2
            halo.position = body.position
            addChild(halo)
        }
    }

    // MARK: - Zustand

    /// Setzt die Ausbaustufe. 0 blendet die Laterne ganz aus.
    func configure(level: Int) {
        guard level != appliedLevel else { return }
        appliedLevel = level
        self.level = level

        guard level > 0 else {
            isHidden = true
            return
        }
        isHidden = false

        // Stufe 2 ist die große Laterne: dickerer Bauch, kräftigerer Schein.
        let radius: CGFloat = level >= 2 ? 9 : 6.5
        body.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius,
                                             width: radius * 2, height: radius * 2),
                           transform: nil)

        ribs.removeAllChildren()
        for index in 0..<(level >= 2 ? 3 : 2) {
            let inset = radius * (0.3 + CGFloat(index) * 0.28)
            let rib = SKShapeNode(circleOfRadius: inset)
            rib.strokeColor = ColorSpec(0xC98A5B).skColor(alpha: 0.6)
            rib.lineWidth = 0.8
            rib.fillColor = .clear
            ribs.addChild(rib)
        }

        halo.size = CGSize(width: radius * 11, height: radius * 11)
    }

    /// - Parameters:
    ///   - night: 0…1 — wie dunkel es ist. Bei Tag bleibt die Laterne aus.
    ///   - sway: Bewegung des Bootes, damit die Laterne nachschwingt.
    func update(deltaTime: CGFloat, night: CGFloat, sway: CGFloat) {
        guard level > 0 else { return }

        // Erst in der Dämmerung wird sie angezündet.
        let lit = max(0, min(1, (night - 0.2) / 0.5))
        alpha += (lit - alpha) * min(1, deltaTime * 2)
        isHidden = alpha < 0.02

        guard !isHidden else { return }

        // Zwei ungleiche Sinuskurven ergeben ein Flackern, das sich nicht
        // hörbar wiederholt.
        flickerPhase += deltaTime * 6.5
        let flicker = 0.86
            + sin(flickerPhase) * 0.06
            + sin(flickerPhase * 2.7 + 1.1) * 0.045

        halo.alpha = flicker * (0.55 + CGFloat(level) * 0.12)
        halo.setScale(flicker)
        flame.setScale(0.8 + flicker * 0.3)

        // Die Laterne pendelt der Bootsbewegung hinterher.
        zRotation += (sway * -0.35 - zRotation) * min(1, deltaTime * 3)
    }
}
