import SpriteKit

/// Die Spielszene. Sie hält die Schleife zusammen und zeichnet — gerechnet wird
/// in den Systemen (`BoatController`, `FishingSystem`, `FishAI`, `DayNightSystem`).
///
/// Aufbau der Ebenen von hinten nach vorn:
/// Wasser → Bodenzonen → Kulisse unter Wasser → Fische → Boot und Schnur →
/// Kulisse über Wasser → Nebel und Lichtstimmung → Blüten.
final class LakeScene: SKScene {

    // MARK: - Abhängigkeiten

    unowned let session: GameSession
    private(set) var map: LakeMap

    // MARK: - Systeme

    private var boat: BoatController
    private let fishing = FishingSystem()
    private var dayNight = DayNightSystem()

    // MARK: - Knoten

    private let worldNode = SKNode()
    private let waterLayer = SKNode()
    private let zoneLayer = SKNode()
    private let underwaterLayer = SKNode()
    private let fishLayer = SKNode()
    private let actorLayer = SKNode()
    private let surfaceLayer = SKNode()
    private let weatherLayer = SKNode()
    private let cameraNode = SKCameraNode()

    private let boatNode = BoatNode()
    private let bobber = BobberNode()
    private let line = FishingLineNode()
    private let tintOverlay = SKSpriteNode()
    private var lanternNode: SKSpriteNode?

    private var fishNodes: [FishNode] = []
    private var lastUpdate: TimeInterval = 0
    private var petalTimer: CGFloat = 0

    // MARK: - Aufbau

