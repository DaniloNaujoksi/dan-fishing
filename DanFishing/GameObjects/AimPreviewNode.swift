import SpriteKit

/// Zielhilfe beim Auswerfen.
///
/// Solange der Finger zieht, zeigt sie als gestrichelte Bahn, wohin der Köder
/// fliegt, und markiert die Stelle, an der er aufkommt. Damit ist der Wurf
/// planbar, statt ein Glücksspiel zu sein.
final class AimPreviewNode: SKNode {

    private let trajectory = SKShapeNode()
    private let landingRing = SKShapeNode(circleOfRadius: 22)
    private let landingDot = SKShapeNode(circleOfRadius: 5)
    private let rangeRing = SKShapeNode(circleOfRadius: 100)

    override init() {
        super.init()

        // Reichweitenkreis: zeigt, wie weit die Rute überhaupt trägt.
        rangeRing.strokeColor = SKColor(white: 1, alpha: 0.16)
        rangeRing.fillColor = .clear
        rangeRing.lineWidth = 1.5
        rangeRing.isAntialiased = true
        addChild(rangeRing)

        trajectory.strokeColor = SKColor(white: 1, alpha: 0.75)
        trajectory.lineWidth = 2.4
        trajectory.lineCap = .round
        trajectory.fillColor = .clear
        addChild(trajectory)

        landingRing.strokeColor = Palette.paper.skColor(alpha: 0.9)
        landingRing.fillColor = Palette.paper.skColor(alpha: 0.12)
        landingRing.lineWidth = 2
        addChild(landingRing)

        landingDot.fillColor = Palette.paper.skColor(alpha: 0.95)
        landingDot.strokeColor = .clear
        addChild(landingDot)

        alpha = 0
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) wird nicht verwendet")
    }

    func show() {
        guard isHidden else { return }
        isHidden = false
        removeAllActions()
        run(.fadeAlpha(to: 1, duration: 0.12))
    }

    /// Sofort weg. Kein Ausblenden: Sobald der Köder fliegt, hat die Zielhilfe
    /// nichts mehr auf dem Wasser zu suchen — eine nachhängende gestrichelte
    /// Linie unter der Schnur sieht aus wie ein Fehler.
    func hide() {
        guard !isHidden else { return }
        removeAllActions()
        alpha = 0
        isHidden = true
        trajectory.path = nil
    }

    /// - Parameters:
    ///   - blocked: true, wenn der Köder dort auf Land käme.
    ///   - maxRange: Reichweite der Rute für den äußeren Kreis.
    func update(from origin: CGPoint, to target: CGPoint, maxRange: CGFloat, blocked: Bool) {
        rangeRing.position = origin
        rangeRing.setScale(maxRange / 100)

        // Gestrichelte Bahn mit leichtem Bogen — sie soll wie eine Flugkurve
        // aussehen, nicht wie ein Lineal.
        let delta = CGVector(dx: target.x - origin.x, dy: target.y - origin.y)
        let length = hypot(delta.dx, delta.dy)
        let path = CGMutablePath()

        if length > 1 {
            let normal = CGVector(dx: -delta.dy / length, dy: delta.dx / length)
            let bow = min(60, length * 0.13)
            let control = CGPoint(x: (origin.x + target.x) / 2 + normal.dx * bow,
                                  y: (origin.y + target.y) / 2 + normal.dy * bow)
            path.move(to: origin)
            path.addQuadCurve(to: target, control: control)
        } else {
            path.move(to: origin)
            path.addLine(to: target)
        }

        let dashed = path.copy(dashingWithPhase: 0, lengths: [12, 10])
        trajectory.path = dashed

        landingRing.position = target
        landingDot.position = target

        let tint = blocked ? Palette.vermilion.skColor : Palette.paper.skColor
        trajectory.strokeColor = tint.withAlphaComponent(blocked ? 0.85 : 0.75)
        landingRing.strokeColor = tint.withAlphaComponent(0.9)
        landingRing.fillColor = tint.withAlphaComponent(0.12)
        landingDot.fillColor = tint.withAlphaComponent(0.95)

        // Der Landering pulsiert leicht, damit das Auge ihn sofort findet.
        let pulse = 1 + 0.06 * sin(CGFloat(CACurrentMediaTime()) * 6)
        landingRing.setScale(pulse)
    }
}
