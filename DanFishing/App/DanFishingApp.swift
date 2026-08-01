import SwiftUI

/// Einstiegspunkt. Hält die einzige `GameSession` und startet den Ton.
@main
struct DanFishingApp: App {

    @StateObject private var session = GameSession()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(.light)
                .onAppear {
                    AudioManager.shared.start()
                    AudioManager.shared.apply(settings: session.save.settings)
                    HapticManager.shared.apply(settings: session.save.settings)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // Beim Wechsel in den Hintergrund wird gespeichert — dann geht
            // auch nach einem Absturz nichts verloren.
            if phase != .active {
                session.persist()
            }
        }
    }
}
