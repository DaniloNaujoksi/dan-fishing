import SwiftUI

/// Hauptmenü. Fortsetzen, neuer Spielstand, Fangbuch, Ausrüstung, Missionen,
/// Einstellungen — alles von hier erreichbar.
struct MainMenuView: View {
    @EnvironmentObject private var session: GameSession

    @State private var showCodex = false
    @State private var showWaters = false
    @State private var showShop = false
    @State private var showMissions = false
    @State private var showLegends = false
    @State private var showSettings = false
    @State private var confirmNewGame = false

    var body: some View {
        ZStack {
            MenuBackground()

            ScrollView {
                VStack(spacing: 24) {
                    header

                    PaperPanel {
                        VStack(spacing: 14) {
                            Button("Weiterspielen") {
                                session.continueGame()
                            }
                            .buttonStyle(BrushButtonStyle())
                            .frame(maxWidth: .infinity)

                            Button("Neuer Spielstand") {
                                if session.hasExistingSave {
                                    confirmNewGame = true
                                } else {
                                    session.startNewGame()
                                }
                            }
                            .buttonStyle(BrushButtonStyle(tint: Palette.inkSoft.swiftUIColor, filled: false))
                            .frame(maxWidth: .infinity)
                        }
                    }

                    PaperPanel {
                        VStack(spacing: 12) {
                            SectionHeading(text: "Am Ufer", subtitle: "Vorbereiten, bevor es hinausgeht")

                            menuRow(icon: "map", title: "Gewässer",
                                    detail: "\(session.currentWater.name) · \(session.unlockedWaters.count) von \(WaterCatalog.all.count) offen") {
                                showWaters = true
                            }
                            menuRow(icon: "book.closed", title: "Fangbuch",
                                    detail: "\(session.save.codex.count) von \(FishCatalog.all.count) Arten") {
                                showCodex = true
                            }
                            menuRow(icon: "bag", title: "Angelladen",
                                    detail: "\(session.save.coins) Münzen") {
                                showShop = true
                            }
                            menuRow(icon: "checklist", title: "Tagesaufgaben",
                                    detail: "\(openMissionCount) offen") {
                                showMissions = true
                            }
                            menuRow(icon: "sparkles", title: "Legenden",
                                    detail: legendDetail) {
                                showLegends = true
                            }
                            menuRow(icon: "slider.horizontal.3", title: "Einstellungen",
                                    detail: nil) {
                                showSettings = true
                            }
                        }
                    }

                    statsPanel
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showCodex) { CodexView() }
        .sheet(isPresented: $showWaters) { WaterSelectionView() }
        .sheet(isPresented: $showShop) { ShopView() }
        .sheet(isPresented: $showMissions) { MissionsView() }
        .sheet(isPresented: $showLegends) { LegendsView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .alert("Neuer Spielstand?", isPresented: $confirmNewGame) {
            Button("Abbrechen", role: .cancel) { }
            Button("Überschreiben", role: .destructive) { session.startNewGame() }
        } message: {
            Text("Der bisherige Fortschritt wird gelöscht: Fänge, Münzen und Ausrüstung.")
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("湖")
                .font(.system(size: 54, weight: .light, design: .serif))
                .foregroundStyle(Palette.vermilion.swiftUIColor)

            Text("Dan-Fishing")
                .font(.system(size: 40, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.uiInk)

            Text("Ein stiller Bergsee, ein Ruderboot, viel Zeit.")
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(Palette.inkSoft.swiftUIColor)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 30)
    }

    private var statsPanel: some View {
        PaperPanel {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(text: "Angler", subtitle: "Stufe \(session.save.level)")

                HStack(spacing: 10) {
                    StatChip(symbol: "circle.hexagongrid.fill", value: "\(session.save.coins)",
                             tint: Palette.gold.swiftUIColor)
                    StatChip(symbol: "fish", value: "\(session.save.totalCatches) Fänge")
                    StatChip(symbol: "trophy", value: "\(session.save.codex.count) Arten")
                }

                ProgressView(value: Double(session.save.experience),
                             total: Double(max(1, session.save.experienceForNextLevel)))
                    .tint(Palette.vermilion.swiftUIColor)

                Text("\(session.save.experience) / \(session.save.experienceForNextLevel) EP bis Stufe \(session.save.level + 1)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Palette.inkSoft.swiftUIColor)
            }
        }
    }

    /// Was in der Menüzeile steht: der Name der aktuellen Legende, sonst der
    /// Stand der Ruhmeshalle.
    private var legendDetail: String {
        let active = session.activeLegends
        if let here = session.activeLegend {
            // Die Legende des eigenen Gewässers zuerst nennen.
            return active.count > 1 ? "\(here.name) · \(active.count - 1) weitere" : here.name
        }
        if let first = active.first {
            return active.count > 1 ? "\(active.count) Geschichten" : first.name
        }
        let caught = session.save.caughtLegends.count
        return caught > 0 ? "\(caught) gefangen" : "ab Stufe \(LegendSystem.minimumLevel)"
    }

    private var openMissionCount: Int {
        session.missions.filter { mission in
            let progress = session.progress(for: mission)
            return !progress.claimed
        }.count
    }

    private func menuRow(icon: String, title: String, detail: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.vermilion.swiftUIColor)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .foregroundStyle(Palette.uiInk)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Palette.inkSoft.swiftUIColor)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft.swiftUIColor.opacity(0.6))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
