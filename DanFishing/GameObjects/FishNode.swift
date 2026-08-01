import SpriteKit

/// Ein sichtbarer Fisch im See. Unter Wasser sieht man ihn als weiche
/// Silhouette; je flacher das Wasser, desto deutlicher.
///
/// Der Knoten zeichnet nur — entschieden wird in `FishAI`. Was der Fisch
/// gerade vorhat, liest der Spieler an seiner Bewegung ab: neugieriges
/// Heranziehen, Kreisen um den Köder, kurzes Zucken beim Zupfen.
final class FishNode: SKNode {

    private(set) var swimmer: FishAI.Swimmer
    let species: FishSpecies

    private let sprite = SKSpriteNode()
    private let ripple = SKShapeNode(circleOfRadius: 10)
    private let interestMark = SKShapeNode(circleOfRadius: 4)
    private var rippleTimer: CGFloat = 0
    private var tailPhase: CGFloat = 0

    /// Schein um einen legendären Fisch. Er ist das einzige, was ihn im
    /// Wasser verrät — die Silhouette selbst sieht aus wie bei jedem anderen
    /// Fisch seiner Art, nur größer.
    private var aura: SKSpriteNode?

    init(swimmer: FishAI.Swimmer, species: FishSpecies) {
        self.swimmer = swimmer
        self.species = species
        super.init()

        // Im Wasser sieht man nur den Rücken als Schemen — die gezeichneten
        // Grafiken erscheinen erst im Fangbuch und auf der Fangkarte.
        if let texture = TextureFactory.fishBackSilhouette(for: species) {
            sprite.texture = texture

            // Maßstab: Ein Boot ist rund 110 Punkte lang. Ein Rotauge misst
            // damit gut 30, ein Wels über 80 — groß genug zum Erkennen, ohne
            // dass der See von Fischen zugestellt wirkt.
            let sizeFactor = min(1.5, CGFloat(species.maxLength) / 70)
            let width = 42 * swimmer.scale * sizeFactor
            let ratio = texture.size().height / max(texture.size().width, 1)
            sprite.size = CGSize(width: width, height: width * ratio)
        }
        sprite.alpha = 0.55
        addChild(sprite)

        ripple.strokeColor = SKColor(white: 1, alpha: 0.35)
        ripple.fillColor = .clear
        ripple.lineWidth = 1.5
        ripple.alpha = 0
        ripple.zPosition = 1
        addChild(ripple)

        // Kleiner Punkt über dem Fisch, sobald er den Köder prüft. Ein
        // dezenter Hinweis, dass gleich etwas passiert.
        interestMark.fillColor = Palette.gold.skColor
        interestMark.strokeColor = .clear
        interestMark.alpha = 0
        interestMark.zPosition = 2
        addChild(interestMark)

        if swimmer.isLegendary {
            buildAura()
        }

        position = swimmer.position
        zRotation = swimmer.heading
    }

    /// Goldener Schein, der langsam atmet. Bewusst ruhig gehalten: Er soll
    /// auffallen, wenn man hinschaut, und nicht über den halben See blinken.
    private func buildAura() {
        guard let texture = TextureFactory.softDisc(color: UIColor(red: 1.0,
                                                                   green: 0.86,
                                                                   blue: 0.45,
                                                                   alpha: 0.75)) else { return }
        let glow = SKSpriteNode(texture: texture)
        glow.size = CGSize(width: sprite.size.width * 3.4,
                           height: sprite.size.width * 3.4)
        glow.blendMode = .add
        glow.alpha = 0.5
        glow.zPosition = -1
        addChild(glow)
        aura = glow

        glow.run(.repeatForever(.sequence([
            .group([.scale(to: 1.18, duration: 1.9), .fadeAlpha(to: 0.7, duration: 1.9)]),
            .group([.scale(to: 1.0, duration: 1.9), .fadeAlpha(to: 0.42, duration: 1.9)])
        ])))

        // Ein paar Funken, die mit ihm ziehen.
        for index in 0..<3 {
            let spark = SKShapeNode(circleOfRadius: 2)
            spark.fillColor = Palette.gold.skColor
            spark.strokeColor = .clear
            spark.alpha = 0
            spark.zPosition = 1
            addChild(spark)

            let radius = sprite.size.width * 0.7
            let angle = CGFloat(index) / 3 * .pi * 2
            spark.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            spark.run(.sequence([
                .wait(forDuration: Double(index) * 0.6),
                .repeatForever(.sequence([
                    .fadeAlpha(to: 0.9, duration: 0.7),
                    .fadeAlpha(to: 0.1, duration: 1.1)
                ]))
            ]))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) wird nicht verwendet")
    }

