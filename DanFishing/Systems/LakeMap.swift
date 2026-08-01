import CoreGraphics
import Foundation

/// Was in einer Rasterzelle liegt. `land` ist alles, wo das Boot nicht hinkommt.
enum CellKind: UInt8 {
    case land
    case shallows
    case reeds
    case lilies
    case deep
    case inflow
    case logs

    /// Zugehörige Angelzone. Land hat keine.
    var habitat: Habitat? {
        switch self {
        case .land: return nil
        case .shallows: return .shallows
        case .reeds: return .reeds
        case .lilies: return .lilies
        case .deep: return .deep
        case .inflow: return .inflow
        case .logs: return .sunkenLogs
        }
    }
}

/// Ein Dekorationsobjekt auf der Karte. Die Szene baut daraus die Grafik; die
/// Karte selbst kennt keine Sprites.
struct DecorItem {
    enum Kind {
        case reed
        case lilyPad
        case rock
        case log
        case mapleTree
        case pineTree
        case shrine
        case ripple
    }

    let kind: Kind
    let position: CGPoint
    let scale: CGFloat
    let rotation: CGFloat
    /// Zufallswert 0…1, damit die Szene Varianten bilden kann, ohne selbst zu würfeln.
    let variant: CGFloat
}

/// Der See als Raster. Kollision, Zonen und Tiefe kommen alle aus dieser
/// Struktur — die Szene rendert nur, was hier steht.
struct LakeMap {

    let columns: Int
    let rows: Int
    let cellSize: CGFloat
    private(set) var cells: [CellKind]
    private(set) var decor: [DecorItem]
    let startPosition: CGPoint

    var worldSize: CGSize {
        CGSize(width: CGFloat(columns) * cellSize, height: CGFloat(rows) * cellSize)
    }

    // MARK: - Zugriff

    func cellIndex(column: Int, row: Int) -> Int {
        row * columns + column
    }

    func kind(column: Int, row: Int) -> CellKind {
        guard column >= 0, column < columns, row >= 0, row < rows else { return .land }
        return cells[cellIndex(column: column, row: row)]
    }

    func kind(at point: CGPoint) -> CellKind {
        let column = Int(floor(point.x / cellSize))
        let row = Int(floor(point.y / cellSize))
        return kind(column: column, row: row)
    }

    func habitat(at point: CGPoint) -> Habitat? {
        kind(at: point).habitat
    }

    func isLand(at point: CGPoint) -> Bool {
        kind(at: point) == .land
    }

    /// Prüft einen Kreis statt eines Punktes — das Boot ist breiter als eine Zelle.
    func isBlocked(circleAt point: CGPoint, radius: CGFloat) -> Bool {
        let offsets: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: radius, y: 0), CGPoint(x: -radius, y: 0),
            CGPoint(x: 0, y: radius), CGPoint(x: 0, y: -radius),
            CGPoint(x: radius * 0.7, y: radius * 0.7),
            CGPoint(x: -radius * 0.7, y: radius * 0.7),
            CGPoint(x: radius * 0.7, y: -radius * 0.7),
            CGPoint(x: -radius * 0.7, y: -radius * 0.7)
        ]
        for offset in offsets {
            let probe = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
            if isLand(at: probe) { return true }
        }
        return false
    }

    /// Wassertiefe in Metern, weich zwischen den Zonen gemittelt.
    func depth(at point: CGPoint) -> Double {
        let column = Int(floor(point.x / cellSize))
        let row = Int(floor(point.y / cellSize))
        var total = 0.0
        var samples = 0.0

        for dy in -1...1 {
            for dx in -1...1 {
                let cell = kind(column: column + dx, row: row + dy)
                guard let habitat = cell.habitat else { continue }
                total += habitat.depthMeters
                samples += 1
            }
        }
        guard samples > 0 else { return 0 }
        return total / samples
    }

    /// Mittelpunkt der Zelle, in der ein Punkt liegt.
    func snappedToCellCenter(_ point: CGPoint) -> CGPoint {
        let column = Int(floor(point.x / cellSize))
        let row = Int(floor(point.y / cellSize))
        return CGPoint(x: (CGFloat(column) + 0.5) * cellSize,
                       y: (CGFloat(row) + 0.5) * cellSize)
    }

    /// Nächstgelegener freier Wasserpunkt — Rettungsanker, falls das Boot
    /// durch einen Rundungsfehler doch einmal im Land steckt.
    func nearestWater(from point: CGPoint, maxRadius: CGFloat = 600) -> CGPoint {
        if !isLand(at: point) { return point }
        var radius = cellSize
        while radius <= maxRadius {
            let steps = 16
            for step in 0..<steps {
                let angle = CGFloat(step) / CGFloat(steps) * .pi * 2
                let probe = CGPoint(x: point.x + cos(angle) * radius,
                                    y: point.y + sin(angle) * radius)
                if !isLand(at: probe) { return probe }
            }
            radius += cellSize
        }
        return startPosition
    }
}

