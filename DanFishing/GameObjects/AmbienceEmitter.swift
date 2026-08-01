import SpriteKit

/// Kleines Leben rund um die Kamera: Luftblasen aus der Tiefe, Libellen über
/// dem Schilf, treibende Blätter, Lichtfunkeln auf dem Wasser.
///
/// Alles wird nur im sichtbaren Bereich erzeugt und räumt sich selbst wieder
/// ab — dadurch bleibt die Zahl der Knoten klein, egal wie lange gespielt wird.
final class AmbienceEmitter {

    private unowned let layer: SKNode
    private unowned let map: LakeMap

    private var bubbleTimer: CGFloat = 0
    private var dragonflyTimer: CGFloat = 2
    private var leafTimer: CGFloat = 4
    private var sparkleTimer: CGFloat = 0

    init(layer: SKNode, map: LakeMap) {
        self.layer = layer
        self.map = map
    }

    /// - Parameters:
    ///   - center: Mittelpunkt des sichtbaren Ausschnitts.
    ///   - darkness: 0…1 — nachts blitzt nichts auf dem Wasser.
    func update(deltaTime: CGFloat, center: CGPoint, darkness: CGFloat) {
        bubbleTimer -= deltaTime
        dragonflyTimer -= deltaTime
        leafTimer -= deltaTime
        sparkleTimer -= deltaTime

        if bubbleTimer <= 0 {
            bubbleTimer = CGFloat.random(in: 0.5...1.6)
            spawnBubbles(near: center)
        }

        if dragonflyTimer <= 0 {
            dragonflyTimer = CGFloat.random(in: 6...14)
            spawnDragonfly(near: center)
        }

        if leafTimer <= 0 {
            leafTimer = CGFloat.random(in: 3...8)
            spawnLeaf(near: center)
        }

        if sparkleTimer <= 0 && darkness < 0.5 {
            sparkleTimer = CGFloat.random(in: 0.25...0.7)
            spawnSparkle(near: center, strength: 1 - darkness)
        }
    }

    // MARK: - Einzelne Erscheinungen

    /// Sucht einen Punkt im sichtbaren Bereich, der zur Bedingung passt.
    private func findSpot(near center: CGPoint,
                          radius: CGFloat = 600,
                          matching: (Habitat?) -> Bool) -> CGPoint? {
        for _ in 0..<12 {
            let point = CGPoint(x: center.x + CGFloat.random(in: -radius...radius),
                                y: center.y + CGFloat.random(in: -radius...radius))
            if matching(map.habitat(at: point)) { return point }
        }
        return nil
    }

    /// Blasen steigen dort auf, wo es tief ist oder Totholz liegt.
    private func spawnBubbles(near center: CGPoint) {
        guard let spot = findSpot(near: center, matching: { $0 == .deep || $0 == .sunkenLogs }) else { return }

        let count = Int.random(in: 2...4)
        for index in 0..<count {
            let bubble = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...3.5))
            bubble.strokeColor = SKColor(white: 1, alpha: 0.5)
            bubble.fillColor = SKColor(white: 1, alpha: 0.12)
            bubble.lineWidth = 1
            bubble.position = CGPoint(x: spot.x + CGFloat.random(in: -10...10),
                                      y: spot.y + CGFloat.random(in: -10...10))
            bubble.alpha = 0
            layer.addChild(bubble)

