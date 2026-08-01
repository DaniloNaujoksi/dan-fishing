import SpriteKit

/// Der Vorspann beim ersten Start.
///
/// Dreizehn Sekunden, alles gezeichnet, kein Video: Nebel über stillem Wasser,
/// Bergrücken in Tuschelagen, ein Kirschzweig im Bild, ein Torii am Ufer. Die
/// Sonne steigt, Dan rudert gemächlich herein, unter ihm zieht ein großer Fisch
/// vorbei und dreht nach oben. Dan wirft aus, es beißt, die Kamera fährt heraus,
/// der Titel steht.
///
/// Das Tempo ist bewusst langsam gewählt: Der Vorspann soll die Ruhe des Spiels
/// ankündigen, nicht Ereignisse abarbeiten. Jederzeit durch Tippen abzubrechen.
final class IntroScene: SKScene {

    /// Wird aufgerufen, wenn der Vorspann durch ist oder übersprungen wurde.
    var onFinish: (() -> Void)?

    private let world = SKNode()
    private let waterNode = SKNode()
    private let sun = SKShapeNode(circleOfRadius: 46)
    private let sky = SKSpriteNode()
    private let fogLayer = SKNode()
    private let boat = SKNode()
    private let rod = SKShapeNode()
    private let line = SKShapeNode()
    private let bobber = SKShapeNode(circleOfRadius: 6)
    private let deepFish = SKNode()
    private let titleBacking = SKSpriteNode()
    private let titleLabel = SKLabelNode(text: "DAN FISHING")
    private let subtitle = SKLabelNode(text: "Ein stiller See, ein Boot, viel Zeit.")
    private let hint = SKLabelNode(text: "Tippen zum Fortfahren")
    private let flash = SKSpriteNode(color: .black, size: CGSize(width: 3000, height: 3000))

    private var elapsed: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0
    private var finished = false