// MARK: - Erzeugung

extension LakeMap {

    /// Baut die Karte eines Gewässers.
    ///
    /// Form, Maße und Startwert kommen aus dem Katalog — dadurch entstehen
    /// aus demselben Verfahren ein enger Teich, ein weiter See und ein
    /// gewundener Fluss.
    static func generate(for water: Water) -> LakeMap {
        switch water.shape {
        case .lake:
            return generate(seed: water.seed,
                            columns: water.columns,
                            rows: water.rows,
                            cellSize: water.cellSize)
        case .pond:
            return generatePond(water: water)
        case .river:
            return generateRiver(water: water)
        case .stream:
            return generateStream(water: water)
        }
    }

    /// Baut den Bergsee auf. Alles ist vom Seed abhängig, damit ein Spielstand
    /// immer denselben See zeigt.
    static func generate(seed: UInt64 = 20_240_517,
                         columns: Int = 46,
                         rows: Int = 74,
                         cellSize: CGFloat = 72) -> LakeMap {

        var rng = SeededGenerator(seed: seed)
        let shoreNoise = ValueNoise(seed: seed &+ 11)
        let zoneNoise = ValueNoise(seed: seed &+ 29)

        var cells = [CellKind](repeating: .land, count: columns * rows)

        let cx = Double(columns) / 2.0
        let cy = Double(rows) / 2.0
        let radiusX = Double(columns) * 0.44
        let radiusY = Double(rows) * 0.45

        // Inseln als Kreise, die später wieder Land werden.
        struct Island { let x: Double; let y: Double; let r: Double }
        var islands: [Island] = []
        for _ in 0..<4 {
            islands.append(Island(x: rng.nextDouble(in: 6...Double(columns - 6)),
                                  y: rng.nextDouble(in: 10...Double(rows - 12)),
                                  r: rng.nextDouble(in: 1.6...3.4)))
        }

        // Zufluss: schmaler Bach, der oben in den See mündet.
        let inflowX = rng.nextDouble(in: Double(columns) * 0.3...Double(columns) * 0.7)

        for row in 0..<rows {
            for column in 0..<columns {
                let x = Double(column)
                let y = Double(row)

                // Grundform des Sees: Ellipse, deren Rand mit Rauschen ausfranst.
                let nx = (x - cx) / radiusX
                let ny = (y - cy) / radiusY
                let ellipse = nx * nx + ny * ny
                let edge = 1.0 + (shoreNoise.fractal(x * 0.14, y * 0.14, octaves: 3) - 0.5) * 0.55

                var kind: CellKind = .land

                if ellipse < edge {
                    // Abstand zum Ufer bestimmt, wie tief es hier ist.
                    let toShore = edge - ellipse
                    if toShore < 0.16 {
                        kind = .shallows
                    } else if toShore < 0.42 {
                        kind = .shallows
                    } else {
                        kind = .deep
                    }

                    // Zonen werden über ein zweites Rauschfeld verteilt, damit
                    // Schilf und Seerosen zusammenhängende Felder bilden.
                    let zone = zoneNoise.fractal(x * 0.11 + 3.5, y * 0.11 + 7.25, octaves: 2)

                    if toShore < 0.55 {
                        if zone > 0.66 {
                            kind = .reeds
                        } else if zone < 0.30 {
                            kind = .lilies
                        }
                    }

                    if kind == .deep && zone > 0.70 && toShore < 0.9 {
                        kind = .logs
                    }
                }

                // Bach von oben in den See hinein.
                let inflowDistance = abs(x - inflowX)
                if y < Double(rows) * 0.22 && inflowDistance < 1.6 {
                    kind = .inflow
                } else if kind != .land && y < Double(rows) * 0.30 && inflowDistance < 3.2 {
                    kind = .inflow
                }

                // Inseln stanzen Land in den See zurück.
                for island in islands {
                    let dx = x - island.x
                    let dy = y - island.y
                    if dx * dx + dy * dy < island.r * island.r {
                        kind = .land
                    }
                }

                cells[row * columns + column] = kind
            }
        }

        // Der Startplatz liegt bewusst nicht mitten im Tiefwasser, sondern an
        // einer Uferkante: Dort sieht man sofort Schilf, Seerosen und Fische
        // und versteht, wonach man Ausschau hält.
        let safeStart = LakeMap.findStartingSpot(cells: cells,
                                                 columns: columns,
                                                 rows: rows,
                                                 cellSize: cellSize)

        return LakeMap(columns: columns,
                       rows: rows,
                       cellSize: cellSize,
                       cells: cells,
                       decor: LakeMap.buildDecor(cells: cells,
                                                 columns: columns,
                                                 rows: rows,
                                                 cellSize: cellSize,
                                                 rng: &rng),
                       startPosition: safeStart)
    }

