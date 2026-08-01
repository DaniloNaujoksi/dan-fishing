import SwiftUI

/// Das Fang-Minispiel. Links die Bahn mit Fisch und Fangbereich, rechts die
/// Spannung der Schnur, unten die große Einholtaste.
///
/// Bewusst ohne SwiftUI-Animationen auf Fisch, Balken und Anzeigen: Die Werte
/// kommen bereits mit jedem Bild aus der Spielschleife. Eine zusätzliche
/// Animation läuft dieser Aktualisierung hinterher und lässt die Anzeige
/// ruckeln, statt sie zu glätten.
struct CatchMiniGameView: View {
    let state: MiniGameSnapshot
    let onReelChanged: (Bool) -> Void

    @State private var isReeling = false

    private let trackHeight: CGFloat = 330

    private var barHeight: CGFloat {
        max(20, trackHeight * CGFloat(state.barUpper - state.barLower))
    }

    private var barCenter: CGFloat {
        CGFloat((state.barLower + state.barUpper) / 2)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 16) {
                Text(state.speciesName.isEmpty ? "Am Haken" : state.speciesName)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.paper.swiftUIColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Palette.ink.swiftUIColor.opacity(0.55)))

                HStack(alignment: .center, spacing: 22) {
                    track
                    tensionGauge
                }

                progressBar

                reelButton
            }
            .padding(.vertical, 22)
        }
    }

    // MARK: - Bahn mit Fisch

    private var track: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.waterDeep.swiftUIColor.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Palette.paper.swiftUIColor.opacity(0.5), lineWidth: 1.5)
                )
                .frame(width: 74, height: trackHeight)

            // Fangbereich. Der ZStack ist unten ausgerichtet: Ein Kind sitzt
            // ohne Versatz mit seiner Mitte auf halber eigener Höhe über dem
            // Boden, deshalb die Korrektur um die halbe Balkenhöhe.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(state.isFishInBar
                      ? Palette.moss.swiftUIColor.opacity(0.85)
                      : Palette.paper.swiftUIColor.opacity(0.4))
                .frame(width: 62, height: barHeight)
                .offset(y: -(barCenter * trackHeight - barHeight / 2))


            // Fisch
            Image(systemName: "fish.fill")
                .font(.system(size: 26))
                .foregroundStyle(Palette.paper.swiftUIColor)
                .rotationEffect(.degrees(-90))
                .offset(y: -trackHeight * CGFloat(state.fishPosition) + 14)

        }
        .frame(width: 74, height: trackHeight)
    }

    // MARK: - Spannung

    private var tensionGauge: some View {
        VStack(spacing: 8) {
            Text("Spannung")
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundStyle(Palette.paper.swiftUIColor)

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Palette.ink.swiftUIColor.opacity(0.45))
                    .frame(width: 22, height: trackHeight - 30)

                Capsule()
                    .fill(tensionColor)
                    .frame(width: 22, height: max(6, (trackHeight - 30) * CGFloat(min(1, state.tension))))


                // Markierung, ab wo es kritisch wird.
                Rectangle()
                    .fill(Palette.paper.swiftUIColor.opacity(0.8))
                    .frame(width: 30, height: 2)
                    .offset(y: -(trackHeight - 30) * 0.82)
            }
        }
    }

    private var tensionColor: Color {
        if state.tension > 0.82 { return Palette.vermilion.swiftUIColor }
        if state.tension > 0.6 { return ColorSpec(0xD8A24A).swiftUIColor }
        return Palette.moss.swiftUIColor
    }

    // MARK: - Fortschritt und Taste

    private var progressBar: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.ink.swiftUIColor.opacity(0.4))
                    .frame(width: 240, height: 12)
                Capsule()
                    .fill(Palette.paper.swiftUIColor)
                    .frame(width: max(8, 240 * CGFloat(state.progress)), height: 12)

            }
            Text("eingeholt")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.paper.swiftUIColor.opacity(0.9))
        }
    }

    private var reelButton: some View {
        Circle()
            .fill(isReeling ? Palette.vermilion.swiftUIColor : ColorSpec(0x4E6E7A).swiftUIColor)
            .frame(width: 110, height: 110)
            .overlay(
                VStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 30, weight: .semibold))
                    Text("Einholen")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                }
                .foregroundStyle(Palette.paper.swiftUIColor)
            )
            .overlay(
                Circle().strokeBorder(Palette.paper.swiftUIColor.opacity(0.85), lineWidth: 2)
            )
            .scaleEffect(isReeling ? 0.96 : 1)
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isReeling else { return }
                        isReeling = true
                        onReelChanged(true)
                    }
                    .onEnded { _ in
                        isReeling = false
                        onReelChanged(false)
                    }
            )
            .onDisappear { onReelChanged(false) }
    }
}
