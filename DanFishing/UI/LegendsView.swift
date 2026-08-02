import SwiftUI

/// Die Legenden: der Fisch, von dem gerade erzählt wird, und alle, die schon
/// im Boot waren.
///
/// Der Hinweis ist absichtlich als Erzählung geschrieben und nicht als
/// Auftragsliste — er nennt Ort, Zone, Zeit und Köder, aber nie die Art. Die
/// erkennt man erst, wenn der Schein im Wasser steht.
struct LegendsView: View {
    @EnvironmentObject private var session: GameSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MenuBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        if session.activeLegends.isEmpty {
                            waitingCard
                        } else {
                            // Die Legende des eigenen Gewässers steht oben.
                            ForEach(sortedLegends) { legend in
                                activeCard(legend)
                            }
                        }

                        if !session.save.caughtLegends.isEmpty {
                            hallOfFame
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Legenden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    /// Zuerst die Legende des aktuellen Gewässers, dann die übrigen.
    private var sortedLegends: [LegendaryFish] {
        session.activeLegends.sorted { a, b in
            (a.waterID == session.save.currentWaterID ? 0 : 1)
                < (b.waterID == session.save.currentWaterID ? 0 : 1)
        }
    }

    private func activeCard(_ legend: LegendaryFish) -> some View {
        let detector = session.legendDetectorLevel
        let daysLeft = legend.daysLeft(onDay: session.inGameDay)
        let here = legend.waterID == session.save.currentWaterID

        return PaperPanel(accent: here ? Palette.gold.swiftUIColor : nil) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(text: legend.name,
                               subtitle: here ? "Hier, an diesem Gewässer" : "Man erzählt sich …")

                // Frist: Nach zwei bis vier Tagen zieht der Fisch weiter.
                HStack(spacing: 8) {
                    Image(systemName: daysLeft <= 0 ? "hourglass.bottomhalf.filled" : "hourglass")
                        .font(.system(size: 13))
                        .foregroundStyle(daysLeft <= 0
                                         ? Palette.vermilion.swiftUIColor
                                         : Palette.inkSoft.swiftUIColor)

                    Text(deadlineText(daysLeft))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(daysLeft <= 0
                                         ? Palette.vermilion.swiftUIColor
                                         : Palette.inkSoft.swiftUIColor)
                }

                Text(legend.hint)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(Palette.uiInk)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    StatChip(symbol: "mappin.and.ellipse",
                             value: legend.water?.name ?? "–")
                    StatChip(symbol: "clock",
                             value: "am besten \(legend.timeOfDay?.displayName ?? "–")")
                }

                HStack(spacing: 10) {
                    StatChip(symbol: "water.waves",
                             value: legend.habitat?.displayName ?? "–")
                    StatChip(symbol: "fishhook",
                             value: legend.bait?.name ?? "–",
                             tint: Palette.gold.swiftUIColor)
                }

                // Der Detektor deckt auf, was in der Geschichte fehlt: die Art
                // selbst — und mit dem Peilsender, wo sie gerade steht.
                if detector >= 1, let species = legend.species {
                    Divider().opacity(0.4)

                    HStack(spacing: 12) {
                        FishSilhouette(species: species)
                            .frame(width: 96, height: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(species.name)
                                .font(.system(size: 17, weight: .medium, design: .serif))
                                .foregroundStyle(Palette.uiInk)
                            Text("\(species.rarity.displayName) · bis \(Int(species.maxLength)) cm")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Palette.inkSoft.swiftUIColor)
                        }
                    }

                    if detector >= 2, session.legendIsHere {
                        if let distance = session.legendDistance {
                            StatChip(symbol: "dot.radiowaves.left.and.right",
                                     value: String(format: "%.0f m entfernt", distance),
                                     tint: Palette.moss.swiftUIColor)
                        } else {
                            Text("Peilsender bereit — er meldet sich, sobald du draußen bist.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Palette.inkSoft.swiftUIColor)
                        }
                    }
                } else {
                    Label("Welche Art es ist, weiß nur der alte Angler am Steg. "
                          + "Sein Notizbuch liegt im Laden.",
                          systemImage: "questionmark.circle")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.inkSoft.swiftUIColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Zone und Köder müssen stimmen, die Uhrzeit hilft nur. "
                     + "Sie ist vorsichtig: Wirf nicht direkt auf sie, sondern daneben — "
                     + "und rechne damit, dass sie den Köder mehrfach anzupft, bevor sie nimmt.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Palette.inkSoft.swiftUIColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func deadlineText(_ daysLeft: Int) -> String {
        switch daysLeft {
        case ..<0: return "Weitergezogen"
        case 0: return "Heute ist der letzte Tag"
        case 1: return "Noch heute und morgen"
        default: return "Noch \(daysLeft + 1) Tage"
        }
    }

    private var waitingCard: some View {
        PaperPanel {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading(text: "Noch keine Geschichte",
                               subtitle: "ab Stufe \(LegendSystem.minimumLevel)")

                Text("Wer lange genug am Wasser ist, hört irgendwann von den Fischen, "
                     + "die schon vor ihm da waren. Bis dahin: fangen, lernen, aufsteigen.")
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(Palette.inkSoft.swiftUIColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var hallOfFame: some View {
        PaperPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(text: "Gefangen",
                               subtitle: "\(session.save.caughtLegends.count) Legenden")

                ForEach(session.save.caughtLegends.reversed()) { legend in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(legend.name)
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(Palette.uiInk)

                        Text("\(legend.species?.name ?? "?") · "
                             + String(format: "%.1f cm · %.2f kg", legend.lengthCm, legend.weightKg)
                             + " · \(legend.water?.name ?? "–")")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Palette.inkSoft.swiftUIColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
