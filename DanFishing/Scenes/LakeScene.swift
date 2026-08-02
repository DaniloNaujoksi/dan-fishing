import SpriteKit

/// Die Spielszene. Sie hält die Schleife zusammen und zeichnet — gerechnet wird
/// in den Systemen (`MovementController`, `FishingSystem`, `FishAI`, `DayNightSystem`).
///
/// Aufbau der Ebenen von hinten nach vorn:
/// Wasser → Bodenzonen → Kulisse unter Wasser → Fische → Boot und Schnur →
/// Kulisse über Wasser → Nebel und Lichtstimmung → Blüten.
final class LakeScene: SKScene {

    // MARK: - Abhängigkeiten

    unowned let session: GameSession
    /// Das Gewässer dieser Szene. Es bestimmt Karte, Fischbestand und Farben.
    let water: Water
    private(set) var map: LakeMap

    // MARK: - Systeme

    private var player: MovementController
    private let fishing = FishingSystem()
    private var dayNight = DayNightSystem()

    // MARK: - Knoten

    private let worldNode = SKNode()
    private let waterLayer = SKNode()
    private let zoneLayer = SKNode()
    private let underwaterLayer = SKNode()
    private let fishLayer = SKNode()
    private let foamLayer = SKNode()
    private let shadowLayer = SKNode()
    private let plantLayer = SKNode()
    private let actorLayer = SKNode()
    private let tackleLayer = SKNode()
    private let shoreLayer = SKNode()
    private let weatherLayer = SKNode()
    private let cameraNode = SKCameraNode()

    /// Boot oder Angler zu Fuß — das Gewässer entscheidet.
    private let actorNode: ActorNode
    /// Der Angler zu Fuß, falls dieses Gewässer ohne Boot gefischt wird.
    private var anglerNode: AnglerNode? { actorNode as? AnglerNode }
    private let bobber = BobberNode()
    private let line = FishingLineNode()
    private let aimPreview = AimPreviewNode()
    private let tintOverlay = SKSpriteNode()
    private var lanternNode: SKSpriteNode?

    private var fishNodes: [FishNode] = []
    /// Der legendäre Fisch dieses Gewässers, falls er hier steht.
    private var legendNode: FishNode?

    /// Die Schleppfahrt, die einem Brocken vorausgeht.
    private struct PowerDrag {
        var remaining: CGFloat
        let anchor: CGPoint
        let fish: HookedFish
    }
    private var powerDrag: PowerDrag?
    /// Versatz für das Zittern der Kamera.
    private var cameraShake: CGPoint = .zero
    private var lastUpdate: TimeInterval = 0
    private var petalTimer: CGFloat = 0

    /// 0…1 — wie stramm die Schnur zwischen Boot und Köder gerade steht.
    private var lineTension: CGFloat = 0
    private var wasLineTaut = false

    private var ambience: AmbienceEmitter?
    private var wakeTimer: CGFloat = 0
    private var minimapTimer: CGFloat = 0
    private var configuredBaitID: String?

    // MARK: - Aufbau