            let rise = Double.random(in: 1.6...2.8)
            bubble.run(.sequence([
                .wait(forDuration: Double(index) * 0.18),
                .fadeAlpha(to: 0.8, duration: 0.2),
                .group([
                    .moveBy(x: CGFloat.random(in: -8...8), y: CGFloat.random(in: 26...48), duration: rise),
                    .sequence([.wait(forDuration: rise * 0.7), .fadeOut(withDuration: rise * 0.3)])
                ]),
                .removeFromParent()
            ]))
        }
    }

    /// Libellen schwirren über Schilf und Seerosen und halten kurz inne.
    private func spawnDragonfly(near center: CGPoint) {
        guard let spot = findSpot(near: center, matching: { $0 == .reeds || $0 == .lilies }) else { return }

        let body = SKShapeNode(ellipseOf: CGSize(width: 12, height: 3))
        body.fillColor = ColorSpec(0x5C86A0).skColor
        body.strokeColor = .clear

        for side in [CGFloat(1), CGFloat(-1)] {
            let wing = SKShapeNode(ellipseOf: CGSize(width: 11, height: 4))
            wing.fillColor = SKColor(white: 1, alpha: 0.45)
            wing.strokeColor = .clear
            wing.position = CGPoint(x: 1, y: 2.5 * side)
            body.addChild(wing)

            // Flügelschlag: viel schneller, als man ihn einzeln sieht.
            wing.run(.repeatForever(.sequence([
                .scaleY(to: 0.3, duration: 0.05),
                .scaleY(to: 1.0, duration: 0.05)
            ])))
        }

        body.position = spot
        body.alpha = 0
        body.zPosition = 5
        layer.addChild(body)

        // Ein paar kurze Sprünge mit Pausen dazwischen — so fliegen Libellen.
        var actions: [SKAction] = [.fadeAlpha(to: 0.9, duration: 0.3)]
        for _ in 0..<Int.random(in: 3...5) {
            let hop = CGPoint(x: CGFloat.random(in: -90...90), y: CGFloat.random(in: -70...70))
            actions.append(.group([
                .moveBy(x: hop.x, y: hop.y, duration: 0.5),
                .rotate(toAngle: atan2(hop.y, hop.x), duration: 0.2)
            ]))
            actions.append(.wait(forDuration: Double.random(in: 0.4...1.4)))
        }
        actions.append(.fadeOut(withDuration: 0.6))
        actions.append(.removeFromParent())
        body.run(.sequence(actions))
    }

    /// Ein Ahornblatt treibt über die Oberfläche.
    private func spawnLeaf(near center: CGPoint) {
        guard let spot = findSpot(near: center, matching: { $0 != nil }) else { return }

        let leaf = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 7))
        path.addQuadCurve(to: CGPoint(x: 6, y: 0), control: CGPoint(x: 6, y: 5))
        path.addQuadCurve(to: CGPoint(x: 0, y: -7), control: CGPoint(x: 6, y: -5))
        path.addQuadCurve(to: CGPoint(x: -6, y: 0), control: CGPoint(x: -6, y: -5))
        path.addQuadCurve(to: CGPoint(x: 0, y: 7), control: CGPoint(x: -6, y: 5))
        path.closeSubpath()

        leaf.path = path
        leaf.fillColor = Bool.random() ? Palette.maple.skColor(alpha: 0.85)
                                       : ColorSpec(0xC98A3C).skColor(alpha: 0.85)
        leaf.strokeColor = .clear
        leaf.position = spot
        leaf.zRotation = CGFloat.random(in: 0..<(.pi * 2))
        leaf.alpha = 0
        layer.addChild(leaf)

        let drift = CGVector(dx: CGFloat.random(in: -60...60), dy: CGFloat.random(in: -60...60))
        leaf.run(.sequence([
            .fadeAlpha(to: 0.9, duration: 1.0),
            .group([
                .moveBy(x: drift.dx, y: drift.dy, duration: 16),
                .rotate(byAngle: CGFloat.random(in: -1.5...1.5), duration: 16),
                .sequence([.wait(forDuration: 12), .fadeOut(withDuration: 4)])
            ]),
            .removeFromParent()
        ]))
    }

    /// Kurzes Glitzern, wo sich Licht auf einer Welle bricht.
    private func spawnSparkle(near center: CGPoint, strength: CGFloat) {
        guard let spot = findSpot(near: center, radius: 500, matching: { $0 != nil }) else { return }

        let sparkle = SKShapeNode(ellipseOf: CGSize(width: CGFloat.random(in: 10...26), height: 2.5))
        sparkle.fillColor = SKColor(white: 1, alpha: 0.55 * strength)
        sparkle.strokeColor = .clear
        sparkle.position = spot
        sparkle.zRotation = CGFloat.random(in: -0.3...0.3)
        sparkle.alpha = 0
        layer.addChild(sparkle)

        sparkle.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.35),
            .fadeOut(withDuration: 0.7),
            .removeFromParent()
        ]))
    }

    /// Kielwasser hinter dem Boot.
    func spawnWake(at point: CGPoint, heading: CGFloat, strength: CGFloat) {
        let ring = SKShapeNode(ellipseOf: CGSize(width: 34, height: 18))
        ring.strokeColor = SKColor(white: 1, alpha: 0.28 * strength)
        ring.fillColor = .clear
        ring.lineWidth = 1.6
        ring.position = CGPoint(x: point.x - cos(heading) * 46,
                                y: point.y - sin(heading) * 46)
        ring.zRotation = heading
        layer.addChild(ring)

        ring.run(.sequence([
            .group([
                .scale(to: 2.2, duration: 1.6),
                .fadeOut(withDuration: 1.6)
            ]),
            .removeFromParent()
        ]))
    }
}