    init(size: CGSize, session: GameSession) {
        self.session = session
        self.map = LakeMap.generate()
        let start = session.storedBoatPosition ?? map.startPosition
        self.boat = BoatController(position: map.nearestWater(from: start))
        super.init(size: size)

        scaleMode = .resizeFill
        backgroundColor = Palette.waterDeep.skColor
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) wird nicht verwendet")
    }

    override func didMove(to view: SKView) {
        guard worldNode.parent == nil else { return }

        addChild(worldNode)
        [waterLayer, zoneLayer, underwaterLayer, fishLayer, actorLayer, surfaceLayer, weatherLayer]
            .enumerated()
            .forEach { index, layer in
                layer.zPosition = CGFloat(index) * 100
                worldNode.addChild(layer)
            }

        buildWater()
        buildZones()
        buildDecor()
        buildActors()
        buildOverlay()
        spawnInitialFish()

        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = boat.position
        // Etwas herausgezoomt: Man soll die nächste Schilfkante und das
        // Seerosenfeld sehen, ohne erst hinrudern zu müssen.
        cameraNode.setScale(1.35)

        fishing.onEvent = { [weak self] event in
            self?.handleFishing(event: event)
        }
    }

    // MARK: - Weltaufbau

    private func buildWater() {
        let worldSize = map.worldSize

        let base = SKSpriteNode(color: Palette.water.skColor, size: worldSize)
        base.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        waterLayer.addChild(base)

        // Wellen und Papierkorn gehören über die Zonenflächen, nicht darunter:
        // Die Zonen sind teilweise deckend und würden beides verschlucken.
        // Deshalb hängen sie im zoneLayer ganz oben.
        if let stripes = TextureFactory.waveStripes() {
            for (index, speed) in [(0, 34.0), (1, 19.0)] {
                let waves = SKSpriteNode(texture: stripes)
                waves.size = CGSize(width: worldSize.width * 1.2, height: worldSize.height * 1.2)
                waves.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
                waves.alpha = index == 0 ? 0.5 : 0.32
                waves.zPosition = 10 + CGFloat(index)
                zoneLayer.addChild(waves)

                let drift = SKAction.sequence([
                    .moveBy(x: 60, y: 26, duration: speed),
                    .moveBy(x: -60, y: -26, duration: speed)
                ])
                waves.run(.repeatForever(drift))
            }
        }

        if let grain = TextureFactory.paperGrain() {
            let paper = SKSpriteNode(texture: grain)
            paper.size = worldSize
            paper.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
            paper.alpha = 0.55
            paper.zPosition = 12
            paper.blendMode = .alpha
            zoneLayer.addChild(paper)
        }
    }

    /// Zonen als weiche Farbflächen. Aus ihnen liest der Spieler ab, wo sich
    /// das Angeln lohnt: helle Ufer, dunkles Tiefwasser, grüne Seerosenfelder.
    /// Die gesamte Zonenkarte steckt in einer einzigen Textur — weiche Ränder
    /// statt sichtbarem Raster, und ein Knoten statt über dreitausend.
    private func buildZones() {
        guard let texture = TextureFactory.zoneMap(map: map) else { return }

        let zones = SKSpriteNode(texture: texture)
        zones.size = map.worldSize
        zones.position = CGPoint(x: map.worldSize.width / 2, y: map.worldSize.height / 2)
        zones.zPosition = 1
        zoneLayer.addChild(zones)
    }

    private func buildDecor() {
        for item in map.decor {
            guard let node = DecorFactory.node(for: item) else { continue }
            switch item.kind {
            case .log:
                node.zPosition = 1
                underwaterLayer.addChild(node)
            case .lilyPad, .reed:
                node.zPosition = 2
                surfaceLayer.addChild(node)
            default:
                node.zPosition = 3
                surfaceLayer.addChild(node)
            }
        }
    }

    private func buildActors() {
        boatNode.position = boat.position
        boatNode.zRotation = boat.heading
        boatNode.zPosition = 10
        actorLayer.addChild(boatNode)

        bobber.zPosition = 9
        bobber.isHidden = true
        actorLayer.addChild(bobber)

        line.zPosition = 11
        actorLayer.addChild(line)
    }

    private func buildOverlay() {
        // Farbschleier für Tageszeit und Wetter.
        tintOverlay.color = .black
        tintOverlay.size = CGSize(width: 4000, height: 4000)
        tintOverlay.alpha = 0
        tintOverlay.zPosition = 500
        tintOverlay.blendMode = .alpha
        cameraNode.addChild(tintOverlay)

        // Nebelbänke am Rand des Bildes.
        if let fog = TextureFactory.softDisc(color: UIColor(white: 1, alpha: 0.35)) {
            for index in 0..<5 {
                let bank = SKSpriteNode(texture: fog)
                bank.size = CGSize(width: 900, height: 420)
                bank.alpha = 0.18
                bank.position = CGPoint(x: CGFloat.random(in: 0..<map.worldSize.width),
                                        y: CGFloat.random(in: 0..<map.worldSize.height))
                bank.zPosition = CGFloat(index)
                weatherLayer.addChild(bank)

                let drift = SKAction.sequence([
                    .moveBy(x: 140, y: 30, duration: 26 + Double(index) * 4),
                    .moveBy(x: -140, y: -30, duration: 26 + Double(index) * 4)
                ])
                bank.run(.repeatForever(drift))
            }
        }
    }

    private func spawnInitialFish() {
        // Pro Zone Schwimmer im ganzen See — sie sind die sichtbare Antwort auf
        // die Frage „wo lohnt es sich?“.
        for habitat in Habitat.allCases {
            addFish(in: habitat, count: 14, near: nil, radius: 0)
        }

        // Zusätzlich eine Handvoll direkt um den Startplatz. Ohne sie wäre der
        // erste Blick auf den See leer, und der Spieler weiß nicht, worauf er
        // achten soll.
        for habitat in Habitat.allCases {
            addFish(in: habitat, count: 4, near: boat.position, radius: 1100)
        }
    }

    private func addFish(in habitat: Habitat, count: Int, near point: CGPoint?, radius: CGFloat) {
        let candidates = FishCatalog.species(in: habitat)
        guard !candidates.isEmpty else { return }

        for _ in 0..<count {
            guard let position = FishAI.randomPosition(in: habitat,
                                                       map: map,
                                                       near: point,
                                                       radius: radius > 0 ? radius : 900) else { break }
            let species = candidates[Int.random(in: 0..<candidates.count)]

            let swimmer = FishAI.Swimmer(position: position,
                                         heading: CGFloat.random(in: 0..<(.pi * 2)),
                                         speed: CGFloat.random(in: 18...46),
                                         habitat: habitat,
                                         speciesID: species.id,
                                         scale: CGFloat.random(in: 0.6...1.3),
                                         turnTimer: CGFloat.random(in: 0.5...2.5))

            let node = FishNode(swimmer: swimmer, species: species)
            node.zPosition = CGFloat.random(in: 0...5)
            fishLayer.addChild(node)
            fishNodes.append(node)
        }
    }

    // MARK: - Eingaben

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Antippen des Wassers: das Boot rudert selbstständig dorthin.
        guard session.miniGame == nil, let touch = touches.first else { return }
        let point = touch.location(in: worldNode)
        guard !map.isLand(at: point) else { return }
        boat.setAutoTarget(point)
    }

    // MARK: - Schleife

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdate == 0 ? 1.0 / 60.0 : min(currentTime - lastUpdate, 1.0 / 20.0)
        lastUpdate = currentTime
        let dt = CGFloat(delta)

        dayNight.update(deltaTime: delta)
        updateBoat(dt: dt)
        updateFishing(delta: delta)
        updateFish(dt: dt)
        updateCamera(dt: dt)
        updateAtmosphere(dt: dt)
        publishEnvironment()
    }

    private func updateBoat(dt: CGFloat) {
        // Während des Drills bleibt das Boot stehen — sonst kämpft man gegen
        // zwei Dinge gleichzeitig.
        let input = session.miniGame == nil ? session.joystick : .zero

        if let target = session.tapTarget {
            boat.setAutoTarget(target)
            session.tapTarget = nil
        }

        boat.update(deltaTime: dt, input: input, stats: session.stats, map: map)
        boatNode.position = boat.position
        boatNode.zRotation = boat.heading
        boatNode.update(deltaTime: dt, rowing: boat.rowingIntensity, speed: boat.speed)

        session.rememberBoatPosition(boat.position)
    }

    private func updateFishing(delta: TimeInterval) {
        let context = fishingContext()
        fishing.update(deltaTime: delta, context: context, bait: session.selectedBait)

        // Schwimmer und Schnur nachführen.
        if let position = fishing.bobberPosition {
            bobber.isHidden = false
            bobber.position = position
            bobber.update(deltaTime: CGFloat(delta))

            let tension = CGFloat(session.miniGame?.tension ?? 0)
            line.update(from: boatNode.rodTipPosition, to: position, tension: tension)
        } else {
            bobber.isHidden = true
            line.clear()
        }

        boatNode.setCastPose(fishing.phase == .charging ? CGFloat(fishing.castPower) : nil)

        // Drill weiterrechnen; endet er, wird die Angel eingeholt.
        if session.isFightRunning {
            let stillRunning = session.updateFight(deltaTime: delta)
            if !stillRunning {
                fishing.finishFight()
            }
        }

        session.updateFishingState(phase: fishing.phase, castPower: fishing.castPower)
    }

    private func updateFish(dt: CGFloat) {
        let lure = fishing.bobberPosition
        let bait = session.selectedBait

        for node in fishNodes {
            // Wie stark sich dieser Fisch für den Köder interessiert.
            var interest: CGFloat = 0
            if lure != nil,
               let species = FishCatalog.species(id: node.swimmer.speciesID),
               let context = fishingContext() {
                let weight = BaitSystem.attraction(species: species, bait: bait, context: context)
                interest = CGFloat(min(1.0, weight / 1.5))
            }
            node.update(deltaTime: dt, map: map, lure: lure, interest: interest)
        }
    }

    private func updateCamera(dt: CGFloat) {
        // Die Kamera zieht weich nach und schaut leicht in Fahrtrichtung voraus.
        let lead = CGPoint(x: boat.position.x + boat.velocity.dx * 0.35,
                           y: boat.position.y + boat.velocity.dy * 0.35)
        let smoothing = min(1, dt * 3.2)
        cameraNode.position = CGPoint(x: cameraNode.position.x + (lead.x - cameraNode.position.x) * smoothing,
                                      y: cameraNode.position.y + (lead.y - cameraNode.position.y) * smoothing)
    }

    private func updateAtmosphere(dt: CGFloat) {
        // Farbschleier für die Tageszeit.
        let darkness = CGFloat(dayNight.darkness)
        let warmth = CGFloat(dayNight.warmth)

        if warmth > 0.05 {
            tintOverlay.color = ColorSpec(0xE8A46A).skColor
            tintOverlay.alpha = warmth * 0.22
        } else {
            tintOverlay.color = ColorSpec(0x101C2C).skColor
            tintOverlay.alpha = darkness * 0.55
        }

        updateLantern(darkness: darkness)
        updatePetals(dt: dt)
    }

    /// Laterne: nur nachts und nur, wenn gekauft. Sie schneidet einen hellen
    /// Kreis in den Nachtschleier.
    private func updateLantern(darkness: CGFloat) {
        let radius = CGFloat(session.stats.lanternRadius)
        guard radius > 0, darkness > 0.15 else {
            lanternNode?.removeFromParent()
            lanternNode = nil
            return
        }

        if lanternNode == nil, let texture = TextureFactory.softDisc(color: UIColor(white: 1, alpha: 0.9)) {
            let node = SKSpriteNode(texture: texture)
            node.blendMode = .add
            node.zPosition = 480
            cameraNode.addChild(node)
            lanternNode = node
        }

        lanternNode?.size = CGSize(width: radius * 2, height: radius * 2)
        lanternNode?.alpha = darkness * 0.32
        // Leichtes Flackern der Flamme.
        lanternNode?.setScale(1 + sin(CGFloat(lastUpdate) * 3) * 0.02)
    }

    /// Kirschblüten, die über das Bild treiben.
    private func updatePetals(dt: CGFloat) {
        petalTimer -= dt
        guard petalTimer <= 0 else { return }
        petalTimer = CGFloat.random(in: 0.6...1.8)

        guard let texture = TextureFactory.petal(color: Palette.blossom.skColor) else { return }

        let petal = SKSpriteNode(texture: texture)
        petal.size = CGSize(width: 14, height: 14)
        petal.alpha = 0.9
        petal.zPosition = 520
        petal.position = CGPoint(x: cameraNode.position.x + CGFloat.random(in: -400...400),
                                 y: cameraNode.position.y + 500)
        worldNode.addChild(petal)

        let duration = Double.random(in: 7...12)
        let drift = CGFloat.random(in: -160...160)
        petal.run(.sequence([
            .group([
                .moveBy(x: drift, y: -1100, duration: duration),
                .rotate(byAngle: CGFloat.random(in: -6...6), duration: duration),
                .sequence([.wait(forDuration: duration - 1.4), .fadeOut(withDuration: 1.4)])
            ]),
            .removeFromParent()
        ]))
    }

    private func publishEnvironment() {
        let point = fishing.bobberPosition ?? boat.position
        let habitat = map.habitat(at: point)
        let depth = map.depth(at: point)

        var activity = 0.0
        if let context = fishingContext() {
            activity = FishSpawner.activityScore(bait: session.selectedBait, context: context)
        }

        session.updateEnvironment(timeOfDay: dayNight.phase,
                                  clock: dayNight.clockText,
                                  depth: depth,
                                  habitat: habitat,
                                  activity: activity)
    }

    /// Bedingungen dort, wo der Köder liegt (oder wo das Boot steht, solange
    /// nicht geworfen wurde).
    private func fishingContext() -> BaitSystem.Context? {
        let point = fishing.bobberPosition ?? boat.position
        guard let habitat = map.habitat(at: point) else { return nil }
        return BaitSystem.Context(habitat: habitat,
                                  timeOfDay: dayNight.phase,
                                  depth: map.depth(at: point),
                                  playerLevel: session.save.level,
                                  stats: session.stats)
    }

    // MARK: - Angel-Ereignisse

    private func handleFishing(event: FishingSystem.Event) {
        switch event {
        case .castLanded:
            bobber.showSplash()
        case .nibble:
            bobber.showNibble()
        case .bite:
            bobber.showBite()
        default:
            break
        }
        session.handle(event: event)
    }

    // MARK: - Schnittstelle für die Oberfläche

    func beginCast() {
        guard session.miniGame == nil else { return }
        if fishing.phase == .idle {
            fishing.beginCharge()
            AudioManager.shared.play(.reel)
        } else if fishing.phase == .waiting || fishing.phase == .nibble || fishing.phase == .biteWindow {
            // Während der Köder liegt, ist die Taste der Anschlag.
            fishing.strike(stats: session.stats)
        }
    }

    func endCast() {
        guard fishing.phase == .charging else { return }

        // Geworfen wird in Blickrichtung des Bootes, mit dem Joystick lässt
        // sich die Richtung vorher feinjustieren.
        var direction = CGVector(dx: cos(boat.heading), dy: sin(boat.heading))
        let joystick = session.joystick
        if hypot(joystick.dx, joystick.dy) > 0.2 {
            direction = joystick
        }

        fishing.releaseCast(from: boatNode.rodTipPosition,
                            direction: direction,
                            stats: session.stats,
                            map: map)
        AudioManager.shared.play(.cast)
    }

    func reelIn() {
        guard session.miniGame == nil else { return }
        fishing.reelIn()
    }
}
