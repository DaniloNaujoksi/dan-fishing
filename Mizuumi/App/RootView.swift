import SwiftUI

/// Schaltet zwischen Hauptmenü und Spiel um.
struct RootView: View {
    @EnvironmentObject private var session: GameSession

    var body: some View {
        ZStack {
            switch session.screen {
            case .menu:
                MainMenuView()
                    .transition(.opacity)
            case .playing:
                GameView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: session.screen)
    }
}
