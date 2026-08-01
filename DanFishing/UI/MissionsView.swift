import SwiftUI

/// Tagesaufgaben. Erfüllte Aufgaben müssen abgeholt werden — so bemerkt der
/// Spieler die Belohnung, statt sie nebenbei zu bekommen.
struct MissionsView: View {
    @EnvironmentObject private var session: GameSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MenuBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(session.missions) { mission in
                            missionCard(mission)
                        }

                        if session.missions.isEmpty {
                            PaperPanel {
                                Text("Heute gibt es keine Aufgaben. Morgen wieder.")
                                    .font(.system(size: 14, design: .serif))
                                    .foregroundStyle(Palette.inkSoft.swiftUIColor)
                            }
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Tagesaufgaben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onAppear { session.refreshMissions() }
        }
    }

    private func missionCard(_ mission: Mission) -> some View {
        let progress = session.progress(for: mission)
        let target = mission.goal.target
        let done = progress.progress >= target

        return PaperPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mission.title)
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(Palette.uiInk)
                        Text(mission.detail)
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(Palette.inkSoft.swiftUIColor)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(mission.rewardCoins) 🪙")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.gold.swiftUIColor)
                        Text("\(mission.rewardXP) EP")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Palette.inkSoft.swiftUIColor)
                    }
                }

                ProgressView(value: Double(min(progress.progress, target)),
                             total: Double(max(1, target)))
                    .tint(done ? Palette.moss.swiftUIColor : Palette.vermilion.swiftUIColor)

                HStack {
                    Text("\(min(progress.progress, target)) / \(target)")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.inkSoft.swiftUIColor)
                        .monospacedDigit()

                    Spacer()

                    if progress.claimed {
                        Label("Abgeholt", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.moss.swiftUIColor)
                    } else if done {
                        Button("Belohnung abholen") {
                            session.claim(mission: mission)
                        }
                        .buttonStyle(BrushButtonStyle())
                    }
                }
            }
        }
    }
}
