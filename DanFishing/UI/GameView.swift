import SpriteKit
import SwiftUI

/// Der Spielbildschirm: SpriteKit-Szene mit einer dünnen Bedienschicht darüber.
struct GameView: View {
    @EnvironmentObject private var session: GameSession

    @State private var scene: LakeScene?
    @State private var isPressingAction = false
    @State private var minimapExpanded = false
    @State private var showBaitBox = false
    @State private var showCodex = false
    @State private var showShop = false
    @State private var showMissions = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let scene {
                    SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                        .ignoresSafeArea()
                } else {
                    Palette.water.swiftUIColor.ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    levelBar
                    topBar

                    HStack {
                        Spacer()
                        minimapOverlay
                    }
                    .padding(.top, 10)

                    Spacer()

                    if session.miniGame == nil {
                        bottomControls
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 18)

                if let miniGame = session.miniGame {
                    CatchMiniGameView(state: miniGame,
                                      onReelChanged: { session.isReeling = $0 })
                        .transition(.opacity)
                }

                if let result = session.pendingCatch {
                    CatchResultView(result: result)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }

                if let step = session.tutorialStep, session.pendingCatch == nil {
                    TutorialOverlay(step: step) { session.skipTutorial() }
                }

                // Meldungen stehen mittig im Bild: Am unteren Rand gingen sie
                // zwischen Wurftaste und Köderanzeige unter.
                if let toast = session.toast {
                    toastView(toast)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                if scene == nil {
                    scene = LakeScene(size: geometry.size, session: session)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: session.miniGame == nil)
            .animation(.easeOut(duration: 0.25), value: session.pendingCatch)
            .animation(.easeInOut(duration: 0.3), value: session.tutorialStep)
        }
        .sheet(isPresented: $showBaitBox) { BaitBoxView() }
        .sheet(isPresented: $showCodex) { CodexView() }
        .sheet(isPresented: $showShop) { ShopView() }
        .sheet(isPresented: $showMissions) { MissionsView() }
    }

    // MARK: - Kopfleiste

