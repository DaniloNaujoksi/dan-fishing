import SpriteKit
import UIKit

/// Erzeugt alle Texturen zur Laufzeit. Es liegen keine Bilddateien im Projekt —
/// wer später echte Grafiken einsetzen will, ersetzt hier die einzelnen
/// Funktionen durch `SKTexture(imageNamed:)` und ändert sonst nichts.
enum TextureFactory {

    private static var cache: [String: SKTexture] = [:]

    private static func cached(_ key: String, build: () -> SKTexture?) -> SKTexture? {
        if let existing = cache[key] { return existing }
        guard let texture = build() else { return nil }
        cache[key] = texture
        return texture
    }

    private static func image(size: CGSize, draw: (CGContext, CGSize) -> Void) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            draw(context.cgContext, size)
        }
    }

    /// Feine Papierkörnung, die über die ganze Szene gelegt wird. Sie nimmt den
    /// Farbflächen das Digitale und lässt sie gemalt wirken.
    static func paperGrain(size: CGSize = CGSize(width: 256, height: 256)) -> SKTexture? {
        cached("paperGrain") {
            let rendered = image(size: size) { context, size in
                context.setFillColor(UIColor(white: 1, alpha: 0).cgColor)
                context.fill(CGRect(origin: .zero, size: size))

                // Zufällige Punkte in zwei Helligkeiten ergeben eine Struktur,
                // die in Bewegung nicht flimmert.
                for _ in 0..<2600 {
                    let x = CGFloat.random(in: 0..<size.width)
                    let y = CGFloat.random(in: 0..<size.height)
                    let radius = CGFloat.random(in: 0.4...1.5)
                    let bright = Bool.random()
                    let alpha = CGFloat.random(in: 0.02...0.07)
                    context.setFillColor(UIColor(white: bright ? 1 : 0, alpha: alpha).cgColor)
                    context.fillEllipse(in: CGRect(x: x, y: y, width: radius, height: radius))
                }
            }
            return SKTexture(image: rendered)
        }
    }

    /// Weicher runder Fleck. Wird für Nebel, Lichtkreise und Schatten benutzt.
    static func softDisc(color: UIColor, size: CGFloat = 256) -> SKTexture? {
        let key = "softDisc-\(color.description)-\(size)"
        return cached(key) {
            let rendered = image(size: CGSize(width: size, height: size)) { context, canvas in
                let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

                let colors = [
                    UIColor(red: red, green: green, blue: blue, alpha: alpha).cgColor,
                    UIColor(red: red, green: green, blue: blue, alpha: 0).cgColor
                ] as CFArray

                guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                                colors: colors,
                                                locations: [0, 1]) else { return }
                context.drawRadialGradient(gradient,
                                           startCenter: center, startRadius: 0,
                                           endCenter: center, endRadius: canvas.width / 2,
                                           options: [])
            }
            return SKTexture(image: rendered)
        }
    }

    /// Wellenband: helle Linien auf durchsichtigem Grund, die als Kachel über
    /// das Wasser laufen.
    static func waveStripes(size: CGSize = CGSize(width: 512, height: 512)) -> SKTexture? {
        cached("waveStripes") {
            let rendered = image(size: size) { context, canvas in
                context.setLineCap(.round)
                context.setLineWidth(2.2)
                context.setStrokeColor(UIColor(white: 1, alpha: 0.16).cgColor)

                var y: CGFloat = 12
                while y < canvas.height {
                    let amplitude = CGFloat.random(in: 3...7)
                    let segments = 40
                    context.beginPath()
                    for step in 0...segments {
                        let x = canvas.width * CGFloat(step) / CGFloat(segments)
                        let wave = sin(CGFloat(step) / CGFloat(segments) * .pi * 4) * amplitude
                        let point = CGPoint(x: x, y: y + wave)
                        if step == 0 {
                            context.move(to: point)
                        } else {
                            context.addLine(to: point)
                        }
                    }
                    context.strokePath()
                    y += CGFloat.random(in: 26...46)
                }
            }
            return SKTexture(image: rendered)
        }
    }

    /// Kirschblütenblatt.
    static func petal(color: UIColor) -> SKTexture? {
        cached("petal-\(color.description)") {
            let rendered = image(size: CGSize(width: 24, height: 24)) { context, canvas in
                context.setFillColor(color.cgColor)
                let path = UIBezierPath()
                path.move(to: CGPoint(x: canvas.width / 2, y: 2))
                path.addCurve(to: CGPoint(x: canvas.width - 3, y: canvas.height / 2),
                              controlPoint1: CGPoint(x: canvas.width * 0.8, y: canvas.height * 0.1),
                              controlPoint2: CGPoint(x: canvas.width - 2, y: canvas.height * 0.3))
                path.addCurve(to: CGPoint(x: canvas.width / 2, y: canvas.height - 2),
                              controlPoint1: CGPoint(x: canvas.width - 2, y: canvas.height * 0.75),
                              controlPoint2: CGPoint(x: canvas.width * 0.7, y: canvas.height - 3))
                path.addCurve(to: CGPoint(x: 3, y: canvas.height / 2),
                              controlPoint1: CGPoint(x: canvas.width * 0.3, y: canvas.height - 3),
                              controlPoint2: CGPoint(x: 2, y: canvas.height * 0.75))
                path.addCurve(to: CGPoint(x: canvas.width / 2, y: 2),
                              controlPoint1: CGPoint(x: 2, y: canvas.height * 0.3),
                              controlPoint2: CGPoint(x: canvas.width * 0.2, y: canvas.height * 0.1))
                context.addPath(path.cgPath)
                context.fillPath()
            }
            return SKTexture(image: rendered)
        }
    }

    /// Holzmaserung für den Bootsrumpf: waagerechte Planken mit Astlöchern.
    /// Ohne sie wirkt der Kahn wie eine ausgefüllte Form, mit ihr wie gebaut.
    static func woodGrain(base: UIColor, dark: UIColor) -> SKTexture? {
        cached("wood-\(base.description)") {
            let size = CGSize(width: 256, height: 128)
            let rendered = image(size: size) { context, canvas in
                context.setFillColor(base.cgColor)
                context.fill(CGRect(origin: .zero, size: canvas))

                // Planken
                let plankHeight = canvas.height / 5
                context.setStrokeColor(dark.withAlphaComponent(0.55).cgColor)
                context.setLineWidth(1.6)
                for index in 1..<5 {
                    let y = CGFloat(index) * plankHeight
                    context.move(to: CGPoint(x: 0, y: y))
                    context.addLine(to: CGPoint(x: canvas.width, y: y))
                }
                context.strokePath()

                // Maserung als lange, leicht wellige Striche
                context.setLineWidth(1.0)
                for _ in 0..<44 {
                    let y = CGFloat.random(in: 0...canvas.height)
                    let alpha = CGFloat.random(in: 0.05...0.16)
                    context.setStrokeColor(dark.withAlphaComponent(alpha).cgColor)
                    context.move(to: CGPoint(x: 0, y: y))

                    var x: CGFloat = 0
                    while x < canvas.width {
                        x += CGFloat.random(in: 20...50)
                        context.addLine(to: CGPoint(x: x, y: y + CGFloat.random(in: -2.5...2.5)))
                    }
                    context.strokePath()
                }

                // Ein paar Astlöcher
                for _ in 0..<5 {
                    let center = CGPoint(x: CGFloat.random(in: 12...(canvas.width - 12)),
                                         y: CGFloat.random(in: 8...(canvas.height - 8)))
                    for ring in 0..<3 {
                        let radius = CGFloat(3 + ring * 3)
                        context.setStrokeColor(dark.withAlphaComponent(0.28 - CGFloat(ring) * 0.07).cgColor)
                        context.setLineWidth(1.4)
                        context.strokeEllipse(in: CGRect(x: center.x - radius,
                                                         y: center.y - radius * 0.7,
                                                         width: radius * 2,
                                                         height: radius * 1.4))
                    }
                }
            }
            return SKTexture(image: rendered)
        }
    }

    /// Bild einer Fischart.
    ///
    /// Zuerst wird die gezeichnete Grafik aus dem Asset-Katalog gesucht
    /// (`fish_<id>`); nur wenn es die nicht gibt, entsteht ersatzweise die
    /// gemalte Silhouette aus Formen. Dadurch lassen sich einzelne Arten
    /// austauschen, ohne dass etwas anderes angefasst werden muss.
    static func fishArtwork(for species: FishSpecies) -> SKTexture? {
        if let artwork = cached("artwork-\(species.id)", build: {
            let image = UIImage(named: "fish_\(species.id)")
            guard let image else { return nil }
            let texture = SKTexture(image: image)
            // Pixelgrafik: Beim Skalieren nicht weichzeichnen.
            texture.filteringMode = .nearest
            return texture
        }) {
            return artwork
        }

        return fishBody(body: species.bodyColor.skColor,
                        belly: species.bellyColor.skColor,
                        fin: species.finColor.skColor,
                        key: species.id)
    }

    /// Gibt es für eine Art eine gezeichnete Grafik?
    static func hasArtwork(for species: FishSpecies) -> Bool {
        UIImage(named: "fish_\(species.id)") != nil
    }

    /// Fischkörper als Silhouette mit Bauch und Flosse. Rückfallebene, falls
    /// für eine Art noch keine Grafik vorliegt.
    static func fishBody(body: UIColor, belly: UIColor, fin: UIColor, key: String) -> SKTexture? {
        cached("fish-\(key)") {
            let size = CGSize(width: 120, height: 54)
            let rendered = image(size: size) { context, canvas in
                let midY = canvas.height / 2

                // Schwanzflosse
                context.setFillColor(fin.cgColor)
                let tail = UIBezierPath()
                tail.move(to: CGPoint(x: 14, y: midY))
                tail.addLine(to: CGPoint(x: 0, y: midY - 16))
                tail.addLine(to: CGPoint(x: 4, y: midY))
                tail.addLine(to: CGPoint(x: 0, y: midY + 16))
                tail.close()
                context.addPath(tail.cgPath)
                context.fillPath()

                // Rückenflosse
                let dorsal = UIBezierPath()
                dorsal.move(to: CGPoint(x: 44, y: midY - 12))
                dorsal.addLine(to: CGPoint(x: 62, y: midY - 24))
                dorsal.addLine(to: CGPoint(x: 76, y: midY - 11))
                dorsal.close()
                context.addPath(dorsal.cgPath)
                context.fillPath()

                // Körper
                context.setFillColor(body.cgColor)
                let shape = UIBezierPath()
                shape.move(to: CGPoint(x: 112, y: midY))
                shape.addCurve(to: CGPoint(x: 60, y: midY - 19),
                               controlPoint1: CGPoint(x: 100, y: midY - 16),
                               controlPoint2: CGPoint(x: 80, y: midY - 20))
                shape.addCurve(to: CGPoint(x: 12, y: midY),
                               controlPoint1: CGPoint(x: 36, y: midY - 18),
                               controlPoint2: CGPoint(x: 18, y: midY - 8))
                shape.addCurve(to: CGPoint(x: 60, y: midY + 19),
                               controlPoint1: CGPoint(x: 18, y: midY + 8),
                               controlPoint2: CGPoint(x: 36, y: midY + 18))
                shape.addCurve(to: CGPoint(x: 112, y: midY),
                               controlPoint1: CGPoint(x: 80, y: midY + 20),
                               controlPoint2: CGPoint(x: 100, y: midY + 16))
                context.addPath(shape.cgPath)
                context.fillPath()

                // Bauch als hellere Sichel
                context.setFillColor(belly.cgColor)
                let bellyPath = UIBezierPath()
                bellyPath.move(to: CGPoint(x: 100, y: midY + 4))
                bellyPath.addCurve(to: CGPoint(x: 28, y: midY + 4),
                                   controlPoint1: CGPoint(x: 78, y: midY + 20),
                                   controlPoint2: CGPoint(x: 44, y: midY + 16))
                bellyPath.addCurve(to: CGPoint(x: 100, y: midY + 4),
                                   controlPoint1: CGPoint(x: 44, y: midY + 9),
                                   controlPoint2: CGPoint(x: 78, y: midY + 11))
                context.addPath(bellyPath.cgPath)
                context.fillPath()

                // Auge
                context.setFillColor(UIColor(white: 0.12, alpha: 0.9).cgColor)
                context.fillEllipse(in: CGRect(x: 98, y: midY - 8, width: 7, height: 7))
            }
            return SKTexture(image: rendered)
        }
    }

    /// Zeichnet die komplette Zonenkarte in ein einziges Bild.
    ///
    /// Vorher lag pro Rasterzelle ein eigener Knoten in der Szene — über 3000
    /// Stück, und jede Zelle blieb als hartes Rechteck sichtbar. Als weiche,
    /// einander überlappende Tupfen in einer Textur wirkt der See gemalt, und
    /// die Szene kommt mit einem Knoten aus.
    ///
    /// - Parameter scale: Auflösung der Textur im Verhältnis zur Weltgröße.
    static func zoneMap(map: LakeMap, scale: CGFloat = 0.33) -> SKTexture? {
        let pixelSize = CGSize(width: map.worldSize.width * scale,
                               height: map.worldSize.height * scale)
        let cell = map.cellSize * scale

        // Farbe je Zelle, in zwei Ebenen: Wassertiefe als Grundton, die
        // Bewuchszonen als zarte Tönung darüber.
        func waterTone(for kind: CellKind) -> UIColor {
            switch kind {
            case .land: return Palette.sand.skColor
            case .shallows, .reeds, .lilies: return Palette.waterShallow.skColor
            case .inflow: return ColorSpec(0x9FD0D6).skColor
            case .deep, .logs: return Palette.waterDeep.skColor
            }
        }

        func overlayTone(for kind: CellKind) -> UIColor? {
            switch kind {
            case .reeds: return Palette.reed.skColor.withAlphaComponent(0.28)
            case .lilies: return Palette.lily.skColor.withAlphaComponent(0.24)
            case .logs: return ColorSpec(0x3F5A4E).skColor.withAlphaComponent(0.3)
            default: return nil
            }
        }

        // Erst eine kleine Karte zeichnen — ein Pixel je Rasterzelle. Beim
        // Hochskalieren glättet CoreGraphics die Übergänge von selbst; das
        // ergibt weiche Farbverläufe statt der vorherigen Kreismuster.
        let smallSize = CGSize(width: map.columns, height: map.rows)
        let small = image(size: smallSize) { context, _ in
            context.interpolationQuality = .none
            for row in 0..<map.rows {
                for column in 0..<map.columns {
                    let kind = map.kind(column: column, row: row)
                    let y = map.rows - row - 1   // Bild läuft von oben nach unten
                    let rect = CGRect(x: CGFloat(column), y: CGFloat(y), width: 1, height: 1)

                    context.setFillColor(waterTone(for: kind).cgColor)
                    context.fill(rect)

                    if let overlay = overlayTone(for: kind) {
                        context.setFillColor(overlay.cgColor)
                        context.fill(rect)
                    }
                }
            }
        }

        // Weich hochziehen. Das Land bekommt danach eine klare Uferlinie,
        // damit die Kante trotz Weichzeichnung ablesbar bleibt.
        let rendered = image(size: pixelSize) { context, canvas in
            context.interpolationQuality = .high
            // Bewusst über UIImage gezeichnet statt über CGImage: Ein CGImage
            // wird im UIKit-Kontext senkrecht gespiegelt, wodurch die ganze
            // Karte auf dem Kopf stünde — Fische schwämmen dann über Land.
            small.draw(in: CGRect(origin: .zero, size: canvas))

            context.setStrokeColor(ColorSpec(0xBBA987).skColor.withAlphaComponent(0.75).cgColor)
            context.setLineWidth(max(1.5, cell * 0.16))
            context.setLineJoin(.round)

            for row in 0..<map.rows {
                for column in 0..<map.columns where map.kind(column: column, row: row) == .land {
                    // Nur Kanten zeichnen, an denen wirklich Wasser anliegt.
                    let x = CGFloat(column) * cell
                    let y = pixelSize.height - CGFloat(row + 1) * cell

                    if map.kind(column: column, row: row + 1) != .land {
                        context.move(to: CGPoint(x: x, y: y + cell))
                        context.addLine(to: CGPoint(x: x + cell, y: y + cell))
                    }
                    if map.kind(column: column, row: row - 1) != .land {
                        context.move(to: CGPoint(x: x, y: y))
                        context.addLine(to: CGPoint(x: x + cell, y: y))
                    }
                    if map.kind(column: column - 1, row: row) != .land {
                        context.move(to: CGPoint(x: x, y: y))
                        context.addLine(to: CGPoint(x: x, y: y + cell))
                    }
                    if map.kind(column: column + 1, row: row) != .land {
                        context.move(to: CGPoint(x: x + cell, y: y))
                        context.addLine(to: CGPoint(x: x + cell, y: y + cell))
                    }
                }
            }
            context.strokePath()
        }

        // Nicht zwischenspeichern: Das Bild hängt an der Karte und wird genau
        // einmal pro Szene gebraucht.
        return SKTexture(image: rendered)
    }

    /// Kleine Übersichtskarte des Sees für die Minimap.
    ///
    /// Bewusst grob: vier Bildpunkte je Rasterzelle reichen, um Ufer, Buchten
    /// und Tiefe zu erkennen, und das Bild bleibt winzig.
    static func minimapImage(for map: LakeMap, pixelsPerCell: CGFloat = 4) -> UIImage {
        let size = CGSize(width: CGFloat(map.columns) * pixelsPerCell,
                          height: CGFloat(map.rows) * pixelsPerCell)

        return image(size: size) { context, _ in
            for row in 0..<map.rows {
                for column in 0..<map.columns {
                    let kind = map.kind(column: column, row: row)

                    let color: UIColor
                    switch kind {
                    case .land: color = Palette.sand.skColor
                    case .shallows: color = Palette.waterShallow.skColor
                    case .reeds: color = Palette.reed.skColor
                    case .lilies: color = Palette.lily.skColor
                    case .deep: color = Palette.waterDeep.skColor
                    case .inflow: color = ColorSpec(0x9FD0D6).skColor
                    case .logs: color = ColorSpec(0x3F5A4E).skColor
                    }

                    // Bild von oben nach unten, Welt von unten nach oben.
                    let y = CGFloat(map.rows - row - 1) * pixelsPerCell
                    context.setFillColor(color.cgColor)
                    context.fill(CGRect(x: CGFloat(column) * pixelsPerCell, y: y,
                                        width: pixelsPerCell, height: pixelsPerCell))
                }
            }
        }
    }

    /// Leert den Zwischenspeicher — nur für Tests und Vorschauen nötig.
    static func clearCache() {
        cache.removeAll()
    }
}
