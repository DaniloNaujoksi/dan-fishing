import SpriteKit

/// Baut die Kulisse: Schilf, Seerosen, Steine, Baumstämme, Bäume und den
/// kleinen Schrein. Alles aus Formen — hier wäre auch die Stelle, um später
/// echte Sprites einzusetzen.
enum DecorFactory {

    /// Mittelpunkt zwischen zwei Punkten — für weiche geschlossene Kurven.
    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    // MARK: - Wind

    /// Ein Windzug: langsam hin, langsam zurück, mit weichem Umkehrpunkt.
    ///
    /// Zwei Dinge machen den Unterschied zwischen „wackelt“ und „weht“: Die
    /// Bewegung muss an den Enden abbremsen statt umzuschnappen, und keine
    /// zwei Pflanzen dürfen im selben Takt laufen. Deshalb bekommt jede über
    /// `phase` einen eigenen Startversatz.
    private static func breeze(angle: CGFloat, period: Double, phase: CGFloat) -> SKAction {
        let out = SKAction.rotate(byAngle: angle, duration: period)
        out.timingMode = .easeInEaseOut
        let back = SKAction.rotate(byAngle: -angle, duration: period)
        back.timingMode = .easeInEaseOut

        return .sequence([
            .wait(forDuration: Double(phase) * period * 2),
            .repeatForever(.sequence([out, back]))
        ])
    }

    /// Dasselbe für eine Verschiebung — für alles, was auf dem Wasser treibt.
    private static func drift(by delta: CGVector, period: Double, phase: CGFloat) -> SKAction {
        let out = SKAction.moveBy(x: delta.dx, y: delta.dy, duration: period)
        out.timingMode = .easeInEaseOut
        let back = SKAction.moveBy(x: -delta.dx, y: -delta.dy, duration: period)
        back.timingMode = .easeInEaseOut

        return .sequence([
            .wait(forDuration: Double(phase) * period * 2),
            .repeatForever(.sequence([out, back]))
        ])
    }

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

        // Der ganze Horst neigt sich langsam im Windzug; darin bewegt sich
        // jeder Halm noch einmal für sich. Übereinandergelegt ergibt das ein
        // Wehen statt eines gleichmäßigen Wackelns.
        let gust = SKNode()
        group.addChild(gust)
        gust.run(breeze(angle: 0.045, period: 5.4 + Double(variant) * 2.2, phase: variant))

