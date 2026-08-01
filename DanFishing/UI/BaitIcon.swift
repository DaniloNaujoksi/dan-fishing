import SwiftUI

/// Kleines Symbol je Köder — gezeichnet, nicht als Bilddatei.
///
/// Ein farbiger Punkt sagte bisher nichts; jetzt erkennt man Wurm, Spinner,
/// Blinker und Fliege auf einen Blick, in der Köderbox wie im Laden.
struct BaitIcon: View {
    let bait: Bait
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.paperDeep.swiftUIColor.opacity(0.55))

            Canvas { context, canvasSize in
                let scale = canvasSize.width / 34
                context.scaleBy(x: scale, y: scale)
                draw(&context)
            }
            .padding(size * 0.14)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().strokeBorder(Palette.inkSoft.swiftUIColor.opacity(0.25), lineWidth: 1)
        )
    }

    /// Zeichnet in einem gedachten Feld von 34 × 34 Punkten.
    private func draw(_ context: inout GraphicsContext) {
        let tint = bait.color.swiftUIColor
        let dark = Palette.ink.swiftUIColor.opacity(0.55)

        switch bait.id {
        case "worm":
            // Geschlängelter Wurm.
            var path = Path()
            path.move(to: CGPoint(x: 6, y: 22))
            path.addCurve(to: CGPoint(x: 16, y: 14),
                          control1: CGPoint(x: 10, y: 24), control2: CGPoint(x: 12, y: 13))
            path.addCurve(to: CGPoint(x: 27, y: 9),
                          control1: CGPoint(x: 20, y: 15), control2: CGPoint(x: 22, y: 7))
            context.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: 4, lineCap: .round))

        case "maggot":
            // Drei kleine Maden.
            for (index, offset) in [CGPoint(x: 9, y: 12), CGPoint(x: 18, y: 20), CGPoint(x: 24, y: 11)].enumerated() {
                let rect = CGRect(x: offset.x, y: offset.y, width: 9, height: 5)
                context.fill(Capsule().path(in: rect), with: .color(tint))
                _ = index
            }

        case "corn":
            // Drei Maiskörner am Haken.
            for offset in [CGPoint(x: 10, y: 10), CGPoint(x: 16, y: 15), CGPoint(x: 22, y: 20)] {
                let rect = CGRect(x: offset.x, y: offset.y, width: 8, height: 7)
                context.fill(Ellipse().path(in: rect), with: .color(tint))
            }

        case "bread":
            // Weiche Flocke.
            var path = Path()
            path.addRoundedRect(in: CGRect(x: 8, y: 10, width: 18, height: 14),
                                cornerSize: CGSize(width: 6, height: 6))
            context.fill(path, with: .color(tint))
            context.stroke(path, with: .color(dark.opacity(0.4)), lineWidth: 1)

        case "insect":
            // Eintagsfliege mit zwei Flügeln.
            context.fill(Ellipse().path(in: CGRect(x: 13, y: 15, width: 12, height: 5)),
                         with: .color(tint))
            for flip in [CGFloat(-1), CGFloat(1)] {
                var wing = Path()
                wing.addEllipse(in: CGRect(x: 12, y: 17 + flip * 7, width: 13, height: 6))
                context.fill(wing, with: .color(.white.opacity(0.6)))
            }

        case "minnow":
            // Kleiner Köderfisch.
            var body = Path()
            body.addEllipse(in: CGRect(x: 9, y: 13, width: 16, height: 8))
            context.fill(body, with: .color(tint))
            var tail = Path()
            tail.move(to: CGPoint(x: 9, y: 17))
            tail.addLine(to: CGPoint(x: 3, y: 12))
            tail.addLine(to: CGPoint(x: 3, y: 22))
            tail.closeSubpath()
            context.fill(tail, with: .color(tint))
            context.fill(Circle().path(in: CGRect(x: 21, y: 15, width: 3, height: 3)),
                         with: .color(dark))

        case "spinner":
            // Achse mit rotierendem Blatt.
            var axis = Path()
            axis.move(to: CGPoint(x: 8, y: 8))
            axis.addLine(to: CGPoint(x: 24, y: 26))
            context.stroke(axis, with: .color(dark), lineWidth: 2)
            context.fill(Ellipse().path(in: CGRect(x: 14, y: 9, width: 8, height: 13)),
                         with: .color(tint))

        case "spoon":
            // Trudelndes Blech.
            var blade = Path()
            blade.addEllipse(in: CGRect(x: 11, y: 7, width: 12, height: 20))
            context.fill(blade, with: .color(tint))
            context.stroke(blade, with: .color(dark.opacity(0.5)), lineWidth: 1)
            context.fill(Ellipse().path(in: CGRect(x: 15, y: 12, width: 4, height: 7)),
                         with: .color(.white.opacity(0.5)))

        case "wobbler":
            // Körper mit Tauchschaufel.
            context.fill(Capsule().path(in: CGRect(x: 8, y: 13, width: 19, height: 9)),
                         with: .color(tint))
            var lip = Path()
            lip.move(to: CGPoint(x: 8, y: 15))
            lip.addLine(to: CGPoint(x: 2, y: 22))
            lip.addLine(to: CGPoint(x: 8, y: 21))
            lip.closeSubpath()
            context.fill(lip, with: .color(dark.opacity(0.6)))

        case "softbait":
            // Gummifisch mit Schaufelschwanz.
            context.fill(Capsule().path(in: CGRect(x: 10, y: 14, width: 17, height: 8)),
                         with: .color(tint))
            context.fill(Ellipse().path(in: CGRect(x: 5, y: 13, width: 7, height: 10)),
                         with: .color(tint.opacity(0.75)))

        case "fly":
            // Fliege: Körper, Flügel, Haken.
            context.fill(Ellipse().path(in: CGRect(x: 14, y: 15, width: 10, height: 5)),
                         with: .color(tint))
            var wings = Path()
            wings.addEllipse(in: CGRect(x: 12, y: 9, width: 12, height: 7))
            context.fill(wings, with: .color(.white.opacity(0.55)))
            var hook = Path()
            hook.move(to: CGPoint(x: 14, y: 20))
            hook.addQuadCurve(to: CGPoint(x: 20, y: 26), control: CGPoint(x: 13, y: 26))
            context.stroke(hook, with: .color(dark), lineWidth: 1.6)

        case "red_october":
            // Schwerer Blinker in Rot mit goldenem Stern.
            var blade = Path()
            blade.addEllipse(in: CGRect(x: 9, y: 5, width: 16, height: 24))
            context.fill(blade, with: .color(tint))
            context.stroke(blade, with: .color(Palette.gold.swiftUIColor.opacity(0.8)), lineWidth: 1.4)

            // Fünfzackiger Stern in der Mitte.
            var star = Path()
            let center = CGPoint(x: 17, y: 17)
            for index in 0..<10 {
                let angle = Double(index) * .pi / 5 - .pi / 2
                let radius: Double = index % 2 == 0 ? 6 : 2.6
                let point = CGPoint(x: center.x + cos(angle) * radius,
                                    y: center.y + sin(angle) * radius)
                if index == 0 { star.move(to: point) } else { star.addLine(to: point) }
            }
            star.closeSubpath()
            context.fill(star, with: .color(Palette.gold.swiftUIColor))

            // Lichtblitz an der Kante.
            context.fill(Ellipse().path(in: CGRect(x: 11, y: 8, width: 4, height: 8)),
                         with: .color(.white.opacity(0.55)))

        case "moonbait":
            // Perle mit Mondsichel.
            context.fill(Circle().path(in: CGRect(x: 10, y: 10, width: 15, height: 15)),
                         with: .color(tint))
            var crescent = Path()
            crescent.addArc(center: CGPoint(x: 17, y: 17), radius: 5.5,
                            startAngle: .degrees(40), endAngle: .degrees(320), clockwise: false)
            context.stroke(crescent, with: .color(Palette.gold.swiftUIColor), lineWidth: 2.2)

        default:
            context.fill(Circle().path(in: CGRect(x: 11, y: 11, width: 13, height: 13)),
                         with: .color(tint))
        }
    }
}