    /// Der Dorfteich.
    ///
    /// Klein, rund und flach: fast alles ist Uferzone, dazu ein dichter
    /// Krautgürtel und eine einzige tiefere Stelle in der Mitte. Kurze Wege,
    /// keine Überraschungen — der Ort zum Lernen.
    private static func generatePond(water: Water) -> LakeMap {
        var rng = SeededGenerator(seed: water.seed)
        let shoreNoise = ValueNoise(seed: water.seed &+ 5)
        let plantNoise = ValueNoise(seed: water.seed &+ 41)

        let columns = water.columns
        let rows = water.rows
        var cells = [CellKind](repeating: .land, count: columns * rows)

        let cx = Double(columns) / 2
        let cy = Double(rows) / 2
        let radiusX = Double(columns) * 0.40
        let radiusY = Double(rows) * 0.41

        for row in 0..<rows {
            for column in 0..<columns {
                let x = Double(column)
                let y = Double(row)

                let nx = (x - cx) / radiusX
                let ny = (y - cy) / radiusY
                let ellipse = nx * nx + ny * ny
                // Der Rand franst nur leicht aus — ein Teich ist gefasst,
                // kein Natursee.
                let edge = 1.0 + (shoreNoise.fractal(x * 0.2, y * 0.2, octaves: 2) - 0.5) * 0.3

                guard ellipse < edge else { continue }

                let toShore = edge - ellipse
                var kind: CellKind = .shallows

                // Nur ganz in der Mitte wird es tiefer.
                if toShore > 0.72 { kind = .deep }

                // Krautgürtel am Ufer, Seerosen in den Buchten.
                let plants = plantNoise.fractal(x * 0.16 + 2.5, y * 0.16 + 4.5, octaves: 2)
                if toShore < 0.45 {
                    if plants > 0.60 {
                        kind = .reeds
                    } else if plants < 0.34 {
                        kind = .lilies
                    }
                }

                // Ein einzelner versunkener Ast als Versteck.
                if toShore > 0.5 && toShore < 0.68 && plants > 0.78 {
                    kind = .logs
                }

                cells[row * columns + column] = kind
            }
        }

        return assemble(cells: cells, water: water, rng: &rng)
    }

