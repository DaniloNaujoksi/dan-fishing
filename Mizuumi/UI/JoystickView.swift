import SwiftUI

/// Virtueller Joystick für die linke Bildschirmhälfte.
///
/// Der Knopf folgt dem Finger innerhalb eines Kreises. Nach oben gezogen fährt
/// das Boot nach oben — SwiftUI zählt y nach unten, SpriteKit nach oben,
/// deshalb wird die Achse hier einmal gedreht.
struct JoystickView: View {

    /// Wird bei jeder Änderung mit einem Vektor der Länge 0…1 aufgerufen.
    let onChange: (CGVector) -> Void

    private let baseRadius: CGFloat = 62
    private let knobRadius: CGFloat = 27

    @State private var knobOffset: CGSize = .zero
    @State private var isActive = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.paper.swiftUIColor.opacity(isActive ? 0.30 : 0.18))
                .overlay(
                    Circle().strokeBorder(Palette.paper.swiftUIColor.opacity(0.5), lineWidth: 1.5)
                )
                .frame(width: baseRadius * 2, height: baseRadius * 2)

            // Vier feine Striche als Richtungshilfe.
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(Palette.paper.swiftUIColor.opacity(0.35))
                    .frame(width: 1.5, height: 10)
                    .offset(y: -baseRadius + 9)
                    .rotationEffect(.degrees(Double(index) * 90))
            }

            Circle()
                .fill(Palette.paper.swiftUIColor.opacity(0.85))
                .overlay(
                    Circle().strokeBorder(Palette.inkSoft.swiftUIColor.opacity(0.35), lineWidth: 1)
                )
                .frame(width: knobRadius * 2, height: knobRadius * 2)
                .offset(knobOffset)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
        .frame(width: baseRadius * 2, height: baseRadius * 2)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isActive = true
                    let raw = CGSize(width: value.translation.width, height: value.translation.height)
                    let distance = sqrt(raw.width * raw.width + raw.height * raw.height)
                    let limit = baseRadius - knobRadius * 0.4

                    if distance > limit && distance > 0 {
                        let factor = limit / distance
                        knobOffset = CGSize(width: raw.width * factor, height: raw.height * factor)
                    } else {
                        knobOffset = raw
                    }

                    guard distance > 0.001 else {
                        onChange(.zero)
                        return
                    }

                    // Richtung aus der Fingerbewegung, Länge auf 0…1 begrenzt.
                    let magnitude = min(1, distance / limit)
                    onChange(CGVector(dx: raw.width / distance * magnitude,
                                      dy: -raw.height / distance * magnitude))
                }
                .onEnded { _ in
                    isActive = false
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        knobOffset = .zero
                    }
                    onChange(.zero)
                }
        )
    }
}
