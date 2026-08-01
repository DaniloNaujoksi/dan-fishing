import SwiftUI

/// Gemeinsame Bausteine der Oberfläche: papierartige Flächen, Pinselstriche
/// und Knöpfe. An einer Stelle gesammelt, damit die Menüs zusammenpassen.
struct PaperPanel<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.paper.swiftUIColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Palette.inkSoft.swiftUIColor.opacity(0.22), lineWidth: 1)
                    )
                    .overlay(PaperTexture().clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)))
                    .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
            )
    }
}

/// Feine Struktur auf Papierflächen. Bewusst sehr dezent — sie soll spürbar,
/// aber nicht sichtbar sein.
struct PaperTexture: View {
    var body: some View {
        Canvas { context, size in
            for _ in 0..<160 {
                let x = Double.random(in: 0...size.width)
                let y = Double.random(in: 0...size.height)
                let radius = Double.random(in: 0.5...1.6)
                let rect = CGRect(x: x, y: y, width: radius, height: radius)
                context.fill(Path(ellipseIn: rect),
                             with: .color(Palette.inkSoft.swiftUIColor.opacity(0.05)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Knopf im Stil eines Holzschnitts.
struct BrushButtonStyle: ButtonStyle {
    var tint: Color = Palette.vermilion.swiftUIColor
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .serif))
            .foregroundStyle(filled ? Palette.paper.swiftUIColor : tint)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(filled ? tint : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(tint.opacity(filled ? 0 : 0.6), lineWidth: 1.5)
                    )
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Überschrift mit Zierstrich, wie in einem Naturtagebuch.
struct SectionHeading: View {
    let text: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.uiInk)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(Palette.inkSoft.swiftUIColor)
            }

            Rectangle()
                .fill(Palette.vermilion.swiftUIColor.opacity(0.7))
                .frame(width: 46, height: 2)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Kleine Werteanzeige (Münzen, Stufe, Uhrzeit).
struct StatChip: View {
    let symbol: String
    let value: String
    var tint: Color = Palette.uiInk

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Palette.paper.swiftUIColor.opacity(0.88))
        )
    }
}

/// Hintergrund für alle Menüs: Verlauf von Morgenlicht zu Wasser.
struct MenuBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [
                ColorSpec(0xE9D8BF).swiftUIColor,
                ColorSpec(0xC9D6CE).swiftUIColor,
                Palette.water.swiftUIColor
            ], startPoint: .top, endPoint: .bottom)

            // Angedeutete Bergrücken im Hintergrund.
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height

                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.42))
                    path.addQuadCurve(to: CGPoint(x: width * 0.45, y: height * 0.33),
                                      control: CGPoint(x: width * 0.22, y: height * 0.24))
                    path.addQuadCurve(to: CGPoint(x: width, y: height * 0.40),
                                      control: CGPoint(x: width * 0.75, y: height * 0.26))
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(ColorSpec(0x8FA5A0).swiftUIColor.opacity(0.55))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.52))
                    path.addQuadCurve(to: CGPoint(x: width * 0.6, y: height * 0.46),
                                      control: CGPoint(x: width * 0.3, y: height * 0.36))
                    path.addQuadCurve(to: CGPoint(x: width, y: height * 0.54),
                                      control: CGPoint(x: width * 0.85, y: height * 0.40))
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(ColorSpec(0x6E8A8C).swiftUIColor.opacity(0.6))
            }
        }
        .ignoresSafeArea()
    }
}