    /// Der Fluss.
    ///
    /// Ein Lauf von oben nach unten, der sich in Windungen durchs Bild zieht.
    /// Die Außenseite jeder Kurve wird ausgespült und ist tief, innen lagert
    /// sich Kies ab und es bleibt flach — genau dort steht die Äsche. Oben
    /// kommt das kalte Wasser herein.
    private static func generateRiver(water: Water) -> LakeMap {
        var rng = SeededGenerator(seed: water.seed)
        let bankNoise = ValueNoise(seed: water.seed &+ 17)
        let plantNoise = ValueNoise(seed: water.seed &+ 63)

        let columns = water.columns
        let rows = water.rows
        var cells = [CellKind](repeating: .land, count: columns * rows)

        let centerBase = Double(columns) / 2

        for row in 0..<rows {
            let y = Double(row)

            // Zwei überlagerte Wellen ergeben einen Lauf, der sich nicht
            // wiederholt.
            let bend = sin(y * 0.075) * 5.4 + sin(y * 0.031 + 1.3) * 3.1
            let center = centerBase + bend
            // Wie stark die Kurve gerade ist, und in welche Richtung.
            let curvature = cos(y * 0.075) * 0.075 * 5.4 + cos(y * 0.031 + 1.3) * 0.031 * 3.1

            let halfWidth = 6.0 + bankNoise.fractal(y * 0.09, 0.5, octaves: 2) * 2.6

            for column in 0..<columns {
                let x = Double(column)
                let offset = x - center
                guard abs(offset) < halfWidth else { continue }

                // Anteil von der Mitte zum Ufer: 0 = Mitte, 1 = Kante.
                let toBank = abs(offset) / halfWidth

                // Außenseite der Kurve: dort, wohin die Strömung drückt.
                let outerSide = curvature > 0 ? 1.0 : -1.0
                let onOuter = (offset * outerSide) > 0

                var kind: CellKind
                if toBank > 0.82 {
                    kind = .shallows
                } else if onOuter && toBank > 0.25 {
                    kind = .deep          // ausgespülter Prallhang
                } else if !onOuter && toBank > 0.4 {
                    kind = .shallows      // Kiesbank im Gleithang
                } else {
                    kind = toBank < 0.35 ? .deep : .shallows
                }

                // Das obere Drittel ist kalt und schnell.
                if y < Double(rows) * 0.34 && kind != .land {
                    kind = .inflow
                }

                // Pflanzen und Totholz an den ruhigen Innenseiten.
                let plants = plantNoise.fractal(x * 0.18, y * 0.12, octaves: 2)
                if !onOuter && toBank > 0.55 && y > Double(rows) * 0.34 {
                    if plants > 0.66 {
                        kind = .reeds
                    } else if plants < 0.3 {
                        kind = .lilies
                    }
                }
                if onOuter && toBank > 0.55 && plants > 0.74 {
                    kind = .logs
                }

                cells[row * columns + column] = kind
            }
        }

        return assemble(cells: cells, water: water, rng: &rng)
    }

