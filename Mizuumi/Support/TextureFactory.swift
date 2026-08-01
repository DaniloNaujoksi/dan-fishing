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

    /// Fischkörper als Silhouette mit Bauch und Flosse. Wird für jede Art in
    /// ihren Farben erzeugt und danach zwischengespeichert.
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

        let rendered = image(size: pixelSize) { context, canvas in
            // Grundfläche: alles ist erst einmal Wasser.
            context.setFillColor(Palette.water.skColor.cgColor)
            context.fill(CGRect(origin: .zero, size: canvas))

            func color(for kind: CellKind) -> UIColor? {
                switch kind {
                case .land: return Palette.sand.skColor
                case .shallows: return Palette.waterShallow.skColor.withAlphaComponent(0.75)
                case .reeds: return Palette.reed.skColor.withAlphaComponent(0.45)
                case .lilies: return Palette.lily.skColor.withAlphaComponent(0.40)
                case .deep: return Palette.waterDeep.skColor.withAlphaComponent(0.7)
                case .inflow: return ColorSpec(0x9FD0D6).skColor.withAlphaComponent(0.6)
                case .logs: return ColorSpec(0x3F5A4E).skColor.withAlphaComponent(0.55)
                }
            }

            // Zwei Durchgänge: erst das Wasser mit seinen Zonen, dann das Land
            // darüber. Sonst würden Schilfflächen die Uferlinie überdecken.
            for pass in 0..<2 {
                for row in 0..<map.rows {
                    for column in 0..<map.columns {
                        let kind = map.kind(column: column, row: row)
                        let isLand = kind == .land
                        if (pass == 0) == isLand { continue }
                        guard let tint = color(for: kind) else { continue }

                        // Bildkoordinaten laufen von oben nach unten, die Welt
                        // von unten nach oben.
                        let x = CGFloat(column) * cell
                        let y = pixelSize.height - CGFloat(row + 1) * cell

                        // Tupfen größer als die Zelle: die Ränder verschmelzen.
                        let bloat = cell * 0.42
                        let rect = CGRect(x: x - bloat / 2,
                                          y: y - bloat / 2,
                                          width: cell + bloat,
                                          height: cell + bloat)

                        context.setFillColor(tint.cgColor)
                        context.fillEllipse(in: rect)
                    }
                }
            }
        }

        // Nicht zwischenspeichern: Das Bild hängt an der Karte und wird genau
        // einmal pro Szene gebraucht.
        return SKTexture(image: rendered)
    }

    /// Leert den Zwischenspeicher — nur für Tests und Vorschauen nötig.
    static func clearCache() {
        cache.removeAll()
    }
}
