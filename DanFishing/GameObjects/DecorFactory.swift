import SpriteKit

/// Baut die Kulisse: Schilf, Seerosen, Steine, Baumstämme, Bäume und den
/// kleinen Schrein. Alles aus Formen — hier wäre auch die Stelle, um später
/// echte Sprites einzusetzen.
enum DecorFactory {

    static func node(for item: DecorItem) -> SKNode? {
        let node: SKNode?

        switch item.kind {
        case .reed: node = reed(variant: item.variant)
        case .lilyPad: node = lilyPad(variant: item.variant)
        case .rock: node = rock(variant: item.variant)
        case .log: node = sunkenLog(variant: item.variant)
        case .mapleTree: node = tree(maple: true, variant: item.variant)
        case .pineTree: node = tree(maple: false, variant: item.variant)
        case .shrine: node = shrine()
        case .ripple: node = nil
        }

        guard let node else { return nil }
        node.position = item.position
        node.zRotation = item.rotation
        node.setScale(item.scale)
        return node
    }

    // MARK: - Einzelteile

    private static func reed(variant: CGFloat) -> SKNode {
        let group = SKNode()
        let count = 3 + Int(variant * 3)

        for index in 0..<count {
            let height = 34 + variant * 26 + CGFloat(index) * 4
            let stalk = SKShapeNode()
            let path = CGMutablePath()
            let lean = CGFloat(index - count / 2) * 3
            path.move(to: .zero)
            path.addQuadCurve(to: CGPoint(x: lean, y: height),
                              control: CGPoint(x: lean * 0.3, y: height * 0.6))
            stalk.path = path
            stalk.strokeColor = Palette.reed.skColor(alpha: 0.95)
            stalk.lineWidth = 2.4
            stalk.position = CGPoint(x: CGFloat(index) * 5 - CGFloat(count) * 2.5, y: 0)
            group.addChild(stalk)

            // Kolben oben drauf
            if index % 2 == 0 {
                let head = SKShapeNode(ellipseOf: CGSize(width: 5, height: 13))
                head.fillColor = ColorSpec(0x7A5C39).skColor
                head.strokeColor = .clear
                head.position = CGPoint(x: stalk.position.x + lean, y: height + 5)
                group.addChild(head)
            }

            // Sanftes Wiegen im Wind — jede Pflanze mit eigenem Takt.
            let sway = SKAction.sequence([
                .rotate(byAngle: 0.05, duration: 1.6 + Double(variant)),
                .rotate(byAngle: -0.05, duration: 1.6 + Double(variant))
            ])
            stalk.run(.repeatForever(sway))
        }
        return group
    }

