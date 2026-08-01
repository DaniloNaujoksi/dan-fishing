import SwiftUI

/// Einblendung, wenn eine Art zum ersten Mal gefangen wurde — und dieselbe
/// Inszenierung, um eine gefangene Legende noch einmal anzusehen.
///
/// Der Moment war vorher nur eine kleine Zeile auf der Fangkarte. Eine neue
/// Art ist aber das, was den Fortschritt trägt — sie verdient einen eigenen
/// Auftritt: Strahlen, die aus dem Fisch hervorbrechen, ein Aufziehen der
/// Karte und eine kurze Fanfare.
struct NewSpeciesBanner: View {
    let species: FishSpecies

    /// Zeile über dem Namen.
    var headline: String = "Neue Art entdeckt"
    /// Name in groß. Nil heißt: der Artname.
    var title: String?
    /// Zeile darunter. Nil heißt: die Seltenheit der Art.
    var subtitle: String?
    /// Fußzeile mit Symbol, etwa der Entdeckerbonus.
    var footnote: String?
    var footnoteSymbol: String = "circle.hexagongrid.fill"
    /// Farbe der Strahlen und der Kopfzeile.
    var accent: Color = Palette.gold.swiftUIColor
    /// Ist die Einblendung antippbar (zum Schließen)?
    var onDismiss: (() -> Void)?

    @State private var appeared = false
    @State private var rayTurn = false
    @State private var sparkle = false

    /// Kurzform für den Entdeckerbonus, damit die alte Verwendung kurz bleibt.
    init(species: FishSpecies, bonusCoins: Int) {
        self.species = species
        self.footnote = "+\(bonusCoins) Münzen Entdeckerbonus"
    }

    init(species: FishSpecies,
         headline: String,
         title: String? = nil,
         subtitle: String? = nil,
         footnote: String? = nil,
         footnoteSymbol: String = "circle.hexagongrid.fill",
         accent: Color = Palette.gold.swiftUIColor,
         onDismiss: (() -> Void)? = nil) {
        self.species = species
        self.headline = headline
        self.title = title
        self.subtitle = subtitle
        self.footnote = footnote
        self.footnoteSymbol = footnoteSymbol
        self.accent = accent
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.35 : 0)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    // Strahlenkranz hinter dem Fisch.
                    ForEach(0..<12, id: \.self) { index in
                        Capsule()
                            .fill(
                                LinearGradient(colors: [accent.opacity(0.75),
                                                        accent.opacity(0)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .frame(width: 10, height: 130)
                            .offset(y: -70)
                            .rotationEffect(.degrees(Double(index) * 30))
                    }
                    .rotationEffect(.degrees(rayTurn ? 30 : 0))
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)

                    // Der Fisch selbst, in voller Zeichnung.
                    FishSilhouette(species: species)
                        .frame(width: 210, height: 84)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

                    // Funkeln an drei Stellen.
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "sparkle")
                            .font(.system(size: [18, 13, 15][index]))
                            .foregroundStyle(accent)
                            .offset(x: [-96, 84, 40][index], y: [-40, -46, 44][index])
                            .opacity(sparkle ? 1 : 0)
                            .scaleEffect(sparkle ? 1 : 0.4)
                    }
                }
                .frame(height: 170)

                VStack(spacing: 6) {
                    Text(headline)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(accent)

                    Text(title ?? species.name)
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(Palette.paper.swiftUIColor)
                        .multilineTextAlignment(.center)

                    Text(subtitle ?? species.rarity.displayName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(subtitle == nil ? species.rarity.tint
                                                         : Palette.paper.swiftUIColor.opacity(0.8))

                    if let footnote {
                        Label(footnote, systemImage: footnoteSymbol)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.paper.swiftUIColor.opacity(0.9))
                            .padding(.top, 4)
                    }

                    if onDismiss != nil {
                        Text("Tippen zum Schließen")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Palette.paper.swiftUIColor.opacity(0.55))
                            .padding(.top, 10)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
            .padding(28)
        }
        .contentShape(Rectangle())
        .allowsHitTesting(onDismiss != nil)
        .onTapGesture { onDismiss?() }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2.2)) {
                rayTurn = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
                sparkle = true
            }
        }
    }
}