    /// Kopfbereich in zwei Zeilen.
    ///
    /// Vorher standen Zurück-Knopf, Werteanzeigen und die drei Menüknöpfe in
    /// einer Reihe — sobald die Anzeigen breiter wurden, schoben sie die
    /// Knöpfe über den Bildrand hinaus. Jetzt hat jede Gruppe ihre eigene
    /// Zeile und die Werte dürfen notfalls seitlich scrollen.
    private var topBar: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Button {
                        session.returnToMenu()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.uiInk)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Palette.paper.swiftUIColor.opacity(0.92)))
                    }

                    // Münzen, Stufe und Uhrzeit stehen zusammen auf einer
                    // Tafel statt als drei einzelne Kacheln. Eine feste Gruppe
                    // kann nicht mehr am Rand anstoßen, egal wie lang die
                    // Zahlen werden.
                    HStack(spacing: 0) {
                        hudValue("circle.hexagongrid.fill", "\(session.save.coins)",
                                 tint: Palette.gold.swiftUIColor)
                        hudDivider
                        hudValue("star.fill", "\(session.save.level)")
                        hudDivider
                        hudValue("clock", session.clockText)
                    }
                    .background(
                        Capsule().fill(Palette.paper.swiftUIColor.opacity(0.92))
                    )
                }

                if session.save.settings.showDepthHint {
                    HStack(spacing: 0) {
                        hudValue("water.waves", session.habitatText)
                        hudDivider
                        hudValue("arrow.down.to.line", session.depthText)
                        if session.stats.hasFishFinder {
                            hudDivider
                            hudValue("dot.radiowaves.up.forward", activityText,
                                     tint: Palette.moss.swiftUIColor)
                        }
                    }
                    .background(
                        Capsule().fill(Palette.paper.swiftUIColor.opacity(UIStyle.overlayOpacity))
                    )
                    .padding(.leading, 42)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 8) {
                iconButton("book.closed", label: "Fangbuch") { showCodex = true }
                iconButton("bag", label: "Shop") { showShop = true }
                iconButton("checklist", label: "Aufgaben") { showMissions = true }
            }
        }
        .padding(.top, 8)
    }

    /// Schmaler Fortschrittsbalken über der ganzen Breite.
    ///
    /// Die Stufe stand bisher nur als Zahl in der Kopfzeile — man sah nicht,
    /// wie weit die nächste entfernt ist. Der Balken beantwortet genau das,
    /// ohne Platz zu beanspruchen.
    private var levelBar: some View {
        let needed = max(1, session.save.experienceForNextLevel)
        let progress = min(1, Double(session.save.experience) / Double(needed))

        return VStack(spacing: 3) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.ink.swiftUIColor.opacity(0.22))

                    Capsule()
                        .fill(
                            LinearGradient(colors: [Palette.gold.swiftUIColor,
                                                    Palette.vermilion.swiftUIColor],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(4, geometry.size.width * progress))
                }
            }
            .frame(height: 6)

            HStack {
                Text("Stufe \(session.save.level)")
                Spacer()
                Text("\(session.save.experience) / \(needed) EP")
                    .monospacedDigit()
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(Palette.paper.swiftUIColor.opacity(0.9))
            .shadow(color: .black.opacity(0.35), radius: 2)
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .animation(.easeOut(duration: 0.4), value: session.save.experience)
    }

    /// Ein Wert in der Kopfzeile.
    private func hudValue(_ symbol: String, _ value: String,
                          tint: Color = Palette.uiInk) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
    }

    private var hudDivider: some View {
        Rectangle()
            .fill(Palette.inkSoft.swiftUIColor.opacity(0.22))
            .frame(width: 1, height: 15)
    }

    /// Die Minimap sitzt frei über dem Wasser und lässt sich antippen.
    @ViewBuilder
    private var minimapOverlay: some View {
        if let minimap = session.minimap {
            MinimapView(image: session.minimapImage,
                        boat: minimap.boat,
                        heading: minimap.heading,
                        lure: minimap.lure,
                        worldSize: minimap.worldSize,
                        size: minimapExpanded ? 210 : 62)
                .opacity(minimapExpanded ? 0.96 : 0.55)
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        minimapExpanded.toggle()
                    }
                    HapticManager.shared.selection()
                }
        }
    }

    private var activityText: String {
        switch session.activityScore {
        case ..<0.2: return "leer"
        case ..<0.45: return "wenig"
        case ..<0.7: return "gut"
        default: return "reich"
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .medium))
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
            }
            .foregroundStyle(Palette.uiInk)
            .frame(width: 64, height: 52)
            .background(
                RoundedRectangle(cornerRadius: UIStyle.controlRadius, style: .continuous)
                    .fill(Palette.paper.swiftUIColor.opacity(UIStyle.overlayOpacity))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            )
        }
    }

    // MARK: - Steuerung unten

    private var bottomControls: some View {
        HStack(alignment: .bottom) {
            JoystickView { vector in
                session.joystick = vector
                if hypot(vector.dx, vector.dy) > 0.4 {
                    session.reportTutorial(.boatMoved)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 14) {
                if session.fishingPhase == .waiting || session.fishingPhase == .nibble {
                    reelInButton
                }
                baitButton
                castHint
                actionButton
            }
        }
    }

    /// Erscheint nur, solange der Köder im Wasser liegt. Vorher war das ein
    /// verstecktes langes Halten auf der Wurftaste — das fand niemand.
    private var reelInButton: some View {
        Button {
            scene?.reelIn()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 12, weight: .semibold))
                Text("Einholen")
                    .font(.system(size: 14, weight: .medium, design: .serif))
            }
            .foregroundStyle(Palette.uiInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Palette.paper.swiftUIColor.opacity(UIStyle.overlayOpacity)))
        }
    }

    private var baitButton: some View {
        Button {
            showBaitBox = true
        } label: {
            HStack(spacing: 8) {
                BaitIcon(bait: session.selectedBait, size: 26)
                Text(session.selectedBait.name)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.uiInk)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Palette.paper.swiftUIColor.opacity(UIStyle.overlayOpacity)))
        }
    }

    /// Kurzer Text, der sagt, was die große Taste gerade tut.
    private var castHint: some View {
        Group {
            switch session.fishingPhase {
            case .idle:
                hintText("Ziehen und loslassen")
            case .aiming:
                castPowerBar
            case .flying:
                hintText("…")
            case .waiting:
                hintText("Warten")
            case .nibble:
                hintText("Etwas zupft")
            case .biteWindow:
                hintText("Jetzt anschlagen!", emphasis: true)
            case .hooked:
                hintText("Dran!")
            }
        }
    }

    private func hintText(_ text: String, emphasis: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 13, weight: emphasis ? .bold : .regular, design: .serif))
            .foregroundStyle(emphasis ? Palette.paper.swiftUIColor : Palette.uiInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(emphasis
                               ? Palette.vermilion.swiftUIColor
                               : Palette.paper.swiftUIColor.opacity(0.82))
            )
    }

    /// Feinanzeige der Wurfweite. Die eigentliche Rückmeldung steht auf dem
    /// Wasser — hier steht nur, wie weit die Rute gerade geladen ist.
    private var castPowerBar: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Wurfweite")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.uiInk)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.paper.swiftUIColor.opacity(0.8))
                    .frame(width: 150, height: 10)
                Capsule()
                    .fill(Palette.vermilion.swiftUIColor)
                    .frame(width: max(6, 150 * CGFloat(session.castPower)), height: 10)
            }
        }
    }

    private var actionButton: some View {
        // Genauso groß wie der Ruderkreis links — beide Daumen bekommen
        // dieselbe Fläche.
        Circle()
            .fill(actionColor)
            .frame(width: 124, height: 124)
            .overlay(
                Circle().strokeBorder(Palette.paper.swiftUIColor.opacity(0.8), lineWidth: 2)
            )
            .overlay(
                VStack(spacing: 3) {
                    Image(systemName: actionSymbol)
                        .font(.system(size: 32, weight: .semibold))
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                }
                .foregroundStyle(Palette.paper.swiftUIColor)
            )
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Erster Kontakt: anschlagen, zielen oder ausholen.
                        if !isPressingAction {
                            isPressingAction = true
                            guard session.fishingPhase != .hooked else { return }
                            scene?.beginAim()
                        }

                        // SwiftUI zählt y nach unten, die Spielwelt nach oben.
                        scene?.updateAim(drag: CGVector(dx: value.translation.width,
                                                        dy: -value.translation.height))
                    }
                    .onEnded { _ in
                        isPressingAction = false

                        // Zwei Schritte: Erst wird die Richtung bestätigt,
                        // beim zweiten Loslassen fliegt der Köder.
                        scene?.releaseAim()
                    }
            )
    }

    private var actionColor: Color {
        switch session.fishingPhase {
        case .biteWindow: return Palette.vermilion.swiftUIColor
        case .aiming: return Palette.gold.swiftUIColor
        default: return Palette.waterDeep.swiftUIColor
        }
    }

    private var actionSymbol: String {
        switch session.fishingPhase {
        case .idle: return "arrow.up.forward"
        case .aiming: return "arrow.up.forward.circle"
        case .flying: return "hourglass"
        case .waiting, .nibble: return "hand.tap"
        case .biteWindow: return "bolt.fill"
        case .hooked: return "figure.fishing"
        }
    }

    private var actionTitle: String {
        switch session.fishingPhase {
        case .idle, .flying: return "Auswerfen"
        case .aiming: return "Auswerfen"
        case .waiting, .nibble, .biteWindow: return "Anschlag"
        case .hooked: return "Drill"
        }
    }

    private func toastView(_ toast: GameToast) -> some View {
        Text(toast.text)
            .font(.system(size: 15, weight: toast.emphasis ? .bold : .medium, design: .serif))
            .foregroundStyle(toast.emphasis ? Palette.paper.swiftUIColor : Palette.uiInk)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(toast.emphasis
                               ? Palette.vermilion.swiftUIColor
                               : Palette.paper.swiftUIColor.opacity(0.92))
            )
            .shadow(color: .black.opacity(0.22), radius: 10, y: 3)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
    }
}
