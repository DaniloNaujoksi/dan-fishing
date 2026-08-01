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

                if let toast = session.toast {
                    toastView(toast)
                        .padding(.bottom, 220)
                        .frame(maxHeight: .infinity, alignment: .bottom)
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
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    session.returnToMenu()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.uiInk)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Palette.paper.swiftUIColor.opacity(0.9)))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        StatChip(symbol: "circle.hexagongrid.fill",
                                 value: "\(session.save.coins)",
                                 tint: ColorSpec(0x9A7B24).swiftUIColor)
                        StatChip(symbol: "star.fill", value: "St. \(session.save.level)")
                        StatChip(symbol: "clock", value: session.clockText)

                        if session.save.settings.showDepthHint {
                            StatChip(symbol: "water.waves", value: session.habitatText)
                            StatChip(symbol: "arrow.down.to.line", value: session.depthText)
                            if session.stats.hasFishFinder {
                                StatChip(symbol: "dot.radiowaves.up.forward",
                                         value: activityText,
                                         tint: Palette.moss.swiftUIColor)
                            }
                        }
                    }
                    .padding(.trailing, 10)
                }
                // Breit genug für Münzen, Stufe und volle Uhrzeit; alles
                // Weitere scrollt. Vorher schnitt die Grenze die Uhr ab.
                .frame(maxWidth: 268)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                iconButton("book.closed", label: "Fangbuch") { showCodex = true }
                iconButton("bag", label: "Shop") { showShop = true }
                iconButton("checklist", label: "Aufgaben") { showMissions = true }
            }
        }
        .padding(.top, 8)
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.paper.swiftUIColor.opacity(0.9))
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
            .background(Capsule().fill(Palette.paper.swiftUIColor.opacity(0.88)))
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
            .background(Capsule().fill(Palette.paper.swiftUIColor.opacity(0.88)))
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
        case .aiming: return ColorSpec(0x9A6A3A).swiftUIColor
        default: return ColorSpec(0x4E6E7A).swiftUIColor
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
            .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
