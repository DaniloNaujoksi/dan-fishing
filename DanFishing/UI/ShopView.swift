import SwiftUI

/// Laden am Steg: Ausrüstung verbessern und neue Köder kaufen.
struct ShopView: View {
    @EnvironmentObject private var session: GameSession
    @Environment(\.dismiss) private var dismiss

    private enum Tab: String, CaseIterable {
        case equipment = "Ausrüstung"
        case baits = "Köder"
    }

    @State private var tab: Tab = .equipment

    var body: some View {
        NavigationStack {
            ZStack {
                MenuBackground()

                VStack(spacing: 0) {
                    Picker("", selection: $tab) {
                        ForEach(Tab.allCases, id: \.self) { entry in
                            Text(entry.rawValue).tag(entry)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                    ScrollView {
                        VStack(spacing: 14) {
                            switch tab {
                            case .equipment:
                                ForEach(UpgradeCategory.allCases, id: \.self) { category in
                                    let tracks = UpgradeCatalog.tracks(in: category)
                                    if !tracks.isEmpty {
                                        categorySection(category: category, tracks: tracks)
                                    }
                                }
                            case .baits:
                                baitSection
                            }
                        }
                        .padding(18)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Am Steg")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(session.save.coins) 🪙")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // MARK: - Ausrüstung

    private func categorySection(category: UpgradeCategory, tracks: [UpgradeTrack]) -> some View {
        PaperPanel {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(text: category.displayName)

                ForEach(tracks) { track in
                    upgradeRow(track)
                    if track.id != tracks.last?.id {
                        Divider().overlay(Palette.inkSoft.swiftUIColor.opacity(0.18))
                    }
                }
            }
        }
    }

    private func upgradeRow(_ track: UpgradeTrack) -> some View {
        let owned = session.upgradeLevel(for: track)
        let maxed = owned >= track.maxLevel
        let next = track.level(at: owned)
        let affordable = next.map { session.save.coins >= $0.price } ?? false

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: track.category.symbolName)
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.vermilion.swiftUIColor)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.name)
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .foregroundStyle(Palette.uiInk)

                    Text(track.summary)
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(Palette.inkSoft.swiftUIColor)
                        .fixedSize(horizontal: false, vertical: true)

                    // Stufenanzeige als Punkte
                    HStack(spacing: 4) {
                        ForEach(0..<track.maxLevel, id: \.self) { index in
                            Circle()
                                .fill(index < owned
                                      ? Palette.vermilion.swiftUIColor
                                      : Palette.inkSoft.swiftUIColor.opacity(0.22))
                                .frame(width: 7, height: 7)
                        }
                    }
                    .padding(.top, 2)
                }
            }

            if let next {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(next.title)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundStyle(Palette.uiInk)
                        Text(next.effect)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Palette.inkSoft.swiftUIColor)
                    }

                    Spacer()

                    Button("\(next.price) 🪙") {
                        session.buyUpgrade(track)
                    }
                    .buttonStyle(BrushButtonStyle(tint: affordable
                                                  ? Palette.vermilion.swiftUIColor
                                                  : Palette.inkSoft.swiftUIColor,
                                                  filled: affordable))
                    .disabled(!affordable)
                }
            } else if maxed {
                Text("Voll ausgebaut")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.moss.swiftUIColor)
            }
        }
    }

    // MARK: - Köder

    private var baitSection: some View {
        let available = UpgradeSystem.purchasableBaits(for: session.save)
        let locked = BaitCatalog.all.filter {
            !session.save.ownedBaitIDs.contains($0.id) && $0.unlockLevel > session.save.level
        }

        return VStack(spacing: 14) {
            PaperPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(text: "Zu kaufen",
                                   subtitle: available.isEmpty ? "Nichts Neues vorrätig" : nil)

                    ForEach(available) { bait in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(bait.color.swiftUIColor)
                                .frame(width: 26, height: 26)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(bait.name)
                                    .font(.system(size: 16, weight: .medium, design: .serif))
                                    .foregroundStyle(Palette.uiInk)
                                Text(bait.summary)
                                    .font(.system(size: 11, design: .serif))
                                    .foregroundStyle(Palette.inkSoft.swiftUIColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 6)

                            Button("\(bait.price) 🪙") {
                                session.buyBait(bait)
                            }
                            .buttonStyle(BrushButtonStyle(
                                tint: session.save.coins >= bait.price
                                ? Palette.vermilion.swiftUIColor
                                : Palette.inkSoft.swiftUIColor,
                                filled: session.save.coins >= bait.price))
                            .disabled(session.save.coins < bait.price)
                        }
                    }
                }
            }

            if !locked.isEmpty {
                PaperPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeading(text: "Später", subtitle: "Höhere Stufe nötig")

                        ForEach(locked) { bait in
                            HStack {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Palette.inkSoft.swiftUIColor)
                                Text(bait.name)
                                    .font(.system(size: 14, design: .serif))
                                    .foregroundStyle(Palette.inkSoft.swiftUIColor)
                                Spacer()
                                Text("ab Stufe \(bait.unlockLevel)")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(Palette.inkSoft.swiftUIColor.opacity(0.8))
                            }
                        }
                    }
                }
            }
        }
    }
}
