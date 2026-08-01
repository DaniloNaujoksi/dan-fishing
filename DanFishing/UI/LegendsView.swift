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
                        if let legend = session.activeLegend {
                            activeCard(legend)
                        } else {
                            waitingCard
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

    private func activeCard(_ legend: LegendaryFish) -> some View {
        PaperPanel(accent: Palette.gold.swiftUIColor) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(text: legend.name, subtitle: "Man erzählt sich …")

                Text(legend.hint)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(Palette.uiInk)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    StatChip(symbol: "mappin.and.ellipse",
                             value: legend.water?.name ?? "–")
                    StatChip(symbol: "clock",
                             value: legend.timeOfDay?.displayName ?? "–")
                }

                HStack(spacing: 10) {
                    StatChip(symbol: "water.waves",
                             value: legend.habitat?.displayName ?? "–")
                    StatChip(symbol: "fishhook",
                             value: legend.bait?.name ?? "–",
                             tint: Palette.gold.swiftUIColor)
                }

                Text("Er ist scheu: Wirf nicht direkt auf ihn, sondern daneben — "
                     + "und rechne damit, dass er den Köder mehrfach prüft, bevor er nimmt.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Palette.inkSoft.swiftUIColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