    /// Der Gebirgsbach.
    ///
    /// Schmal, schnell und steinig: ein paar Zellen breit, mit Schwällen über
    /// Kies und ausgewaschenen Gumpen unter den Kurven. Für ein Boot ist hier
    /// kein Platz — man geht am Ufer entlang und steigt hinein, so weit die
    /// Wathose reicht.
    private static func generateStream(water: Water) -> LakeMap {
        var rng = SeededGenerator(seed: water.seed)
        let bankNoise = ValueNoise(seed: water.seed &+ 23)
        let poolNoise = ValueNoise(seed: water.seed &+ 91)

        let columns = water.columns
        let rows = water.rows
        var cells = [CellKind](repeating: .land, count: columns * rows)

        let centerBase = Double(columns) / 2

        for row in 0..<rows {
            let y = Double(row)

            // Enger und unruhiger als der Fluss: kurze Wellenlänge, kräftiger
            // Ausschlag. Der Bach schlängelt sich sichtbar durchs Tal.
            let bend = sin(y * 0.16) * 3.4 + sin(y * 0.061 + 2.2) * 2.6
            let center = centerBase + bend
            let curvature = cos(y * 0.16) * 0.16 * 3.4 + cos(y * 0.061 + 2.2) * 0.061 * 2.6

            // 2 bis knapp 4 Zellen halbe Breite — zu eng zum Rudern.
            let halfWidth = 2.1 + bankNoise.fractal(y * 0.14, 0.5, octaves: 2) * 1.7

            // Abwechselnd rauschende Schwälle und ruhige Gumpen.
            let pool = poolNoise.fractal(y * 0.07, 3.5, octaves: 2)

            for column in 0..<columns {
                let x = Double(column)
                let offset = x - center
                guard abs(offset) < halfWidth else { continue }

                let toBank = abs(offset) / halfWidth
                let outerSide = curvature > 0 ? 1.0 : -1.0
                let onOuter = (offset * outerSide) > 0

                var kind: CellKind

                if pool > 0.62 && toBank < 0.72 {
                    // Gumpen: ausgewaschener Kolk hinter einem Schwall.
                    kind = onOuter || toBank < 0.35 ? .deep : .inflow
                } else if toBank > 0.78 {
                    // Kiesrand, knöcheltief.
                    kind = .shallows
                } else if onOuter && toBank > 0.3 {
                    // Prallhang: die Rinne, in der die Forellen stehen.
                    kind = .inflow
                } else {
                    kind = .shallows
                }

                // Totholz, das sich an den Steinen verfangen hat.
                if toBank > 0.5 && pool < 0.24 && bankNoise.fractal(x * 0.4, y * 0.4, octaves: 1) > 0.72 {
                    kind = .logs
                }

                cells[row * columns + column] = kind
            }
        }

        return assemble(cells: cells, water: water, rng: &rng)
    }

    /// Baut aus fertigen Zellen die Karte samt Kulisse und Startplatz.
    private static func assemble(cells: [CellKind],
                                 water: Water,
                                 rng: inout SeededGenerator) -> LakeMap {
        let start: CGPoint
        switch water.movement {
        case .boat:
            start = findStartingSpot(cells: cells,
                                     columns: water.columns,
                                     rows: water.rows,
                                     cellSize: water.cellSize)
        case .wading:
            start = findBankSpot(cells: cells,
                                 columns: water.columns,
                                 rows: water.rows,
                                 cellSize: water.cellSize)
        }

        return LakeMap(columns: water.columns,
                       rows: water.rows,
                       cellSize: water.cellSize,
                       cells: cells,
                       decor: buildDecor(cells: cells,
                                         columns: water.columns,
                                         rows: water.rows,
                                         cellSize: water.cellSize,
                                         rng: &rng),
                       startPosition: start)
    }

