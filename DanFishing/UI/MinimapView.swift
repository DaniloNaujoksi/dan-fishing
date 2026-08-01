import SwiftUI

/// Übersicht über den See in der Ecke.
///
/// Der See ist deutlich größer als der Bildausschnitt; ohne Karte weiß man
/// nicht, wo man ist und wohin sich das Rudern lohnt. Gezeigt werden die
/// Umrisse, die Zonen in ihren Farben, das Boot mit Blickrichtung und — falls
/// ausgeworfen — der Köder.
struct MinimapView: View {

    /// Vorberechnete Kartendaten. Das Bild wird einmal erzeugt und danach nur
    /// noch angezeigt; pro Bild neu zu zeichnen wäre Verschwendung.
    let image: UIImage?
    /// Bootsposition in Weltkoordinaten.
    let boat: CGPoint
    /// Blickrichtung in Bogenmaß.
    let heading: CGFloat
    /// Position des Köders, falls einer im Wasser liegt.
    let lure: CGPoint?
    /// Größe der Spielwelt.
    let worldSize: CGSize

    var size: CGFloat = 104

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fill)
            } else {
                Palette.water.swiftUIColor
            }

            // Köder
            if let lure {
                Circle()
                    .fill(Palette.paper.swiftUIColor)
                    .frame(width: 5, height: 5)
                    .position(mapped(lure))
            }

            // Boot als kleine Spitze in Fahrtrichtung.
            Triangle()
                .fill(Palette.vermilion.swiftUIColor)
                .frame(width: 9, height: 11)
                .rotationEffect(.radians(Double(-heading) + .pi / 2))
                .position(mapped(boat))
                .shadow(color: .black.opacity(0.3), radius: 1)
        }
        .frame(width: size, height: size * (worldSize.height / max(worldSize.width, 1)))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.paper.swiftUIColor.opacity(0.75), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
    }

    /// Rechnet Weltkoordinaten in Punkte auf der Karte um. Die Welt zählt y
    /// nach oben, SwiftUI nach unten.
    private func mapped(_ point: CGPoint) -> CGPoint {
        let height = size * (worldSize.height / max(worldSize.width, 1))
        let x = point.x / max(worldSize.width, 1) * size
        let y = (1 - point.y / max(worldSize.height, 1)) * height
        return CGPoint(x: x, y: y)
    }
}

/// Schlichtes Dreieck als Bootsmarkierung.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.72))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