    /// - Returns: Was der Fisch in diesem Schritt entschieden hat.
    @discardableResult
    func update(deltaTime: CGFloat,
                map: LakeMap,
                lure: CGPoint?,
                interest: CGFloat,
                biteAllowed: Bool) -> FishAI.Outcome {

        let outcome = FishAI.update(&swimmer,
                                    deltaTime: deltaTime,
                                    map: map,
                                    lure: lure,
                                    interest: interest,
                                    biteAllowed: biteAllowed)

        position = swimmer.position
        zRotation = MovementController.turn(from: zRotation, to: swimmer.heading, maxStep: deltaTime * 3)

        // Schwanzschlag: schneller, je eiliger der Fisch unterwegs ist.
        let effort: CGFloat = (swimmer.behaviour == .spooked || swimmer.behaviour == .retreat) ? 2.2 : 1.0
        tailPhase += deltaTime * (3 + swimmer.speed * 0.06) * effort
        // Ein legendärer Fisch ist sichtbar größer als seine Artgenossen.
        let bodyScale: CGFloat = swimmer.isLegendary ? 1.35 : 1.0
        sprite.xScale = bodyScale * (1 - abs(sin(tailPhase)) * 0.06)
        sprite.yScale = bodyScale

        // Flaches Wasser: besser zu sehen. Tiefes Wasser: nur ein Schemen.
        let depth = map.depth(at: swimmer.position)
        let visibility = max(0.18, 0.75 - CGFloat(depth) * 0.08)
        // Die Legende bleibt auch im tiefen Wasser erkennbar — sonst findet
        // man sie nie, obwohl der Hinweis stimmt.
        let legendBoost: CGFloat = swimmer.isLegendary ? 0.3 : 0
        sprite.alpha = min(1, visibility + swimmer.attraction * 0.25 + legendBoost)

        // Neugier sichtbar machen.
        let showMark = swimmer.behaviour == .inspect || swimmer.behaviour == .nibble
        interestMark.alpha += ((showMark ? 0.9 : 0) - interestMark.alpha) * min(1, deltaTime * 5)
        interestMark.position = CGPoint(x: 0, y: sprite.size.height * 0.9)

        if outcome == .nibbled {
            showNibble()
        }

        // Ab und zu ein Ring an der Oberfläche — häufiger, wenn der Fisch
        // aufgeregt ist.
        rippleTimer -= deltaTime * (1 + swimmer.attraction * 2)
        if rippleTimer <= 0 {
            rippleTimer = CGFloat.random(in: 3...9)
            showRipple()
        }

        return outcome
    }

    /// Der Fisch erschrickt, etwa vom einschlagenden Köder.
    func spook(from point: CGPoint) {
        FishAI.spook(&swimmer, awayFrom: point)
    }

    private func showNibble() {
        sprite.removeAllActions()
        sprite.run(.sequence([
            .scale(to: 1.12, duration: 0.08),
            .scale(to: 1.0, duration: 0.16)
        ]))
        showRipple()
    }

    private func showRipple() {
        ripple.removeAllActions()
        ripple.setScale(0.3)
        ripple.alpha = 0.45
        ripple.run(.group([
            .scale(to: 1.8, duration: 1.6),
            .fadeOut(withDuration: 1.6)
        ]))
    }
}