    /// Sucht eine flache Stelle, an der möglichst viele verschiedene Zonen in
    /// Reichweite liegen. Das ist der Platz mit dem meisten zu sehen.
    private static func findStartingSpot(cells: [CellKind],
                                         columns: Int,
                                         rows: Int,
                                         cellSize: CGFloat) -> CGPoint {
        func kind(_ column: Int, _ row: Int) -> CellKind {
            guard column >= 0, column < columns, row >= 0, row < rows else { return .land }
            return cells[row * columns + column]
        }

        var best: (score: Int, point: CGPoint)?

        for row in 3..<(rows - 3) {
            for column in 3..<(columns - 3) {
                let cell = kind(column, row)
                // Gestartet wird im flachen Wasser, nicht im Schilf selbst —
                // sonst steht das Boot direkt in den Halmen.
                guard cell == .shallows else { continue }

                var neighbours = Set<UInt8>()
                var freeWater = 0
                for dy in -3...3 {
                    for dx in -3...3 {
                        let neighbour = kind(column + dx, row + dy)
                        neighbours.insert(neighbour.rawValue)
                        if neighbour != .land { freeWater += 1 }
                    }
                }

                // Genug Platz zum Rudern, dazu Punkte für jede Zonenart in Sicht.
                guard freeWater > 34 else { continue }
                let score = neighbours.count * 10 + freeWater

                if best == nil || score > best!.score {
                    best = (score, CGPoint(x: (CGFloat(column) + 0.5) * cellSize,
                                           y: (CGFloat(row) + 0.5) * cellSize))
                }
            }
        }

        return best?.point ?? CGPoint(x: CGFloat(columns) * 0.5 * cellSize,
                                      y: CGFloat(rows) * 0.5 * cellSize)
    }

    /// Sucht für den Angler zu Fuß einen Platz am Ufer: fester Boden, aber
    /// direkt am Wasser und mit Auslauf nach beiden Seiten.
    private static func findBankSpot(cells: [CellKind],
                                     columns: Int,
                                     rows: Int,
                                     cellSize: CGFloat) -> CGPoint {
        func kind(_ column: Int, _ row: Int) -> CellKind {
            guard column >= 0, column < columns, row >= 0, row < rows else { return .land }
            return cells[row * columns + column]
        }

        var best: (score: Int, point: CGPoint)?

        // Von unten nach oben suchen: der Bach wird talwärts breiter, dort
        // fängt man an und arbeitet sich nach oben.
        for row in 2..<(rows / 3) {
            for column in 2..<(columns - 2) {
                guard kind(column, row) == .land else { continue }

                var landAround = 0
                var waterNear = 0
                for dy in -2...2 {
                    for dx in -2...2 {
                        if kind(column + dx, row + dy) == .land {
                            landAround += 1
                        } else {
                            waterNear += 1
                        }
                    }
                }

                // Genug Land zum Stehen und Wasser in Wurfweite.
                guard landAround >= 14, waterNear >= 4 else { continue }
                let score = waterNear * 10 + landAround

                if best == nil || score > best!.score {
                    best = (score, CGPoint(x: (CGFloat(column) + 0.5) * cellSize,
                                           y: (CGFloat(row) + 0.5) * cellSize))
                }
            }
        }

        return best?.point ?? CGPoint(x: CGFloat(columns) * 0.2 * cellSize,
                                      y: CGFloat(rows) * 0.2 * cellSize)
    }

