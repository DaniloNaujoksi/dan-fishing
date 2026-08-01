import SwiftUI

/// Auswahl des Gewässers.
///
/// Jedes Gewässer bekommt eine eigene Karte mit Stimmungstext, Artenzahl und
/// dem größten Fisch, der dort vorkommt. Gesperrte Gewässer bleiben sichtbar —
/// man soll wissen, worauf man hinarbeitet.
struct WaterSelectionView: View {
    @EnvironmentObject private var session: GameSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MenuBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(WaterCatalog.all) { water in
                            waterCard(water)
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Gewässer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func waterCard(_ water: Water) -> some View {
        let locked = water.requiredLevel > session.save.level
        let selected = water.id == session.save.currentWaterID
        let caught = water.species.filter { session.save.codex[$0.id] != nil }.count

        return Button {
            guard !locked else { return }
            session.selectWater(water)
            dismiss()
        } label: {
            PaperPanel(accent: selected ? Palette.vermilion.swiftUIColor : nil) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(water.name)
                                .font(.system(size: 22, weight: .semibold, design: .serif))
                                .foregroundStyle(locked
                                                 ? Palette.inkSoft.swiftUIColor
                                                 : Palette.uiInk)

                            Text(water.subtitle)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Palette.vermilion.swiftUIColor.opacity(locked ? 0.5 : 1))
                        }

                        Spacer()

                        if locked {
                            Label("ab Stufe \(water.requiredLevel)", systemImage: "lock.fill")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.inkSoft.swiftUIColor)
                        } else if selected {
                            Label("Hier", systemImage: "mappin.circle.fill")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.vermilion.swiftUIColor)
                        }
                    }

                    // Farbstreifen als Vorschau auf die Stimmung des Ortes.
                    HStack(spacing: 0) {
                        water.shoreColor.swiftUIColor
                        water.shallowColor.swiftUIColor
                        water.deepColor.swiftUIColor
                    }
                    .frame(height: 8)
                    .clipShape(Capsule())
                    .opacity(locked ? 0.4 : 1)

                    Text(water.summary)
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(Palette.inkSoft.swiftUIColor)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        StatChip(symbol: "fish", value: "\(caught) / \(water.species.count) Arten")

                        if let biggest = water.biggestSpecies {
                            StatChip(symbol: "arrow.up.left.and.arrow.down.right",
                                     value: "bis \(Int(biggest.maxLength)) cm",
                                     tint: biggest.rarity.tint)
                        }

                        // Am Bach gibt es kein Boot — das gehört vor die Anreise.
                        if water.movement == .wading {
                            StatChip(symbol: "figure.walk", value: "zu Fuß")
                        }
                    }
                }
            }
            .opacity(locked ? 0.72 : 1)
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }
}
