import SwiftUI

/// Die Köderbox. Zeigt nur, was der Spieler besitzt — was ein Köder wirklich
/// taugt, findet er beim Angeln heraus, nicht in einer Tabelle.
struct BaitBoxView: View {
    @EnvironmentObject private var session: GameSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MenuBackground()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(session.ownedBaits) { bait in
                            baitRow(bait)
                        }

                        if !UpgradeSystem.purchasableBaits(for: session.save).isEmpty {
                            PaperPanel(padding: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Weitere Köder gibt es beim Händler am Steg.")
                                        .font(.system(size: 13, design: .serif))
                                        .foregroundStyle(Palette.inkSoft.swiftUIColor)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Köderbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func baitRow(_ bait: Bait) -> some View {
        let isSelected = bait.id == session.save.selectedBaitID

        return Button {
            session.selectBait(bait)
            dismiss()
        } label: {
            PaperPanel(padding: 14) {
                HStack(spacing: 14) {
                    BaitIcon(bait: bait, size: 38)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(bait.name)
                            .font(.system(size: 17, weight: .medium, design: .serif))
                            .foregroundStyle(Palette.uiInk)
                        Text(bait.summary)
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(Palette.inkSoft.swiftUIColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 6)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Palette.vermilion.swiftUIColor)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