    /// Gesamtlänge, abgestimmt auf das Titelstück. Bewusst langsam: Der
    /// Vorspann soll den Ton des Spiels setzen, nicht Ereignisse abhaken.
    private let duration: TimeInterval = 13.5

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = ColorSpec(0x1B2C3E).skColor
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) wird nicht verwendet")
    }

    override func didMove(to view: SKView) {
        guard world.parent == nil else { return }
        addChild(world)

        buildSky()
        buildWater()
        buildDeepFish()
        buildBoat()
        buildScenery()
        buildFog()
        buildTitle()

        flash.zPosition = 900
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(flash)
        flash.run(.fadeAlpha(to: 0, duration: 1.8))

        runTimeline()
        AudioManager.shared.playIntroTheme()
    }

    // MARK: - Aufbau

    private func buildSky() {
        // Gedämpftes Morgengrau statt kräftigem Blau — die Farben sollen wie
        // auf getöntem Papier liegen, nicht leuchten.
        sky.color = ColorSpec(0x6E7A82).skColor
        sky.size = CGSize(width: size.width * 1.4, height: size.height)
        sky.position = CGPoint(x: size.width / 2, y: size.height * 0.75)
        sky.zPosition = 0
        world.addChild(sky)

        // Drei Bergrücken in abgestuftem Grau — wie Tuschelagen auf Papier,
        // von hinten nach vorn dunkler.
        for (index, shade) in [ColorSpec(0x9AA6AC), ColorSpec(0x77858E), ColorSpec(0x56646D)].enumerated() {
            let ridge = SKShapeNode()
            let path = CGMutablePath()
            let baseY = size.height * (0.60 - CGFloat(index) * 0.04)
            path.move(to: CGPoint(x: -50, y: baseY))
            path.addQuadCurve(to: CGPoint(x: size.width * 0.5, y: baseY),
                              control: CGPoint(x: size.width * 0.25, y: baseY + 110 - CGFloat(index) * 30))
            path.addQuadCurve(to: CGPoint(x: size.width + 50, y: baseY),
                              control: CGPoint(x: size.width * 0.78, y: baseY + 140 - CGFloat(index) * 40))
            path.addLine(to: CGPoint(x: size.width + 50, y: -10))
            path.addLine(to: CGPoint(x: -50, y: -10))
            path.closeSubpath()

            ridge.path = path
            ridge.fillColor = shade.skColor
            ridge.strokeColor = .clear
            ridge.zPosition = 1 + CGFloat(index)
            world.addChild(ridge)
        }

        sun.fillColor = ColorSpec(0xF6D9A0).skColor
        sun.strokeColor = .clear
        sun.alpha = 0.9
        sun.position = CGPoint(x: size.width * 0.68, y: size.height * 0.5)
        sun.zPosition = 0.5
        world.addChild(sun)

        // Weicher Schein um die Sonne.
        if let glow = TextureFactory.softDisc(color: UIColor(red: 1, green: 0.85, blue: 0.6, alpha: 0.55)) {
            let halo = SKSpriteNode(texture: glow)
            halo.size = CGSize(width: 420, height: 420)
            halo.zPosition = -0.5
            sun.addChild(halo)
        }
    }

    private func buildWater() {
        waterNode.zPosition = 3
        world.addChild(waterNode)

        let surface = SKSpriteNode(color: ColorSpec(0x5C7480).skColor,
                                   size: CGSize(width: size.width * 1.4, height: size.height * 0.62))
        surface.position = CGPoint(x: size.width / 2, y: size.height * 0.30)
        waterNode.addChild(surface)

        // Wellenlinien, die langsam wandern.
        for index in 0..<9 {
            let wave = SKShapeNode()
            let path = CGMutablePath()
            let y = size.height * (0.14 + CGFloat(index) * 0.045)
            path.move(to: CGPoint(x: -60, y: y))
            for step in 0...10 {
                let x = CGFloat(step) / 10 * (size.width + 120) - 60
                path.addLine(to: CGPoint(x: x, y: y + sin(CGFloat(step) * 0.9 + CGFloat(index)) * 4))
            }
            wave.path = path
            wave.strokeColor = SKColor(white: 1, alpha: 0.13)
            wave.lineWidth = 2
            waterNode.addChild(wave)

            wave.run(.repeatForever(.sequence([
                .moveBy(x: 26, y: 0, duration: 4 + Double(index) * 0.4),
                .moveBy(x: -26, y: 0, duration: 4 + Double(index) * 0.4)
            ])))
        }

        // Sonnenpfad auf dem Wasser: einzelne Lichtstriche, die zur Sonne hin
        // schmaler werden. Ein durchgehendes Rechteck sah aus wie ein Fehler.
        for index in 0..<14 {
            let fraction = CGFloat(index) / 14
            let streak = SKShapeNode(ellipseOf: CGSize(width: 20 + fraction * 78,
                                                       height: 3 + fraction * 2))
            streak.fillColor = ColorSpec(0xF6D9A0).skColor(alpha: 0.05 + (1 - fraction) * 0.16)
            streak.strokeColor = .clear
            streak.position = CGPoint(x: size.width * 0.68 + CGFloat.random(in: -12...12),
                                      y: size.height * (0.44 - fraction * 0.34))
            waterNode.addChild(streak)

            // Leichtes Wandern, als bräche sich das Licht in den Wellen.
            streak.run(.repeatForever(.sequence([
                .group([.moveBy(x: 8, y: 0, duration: 1.8 + Double(index) * 0.1),
                        .fadeAlpha(to: 0.06, duration: 1.8)]),
                .group([.moveBy(x: -8, y: 0, duration: 1.8 + Double(index) * 0.1),
                        .fadeAlpha(to: 0.2, duration: 1.8)])
            ])))
        }
    }

    private func buildDeepFish() {
        // Großer Fisch als Schatten unter der Oberfläche.
        let body = SKShapeNode(ellipseOf: CGSize(width: 190, height: 58))
        body.fillColor = ColorSpec(0x11242F).skColor(alpha: 0.55)
        body.strokeColor = .clear
        deepFish.addChild(body)

        let tail = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -92, y: 0))
        path.addLine(to: CGPoint(x: -138, y: 30))
        path.addLine(to: CGPoint(x: -122, y: 0))
        path.addLine(to: CGPoint(x: -138, y: -30))
        path.closeSubpath()
        tail.path = path
        tail.fillColor = ColorSpec(0x11242F).skColor(alpha: 0.55)
        tail.strokeColor = .clear
        deepFish.addChild(tail)

        deepFish.position = CGPoint(x: -200, y: size.height * 0.16)
        deepFish.zPosition = 4
        deepFish.alpha = 0
        world.addChild(deepFish)
    }

    private func buildBoat() {
        let hull = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 62, y: 0))
        path.addQuadCurve(to: CGPoint(x: -58, y: 14), control: CGPoint(x: 0, y: 26))
        path.addQuadCurve(to: CGPoint(x: -58, y: -6), control: CGPoint(x: -74, y: 4))
        path.addQuadCurve(to: CGPoint(x: 62, y: 0), control: CGPoint(x: 0, y: -14))
        path.closeSubpath()
        hull.path = path
        hull.fillColor = ColorSpec(0x8A6A46).skColor
        hull.strokeColor = ColorSpec(0x4E3823).skColor
        hull.lineWidth = 2
        boat.addChild(hull)

        // Dan: Rumpf, Kopf, Strohhut — von der Seite.
        let torso = SKShapeNode(rectOf: CGSize(width: 16, height: 26), cornerRadius: 7)
        torso.fillColor = ColorSpec(0x3C4A5A).skColor
        torso.strokeColor = .clear
        torso.position = CGPoint(x: -6, y: 20)
        boat.addChild(torso)

        let head = SKShapeNode(circleOfRadius: 8)
        head.fillColor = ColorSpec(0xE8B98C).skColor
        head.strokeColor = .clear
        head.position = CGPoint(x: -6, y: 40)
        boat.addChild(head)

        let hat = SKShapeNode(ellipseOf: CGSize(width: 34, height: 10))
        hat.fillColor = ColorSpec(0xD9C48A).skColor
        hat.strokeColor = ColorSpec(0xA98F55).skColor
        hat.lineWidth = 1
        hat.position = CGPoint(x: -6, y: 46)
        boat.addChild(hat)

        let rodPath = CGMutablePath()
        rodPath.move(to: .zero)
        rodPath.addQuadCurve(to: CGPoint(x: 92, y: 44), control: CGPoint(x: 50, y: 10))
        rod.path = rodPath
        rod.strokeColor = ColorSpec(0x7A5B34).skColor
        rod.lineWidth = 3
        rod.position = CGPoint(x: 2, y: 30)
        boat.addChild(rod)

        line.strokeColor = SKColor(white: 1, alpha: 0.6)
        line.lineWidth = 1.6
        // Über Wasserfläche (3) und Boot (5) — sonst deckt das Wasser die
        // Schnur zu und Dan angelt sichtbar ins Nichts.
        line.zPosition = 6
        world.addChild(line)

        bobber.fillColor = Palette.paper.skColor
        bobber.strokeColor = Palette.vermilion.skColor
        bobber.lineWidth = 2
        bobber.alpha = 0
        // Der Schwimmer liegt über der Schnur.
        bobber.zPosition = 6.5
        world.addChild(bobber)

        boat.position = CGPoint(x: -140, y: size.height * 0.27)
        boat.zPosition = 5
        world.addChild(boat)
    }

    /// Kirschzweig am oberen Bildrand, ein Torii am Ufer, treibende Blüten.
    /// Diese drei Zeichen setzen den Ort, ohne dass etwas erklärt werden muss.
    private func buildScenery() {
        // Zweig, der von oben links ins Bild hängt.
        let branch = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -20, y: size.height + 20))
        path.addQuadCurve(to: CGPoint(x: size.width * 0.42, y: size.height * 0.86),
                          control: CGPoint(x: size.width * 0.16, y: size.height * 0.9))
        branch.path = path
        branch.strokeColor = ColorSpec(0x4A3A32).skColor
        branch.lineWidth = 5
        branch.lineCap = .round
        branch.zPosition = 8
        world.addChild(branch)

        // Blütenbüschel entlang des Zweigs.
        for index in 0..<16 {
            let fraction = CGFloat(index) / 16
            let point = CGPoint(x: -20 + (size.width * 0.42 + 20) * fraction,
                                y: size.height + 20 - (size.height * 0.16) * fraction * fraction)

            let blossom = SKShapeNode(circleOfRadius: CGFloat.random(in: 4...8))
            blossom.fillColor = Palette.blossom.skColor(alpha: 0.9)
            blossom.strokeColor = ColorSpec(0xD9A7B0).skColor(alpha: 0.6)
            blossom.lineWidth = 1
            blossom.position = CGPoint(x: point.x + CGFloat.random(in: -16...16),
                                       y: point.y + CGFloat.random(in: -18...10))
            blossom.zPosition = 9
            world.addChild(blossom)
        }

        // Torii am gegenüberliegenden Ufer, nur als Silhouette.
        let torii = SKNode()
        for side in [CGFloat(-1), CGFloat(1)] {
            let post = SKShapeNode(rectOf: CGSize(width: 5, height: 44))
            post.fillColor = ColorSpec(0x8C4A3A).skColor(alpha: 0.75)
            post.strokeColor = .clear
            post.position = CGPoint(x: 15 * side, y: 0)
            torii.addChild(post)
        }
        let top = SKShapeNode(rectOf: CGSize(width: 52, height: 6))
        top.fillColor = ColorSpec(0x8C4A3A).skColor(alpha: 0.75)
        top.strokeColor = .clear
        top.position = CGPoint(x: 0, y: 24)
        torii.addChild(top)

        torii.position = CGPoint(x: size.width * 0.13, y: size.height * 0.53)
        torii.setScale(0.9)
        torii.zPosition = 2.5
        world.addChild(torii)

        // Einzelne Blütenblätter, die durchs Bild treiben.
        guard let texture = TextureFactory.petal(color: Palette.blossom.skColor) else { return }
        for index in 0..<9 {
            let petal = SKSpriteNode(texture: texture)
            petal.size = CGSize(width: 13, height: 13)
            petal.alpha = 0.85
            petal.zPosition = 8.5
            petal.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                     y: size.height + CGFloat.random(in: 0...300))
            world.addChild(petal)

            let fall = Double.random(in: 9...15)
            petal.run(.repeatForever(.sequence([
                .group([
                    .moveBy(x: CGFloat.random(in: -70...50), y: -(size.height + 320), duration: fall),
                    .rotate(byAngle: CGFloat.random(in: -4...4), duration: fall)
                ]),
                .run { [weak petal, weak self] in
                    guard let self, let petal else { return }
                    petal.position = CGPoint(x: CGFloat.random(in: 0...self.size.width),
                                             y: self.size.height + 40)
                }
            ])))
            _ = index
        }
    }

    private func buildFog() {
        fogLayer.zPosition = 7
        world.addChild(fogLayer)

        guard let texture = TextureFactory.softDisc(color: UIColor(white: 1, alpha: 0.4)) else { return }
        for index in 0..<5 {
            let bank = SKSpriteNode(texture: texture)
            bank.size = CGSize(width: size.width * 0.9, height: 150)
            bank.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                    y: size.height * CGFloat.random(in: 0.18...0.44))
            bank.alpha = 0.30
            fogLayer.addChild(bank)

            bank.run(.repeatForever(.sequence([
                .moveBy(x: 60, y: 0, duration: 7 + Double(index)),
                .moveBy(x: -60, y: 0, duration: 7 + Double(index))
            ])))
        }
    }

    private func buildTitle() {
        // Dunkler Schleier hinter dem Titel: Ohne ihn verschwindet die helle
        // Schrift im hellen Morgenhimmel.
        if let texture = TextureFactory.softDisc(color: UIColor(white: 0, alpha: 0.6)) {
            titleBacking.texture = texture
            titleBacking.size = CGSize(width: size.width * 1.3, height: 320)
            titleBacking.position = CGPoint(x: size.width / 2, y: size.height * 0.66)
            titleBacking.zPosition = 790
            titleBacking.alpha = 0
            addChild(titleBacking)
        }

        titleLabel.fontName = "Georgia-Bold"
        titleLabel.fontSize = 46
        titleLabel.fontColor = Palette.paper.skColor
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.70)
        titleLabel.zPosition = 800
        titleLabel.alpha = 0
        titleLabel.setScale(0.92)
        addChild(titleLabel)

        subtitle.fontName = "Georgia"
        subtitle.fontSize = 15
        subtitle.fontColor = Palette.paper.skColor(alpha: 0.85)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.65)
        subtitle.zPosition = 800
        subtitle.alpha = 0
        addChild(subtitle)

        hint.fontName = "Georgia"
        hint.fontSize = 12
        hint.fontColor = Palette.paper.skColor(alpha: 0.6)
        hint.position = CGPoint(x: size.width / 2, y: size.height * 0.12)
        hint.zPosition = 800
        hint.alpha = 0
        addChild(hint)
    }

    // MARK: - Ablauf

    private func runTimeline() {
        // Sonnenaufgang: Die Sonne steigt langsam, der Himmel wird warm.
        sun.run(.sequence([
            .wait(forDuration: 0.8),
            .group([
                .moveBy(x: 0, y: size.height * 0.17, duration: 7.5),
                .fadeAlpha(to: 1, duration: 4.5)
            ])
        ]))
        sky.run(.sequence([
            .wait(forDuration: 0.8),
            .colorize(with: ColorSpec(0xE4C39C).skColor, colorBlendFactor: 0.7, duration: 6.5)
        ]))

        // Dan rudert gemächlich ins Bild.
        boat.run(.sequence([
            .wait(forDuration: 1.6),
            .move(to: CGPoint(x: size.width * 0.34, y: size.height * 0.27), duration: 4.6)
        ]))
        boat.run(.repeatForever(.sequence([
            .rotate(byAngle: 0.02, duration: 1.1),
            .rotate(byAngle: -0.02, duration: 1.1)
        ])))

        // Der große Fisch zieht unten durch und dreht nach oben.
        deepFish.run(.sequence([
            .wait(forDuration: 3.6),
            .fadeAlpha(to: 1, duration: 0.8),
            .group([
                .move(to: CGPoint(x: size.width * 0.55, y: size.height * 0.15), duration: 5.0),
                .sequence([
                    .wait(forDuration: 3.0),
                    .rotate(toAngle: 0.35, duration: 1.4)
                ])
            ])
        ]))

        // Wurf: Der Schwimmer fliegt hinaus und landet.
        bobber.run(.sequence([
            .wait(forDuration: 9.0),
            .run { [weak self] in
                guard let self else { return }
                self.bobber.position = CGPoint(x: self.size.width * 0.42, y: self.size.height * 0.34)
                self.bobber.alpha = 1
                AudioManager.shared.play(.cast)
            },
            .move(to: CGPoint(x: size.width * 0.68, y: size.height * 0.30), duration: 0.9),
            .run { [weak self] in
                AudioManager.shared.play(.splash)
                self?.emitRipple(at: CGPoint(x: (self?.size.width ?? 0) * 0.68,
                                             y: (self?.size.height ?? 0) * 0.30))
            }
        ]))

        // Der Biss.
        bobber.run(.sequence([
            .wait(forDuration: 9.0),
            .run { AudioManager.shared.play(.bite) },
            .moveBy(x: 0, y: -14, duration: 0.16),
            .moveBy(x: 0, y: 9, duration: 0.2),
            .moveBy(x: 0, y: -18, duration: 0.18),
            .run { [weak self] in
                guard let self else { return }
                self.emitRipple(at: self.bobber.position)
                self.emitRipple(at: self.bobber.position)
                AudioManager.shared.play(.splash)
            }
        ]))

        // Die Rute biegt sich, der Kampf beginnt.
        rod.run(.sequence([
            .wait(forDuration: 9.1),
            .rotate(toAngle: -0.55, duration: 0.35),
            .repeat(.sequence([
                .rotate(toAngle: -0.35, duration: 0.28),
                .rotate(toAngle: -0.6, duration: 0.28)
            ]), count: 3)
        ]))

        // Kamera fährt heraus, Titel erscheint.
        world.run(.sequence([
            .wait(forDuration: 10.3),
            .group([
                .scale(to: 0.9, duration: 1.8),
                .fadeAlpha(to: 0.78, duration: 1.8)
            ])
        ]))
        world.position = .zero

        titleBacking.run(.sequence([
            .wait(forDuration: 10.6),
            .fadeAlpha(to: 0.55, duration: 0.8)
        ]))

        titleLabel.run(.sequence([
            .wait(forDuration: 10.8),
            .group([
                .fadeIn(withDuration: 0.9),
                .scale(to: 1.0, duration: 0.9)
            ])
        ]))
        subtitle.run(.sequence([.wait(forDuration: 11.4), .fadeAlpha(to: 1, duration: 0.7)]))
        hint.run(.sequence([
            .wait(forDuration: 11.9),
            .fadeAlpha(to: 1, duration: 0.5),
            .repeatForever(.sequence([
                .fadeAlpha(to: 0.35, duration: 0.8),
                .fadeAlpha(to: 0.85, duration: 0.8)
            ]))
        ]))
    }

    /// Zieht die Schnur von der Rutenspitze zum Schwimmer. Sie folgt der
    /// Rutenbewegung, hängt leicht durch und strafft sich beim Biss.
    private func updateLine() {
        guard bobber.alpha > 0.05 else {
            line.path = nil
            return
        }

        // Spitze der Rute in Weltkoordinaten. Die Rute ist gedreht, deshalb
        // wird ihr Endpunkt mitgedreht.
        let tipLocal = CGPoint(
            x: rod.position.x + cos(rod.zRotation) * 92 - sin(rod.zRotation) * 44,
            y: rod.position.y + sin(rod.zRotation) * 92 + cos(rod.zRotation) * 44
        )
        let tip = boat.convert(tipLocal, to: world)
        let end = bobber.position

        let path = CGMutablePath()
        path.move(to: tip)
        // Beim Drill zieht die Rute nach unten, dann hängt die Schnur weniger
        // durch — das liest sich als Spannung.
        let sag: CGFloat = rod.zRotation < -0.2 ? 8 : 26
        path.addQuadCurve(to: end,
                          control: CGPoint(x: (tip.x + end.x) / 2,
                                           y: (tip.y + end.y) / 2 - sag))
        line.path = path
        line.strokeColor = rod.zRotation < -0.2
            ? Palette.vermilion.skColor(alpha: 0.8)
            : SKColor(white: 1, alpha: 0.6)
    }

    private func emitRipple(at point: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 10)
        ring.position = point
        ring.strokeColor = SKColor(white: 1, alpha: 0.55)
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.zPosition = 6
        ring.setScale(0.3)
        world.addChild(ring)

        ring.run(.sequence([
            .group([.scale(to: 3.2, duration: 1.4), .fadeOut(withDuration: 1.4)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Schleife und Abbruch

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        lastUpdate = currentTime
        elapsed += delta

        // Wasser hebt und senkt sich ganz leicht — das hält das Bild lebendig.
        waterNode.position = CGPoint(x: 0, y: sin(CGFloat(elapsed) * 0.7) * 3)

        updateLine()

        if elapsed >= duration {
            finish()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true

        AudioManager.shared.stopIntroTheme()

        // Weiches Abblenden, damit der Übergang ins Menü nicht schneidet.
        flash.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.35),
            .run { [weak self] in self?.onFinish?() }
        ]))
    }
}
