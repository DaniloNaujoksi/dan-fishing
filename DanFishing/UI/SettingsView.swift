import SwiftUI

/// Einstellungen: Ton, Haptik, Hinweise. Bewusst kurz gehalten.
struct SettingsView: View {
    @EnvironmentObject private var session: GameSession
    @Environment(\.dismiss) private var dismiss

    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            ZStack {
                MenuBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        PaperPanel {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeading(text: "Ton")

                                toggleRow("Musik", isOn: session.save.settings.music) { value in
                                    session.setMusic(value)
                                }
                                toggleRow("Geräusche", isOn: session.save.settings.sfx) { value in
                                    session.setEffects(value)
                                }
                                toggleRow("Vibration", isOn: session.save.settings.haptics) { value in
                                    session.setHaptics(value)
                                }
                            }
                        }

                        PaperPanel {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeading(text: "Anzeige")

                                toggleRow("Tiefe und Zone einblenden",
                                          isOn: session.save.settings.showDepthHint) { value in
                                    session.setDepthHint(value)
                                }
                            }
                        }

                        PaperPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeading(text: "Über das Spiel")

                                Text("Alle Grafiken und Klänge entstehen zur Laufzeit im Code. "
                                     + "Es gibt keine Werbung, keine Käufe und keine Verbindung ins Netz.")
                                    .font(.system(size: 13, design: .serif))
                                    .foregroundStyle(Palette.inkSoft.swiftUIColor)
                                    .fixedSize(horizontal: false, vertical: true)

                                Button("Vorspann noch einmal ansehen") {
                                    dismiss()
                                    session.replayIntro()
                                }
                                .buttonStyle(BrushButtonStyle(tint: Palette.inkSoft.swiftUIColor,
                                                              filled: false))

                                Button("Spielstand löschen") {
                                    confirmReset = true
                                }
                                .buttonStyle(BrushButtonStyle(tint: Palette.vermilion.swiftUIColor,
                                                              filled: false))
                            }
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
            .alert("Spielstand löschen?", isPresented: $confirmReset) {
                Button("Abbrechen", role: .cancel) { }
                Button("Löschen", role: .destructive) {
                    session.startNewGame()
                    session.returnToMenu()
                    dismiss()
                }
            } message: {
                Text("Fänge, Münzen und Ausrüstung gehen verloren.")
            }
        }
    }

    private func toggleRow(_ title: String, isOn: Bool, action: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { isOn }, set: { action($0) })) {
            Text(title)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(Palette.uiInk)
        }
        .tint(Palette.vermilion.swiftUIColor)
    }
}