        for index in 0..<count {
            let height = 34 + variant * 26 + CGFloat(index) * 4
            let lean = CGFloat(index - count / 2) * 3

            // Jeder Halm dreht um seinen eigenen Fuß, deshalb ein Drehpunkt
            // pro Halm statt einer gemeinsamen Drehung.
            let pivot = SKNode()
            pivot.position = CGPoint(x: CGFloat(index) * 5 - CGFloat(count) * 2.5, y: 0)
            gust.addChild(pivot)

            let stalk = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addQuadCurve(to: CGPoint(x: lean, y: height),
                              control: CGPoint(x: lean * 0.3, y: height * 0.6))
            stalk.path = path
            stalk.strokeColor = Palette.reed.skColor(alpha: 0.95)
            stalk.lineWidth = 2.4
            pivot.addChild(stalk)

            // Kolben oben drauf
            if index % 2 == 0 {
                let head = SKShapeNode(ellipseOf: CGSize(width: 5, height: 13))
                head.fillColor = ColorSpec(0x7A5C39).skColor
                head.strokeColor = .clear
                head.position = CGPoint(x: lean, y: height + 5)
                pivot.addChild(head)
            }

            // Der einzelne Halm zittert schneller, aber viel schwächer.
            let phase = variant + CGFloat(index) * 0.17
            pivot.run(breeze(angle: 0.022,
                             period: 2.1 + Double(variant) * 0.9 + Double(index) * 0.13,
                             phase: phase.truncatingRemainder(dividingBy: 1)))
        }
        return group
    }

    private static func lilyPad(variant: CGFloat) -> SKNode {
        let group = SKNode()

        // Ohne Kontur: Der dunkle Rand hat die Blätter wie Aufkleber wirken
        // lassen. Die Fläche allein liegt ruhiger auf dem Wasser.
        let pad = SKShapeNode(circleOfRadius: 17 + variant * 7)
        pad.fillColor = Palette.lily.skColor(alpha: 0.92)
        pad.strokeColor = .clear
        pad.lineWidth = 0
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

        // Seerosen liegen auf dem Wasser, sie werden also nicht geschoben,
        // sondern getragen: ein langes Wandern über wenige Punkte, dazu ein
        // kaum sichtbares Drehen. Beides mit eigener Dauer, damit sich das
        // Feld nie im Gleichschritt bewegt.
        let period = 5.6 + Double(variant) * 3.4
        group.run(drift(by: CGVector(dx: 2.6, dy: 1.4), period: period, phase: variant))

        // Drehen und Wandern laufen nebeneinander — verschiedene Werte,
        // deshalb stören sich die beiden Aktionen nicht.
        group.run(breeze(angle: 0.05,
                         period: period * 1.37,
                         phase: (variant + 0.4).truncatingRemainder(dividingBy: 1)))

        // Ganz leichtes Heben und Senken auf der Dünung.
        let lift = SKAction.scale(to: 1.015, duration: period * 0.5)
        lift.timingMode = .easeInEaseOut
        let settle = SKAction.scale(to: 1.0, duration: period * 0.5)
        settle.timingMode = .easeInEaseOut
        pad.run(.sequence([
            .wait(forDuration: Double(variant) * period),
            .repeatForever(.sequence([lift, settle]))
        ]))

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
            // Warmes, leicht rötliches Grau statt Betongrau, und die Kontur
            // nur angedeutet: Ein kräftiger Rand ließ die Steine wie
            // aufgeklebte Formen aussehen.
            shape.fillColor = index == 0
                ? ColorSpec(0x9B9388).skColor
                : ColorSpec(0xADA79B).skColor
            shape.strokeColor = ColorSpec(0x726A5F).skColor(alpha: 0.45)
            shape.lineWidth = 1.0
            node.addChild(shape)

            // Die sonnenabgewandte Hälfte etwas dunkler — das gibt Rundung,
            // ohne dass ein heller Fleck aufgesetzt wirkt.
            let shading = SKShapeNode(path: path)
            shading.fillColor = ColorSpec(0x6E675D).skColor(alpha: 0.3)
            shading.strokeColor = .clear
            shading.position = CGPoint(x: stone.size * 0.16, y: -stone.size * 0.16)
            shading.setScale(0.82)
            node.addChild(shading)

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

        let base = maple ? ColorSpec(0x8E3A28) : ColorSpec(0x2F4630)
        let mid = maple ? Palette.maple : Palette.pine
        let light = maple ? ColorSpec(0xD46E45) : ColorSpec(0x6B8757)

        /// Geschlossene, unregelmäßige Kronenform.
        ///
        /// Aus Kreisen zusammengesetzte Kronen bekommen zwangsläufig eine
        /// Kontur aus Bögen und Knubbeln. Eine einzige weiche Kurve mit
        /// ungleichen Radien wirkt dagegen wie eine gewachsene Baumkrone.
        func crownPath(radius: CGFloat, seed: CGFloat, squash: CGFloat = 0.74) -> CGPath {
            let path = CGMutablePath()
            let steps = 18
            var points: [CGPoint] = []

            for step in 0..<steps {
                let angle = CGFloat(step) / CGFloat(steps) * .pi * 2
                // Drei überlagerte Wellen ergeben eine Kontur, die nirgends
                // regelmäßig wirkt.
                let wobble = 1
                    + sin(angle * 3 + seed) * 0.12
                    + sin(angle * 5 - seed * 1.7) * 0.07
                    + sin(angle * 2 + seed * 0.6) * 0.05
                points.append(CGPoint(x: cos(angle) * radius * wobble,
                                      y: sin(angle) * radius * wobble * squash))
            }

            // Durch die Punkte eine geschlossene weiche Kurve legen.
            path.move(to: midpoint(points[points.count - 1], points[0]))
            for index in 0..<points.count {
                let current = points[index]
                let next = points[(index + 1) % points.count]
                path.addQuadCurve(to: midpoint(current, next), control: current)
            }
            path.closeSubpath()
            return path
        }

        // Lage 1: die Grundmasse, dunkel und am breitesten.
        let outer = SKShapeNode(path: crownPath(radius: 34 * scale, seed: variant * 6))
        outer.fillColor = base.skColor
        outer.strokeColor = base.skColor
        outer.lineWidth = 2
        outer.position = CGPoint(x: 0, y: 27 * scale)
        outer.zPosition = 1
        group.addChild(outer)

        // Lage 2: mittlerer Ton, nach oben links versetzt — dorthin fällt das Licht.
        let middle = SKShapeNode(path: crownPath(radius: 26 * scale, seed: variant * 6 + 2.1))
        middle.fillColor = mid.skColor
        middle.strokeColor = .clear
        middle.position = CGPoint(x: -4 * scale, y: 32 * scale)
        middle.zPosition = 2
        group.addChild(middle)

        // Lage 3: kleine Lichtinseln im oberen Drittel.
        for index in 0..<3 {
            let patch = SKShapeNode(path: crownPath(radius: (9 + variant * 4) * scale,
                                                    seed: variant * 3 + CGFloat(index) * 1.9,
                                                    squash: 0.85))
            patch.fillColor = light.skColor(alpha: 0.85)
            patch.strokeColor = .clear
            patch.position = CGPoint(x: (-11 + CGFloat(index) * 11) * scale,
                                     y: (38 + CGFloat(index % 2) * 5) * scale)
            patch.zPosition = 3
            group.addChild(patch)
        }

        // Der ganze Baum atmet im Wind: eine sehr lange, weiche Neigung. Kurze
        // Ausschläge sähen aus, als stünde er im Sturm.
        group.run(breeze(angle: 0.016,
                         period: 6.2 + Double(variant) * 3.0,
                         phase: variant))

        // Dazu die Krone selbst — Laub bewegt sich anders als der Stamm, und
        // gerade dieser kleine Versatz macht das Bild lebendig.
        for (index, layer) in [outer, middle].enumerated() {
            let period = 3.4 + Double(variant) * 1.6 + Double(index) * 0.8
            layer.run(breeze(angle: 0.02,
                             period: period,
                             phase: (variant + CGFloat(index) * 0.35)
                                .truncatingRemainder(dividingBy: 1)))

            let swell = SKAction.scale(to: 1.012, duration: period * 0.8)
            swell.timingMode = .easeInEaseOut
            let ease = SKAction.scale(to: 1.0, duration: period * 0.8)
            ease.timingMode = .easeInEaseOut
            layer.run(.sequence([
                .wait(forDuration: Double(variant) * period),
                .repeatForever(.sequence([swell, ease]))
            ]))
        }

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