    init(size: CGSize, session: GameSession) {
        self.session = session
        let water = session.currentWater
        let map = LakeMap.generate(for: water)
        self.water = water
        self.map = map

        let stored = session.storedBoatPosition ?? map.startPosition
        var controller = MovementController(position: stored)

        switch water.movement {
        case .boat:
            controller.place(at: map.nearestWater(from: stored))
            self.actorNode = BoatNode()
        case .wading:
            // Zu Fuß gelten umgekehrte Regeln, deshalb wird der Startplatz
            // erst gesucht, wenn die Bewegungsart feststeht.
            controller.mode = .wading(maxDepth: session.stats.wadingDepth)
            controller.place(at: LakeScene.freeSpot(near: stored,
                                                    controller: controller,
                                                    map: map))
            self.actorNode = AnglerNode()
        }

        self.player = controller
        super.init(size: size)

        scaleMode = .resizeFill
        backgroundColor = water.deepColor.skColor
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) wird nicht verwendet")
    }

    /// Sucht spiralförmig einen Punkt, an dem die Figur stehen darf.
    ///
    /// Nötig, weil ein gespeicherter Platz nach dem Kauf einer Wathose noch
    /// passen kann, ohne sie aber mitten im Wasser läge.
    private static func freeSpot(near point: CGPoint,
                                 controller: MovementController,
                                 map: LakeMap) -> CGPoint {
        if !controller.isBlocked(point, map: map) { return point }

        var radius = map.cellSize
        while radius <= map.cellSize * 12 {
            for step in 0..<24 {
                let angle = CGFloat(step) / 24 * .pi * 2
                let probe = CGPoint(x: point.x + cos(angle) * radius,
                                    y: point.y + sin(angle) * radius)
                if !controller.isBlocked(probe, map: map) { return probe }
            }
            radius += map.cellSize
        }
        return map.startPosition
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
            (foamLayer, .shadows),
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
        buildShoreFoam()
        buildCurrentStreaks()
        buildDecor()
        buildActors()
        buildOverlay()
        spawnInitialFish()

        ambience = AmbienceEmitter(layer: weatherLayer, map: map)
        session.setMinimapImage(TextureFactory.minimapImage(for: map), worldSize: map.worldSize)

        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = player.position
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

        let base = SKSpriteNode(color: water.shallowColor.skColor, size: worldSize)
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
                // Dezent: Das Wasser soll ruhig wirken, nicht gemustert.
                waves.alpha = index == 0 ? 0.22 : 0.13
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
            paper.alpha = 0.28
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
        guard let texture = TextureFactory.zoneMap(map: map, water: water) else { return }

        let zones = SKSpriteNode(texture: texture)
        zones.size = map.worldSize
        zones.position = CGPoint(x: map.worldSize.width / 2, y: map.worldSize.height / 2)
        zones.zPosition = 1
        zoneLayer.addChild(zones)
    }

    /// Brandungssaum am Ufer.
    ///
    /// Entlang jeder Wasserzelle, die an Land grenzt, liegt ein heller Bogen,
    /// der langsam anschwillt und wieder zurückläuft. Die Bögen sind zeitlich
    /// versetzt, sodass die Wellen die Uferlinie entlangwandern, statt im
    /// Gleichtakt zu blinken.
    private func buildShoreFoam() {
        let cell = map.cellSize
        var placed = 0

        for row in 0..<map.rows {
            for column in 0..<map.columns {
                guard map.kind(column: column, row: row) != .land else { continue }

                // Richtung zum angrenzenden Land bestimmen.
                var landDirection: CGVector?
                if map.kind(column: column, row: row + 1) == .land {
                    landDirection = CGVector(dx: 0, dy: 1)
                } else if map.kind(column: column, row: row - 1) == .land {
                    landDirection = CGVector(dx: 0, dy: -1)
                } else if map.kind(column: column + 1, row: row) == .land {
                    landDirection = CGVector(dx: 1, dy: 0)
                } else if map.kind(column: column - 1, row: row) == .land {
                    landDirection = CGVector(dx: -1, dy: 0)
                }

                guard let direction = landDirection else { continue }

                let center = CGPoint(x: (CGFloat(column) + 0.5) * cell,
                                     y: (CGFloat(row) + 0.5) * cell)

                let foam = SKShapeNode()
                let path = CGMutablePath()
                let width = cell * 0.9
                let bulge = cell * 0.18

                // Bogen quer zur Uferrichtung, zum Land hin gewölbt.
                let across = CGVector(dx: -direction.dy, dy: direction.dx)
                let start = CGPoint(x: center.x - across.dx * width / 2,
                                    y: center.y - across.dy * width / 2)
                let end = CGPoint(x: center.x + across.dx * width / 2,
                                  y: center.y + across.dy * width / 2)
                let control = CGPoint(x: center.x + direction.dx * bulge * 2,
                                      y: center.y + direction.dy * bulge * 2)

                path.move(to: start)
                path.addQuadCurve(to: end, control: control)

                foam.path = path
                foam.strokeColor = SKColor(white: 1, alpha: 0.55)
                foam.lineWidth = 3
                foam.lineCap = .round
                foam.alpha = 0
                foam.position = CGPoint(x: direction.dx * cell * 0.22,
                                        y: direction.dy * cell * 0.22)
                foamLayer.addChild(foam)

                // Zeitversatz aus der Lage: benachbarte Bögen laufen kurz
                // nacheinander an, das ergibt die wandernde Welle.
                let offset = Double((column + row * 2) % 9) * 0.42
                let swell = SKAction.sequence([
                    .wait(forDuration: offset),
                    .repeatForever(.sequence([
                        .group([
                            .fadeAlpha(to: 0.75, duration: 1.5),
                            .moveBy(x: direction.dx * cell * 0.16,
                                    y: direction.dy * cell * 0.16, duration: 1.5)
                        ]),
                        .group([
                            .fadeAlpha(to: 0.05, duration: 2.0),
                            .moveBy(x: -direction.dx * cell * 0.16,
                                    y: -direction.dy * cell * 0.16, duration: 2.0)
                        ])
                    ]))
                ])
                foam.run(swell)

                placed += 1
                if placed > 900 { return }   // Sicherheitsnetz für sehr zerklüftete Ufer
            }
        }
    }

    /// Sichtbare Strömung: feine helle Striche, die talwärts wandern.
    ///
    /// Ohne sie merkt man erst am abtreibenden Köder, dass das Wasser zieht.
    /// Die Striche stehen nur dort, wo wirklich Strömung ist — an der
    /// Bachmündung des Sees also genau in dem einen Streifen.
    private func buildCurrentStreaks() {
        let cell = map.cellSize
        var placed = 0

        for row in 0..<map.rows {
            for column in 0..<map.columns {
                let center = CGPoint(x: (CGFloat(column) + 0.5) * cell,
                                     y: (CGFloat(row) + 0.5) * cell)

                let flow = map.current(at: center)
                let speed = hypot(flow.dx, flow.dy)
                guard speed > 8 else { continue }

                // Je stärker der Zug, desto dichter die Striche.
                let density = min(0.85, speed / 70)
                guard CGFloat.random(in: 0...1) < density else { continue }

                let length = cell * (0.3 + CGFloat.random(in: 0...0.35))
                let streak = SKShapeNode(rectOf: CGSize(width: 1.6, height: length),
                                         cornerRadius: 0.8)
                streak.fillColor = SKColor(white: 1, alpha: 0.5)
                streak.strokeColor = .clear
                streak.alpha = 0
                streak.position = CGPoint(x: center.x + CGFloat.random(in: -0.4...0.4) * cell,
                                          y: center.y + CGFloat.random(in: -0.5...0.5) * cell)
                foamLayer.addChild(streak)

                // Einmal durch die Zelle treiben, dabei auf- und wieder
                // abblenden — und danach von vorn, mit eigenem Versatz.
                let travel = cell * 1.6
                let duration = Double(travel / speed)
                let run = SKAction.sequence([
                    .run { streak.position.y -= travel / 2 },
                    .group([
                        .moveBy(x: 0, y: travel, duration: duration),
                        .sequence([
                            .fadeAlpha(to: 0.45, duration: duration * 0.3),
                            .wait(forDuration: duration * 0.35),
                            .fadeAlpha(to: 0, duration: duration * 0.35)
                        ])
                    ]),
                    .run { streak.position.y -= travel / 2 }
                ])
                streak.run(.sequence([
                    .wait(forDuration: Double.random(in: 0...duration)),
                    .repeatForever(run)
                ]))

                placed += 1
                if placed > 700 { return }
            }
        }
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
        actorNode.position = player.position
        actorNode.zRotation = player.heading
        actorLayer.addChild(actorNode)

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
            addFish(in: habitat, count: 4, near: player.position, radius: 1100)
        }

        spawnLegend()
    }

    /// Setzt den legendären Fisch aus, falls er in diesem Gewässer steht.
    ///
    /// Er hält sich ausschließlich in seiner Zone auf — der Hinweis ist damit
    /// wirklich die einzige Information, die man braucht.
    private func spawnLegend() {
        guard let legend = session.activeLegend,
              LegendSystem.isPresent(legend, waterID: water.id),
              let species = legend.species,
              let habitat = legend.habitat,
              let position = legendSpot(in: habitat) else { return }

        var swimmer = FishAI.Swimmer(position: position,
                                     heading: CGFloat.random(in: 0..<(.pi * 2)),
                                     speed: 14 + CGFloat(species.fightStrength) * 26,
                                     habitat: habitat,
                                     speciesID: species.id,
                                     scale: 1.4,
                                     turnTimer: CGFloat.random(in: 0.5...2.5),
                                     // Die alten Werte waren nicht schwer,
                                     // sondern unmöglich: Selbst wenn Zone,
                                     // Zeit und Köder passten, lag der
                                     // Appetit rechnerisch immer unter dem
                                     // Misstrauen — sie hat also jedes Mal
                                     // abgelehnt. Jetzt ist sie vorsichtig,
                                     // aber zu überzeugen.
                                     traits: FishAI.Traits(hunger: 0.9,
                                                           curiosity: 0.8,
                                                           caution: 0.5))
        swimmer.isLegendary = true

        let node = FishNode(swimmer: swimmer, species: species)
        node.zPosition = 8
        fishLayer.addChild(node)
        fishNodes.append(node)
        legendNode = node
    }

    private func addFish(in habitat: Habitat, count: Int, near point: CGPoint?, radius: CGFloat) {
        // Nur Arten, die es in diesem Gewässer gibt — im Teich schwimmt kein
        // Stör herum, auch nicht als Kulisse.
        // Auch die Kulisse folgt der Uhr: Nachts stehen die Räuber sichtbar im
        // Flachen, tagsüber sieht man dort nur Weißfisch.
        let candidates = water.species.filter {
            $0.habitats(at: dayNight.phase).contains(habitat)
        }
        guard !candidates.isEmpty else { return }

        for _ in 0..<count {
            guard let position = FishAI.randomPosition(in: habitat,
                                                       map: map,
                                                       near: point,
                                                       radius: radius > 0 ? radius : 900) else { break }
            let species = candidates[Int.random(in: 0..<candidates.count)]

            // Tempo aus der Art ableiten: Barrakuda-artige Räuber ziehen
            // schneller durchs Wasser als ein gründelnder Karpfen.
            let baseSpeed = 16 + CGFloat(species.fightStrength) * 34

            let swimmer = FishAI.Swimmer(position: position,
                                         heading: CGFloat.random(in: 0..<(.pi * 2)),
                                         speed: baseSpeed * CGFloat.random(in: 0.8...1.25),
                                         habitat: habitat,
                                         speciesID: species.id,
                                         scale: CGFloat.random(in: 0.6...1.3),
                                         turnTimer: CGFloat.random(in: 0.5...2.5),
                                         traits: FishAI.Traits.random(for: species))

            let node = FishNode(swimmer: swimmer, species: species)
            node.zPosition = CGFloat.random(in: 0...5)
            fishLayer.addChild(node)
            fishNodes.append(node)
        }
    }

    // MARK: - Eingaben

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Antippen: die Figur geht selbstständig dorthin. Was erreichbar ist,
        // hängt an der Bewegungsart — im Boot Wasser, zu Fuß Ufer und Flachwasser.
        guard session.miniGame == nil, let touch = touches.first else { return }
        let point = touch.location(in: worldNode)
        guard !player.isBlocked(point, map: map) else { return }
        player.setAutoTarget(point)
    }

    // MARK: - Schleife

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdate == 0 ? 1.0 / 60.0 : min(currentTime - lastUpdate, 1.0 / 20.0)
        lastUpdate = currentTime
        let dt = CGFloat(delta)

        // Mitternacht: ein Spieltag ist vorbei. Danach kann eine Legende
        // weitergezogen sein.
        if dayNight.update(deltaTime: delta) {
            session.advanceDay()
        }
        session.updateTutorial(deltaTime: delta)
        updateMovement(dt: dt)
        updateFishing(delta: delta)
        updateFish(dt: dt)
        updateCamera(dt: dt)
        updateAtmosphere(dt: dt)
        updateMinimap(dt: dt)
        publishEnvironment()
    }

    private func updateMovement(dt: CGFloat) {
        // Solange der Fisch das Boot schleppt, hat der Spieler nichts zu
        // sagen — genau das ist die Aussage der Szene.
        if updatePowerDrag(dt: dt) {
            actorNode.position = player.position
            actorNode.zRotation = player.heading
            actorNode.update(deltaTime: dt, effort: 0, speed: 200,
                             night: CGFloat(dayNight.darkness))
            return
        }

        // Während des Drills bleibt die Figur stehen — sonst kämpft man gegen
        // zwei Dinge gleichzeitig.
        let input = session.miniGame == nil ? session.joystick : .zero

        // Eine neu gekaufte Wathose wirkt sofort, ohne Neustart der Szene.
        if water.movement == .wading {
            player.mode = .wading(maxDepth: session.stats.wadingDepth)
        }

        if let target = session.tapTarget {
            player.setAutoTarget(target)
            session.tapTarget = nil
        }

        player.update(deltaTime: dt, input: input, stats: session.stats, map: map)

        // Liegt der Köder im Wasser, hängt das Boot an der Schnur.
        if let anchor = fishing.bobberPosition, fishing.phase != .flying {
            let maxLength = CGFloat(session.stats.castRange) * 1.2 + 140
            lineTension = player.applyLineTether(anchor: anchor,
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

        actorNode.position = player.position
        actorNode.zRotation = player.heading
        actorNode.update(deltaTime: dt,
                         effort: player.rowingIntensity,
                         speed: player.speed,
                         night: CGFloat(dayNight.darkness))
        actorNode.setLantern(level: session.save.upgradeLevels["lantern"] ?? 0)

        // Sichtbare Ausrüstung: am See der Bootsausbau, am Bach die Wathose.
        let upgradeID = water.movement == .wading ? "waders" : "boat"
        actorNode.applyUpgrade(level: session.save.upgradeLevels[upgradeID] ?? 0)

        // Zu Fuß entscheidet der Untergrund, ob er geht oder watet.
        anglerNode?.isWading = player.isInWater(map: map)

        // Kielwasser: je schneller, desto dichter die Ringe. Zu Fuß gibt es
        // stattdessen Spritzer direkt an der Figur.
        if water.movement == .boat, player.speed > 25 {
            wakeTimer -= dt * (0.6 + player.speed / 90)
            if wakeTimer <= 0 {
                wakeTimer = 0.4
                ambience?.spawnWake(at: player.position,
                                    heading: player.heading,
                                    strength: min(1, player.speed / 120))
            }
        }

        session.rememberBoatPosition(player.position)
    }

    private func updateFishing(delta: TimeInterval) {
        let context = fishingContext()
        fishing.update(deltaTime: delta, context: context, bait: session.selectedBait)

        updateAimPreview()

        // Strömung: Der Köder treibt ab, sobald er im ziehenden Wasser liegt.
        // Am See merkt man das nur an der Bachmündung, im Fluss überall.
        if let lure = fishing.bobberPosition {
            let flow = map.current(at: lure)
            if flow.dy != 0 || flow.dx != 0 {
                fishing.drift(CGVector(dx: flow.dx * CGFloat(delta),
                                       dy: flow.dy * CGFloat(delta)),
                              map: map)
            }
        }

        // Aussehen des Köders nachziehen, wenn in der Köderbox gewechselt wurde.
        if configuredBaitID != session.selectedBait.id {
            let hadCast = fishing.phase != .idle

            // Den Köder wechselt man am Haken, nicht auf zwanzig Meter
            // Entfernung. Wer mitten im Wurf umstellt, kurbelt deshalb erst
            // ein — im Drill bleibt der Wechsel ohne Wirkung, dort hängt der
            // Fisch schon am alten Köder.
            if hadCast && session.miniGame == nil {
                fishing.reelIn()
                AudioManager.shared.play(.reel)
                session.showToast("Eingeholt — \(session.selectedBait.name) montiert")
            }

            configuredBaitID = session.selectedBait.id
            bobber.configure(for: session.selectedBait)
        }

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
            // Während der Schleppfahrt steht die Schnur bis zum Anschlag.
            let tension = max(CGFloat(session.miniGame?.tension ?? 0),
                              max(lineTension, powerDrag != nil ? 1 : 0))
            line.update(from: actorNode.rodTipPosition, to: position, tension: tension)
        } else {
            bobber.isHidden = true
            line.clear()
        }

        // Die Rute zeigt beim Zielen in die Wurfrichtung und danach dorthin,
        // wo der Schwimmer liegt — sie folgt also immer der Schnur.
        if fishing.phase == .aiming {
            actorNode.setCastPose(CGFloat(fishing.castPower),
                                 direction: fishing.aimDirection,
                                 heading: player.heading)
        } else if let bobberPosition = fishing.bobberPosition {
            let toBobber = CGVector(dx: bobberPosition.x - player.position.x,
                                    dy: bobberPosition.y - player.position.y)
            actorNode.setCastPose(0, direction: toBobber, heading: player.heading)
        } else {
            actorNode.setCastPose(nil, direction: nil, heading: player.heading)
        }

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
        syncLegend()

        // Nur ein liegender Köder ist interessant — ein fliegender nicht.
        let lure = fishing.isFishing ? fishing.bobberPosition : nil
        let bait = session.selectedBait
        let context = lure != nil ? fishingContext() : nil
        let biteAllowed = fishing.isFishing

        for node in fishNodes {
            // Wie gut Köder, Zone und Tageszeit zu genau dieser Art passen.
            var interest: CGFloat = 0
            if let context {
                let weight = BaitSystem.attraction(species: node.species, bait: bait, context: context)
                interest = CGFloat(min(1.0, weight / 1.2))
            }

            // Die Legende hält sich an ihre eigenen Regeln: Stimmen Zone,
            // Uhrzeit und Köder nicht, sieht sie den Köder gar nicht an.
            // Stimmt alles, ist sie interessiert — aber immer noch scheu.
            if node === legendNode {
                if let context, let legend = session.activeLegend {
                    interest = CGFloat(LegendSystem.biteFactor(legend,
                                                               habitat: context.habitat,
                                                               timeOfDay: context.timeOfDay,
                                                               baitID: bait.id))
                } else {
                    interest = 0
                }
            }

            let outcome = node.update(deltaTime: dt,
                                      map: map,
                                      lure: lure,
                                      interest: interest,
                                      biteAllowed: biteAllowed)

            // Fürs Tutorial: Sobald der erste Fisch den Köder prüft, wird der
            // Spieler darauf hingewiesen.
            if node.swimmer.behaviour == .inspect {
                session.reportTutorial(.fishInspecting)
            }

            switch outcome {
            case .nibbled:
                fishing.reportNibble()
                bobber.showNibble()
                AudioManager.shared.play(.reel)
                HapticManager.shared.reelTick()

            case .bit:
                // Der Fisch, der zugebissen hat, ist auch der Fisch am Haken.
                // Vorher wurde beim Biss neu ausgewürfelt — dadurch hatte das,
                // was man im Wasser sah, nichts mit dem Fang zu tun.
                guard let context else { break }

                // Die Legende hängt mit ihren eigenen Maßen am Haken.
                if node === legendNode,
                   let legend = session.activeLegend,
                   let hooked = LegendSystem.hookedFish(legend, habitat: context.habitat) {
                    fishing.reportBite(fish: hooked)
                    break
                }

                let length = FishSpawner.rollLength(for: node.species,
                                                    bait: bait,
                                                    stats: session.stats)
                let fish = HookedFish(species: node.species,
                                      lengthCm: length,
                                      weightKg: (node.species.weight(forLength: length) * 100).rounded() / 100,
                                      habitat: context.habitat,
                                      baitID: bait.id)
                fishing.reportBite(fish: fish)

            case .rejected, .none:
                break
            }
        }
    }

    /// Fische in unmittelbarer Nähe des Einschlags erschrecken.
    ///
    /// Die Legende hat einen viel größeren Radius: Ihr direkt auf den Kopf zu
    /// werfen, ist der sicherste Weg, sie für lange Zeit zu vertreiben. Man
    /// muss daneben anbieten und warten.
    private func spookFish(around point: CGPoint) {
        for node in fishNodes {
            let delta = CGVector(dx: node.swimmer.position.x - point.x,
                                 dy: node.swimmer.position.y - point.y)
            let radius: CGFloat = node === legendNode ? 140 : 90
            if hypot(delta.dx, delta.dy) < radius {
                node.spook(from: point)
                if node === legendNode {
                    session.showToast("Zu dicht — er ist weg.")
                }
            }
        }
    }

    /// Sucht den Standplatz der Legende.
    ///
    /// Nicht irgendeine Zelle der Zone: Am äußersten Kartenrand — etwa ganz
    /// unten im Zufluss — steht sie so ungünstig, dass man sie kaum anwerfen
    /// kann. Deshalb bleibt ein Sicherheitsabstand zum Rand, und unter
    /// mehreren Möglichkeiten gewinnt die, die weiter im Wasser liegt.
    private func legendSpot(in habitat: Habitat) -> CGPoint? {
        let all = map.positions(of: habitat)
        guard !all.isEmpty else { return nil }

        let margin = map.cellSize * 3
        let size = map.worldSize
        let inner = all.filter {
            $0.x > margin && $0.x < size.width - margin
                && $0.y > margin && $0.y < size.height - margin
        }

        let pool = inner.isEmpty ? all : inner

        // Von fünf Vorschlägen gewinnt der mit dem meisten offenen Wasser
        // ringsum — dort kann man werfen, ohne im Ufer zu landen.
        var best: (space: Int, point: CGPoint)?
        for _ in 0..<5 {
            guard let candidate = pool.randomElement() else { break }
            var space = 0
            for dy in -2...2 {
                for dx in -2...2 {
                    let probe = CGPoint(x: candidate.x + CGFloat(dx) * map.cellSize,
                                        y: candidate.y + CGFloat(dy) * map.cellSize)
                    if !map.isLand(at: probe) { space += 1 }
                }
            }
            if best == nil || space > best!.space { best = (space, candidate) }
        }

        return best?.point ?? pool.randomElement()
    }

    /// Hält den sichtbaren legendären Fisch mit dem Spielstand im Einklang:
    /// Gefangene verschwinden, neue tauchen auf.
    private func syncLegend() {
        let shouldBeHere = session.legendIsHere

        // Peilsender: Entfernung und Richtung an die Oberfläche geben.
        if session.legendDetectorLevel >= 2, let node = legendNode {
            let delta = CGVector(dx: node.swimmer.position.x - player.position.x,
                                 dy: node.swimmer.position.y - player.position.y)
            // Eine Zelle sind rund fünf Meter Wasser.
            let distance = Double(hypot(delta.dx, delta.dy) / map.cellSize * 5)

            // Nur bei spürbarer Änderung melden — sonst zeichnet die
            // Oberfläche sechzigmal in der Sekunde neu.
            if session.legendDistance == nil || abs(session.legendDistance! - distance) > 1.5 {
                session.legendDistance = distance
                session.legendBearing = Double(atan2(delta.dy, delta.dx))
            }
        } else if session.legendDistance != nil {
            session.legendDistance = nil
            session.legendBearing = nil
        }

        if let node = legendNode, !shouldBeHere {
            node.removeFromParent()
            fishNodes.removeAll { $0 === node }
            legendNode = nil
        } else if legendNode == nil, shouldBeHere {
            spawnLegend()
        }
    }

    private func updateCamera(dt: CGFloat) {
        // Die Kamera zieht weich nach und schaut leicht in Fahrtrichtung voraus.
        let lead = CGPoint(x: player.position.x + player.velocity.dx * 0.35,
                           y: player.position.y + player.velocity.dy * 0.35)
        let smoothing = min(1, dt * 3.2)
        cameraNode.position = CGPoint(x: cameraNode.position.x + (lead.x - cameraNode.position.x) * smoothing + cameraShake.x,
                                      y: cameraNode.position.y + (lead.y - cameraNode.position.y) * smoothing + cameraShake.y)

        // Das Zittern ist ein einmaliger Versatz je Frame, kein Zustand.
        cameraShake = .zero
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

        // Blasen, Libellen, Blätter und Lichtreflexe im sichtbaren Bereich.
        ambience?.update(deltaTime: dt, center: cameraNode.position, darkness: darkness)
    }

    /// Der Schein der Laterne auf dem Wasser.
    ///
    /// Er liegt über dem Nachtschleier — sonst würde ihn genau die Dunkelheit
    /// schlucken, gegen die er leuchten soll — und hängt am Boot, nicht an der
    /// Bildmitte. Warm, weich und leicht unruhig: Man soll nachts hinausfahren
    /// wollen, nicht nur besser sehen.
    private func updateLantern(darkness: CGFloat) {
        let radius = CGFloat(session.stats.lanternRadius)
        guard radius > 0, darkness > 0.12 else {
            lanternNode?.removeFromParent()
            lanternNode = nil
            return
        }

        if lanternNode == nil,
           let texture = TextureFactory.softDisc(color: UIColor(red: 1.0, green: 0.84, blue: 0.56, alpha: 0.9)) {
            let node = SKSpriteNode(texture: texture)
            node.blendMode = .add
            // Über dem Farbschleier der Nacht (zPosition 500).
            node.zPosition = 520
            cameraNode.addChild(node)

            // Ein zweiter, kleinerer Kern direkt unter der Laterne macht den
            // Übergang vom hellen Fleck zum Rand weicher.
            let core = SKSpriteNode(texture: texture)
            core.blendMode = .add
            core.alpha = 0.5
            core.name = "core"
            node.addChild(core)

            lanternNode = node
        }

        guard let glow = lanternNode else { return }

        glow.size = CGSize(width: radius * 2, height: radius * 2)
        (glow.childNode(withName: "core") as? SKSpriteNode)?.size =
            CGSize(width: radius * 0.9, height: radius * 0.9)

        // Der Schein sitzt dort, wo die Laterne hängt: leicht vor dem Boot.
        let offset = CGPoint(x: player.position.x + cos(player.heading) * 30 - cameraNode.position.x,
                             y: player.position.y + sin(player.heading) * 30 - cameraNode.position.y)
        glow.position = offset

        // Flackern aus zwei ungleichen Wellen — nie ganz derselbe Rhythmus.
        let t = CGFloat(lastUpdate)
        let flicker = 1 + sin(t * 3.1) * 0.03 + sin(t * 7.7 + 1.2) * 0.018
        glow.alpha = darkness * 0.46 * flicker
        glow.setScale(flicker)
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

    /// Minimap ein paar Mal pro Sekunde auffrischen.
    private func updateMinimap(dt: CGFloat) {
        minimapTimer -= dt
        guard minimapTimer <= 0 else { return }
        minimapTimer = 0.15

        session.updateMinimap(boat: player.position,
                              heading: player.heading,
                              lure: fishing.bobberPosition)
    }

    private func publishEnvironment() {
        let point = fishing.bobberPosition ?? player.position
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
                                  activity: activity,
                                  darkness: dayNight.darkness)
    }

    /// Bedingungen dort, wo der Köder liegt (oder wo das Boot steht, solange
    /// nicht geworfen wurde).
    private func fishingContext() -> BaitSystem.Context? {
        let point = fishing.bobberPosition ?? player.position
        guard let habitat = map.habitat(at: point) else { return nil }
        return BaitSystem.Context(habitat: habitat,
                                  timeOfDay: dayNight.phase,
                                  depth: map.depth(at: point),
                                  playerLevel: session.save.level,
                                  stats: session.stats,
                                  pool: water.species)
    }

    // MARK: - Angel-Ereignisse

    private func handleFishing(event: FishingSystem.Event) {
        switch event {
        case .castLanded(let point):
            bobber.showSplash()
            // Wer direkt unter dem Einschlag steht, sucht das Weite. Genau
            // neben den Schwarm zu werfen, ist deshalb keine gute Idee.
            spookFish(around: point)
        case .nibble:
            bobber.showNibble()
        case .bite:
            bobber.showBite()

        case .hooked(let fish):
            // Ein Brocken zieht erst einmal das Boot hinter sich her. Der
            // Drill beginnt danach — man soll begriffen haben, was da hängt,
            // bevor die Leiste aufgeht.
            if let anchor = fishing.bobberPosition, isHeavyweight(fish) {
                startPowerDrag(towards: anchor, fish: fish)
                return
            }

        default:
            break
        }
        session.handle(event: event)
    }

    /// Fische, die das Boot bewegen können.
    private func isHeavyweight(_ fish: HookedFish) -> Bool {
        fish.weightKg >= 45 || fish.species.rarity == .monster
    }

    /// Die Schleppfahrt vor dem Drill.
    ///
    /// Das Boot wird ein paar Sekunden lang zum Fisch gezogen, die Schnur
    /// steht stramm, Gischt läuft mit, die Kamera zittert. Erst danach
    /// bekommt die Oberfläche den Haken gemeldet.
    private func startPowerDrag(towards anchor: CGPoint, fish: HookedFish) {
        powerDrag = PowerDrag(remaining: 2.1, anchor: anchor, fish: fish)

        session.showToast("Er nimmt das Boot mit!", emphasis: true)
        AudioManager.shared.play(.lineSnap)
        HapticManager.shared.tensionWarning()

        // Kurzes Zittern in der Kamera, solange es zieht.
        cameraNode.removeAction(forKey: "shake")
        let shake = SKAction.sequence([
            .run { [weak self] in
                guard let self else { return }
                self.cameraShake = CGPoint(x: CGFloat.random(in: -7...7),
                                           y: CGFloat.random(in: -7...7))
            },
            .wait(forDuration: 0.05)
        ])
        cameraNode.run(.repeat(shake, count: 42), withKey: "shake")
    }

    /// Läuft die Schleppfahrt weiter. Gibt true zurück, solange sie dauert.
    private func updatePowerDrag(dt: CGFloat) -> Bool {
        guard var drag = powerDrag else { return false }

        drag.remaining -= dt
        powerDrag = drag

        // Zum Köder ziehen, aber nie ganz darauf — sonst steht das Boot auf
        // dem Fisch.
        let delta = CGVector(dx: drag.anchor.x - player.position.x,
                             dy: drag.anchor.y - player.position.y)
        let distance = hypot(delta.dx, delta.dy)

        if distance > 90 {
            let pull: CGFloat = 190
            let step = CGPoint(x: player.position.x + delta.dx / distance * pull * dt,
                               y: player.position.y + delta.dy / distance * pull * dt)
            if !player.isBlocked(step, map: map) {
                player.place(at: step)
            }
            player.face(towards: drag.anchor, maxStep: dt * 2.4)
        }

        // Gischt und Kielwasser, als führe man volle Fahrt.
        wakeTimer -= dt * 3
        if wakeTimer <= 0 {
            wakeTimer = 0.4
            ambience?.spawnWake(at: player.position, heading: player.heading, strength: 1)
        }

        line.update(from: actorNode.rodTipPosition, to: drag.anchor, tension: 1)
        bobber.showTug()

        if drag.remaining <= 0 {
            powerDrag = nil
            cameraShake = .zero
            cameraNode.removeAction(forKey: "shake")
            session.handle(event: .hooked(drag.fish))
            return false
        }
        return true
    }

    // MARK: - Schnittstelle für die Oberfläche

    /// Finger aufgesetzt. Liegt der Köder schon im Wasser, ist das der
    /// Anschlag; sonst beginnt das Zielen.
    func beginAim() {
        guard session.miniGame == nil else { return }

        switch fishing.phase {
        case .idle:
            fishing.beginAim(direction: CGVector(dx: cos(player.heading), dy: sin(player.heading)))
            aimPreview.show()
            HapticManager.shared.selection()
        case .waiting, .nibble, .biteWindow:
            fishing.strike(stats: session.stats)
        default:
            break
        }
    }

    /// Fingerbewegung. `drag` ist der Vektor vom Aufsetzpunkt zum Finger, in
    /// Punkten und bereits in Weltausrichtung (y zeigt nach oben).
    ///
    /// Schritt 1 nimmt daraus die Richtung, Schritt 2 die Länge als Wurfweite.
    func updateAim(drag: CGVector) {
        guard fishing.phase == .aiming else { return }

        let length = hypot(drag.dx, drag.dy)

        // Kurze Fingerbewegung = kurzer Wurf. Nach dieser Strecke ist die
        // volle Weite erreicht.
        let fullPullDistance: CGFloat = 150
        let power = Double(min(1, length / fullPullDistance))

        fishing.updateAim(direction: length > 6 ? drag : fishing.aimDirection, power: power)
    }

    func releaseAim() {
        guard fishing.phase == .aiming else { return }

        if fishing.releaseCast(from: actorNode.rodTipPosition,
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

        let origin = actorNode.rodTipPosition
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
