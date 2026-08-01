import SpriteKit
import SwiftUI

/// Der Spielbildschirm: SpriteKit-Szene mit einer dünnen Bedienschicht darüber.
struct GameView: View {
    @EnvironmentObject private var session: GameSession

    @State private var scene: LakeScene?
    @State private var isPressingAction = false
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
                    Spacer()
                    if session.miniGame == nil {
                        bottomControls
                    }
                }
                .padding(.horizontal, 16)
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
        }
        .sheet(isPresented: $showBaitBox) { BaitBoxView() }
        .sheet(isPresented: $showCodex) { CodexView() }
        .sheet(isPresented: $showShop) { ShopView() }
        .sheet(isPresented: $showMissions) { MissionsView() }
    }

    // MARK: - Kopfleiste

    private var topBar: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                session.returnToMenu()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.uiInk)
                    .padding(9)
                    .background(Circle().fill(Palette.paper.swiftUIColor.opacity(0.88)))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    StatChip(symbol: "circle.hexagongrid.fill",
                             value: "\(session.save.coins)",
                             tint: ColorSpec(0x9A7B24).swiftUIColor)
                    StatChip(symbol: "star.fill", value: "St. \(session.save.level)")
                    StatChip(symbol: "clock", value: session.clockText)
                }

                if session.save.settings.showDepthHint {
                    HStack(spacing: 8) {
                        StatChip(symbol: "water.waves", value: session.habitatText)
                        StatChip(symbol: "arrow.down.to.line", value: session.depthText)
                        if session.stats.hasFishFinder {
                            StatChip(symbol: "dot.radiowaves.up.forward",
                                     value: activityText,
                                     tint: Palette.moss.swiftUIColor)
                        }
                    }
                }
            }

            Spacer()

            VStack(spacing: 8) {
                iconButton("book.closed") { showCodex = true }
                iconButton("bag") { showShop = true }
                iconButton("checklist") { showMissions = true }
            }
        }
        .padding(.top, 8)
    }

    private var activityText: String {
        switch session.activityScore {
        case ..<0.2: return "leer"
        case ..<0.45: return "wenig"
        case ..<0.7: return "gut"
        default: return "reich"
        }
    }

    private func iconButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.uiInk)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Palette.paper.swiftUIColor.opacity(0.88)))
        }
    }

    // MARK: - Steuerung unten

    private var bottomControls: some View {
        HStack(alignment: .bottom) {
            JoystickView { vector in
                session.joystick = vector
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
                Circle()
                    .fill(session.selectedBait.color.swiftUIColor)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().strokeBorder(Palette.inkSoft.swiftUIColor.opacity(0.4), lineWidth: 1))
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
        Circle()
            .fill(actionColor)
            .frame(width: 96, height: 96)
            .overlay(
                Circle().strokeBorder(Palette.paper.swiftUIColor.opacity(0.8), lineWidth: 2)
            )
            .overlay(
                VStack(spacing: 2) {
                    Image(systemName: actionSymbol)
                        .font(.system(size: 26, weight: .semibold))
                    Text(actionTitle)
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                }
                .foregroundStyle(Palette.paper.swiftUIColor)
            )
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Erster Kontakt: entweder anschlagen oder zielen.
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
        case .aiming: return "scope"
        case .flying: return "hourglass"
        case .waiting, .nibble: return "hand.tap"
        case .biteWindow: return "bolt.fill"
        case .hooked: return "figure.fishing"
        }
    }

    private var actionTitle: String {
        switch session.fishingPhase {
        case .idle, .aiming, .flying: return "Werfen"
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
