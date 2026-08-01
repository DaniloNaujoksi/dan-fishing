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
    private let shadowLayer = SKNode()
    private let plantLayer = SKNode()
    private let actorLayer = SKNode()
    private let tackleLayer = SKNode()
    private let shoreLayer = SKNode()
    private let weatherLayer = SKNode()
    private let cameraNode = SKCameraNode()

    private let boatNode = BoatNode()
    private let bobber = BobberNode()
    private let line = FishingLineNode()
    private let aimPreview = AimPreviewNode()
    private let tintOverlay = SKSpriteNode()
    private var lanternNode: SKSpriteNode?

    private var fishNodes: [FishNode] = []
    private var lastUpdate: TimeInterval = 0
    private var petalTimer: CGFloat = 0

    /// 0…1 — wie stramm die Schnur zwischen Boot und Köder gerade steht.
    private var lineTension: CGFloat = 0
    private var wasLineTaut = false

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

        // Feste Zeichenreihenfolge statt „wer zuerst kommt, liegt hinten“.
        let layers: [(SKNode, SceneLayer)] = [
            (waterLayer, .water),
            (zoneLayer, .zones),
            (underwaterLayer, .underwaterPlants),
            (fishLayer, .fish),
            (shadowLayer, .shadows),
            (plantLayer, .floatingPlants),
            (actorLayer, .boat),
            (tackleLayer, .line),
            (shoreLayer, .shore),
            (weatherLayer, .weather)
        ]
        for (node, layer) in layers {
            node.zPosition = layer.z
            worldNode.addChild(node)
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
                // Totholz liegt unter Wasser, Fische stehen darüber.
                underwaterLayer.addChild(node)
            case .lilyPad, .reed:
                // Schwimmpflanzen bleiben unter dem Boot — sonst verschwindet
                // der Kahn beim Durchfahren im Blattwerk.
                plantLayer.addChild(node)
            default:
                // Bäume, Steine und Schrein stehen am Ufer und dürfen über das
                // Boot ragen; dorthin kommt es ohnehin nicht.
                shoreLayer.addChild(node)
            }
        }
    }

    private func buildActors() {
        boatNode.position = boat.position
        boatNode.zRotation = boat.heading
        actorLayer.addChild(boatNode)

        // Schnur und Köder liegen zusammen über dem Boot. Innerhalb der Ebene
        // gilt: Schnur unten, Köder darüber.
        line.zPosition = 0
        tackleLayer.addChild(line)

        bobber.zPosition = 10
        bobber.isHidden = true
        tackleLayer.addChild(bobber)

        // Die Zielhilfe liegt auf dem Wasser, also unter Boot und Schnur.
        aimPreview.zPosition = SceneLayer.shadows.z + 10
        worldNode.addChild(aimPreview)
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

        // Liegt der Köder im Wasser, hängt das Boot an der Schnur.
        if let anchor = fishing.bobberPosition, fishing.phase != .flying {
            let maxLength = CGFloat(session.stats.castRange) * 1.2 + 140
            lineTension = boat.applyLineTether(anchor: anchor,
                                               maxLength: maxLength,
                                               deltaTime: dt)

            // Am Anschlag rückmelden — einmal pro Straffung, nicht dauernd.
            if lineTension > 0.85 {
                if !wasLineTaut {
                    wasLineTaut = true
                    HapticManager.shared.tensionWarning()
                    AudioManager.shared.play(.reel)
                    bobber.showTug()
                }
            } else if lineTension < 0.5 {
                wasLineTaut = false
            }
        } else {
            lineTension = 0
            wasLineTaut = false
        }

        boatNode.position = boat.position
        boatNode.zRotation = boat.heading
        boatNode.update(deltaTime: dt, rowing: boat.rowingIntensity, speed: boat.speed)

        session.rememberBoatPosition(boat.position)
    }

    private func updateFishing(delta: TimeInterval) {
        let context = fishingContext()
        fishing.update(deltaTime: delta, context: context, bait: session.selectedBait)

        updateAimPreview()

        // Schwimmer und Schnur nachführen.
        if let position = fishing.bobberPosition {
            bobber.isHidden = false
            bobber.position = position
            bobber.update(deltaTime: CGFloat(delta))
            // Während des Flugs wirkt der Köder größer und wirft einen
            // Schatten daneben — das liest sich als Höhe über dem Wasser.
            bobber.setFlightHeight(fishing.lureHeight)

            // Im Drill zeigt die Schnur die Spannung des Fisches, sonst die
            // Straffung durch die Bootsfahrt.
            let tension = max(CGFloat(session.miniGame?.tension ?? 0), lineTension)
            line.update(from: boatNode.rodTipPosition, to: position, tension: tension)
        } else {
            bobber.isHidden = true
            line.clear()
        }

        // Die Rute lädt sich sichtbar auf, solange gezielt wird.
        boatNode.setCastPose(fishing.phase == .aiming ? CGFloat(fishing.castPower) : nil,
                             aimDirection: fishing.aimDirection,
                             boatHeading: boat.heading)

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
        petal.position = CGPoint(x: cameraNode.position.x + CGFloat.random(in: -500...500),
                                 y: cameraNode.position.y + 600)
        weatherLayer.addChild(petal)

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

    /// Finger aufgesetzt. Liegt der Köder schon im Wasser, ist das der
    /// Anschlag; sonst beginnt das Zielen.
    func beginAim() {
        guard session.miniGame == nil else { return }

        switch fishing.phase {
        case .idle:
            fishing.beginAim(direction: CGVector(dx: cos(boat.heading), dy: sin(boat.heading)))
            aimPreview.show()
        case .waiting, .nibble, .biteWindow:
            fishing.strike(stats: session.stats)
        default:
            break
        }
    }

    /// Fingerbewegung. `drag` ist der Vektor vom Aufsetzpunkt zum Finger, in
    /// Punkten und bereits in Weltausrichtung (y zeigt nach oben).
    func updateAim(drag: CGVector) {
        guard fishing.phase == .aiming else { return }

        let length = hypot(drag.dx, drag.dy)

        // Kurze Fingerbewegung = kurzer Wurf. Nach dieser Strecke ist die
        // volle Weite erreicht; darüber hinaus ändert sich nichts mehr.
        let fullPullDistance: CGFloat = 170
        let power = Double(min(1, length / fullPullDistance))

        // Gezogen wird in die Richtung, in die geworfen werden soll.
        fishing.updateAim(direction: length > 6 ? drag : fishing.aimDirection, power: power)
    }

    func releaseAim() {
        guard fishing.phase == .aiming else { return }

        if fishing.releaseCast(from: boatNode.rodTipPosition,
                               stats: session.stats,
                               map: map) != nil {
            AudioManager.shared.play(.cast)
            HapticManager.shared.selection()
        }
        aimPreview.hide()
    }

    func cancelAim() {
        aimPreview.hide()
    }

    func reelIn() {
        guard session.miniGame == nil else { return }
        fishing.reelIn()
        aimPreview.hide()
    }

    /// Führt die Zielhilfe nach: Bahn, Landepunkt und Reichweite.
    private func updateAimPreview() {
        guard fishing.phase == .aiming else {
            aimPreview.hide()
            return
        }

        let origin = boatNode.rodTipPosition
        let target = fishing.previewTarget(from: origin, stats: session.stats)
        let landing = firstWaterPoint(from: origin, to: target)

        aimPreview.show()
        aimPreview.update(from: origin,
                          to: landing.point,
                          maxRange: CGFloat(session.stats.castRange),
                          blocked: landing.blocked)
    }

    /// Sucht entlang der Wurfbahn den letzten Punkt über Wasser. Zeigt die
    /// Bahn auf Land, weiß der Spieler das vor dem Loslassen.
    private func firstWaterPoint(from origin: CGPoint, to target: CGPoint) -> (point: CGPoint, blocked: Bool) {
        guard map.isLand(at: target) else { return (target, false) }

        let steps = 18
        var lastWater = origin
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let probe = CGPoint(x: origin.x + (target.x - origin.x) * t,
                                y: origin.y + (target.y - origin.y) * t)
            if map.isLand(at: probe) { break }
            lastWater = probe
        }
        return (lastWater, true)
    }
}