    private static func lilyPad(variant: CGFloat) -> SKNode {
        let group = SKNode()

        let pad = SKShapeNode(circleOfRadius: 17 + variant * 7)
        pad.fillColor = Palette.lily.skColor(alpha: 0.92)
        pad.strokeColor = ColorSpec(0x3F5C3B).skColor(alpha: 0.8)
        pad.lineWidth = 1.5
        group.addChild(pad)

        // Einschnitt, damit das Blatt nicht wie ein Kreis wirkt
        let notch = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 20, y: 6))
        path.addLine(to: CGPoint(x: 20, y: -6))
        path.closeSubpath()
        notch.path = path
        notch.fillColor = Palette.water.skColor(alpha: 0.55)
        notch.strokeColor = .clear
        group.addChild(notch)

        // Ab und zu eine Blüte
        if variant > 0.72 {
            let flower = SKShapeNode(circleOfRadius: 6)
            flower.fillColor = Palette.blossom.skColor
            flower.strokeColor = ColorSpec(0xC98FA0).skColor
            flower.lineWidth = 1
            flower.position = CGPoint(x: -4, y: 4)
            flower.zPosition = 1
            group.addChild(flower)
        }

        group.run(.repeatForever(.sequence([
            .moveBy(x: 2, y: 1, duration: 2.4 + Double(variant)),
            .moveBy(x: -2, y: -1, duration: 2.4 + Double(variant))
        ])))
        return group
    }

    private static func rock(variant: CGFloat) -> SKNode {
        let group = SKNode()
        let size = 16 + variant * 18

        let shape = SKShapeNode()
        let path = CGMutablePath()
        let corners = 6
        for index in 0...corners {
            let angle = CGFloat(index) / CGFloat(corners) * .pi * 2
            let radius = size * (0.75 + (index % 2 == 0 ? variant * 0.3 : 0.15))
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius * 0.7)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()

        shape.path = path
        shape.fillColor = Palette.stone.skColor
        shape.strokeColor = ColorSpec(0x5F5C55).skColor
        shape.lineWidth = 2
        group.addChild(shape)

        // Moosfleck
        let moss = SKShapeNode(ellipseOf: CGSize(width: size * 0.7, height: size * 0.4))
        moss.fillColor = Palette.moss.skColor(alpha: 0.6)
        moss.strokeColor = .clear
        moss.position = CGPoint(x: -size * 0.2, y: size * 0.15)
        group.addChild(moss)

        return group
    }

    private static func sunkenLog(variant: CGFloat) -> SKNode {
        let group = SKNode()
        let length = 90 + variant * 60

        let trunk = SKShapeNode(rectOf: CGSize(width: length, height: 16), cornerRadius: 8)
        trunk.fillColor = ColorSpec(0x4E3B2A).skColor(alpha: 0.85)
        trunk.strokeColor = ColorSpec(0x33261B).skColor(alpha: 0.9)
        trunk.lineWidth = 1.5
        group.addChild(trunk)

        // Zwei abgebrochene Äste
        for side in [CGFloat(1), CGFloat(-1)] {
            let branch = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: length * 0.1 * side, y: 0))
            path.addLine(to: CGPoint(x: length * 0.32 * side, y: 22 * side))
            branch.path = path
            branch.strokeColor = ColorSpec(0x4E3B2A).skColor(alpha: 0.8)
            branch.lineWidth = 6
            branch.lineCap = .round
            group.addChild(branch)
        }

        group.alpha = 0.9
        return group
    }

    private static func tree(maple: Bool, variant: CGFloat) -> SKNode {
        let group = SKNode()

        // Schatten auf dem Boden
        if let shadowTexture = TextureFactory.softDisc(color: UIColor(white: 0, alpha: 0.3)) {
            let shadow = SKSpriteNode(texture: shadowTexture)
            shadow.size = CGSize(width: 120, height: 80)
            shadow.position = CGPoint(x: 6, y: -10)
            shadow.zPosition = -1
            group.addChild(shadow)
        }

        let trunk = SKShapeNode(rectOf: CGSize(width: 9, height: 26), cornerRadius: 3)
        trunk.fillColor = ColorSpec(0x5A4632).skColor
        trunk.strokeColor = .clear
        group.addChild(trunk)

        // Krone aus mehreren Tupfen — wie mit dem Pinsel gesetzt.
        let baseColor = maple ? Palette.maple : Palette.pine
        let blobCount = 5
        for index in 0..<blobCount {
            let angle = CGFloat(index) / CGFloat(blobCount) * .pi * 2 + variant * 3
            let radius = 20 + variant * 8
            let blob = SKShapeNode(circleOfRadius: 22 + variant * 8)
            blob.fillColor = baseColor.skColor(alpha: 0.92)
            blob.strokeColor = .clear
            blob.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius * 0.7 + 22)
            blob.zPosition = 1
            group.addChild(blob)
        }

        let crown = SKShapeNode(circleOfRadius: 26 + variant * 8)
        crown.fillColor = baseColor.skColor
        crown.strokeColor = .clear
        crown.position = CGPoint(x: 0, y: 24)
        crown.zPosition = 2
        group.addChild(crown)

        group.run(.repeatForever(.sequence([
            .rotate(byAngle: 0.02, duration: 2.8 + Double(variant)),
            .rotate(byAngle: -0.02, duration: 2.8 + Double(variant))
        ])))
        return group
    }

    private static func shrine() -> SKNode {
        let group = SKNode()

        // Torii von oben-schräg: zwei Pfosten und zwei Querbalken.
        for side in [CGFloat(-1), CGFloat(1)] {
            let post = SKShapeNode(rectOf: CGSize(width: 7, height: 46), cornerRadius: 2)
            post.fillColor = Palette.vermilion.skColor
            post.strokeColor = ColorSpec(0x8C3E2B).skColor
            post.lineWidth = 1
            post.position = CGPoint(x: 20 * side, y: 0)
            group.addChild(post)
        }

        let top = SKShapeNode(rectOf: CGSize(width: 66, height: 8), cornerRadius: 3)
        top.fillColor = Palette.vermilion.skColor
        top.strokeColor = ColorSpec(0x8C3E2B).skColor
        top.lineWidth = 1
        top.position = CGPoint(x: 0, y: 26)
        group.addChild(top)

        let beam = SKShapeNode(rectOf: CGSize(width: 52, height: 6), cornerRadius: 2)
        beam.fillColor = ColorSpec(0xA84B34).skColor
        beam.strokeColor = .clear
        beam.position = CGPoint(x: 0, y: 14)
        group.addChild(beam)

        return group
    }
}
