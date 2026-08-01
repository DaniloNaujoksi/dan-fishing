import SwiftUI

/// Das Fangbuch im Stil eines Naturtagebuchs. Unbekannte Arten stehen als
/// Silhouette darin; Einzelheiten kommen erst mit der Zahl der Fänge dazu.
struct CodexView: View {
    @EnvironmentObject private var session: GameSession
    @Environment(\.dismiss) private var dismiss

    @State private var selected: FishSpecies?

    var body: some View {
        NavigationStack {
            ZStack {
                MenuBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        summary

                        // Nach Seltenheit gruppiert: Die gewöhnlichen Arten
                        // stehen oben, die Ungeheuer unten. So sieht man auf
                        // einen Blick, wie weit man in die Tiefe gekommen ist.
                        ForEach(Rarity.allCases, id: \.self) { rarity in
                            let species = FishCatalog.all.filter { $0.rarity == rarity }
                            if !species.isEmpty {
                                rarityHeader(rarity, species: species)

                                ForEach(species) { entry in
                                    entryRow(for: entry)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Fangbuch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $selected) { species in
                CodexDetailView(species: species,
                                entry: session.save.codex[species.id])
                    .environmentObject(session)
            }
        }
    }

    private var summary: some View {
        PaperPanel {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading(text: "Gesammelt",
                               subtitle: "\(session.save.codex.count) von \(FishCatalog.all.count) Arten")

                ProgressView(value: Double(session.save.codex.count),
                             total: Double(FishCatalog.all.count))
                    .tint(Palette.vermilion.swiftUIColor)
            }
        }
    }

    /// Zwischenüberschrift je Seltenheitsstufe, mit Zähler.
    private func rarityHeader(_ rarity: Rarity, species: [FishSpecies]) -> some View {
        let found = species.filter { session.save.codex[$0.id] != nil }.count

        return HStack(spacing: 8) {
            Circle()
                .fill(rarity.tint)
                .frame(width: 8, height: 8)

            Text(rarity.displayName)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(rarity.tint)

            Rectangle()
                .fill(rarity.tint.opacity(0.28))
                .frame(height: 1)

            Text("\(found) / \(species.count)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.inkSoft.swiftUIColor)
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    private func entryRow(for species: FishSpecies) -> some View {
        let entry = session.save.codex[species.id]
        let known = entry != nil

        return Button {
            selected = species
        } label: {
            PaperPanel(padding: 14) {
                HStack(spacing: 14) {
                    FishSilhouette(species: species, silhouetteOnly: !known)
                        .frame(width: 84, height: 34)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(known ? species.name : "? ? ?")
                            .font(.system(size: 17, weight: .medium, design: .serif))
                            .foregroundStyle(Palette.uiInk)

                        if let entry {
                            Text("\(entry.count)× · größter \(String(format: "%.1f", entry.longestCm)) cm")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Palette.inkSoft.swiftUIColor)
                        } else {
                            Text("noch nicht gefangen")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Palette.inkSoft.swiftUIColor.opacity(0.7))
                        }
                    }

                    Spacer()

                    Text(species.rarity.displayName)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(species.rarity.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(species.rarity.tint.opacity(0.14)))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Einzelseite einer Art. Was hier steht, hängt davon ab, wie oft der Spieler
/// sie schon gefangen hat.
struct CodexDetailView: View {
    let species: FishSpecies
    let entry: CodexEntry?

    @EnvironmentObject private var session: GameSession
    @Environment(\.dismiss) private var dismiss

    /// Legende, die gerade groß angesehen wird.
    @State private var shownLegend: LegendaryFish?

    private var detailLevel: Int { entry?.detailLevel ?? -1 }

    /// Die legendären Exemplare dieser Art, die schon im Boot lagen.
    private var legends: [LegendaryFish] {
        session.save.caughtLegends.filter { $0.speciesID == species.id }
    }

    /// Eigene Tafel unter den Beobachtungen. Ein gefangener Einzelfisch ist
    /// kein Fangbucheintrag wie jeder andere — er bekommt seinen Namen und
    /// bleibt anklickbar.
    private var legendPanel: some View {
        PaperPanel(accent: Palette.gold.swiftUIColor) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(text: "Legenden dieser Art",
                               subtitle: "\(legends.count) gefangen · antippen zum Ansehen")

                ForEach(legends) { legend in
                    Button {
                        AudioManager.shared.play(.discovery)
                        HapticManager.shared.success()
                        withAnimation(.easeIn(duration: 0.2)) { shownLegend = legend }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.gold.swiftUIColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(legend.name)
                                    .font(.system(size: 16, weight: .medium, design: .serif))
                                    .foregroundStyle(Palette.uiInk)
                                    .multilineTextAlignment(.leading)

                                Text(String(format: "%.1f cm · %.2f kg", legend.lengthCm, legend.weightKg)
                                     + " · \(legend.water?.name ?? "–")")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Palette.inkSoft.swiftUIColor)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.inkSoft.swiftUIColor.opacity(0.6))
                        }
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MenuBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        PaperPanel {
                            VStack(spacing: 12) {
                                FishSilhouette(species: species, silhouetteOnly: entry == nil)
                                    .frame(height: 80)

                                // Solange die Art nicht gefangen wurde, gibt
                                // auch die Detailseite nichts preis — nicht
                                // einmal den Namen. Sonst wäre der Reiz weg,
                                // bevor man ihr überhaupt begegnet ist.
                                Text(entry != nil ? species.name : "? ? ?")
                                    .font(.system(size: 26, weight: .semibold, design: .serif))
                                    .foregroundStyle(entry != nil
                                                     ? Palette.uiInk
                                                     : Palette.inkSoft.swiftUIColor)

                                Text(species.rarity.displayName)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(species.rarity.tint)

                                if entry != nil {
                                    Text(species.summary)
                                        .font(.system(size: 14, design: .serif))
                                        .foregroundStyle(Palette.inkSoft.swiftUIColor)
                                        .multilineTextAlignment(.center)
                                } else {
                                    Text("Diese Art ist dir noch nicht begegnet.")
                                        .font(.system(size: 14, design: .serif))
                                        .foregroundStyle(Palette.inkSoft.swiftUIColor)
                                }
                            }
                        }

                        if let entry {
                            PaperPanel {
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionHeading(text: "Deine Fänge")
                                    row("Gefangen", "\(entry.count)×")
                                    row("Größter", String(format: "%.1f cm", entry.longestCm))
                                    row("Schwerster", String(format: "%.2f kg", entry.heaviestKg))
                                    row("Größe der Art",
                                        String(format: "%.0f – %.0f cm", species.minLength, species.maxLength))
                                }
                            }

                            PaperPanel {
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionHeading(text: "Beobachtungen",
                                                   subtitle: detailLevel >= 2
                                                   ? "Vollständig"
                                                   : "Wächst mit jedem Fang")

                                    if detailLevel >= 1 {
                                        row("Beste Köder", baitNames(entry.baitIDs))
                                        row("Fundorte", habitatNames(entry.habitatIDs))
                                    } else {
                                        Text("Fange diese Art dreimal, um Köder und Fundorte einzutragen.")
                                            .font(.system(size: 13, design: .serif))
                                            .foregroundStyle(Palette.inkSoft.swiftUIColor)
                                    }

                                    if detailLevel >= 2 {
                                        row("Aktiv", species.activeTimes.map(\.displayName).joined(separator: ", "))
                                        row("Kampf", species.motion.displayName)

                                        // Der Nachtzug ist die wertvollste
                                        // Beobachtung: Er sagt, wo man im
                                        // Dunkeln werfen muss.
                                        if !species.nightHabitats.isEmpty {
                                            row("Nachts",
                                                species.nightHabitats.map(\.displayName)
                                                    .joined(separator: ", "))
                                        }
                                    } else if detailLevel >= 1 {
                                        Text("Nach fünf Fängen kennst du auch die Beißzeiten.")
                                            .font(.system(size: 13, design: .serif))
                                            .foregroundStyle(Palette.inkSoft.swiftUIColor)
                                    }
                                }
                            }

                            if !legends.isEmpty {
                                legendPanel
                            }
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 30)
                }

                // Ansehen wie beim ersten Fang: derselbe Auftritt mit
                // Strahlenkranz — nur in Gold und mit dem Namen der Legende.
                if let shown = shownLegend {
                    NewSpeciesBanner(species: species,
                                     headline: "Legende",
                                     title: shown.name,
                                     subtitle: String(format: "%.1f cm · %.2f kg",
                                                      shown.lengthCm, shown.weightKg),
                                     footnote: shown.water?.name,
                                     footnoteSymbol: "mappin.and.ellipse",
                                     accent: Palette.gold.swiftUIColor) {
                        withAnimation(.easeOut(duration: 0.2)) { shownLegend = nil }
                    }
                    .transition(.opacity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(Palette.inkSoft.swiftUIColor)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(Palette.uiInk)
                .multilineTextAlignment(.trailing)
        }
    }

    private func baitNames(_ ids: [String]) -> String {
        let names = ids.compactMap { BaitCatalog.bait(id: $0)?.name }
        return names.isEmpty ? "–" : names.joined(separator: ", ")
    }

    private func habitatNames(_ ids: [String]) -> String {
        let names = ids.compactMap { Habitat(rawValue: $0)?.displayName }
        return names.isEmpty ? "–" : names.joined(separator: ", ")
    }
}