    /// Streut Pflanzen, Steine und Bäume passend zu den Zonen.
    private static func buildDecor(cells: [CellKind],
                                   columns: Int,
                                   rows: Int,
                                   cellSize: CGFloat,
                                   rng: inout SeededGenerator) -> [DecorItem] {
        var items: [DecorItem] = []

        func kind(_ column: Int, _ row: Int) -> CellKind {
            guard column >= 0, column < columns, row >= 0, row < rows else { return .land }
            return cells[row * columns + column]
        }

        func touchesLand(_ column: Int, _ row: Int) -> Bool {
            for dy in -1...1 {
                for dx in -1...1 {
                    if kind(column + dx, row + dy) == .land { return true }
                }
            }
            return false
        }

        for row in 0..<rows {
            for column in 0..<columns {
                let cell = kind(column, row)
                let base = CGPoint(x: (CGFloat(column) + 0.5) * cellSize,
                                   y: (CGFloat(row) + 0.5) * cellSize)

                func jittered() -> CGPoint {
                    CGPoint(x: base.x + CGFloat(rng.nextDouble(in: -0.4...0.4)) * cellSize,
                            y: base.y + CGFloat(rng.nextDouble(in: -0.4...0.4)) * cellSize)
                }

                switch cell {
                case .reeds:
                    let count = rng.nextInt(in: 2...4)
                    for _ in 0..<count {
                        items.append(DecorItem(kind: .reed,
                                               position: jittered(),
                                               scale: CGFloat(rng.nextDouble(in: 0.7...1.3)),
                                               rotation: CGFloat(rng.nextDouble(in: -0.18...0.18)),
                                               variant: CGFloat(rng.nextUnit())))
                    }

                case .lilies:
                    let count = rng.nextInt(in: 1...3)
                    for _ in 0..<count {
                        items.append(DecorItem(kind: .lilyPad,
                                               position: jittered(),
                                               scale: CGFloat(rng.nextDouble(in: 0.65...1.25)),
                                               rotation: CGFloat(rng.nextDouble(in: 0...6.28)),
                                               variant: CGFloat(rng.nextUnit())))
                    }

                case .logs:
                    if rng.nextUnit() < 0.55 {
                        items.append(DecorItem(kind: .log,
                                               position: jittered(),
                                               scale: CGFloat(rng.nextDouble(in: 0.8...1.4)),
                                               rotation: CGFloat(rng.nextDouble(in: 0...6.28)),
                                               variant: CGFloat(rng.nextUnit())))
                    }

                case .land:
                    // Bäume und Steine nur direkt am Wasser, sonst wird es unruhig.
                    var nextToWater = false
                    for dy in -1...1 {
                        for dx in -1...1 where kind(column + dx, row + dy) != .land {
                            nextToWater = true
                        }
                    }
                    guard nextToWater else { continue }

                    let roll = rng.nextUnit()
                    if roll < 0.22 {
                        items.append(DecorItem(kind: .mapleTree,
                                               position: jittered(),
                                               scale: CGFloat(rng.nextDouble(in: 0.8...1.4)),
                                               rotation: 0,
                                               variant: CGFloat(rng.nextUnit())))
                    } else if roll < 0.38 {
                        items.append(DecorItem(kind: .pineTree,
                                               position: jittered(),
                                               scale: CGFloat(rng.nextDouble(in: 0.8...1.3)),
                                               rotation: 0,
                                               variant: CGFloat(rng.nextUnit())))
                    } else if roll < 0.54 {
                        items.append(DecorItem(kind: .rock,
                                               position: jittered(),
                                               scale: CGFloat(rng.nextDouble(in: 0.6...1.2)),
                                               rotation: CGFloat(rng.nextDouble(in: 0...6.28)),
                                               variant: CGFloat(rng.nextUnit())))
                    }

                case .shallows:
                    if touchesLand(column, row) && rng.nextUnit() < 0.12 {
                        items.append(DecorItem(kind: .rock,
                                               position: jittered(),
                                               scale: CGFloat(rng.nextDouble(in: 0.5...0.9)),
                                               rotation: CGFloat(rng.nextDouble(in: 0...6.28)),
                                               variant: CGFloat(rng.nextUnit())))
                    }

                default:
                    break
                }
            }
        }

        // Ein kleiner Schrein am Ufer als Blickfang.
        for row in stride(from: rows - 4, through: 4, by: -1) {
            for column in stride(from: 4, to: columns - 4, by: 1) where kind(column, row) == .land {
                if kind(column, row + 1) != .land {
                    items.append(DecorItem(kind: .shrine,
                                           position: CGPoint(x: (CGFloat(column) + 0.5) * cellSize,
                                                             y: (CGFloat(row) + 0.5) * cellSize),
                                           scale: 1.2,
                                           rotation: 0,
                                           variant: 0.5))
                    return items
                }
            }
        }

        return items
    }
}
