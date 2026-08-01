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

    /// Eine Steingruppe statt eines einzelnen Klotzes.
    ///
    /// Steine liegen selten allein: ein großer, ein mittlerer, ein kleiner
    /// daneben. Dazu Schatten unter jedem, eine Lichtkante oben und Moos an
    /// der Wetterseite — damit wirken sie plastisch statt wie Aufkleber.
    private static func rock(variant: CGFloat) -> SKNode {
        let group = SKNode()

        struct Stone {
            let offset: CGPoint
            let size: CGFloat
            let tilt: CGFloat
        }

        let stones: [Stone] = [
            Stone(offset: .zero, size: 18 + variant * 16, tilt: variant * 0.5),
            Stone(offset: CGPoint(x: 15 + variant * 9, y: -8), size: 10 + variant * 8, tilt: -0.3),
            Stone(offset: CGPoint(x: -13 - variant * 6, y: -11), size: 7 + variant * 6, tilt: 0.7)
        ]

        for (index, stone) in stones.enumerated() {
            let node = SKNode()
            node.position = stone.offset
            node.zRotation = stone.tilt

            // Schatten auf dem Boden.
            if let shadowTexture = TextureFactory.softDisc(color: UIColor(white: 0, alpha: 0.32)) {
                let shadow = SKSpriteNode(texture: shadowTexture)
                shadow.size = CGSize(width: stone.size * 3.0, height: stone.size * 1.8)
                shadow.position = CGPoint(x: stone.size * 0.16, y: -stone.size * 0.42)
                shadow.zPosition = -1
                node.addChild(shadow)
            }

            // Unregelmäßiger Umriss aus acht Ecken mit ungleichen Radien.
            let shape = SKShapeNode()
            let path = CGMutablePath()
            let corners = 8
            for step in 0...corners {
                let angle = CGFloat(step) / CGFloat(corners) * .pi * 2
                let wobble = 0.72 + sin(angle * 3 + variant * 6 + CGFloat(index)) * 0.2
                let point = CGPoint(x: cos(angle) * stone.size * wobble,
                                    y: sin(angle) * stone.size * wobble * 0.74)
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()

            shape.path = path
            shape.fillColor = index == 0
                ? Palette.stone.skColor
                : ColorSpec(0x9C988D).skColor
            shape.strokeColor = ColorSpec(0x625E56).skColor(alpha: 0.85)
            shape.lineWidth = 1.6
            node.addChild(shape)

            // Lichtkante oben links — die Sonne steht im Spiel oben.
            let highlight = SKShapeNode(ellipseOf: CGSize(width: stone.size * 0.9,
                                                          height: stone.size * 0.45))
            highlight.fillColor = SKColor(white: 1, alpha: 0.22)
            highlight.strokeColor = .clear
            highlight.position = CGPoint(x: -stone.size * 0.18, y: stone.size * 0.26)
            highlight.zRotation = -0.25
            node.addChild(highlight)

            // Moos an der Nordseite, nur beim größten Stein.
            if index == 0 && variant > 0.35 {
                let moss = SKShapeNode(ellipseOf: CGSize(width: stone.size * 0.8,
                                                         height: stone.size * 0.42))
                moss.fillColor = Palette.moss.skColor(alpha: 0.55)
                moss.strokeColor = .clear
                moss.position = CGPoint(x: -stone.size * 0.26, y: -stone.size * 0.2)
                moss.zRotation = 0.3
                node.addChild(moss)
            }

            group.addChild(node)
        }

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

    /// Baum von schräg oben.
    ///
    /// Die Krone besteht aus drei Lagen: dunkle Grundmasse, mittlere Tupfen,
    /// helle Lichter obenauf. Erst diese Staffelung lässt sie räumlich wirken;
    /// eine einzelne Farbfläche sah aus wie ein grüner Kreis. Der Ahorn
    /// bekommt zusätzlich einzelne Blätter am Rand, die Kiefer eine gezackte
    /// Silhouette.
    private static func tree(maple: Bool, variant: CGFloat) -> SKNode {
        let group = SKNode()
        let scale = 0.85 + variant * 0.5

        // Weicher Schlagschatten, leicht versetzt.
        if let shadowTexture = TextureFactory.softDisc(color: UIColor(white: 0, alpha: 0.34)) {
            let shadow = SKSpriteNode(texture: shadowTexture)
            shadow.size = CGSize(width: 132 * scale, height: 86 * scale)
            shadow.position = CGPoint(x: 12 * scale, y: -16 * scale)
            shadow.zPosition = -1
            group.addChild(shadow)
        }

        // Stamm mit zwei sichtbaren Ästen.
        let trunk = SKShapeNode()
        let trunkPath = CGMutablePath()
        trunkPath.move(to: CGPoint(x: -5 * scale, y: -14 * scale))
        trunkPath.addLine(to: CGPoint(x: -3 * scale, y: 16 * scale))
        trunkPath.addLine(to: CGPoint(x: 3 * scale, y: 16 * scale))
        trunkPath.addLine(to: CGPoint(x: 5 * scale, y: -14 * scale))
        trunkPath.closeSubpath()
        trunkPath.move(to: CGPoint(x: 0, y: 6 * scale))
        trunkPath.addLine(to: CGPoint(x: -14 * scale, y: 18 * scale))
        trunkPath.move(to: CGPoint(x: 0, y: 10 * scale))
        trunkPath.addLine(to: CGPoint(x: 13 * scale, y: 20 * scale))

        trunk.path = trunkPath
        trunk.fillColor = ColorSpec(0x5A4632).skColor
        trunk.strokeColor = ColorSpec(0x5A4632).skColor
        trunk.lineWidth = 3 * scale
        trunk.lineCap = .round
        group.addChild(trunk)

        let base = maple ? ColorSpec(0x9E3F2A) : ColorSpec(0x33492F)
        let mid = maple ? Palette.maple : Palette.pine
        let light = maple ? ColorSpec(0xE0764A) : ColorSpec(0x6F8B5A)

        // Lage 1: breite dunkle Grundmasse.
        for index in 0..<6 {
            let angle = CGFloat(index) / 6 * .pi * 2 + variant * 4
            let blob = SKShapeNode(circleOfRadius: (19 + variant * 5) * scale)
            blob.fillColor = base.skColor
            blob.strokeColor = .clear
            blob.position = CGPoint(x: cos(angle) * 18 * scale,
                                    y: sin(angle) * 13 * scale + 26 * scale)
            blob.zPosition = 1
            group.addChild(blob)
        }

        // Lage 2: mittlere Tupfen, etwas nach oben versetzt.
        for index in 0..<5 {
            let angle = CGFloat(index) / 5 * .pi * 2 + variant * 2.2
            let blob = SKShapeNode(circleOfRadius: (14 + variant * 4) * scale)
            blob.fillColor = mid.skColor
            blob.strokeColor = .clear
            blob.position = CGPoint(x: cos(angle) * 13 * scale,
                                    y: sin(angle) * 9 * scale + 31 * scale)
            blob.zPosition = 2
            group.addChild(blob)
        }

        // Lage 3: Lichter dort, wo die Sonne hinfällt.
        for index in 0..<3 {
            let blob = SKShapeNode(circleOfRadius: (8 + variant * 3) * scale)
            blob.fillColor = light.skColor(alpha: 0.9)
            blob.strokeColor = .clear
            blob.position = CGPoint(x: (-9 + CGFloat(index) * 9) * scale,
                                    y: (38 + CGFloat(index % 2) * 6) * scale)
            blob.zPosition = 3
            group.addChild(blob)
        }

        // Einzelne Blätter am Rand lösen die Kontur auf.
        for index in 0..<7 {
            let angle = CGFloat(index) / 7 * .pi * 2 + variant
            let leaf = SKShapeNode(ellipseOf: CGSize(width: 7 * scale, height: 5 * scale))
            leaf.fillColor = (maple ? light : mid).skColor(alpha: 0.85)
            leaf.strokeColor = .clear
            leaf.position = CGPoint(x: cos(angle) * 32 * scale,
                                    y: sin(angle) * 22 * scale + 28 * scale)
            leaf.zRotation = angle
            leaf.zPosition = 4
            group.addChild(leaf)
        }

        // Der ganze Baum wiegt sich im Wind, jeder mit eigenem Takt.
        group.run(.repeatForever(.sequence([
            .rotate(byAngle: 0.018, duration: 2.6 + Double(variant) * 1.4),
            .rotate(byAngle: -0.018, duration: 2.6 + Double(variant) * 1.4)
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
