import SwiftUI

/// Die Karte nach einem gelandeten Fisch. Hier entscheidet der Spieler, was
/// mit dem Fang passiert — verkaufen, behalten oder zurücksetzen.
struct CatchResultView: View {
    @EnvironmentObject private var session: GameSession
    let result: CatchResult

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            PaperPanel(padding: 22) {
                VStack(spacing: 16) {
                    header
                    fishPortrait
                    measurements
                    badges
                    actions
                }
                .frame(maxWidth: 320)
            }
            .padding(28)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(headline)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .textCase(.uppercase)
                .foregroundStyle(result.fish.isLegendary
                                 ? Palette.gold.swiftUIColor
                                 : Palette.vermilion.swiftUIColor)

            // Bei einer Legende steht ihr Name groß — die Art darunter.
            Text(result.fish.legendName ?? result.fish.species.name)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.uiInk)
                .multilineTextAlignment(.center)

            Text(result.fish.isLegendary
                 ? result.fish.species.name
                 : result.fish.species.rarity.displayName)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(result.fish.isLegendary
                                 ? Palette.inkSoft.swiftUIColor
                                 : result.fish.species.rarity.tint)
        }
    }

    private var headline: String {
        if result.fish.isLegendary { return "Legende gefangen!" }
        return result.isNewSpecies ? "Neue Art!" : "Gefangen"
    }

    /// Der Fisch in seinen Farben, in der Größe passend zum Exemplar.
    private var fishPortrait: some View {
        ZStack {
            Capsule()
                .fill(Palette.water.swiftUIColor.opacity(0.25))
                .frame(height: 92)

            FishSilhouette(species: result.fish.species)
                .frame(width: 190, height: 70)
                .scaleEffect(0.75 + CGFloat(result.fish.trophyFactor) * 0.35)
        }
    }

    private var measurements: some View {
        HStack(spacing: 22) {
            measure(title: "Länge", value: String(format: "%.1f cm", result.fish.lengthCm))
            measure(title: "Gewicht", value: String(format: "%.2f kg", result.fish.weightKg))
            measure(title: "Erlös", value: "+\(result.coins) 🪙")
        }
    }

    private func measure(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.inkSoft.swiftUIColor)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.uiInk)
                .monospacedDigit()
        }
    }

    private var badges: some View {
        VStack(spacing: 6) {
            if result.fish.isTrophy {
                badge(text: "Außergewöhnliches Exemplar", symbol: "crown.fill",
                      color: Palette.gold.swiftUIColor)
            }
            if result.isPersonalRecord && !result.isNewSpecies {
                badge(text: "Persönlicher Rekord", symbol: "chart.line.uptrend.xyaxis",
                      color: Palette.moss.swiftUIColor)
            }
            badge(text: "+\(result.experience) Erfahrung", symbol: "sparkles",
                  color: Palette.inkSoft.swiftUIColor)

            if !session.completedMissions.isEmpty {
                ForEach(session.completedMissions) { mission in
                    badge(text: "Aufgabe erfüllt: \(mission.title)",
                          symbol: "checkmark.seal.fill",
                          color: Palette.vermilion.swiftUIColor)
                }
            }
        }
    }

    private func badge(text: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .serif))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    /// Ein Knopf, kein Menü.
    ///
    /// Münzen und Erfahrung sind beim Landen bereits gutgeschrieben; die Karte
    /// zeigt nur, was der Fisch eingebracht hat. Die frühere Wahl zwischen
    /// Verkaufen, Behalten und Freilassen hatte nur einen Zweig mit Wirkung
    /// und hielt den Spielfluss ohne Gegenwert auf.
    private var actions: some View {
        Button("Weiter") {
            session.dismissCatch()
        }
        .buttonStyle(BrushButtonStyle())
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }
}

/// Fischform in den Farben der Art. Dieselbe Silhouette nutzt das Fangbuch —
/// dadurch sehen Fang und Eintrag gleich aus.
struct FishSilhouette: View {
    let species: FishSpecies
    var silhouetteOnly: Bool = false

    var body: some View {
        if let image = UIImage(named: "fish_\(species.id)") {
            // Gezeichnete Grafik. Unbekannte Arten erscheinen als dunkle
            // Silhouette, damit das Fangbuch nichts vorwegnimmt.
            // Unbekannte Arten erscheinen als vollständig schwarze Silhouette:
            // Man sieht die Form, aber nichts von der Zeichnung — das hält die
            // Neugier auf den ersten Fang wach.
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .scaleEffect(x: -1)
                .colorMultiply(silhouetteOnly ? .black : .white)
        } else {
            drawnShape
        }
    }

    /// Rückfallebene, solange für eine Art keine Grafik vorliegt.
    private var drawnShape: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let midY = height / 2

            ZStack {
                // Schwanz
                Path { path in
                    path.move(to: CGPoint(x: width * 0.13, y: midY))
                    path.addLine(to: CGPoint(x: 0, y: midY - height * 0.30))
                    path.addLine(to: CGPoint(x: width * 0.05, y: midY))
                    path.addLine(to: CGPoint(x: 0, y: midY + height * 0.30))
                    path.closeSubpath()
                }
                .fill(silhouetteOnly ? Palette.inkSoft.swiftUIColor.opacity(0.35)
                                     : species.finColor.swiftUIColor)

                // Rückenflosse
                Path { path in
                    path.move(to: CGPoint(x: width * 0.36, y: midY - height * 0.22))
                    path.addLine(to: CGPoint(x: width * 0.52, y: midY - height * 0.46))
                    path.addLine(to: CGPoint(x: width * 0.64, y: midY - height * 0.20))
                    path.closeSubpath()
                }
                .fill(silhouetteOnly ? Palette.inkSoft.swiftUIColor.opacity(0.35)
                                     : species.finColor.swiftUIColor)

                // Körper
                Path { path in
                    path.move(to: CGPoint(x: width * 0.96, y: midY))
                    path.addCurve(to: CGPoint(x: width * 0.5, y: midY - height * 0.34),
                                  control1: CGPoint(x: width * 0.84, y: midY - height * 0.30),
                                  control2: CGPoint(x: width * 0.66, y: midY - height * 0.36))
                    path.addCurve(to: CGPoint(x: width * 0.1, y: midY),
                                  control1: CGPoint(x: width * 0.30, y: midY - height * 0.32),
                                  control2: CGPoint(x: width * 0.15, y: midY - height * 0.14))
                    path.addCurve(to: CGPoint(x: width * 0.5, y: midY + height * 0.34),
                                  control1: CGPoint(x: width * 0.15, y: midY + height * 0.14),
                                  control2: CGPoint(x: width * 0.30, y: midY + height * 0.32))
                    path.addCurve(to: CGPoint(x: width * 0.96, y: midY),
                                  control1: CGPoint(x: width * 0.66, y: midY + height * 0.36),
                                  control2: CGPoint(x: width * 0.84, y: midY + height * 0.30))
                    path.closeSubpath()
                }
                .fill(silhouetteOnly ? Palette.inkSoft.swiftUIColor.opacity(0.45)
                                     : species.bodyColor.swiftUIColor)

                if !silhouetteOnly {
                    // Auge
                    Circle()
                        .fill(Palette.ink.swiftUIColor.opacity(0.85))
                        .frame(width: height * 0.11, height: height * 0.11)
                        .position(x: width * 0.85, y: midY - height * 0.08)
                }
            }
        }
    }
}
