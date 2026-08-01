import Foundation

/// Erzeugt und verwaltet die legendären Einzelfische.
///
/// Es ist immer genau einer draußen. Wer ihn fängt, bekommt den nächsten —
/// dadurch endet das Spiel nie, ohne dass ständig neue Inhalte nachgeliefert
/// werden müssen. Welche Art es wird, hängt an der Spielerstufe: Am Anfang
/// sind es kleine, komische Fische, später die Kapitalen.
enum LegendSystem {

    /// Ab dieser Stufe fängt das Gerede über legendäre Fische an. Früher wäre
    /// es Ablenkung, später verschenkt es die schönste Motivation.
    static let minimumLevel = 6

    /// Seltenheitsgrenze je Stufe. Der Hausen soll nicht als erster Auftrag
    /// erscheinen, wenn man ihn ohnehin noch nicht haken könnte.
    private static func maxRarity(forLevel level: Int) -> Rarity {
        switch level {
        case ..<8: return .uncommon
        case 8..<11: return .rare
        case 11..<14: return .legendary
        default: return .monster
        }
    }

    /// Würfelt einen neuen legendären Fisch aus.
    ///
    /// - Parameter avoiding: IDs von Arten, die schon als Legende gefangen
    ///   wurden. Sie kommen erst wieder dran, wenn alles andere durch ist.
    static func roll(level: Int,
                     ownedBaitIDs: [String],
                     avoiding caughtSpeciesIDs: [String],
                     seed: UInt64) -> LegendaryFish? {
        guard level >= minimumLevel else { return nil }

        var rng = SeededGenerator(seed: seed)
        let waters = WaterCatalog.unlocked(for: level)
        guard !waters.isEmpty else { return nil }

        let ceiling = maxRarity(forLevel: level)

        // Alle Kombinationen aus Gewässer und Art, die gerade in Frage kommen.
        // Entscheidend ist die dritte Bedingung: Die Art muss in diesem
        // Gewässer auch eine Zone haben, in der sie steht — sonst zeigt der
        // Hinweis auf einen Ort, den es dort nicht gibt.
        var options: [(water: Water, species: FishSpecies, habitats: [Habitat])] = []
        for water in waters {
            let available = habitats(in: water)
            for species in water.species
            where species.rarity <= ceiling && species.minPlayerLevel <= level {
                let usable = (species.habitats + species.nightHabitats)
                    .filter { available.contains($0) }
                guard !usable.isEmpty else { continue }
                options.append((water, species, usable))
            }
        }

        // Bereits als Legende gefangene Arten werden zurückgestellt, solange
        // es Alternativen gibt.
        let fresh = options.filter { !caughtSpeciesIDs.contains($0.species.id) }
        let pool = fresh.isEmpty ? options : fresh
        guard !pool.isEmpty else { return nil }

        // Nicht rein gleichverteilt: Seltene Arten sind auch als Legende
        // seltener, ganz ausgeschlossen ist aber nichts.
        let weights = pool.map { 1.0 / (1.0 + Double($0.species.rarity.sortIndex)) }
        guard let index = RandomHelper.weightedIndex(weights, using: &rng) else { return nil }
        let choice = pool[index]

        let habitat = choice.habitats[rng.nextInt(in: 0...(choice.habitats.count - 1))]

        guard let time = time(for: choice.species, using: &rng),
              let bait = bait(for: choice.species,
                              habitat: habitat,
                              time: time,
                              level: level,
                              ownedBaitIDs: ownedBaitIDs,
                              using: &rng) else { return nil }

        let name = LegendNames.name(for: choice.species, habitat: habitat, using: &rng)

        // Ein legendärer Fisch ist immer ein Ausnahmeexemplar: die obersten
        // Prozent seiner Art.
        let span = choice.species.maxLength - choice.species.minLength
        let length = choice.species.minLength + span * rng.nextDouble(in: 0.93...1.0)

        return LegendaryFish(id: UUID().uuidString,
                             name: name,
                             speciesID: choice.species.id,
                             waterID: choice.water.id,
                             habitatID: habitat.rawValue,
                             timeOfDayID: time.rawValue,
                             baitID: bait.id,
                             lengthCm: (length * 10).rounded() / 10,
                             caughtAt: nil)
    }

    /// Welche Zonen es in einem Gewässer wirklich gibt.
    ///
    /// Die Karte wird dafür einmal erzeugt und das Ergebnis behalten — sie
    /// hängt nur am Startwert und ändert sich nie.
    private static var habitatCache: [String: Set<Habitat>] = [:]

    private static func habitats(in water: Water) -> Set<Habitat> {
        if let known = habitatCache[water.id] { return known }

        let map = LakeMap.generate(for: water)

        // Nur Zonen, die groß genug zum Suchen sind. Der Dorfteich hat drei
        // Zellen Totholz — dorthin einen Hinweis zu schicken, wäre eine
        // Schnitzeljagd ohne Chance.
        let minimum = max(10, map.cells.count / 120)
        var found = Set<Habitat>()
        for habitat in Habitat.allCases where map.cellCount(of: habitat) >= minimum {
            found.insert(habitat)
        }

        habitatCache[water.id] = found
        return found
    }

    private static func time(for species: FishSpecies,
                             using rng: inout SeededGenerator) -> TimeOfDay? {
        let times = species.activeTimes.isEmpty ? TimeOfDay.allCases : species.activeTimes
        return times[rng.nextInt(in: 0...(times.count - 1))]
    }

    /// Sucht den Köder, auf den die Legende geht.
    ///
    /// Er muss zwei Dinge erfüllen: Die Art muss ihn überhaupt nehmen, und der
    /// Spieler muss ihn bekommen können. Ein Hinweis auf einen Köder, den es
    /// erst zehn Stufen später gibt, wäre eine Sackgasse.
    private static func bait(for species: FishSpecies,
                             habitat: Habitat,
                             time: TimeOfDay,
                             level: Int,
                             ownedBaitIDs: [String],
                             using rng: inout SeededGenerator) -> Bait? {
        let context = BaitSystem.Context(habitat: habitat,
                                         timeOfDay: time,
                                         depth: habitat.depthMeters,
                                         playerLevel: level,
                                         stats: EquipmentStats(),
                                         pool: [species])

        let reachable = BaitCatalog.all.filter { bait in
            guard bait.unlockLevel <= level || ownedBaitIDs.contains(bait.id) else { return false }
            return BaitSystem.attraction(species: species, bait: bait, context: context) > 0
        }
        guard !reachable.isEmpty else { return nil }

        // Der Lieblingsköder der Art bekommt den Vorzug — das macht den
        // Hinweis stimmig, statt einen Zufallsköder zu nennen.
        let preferred = reachable.filter { species.preferredBaitIDs.contains($0.id) }
        let pool = preferred.isEmpty ? reachable : preferred
        return pool[rng.nextInt(in: 0...(pool.count - 1))]
    }

    // MARK: - Fangregeln

    /// Steht die Legende gerade in diesem Gewässer?
    static func isPresent(_ legend: LegendaryFish, waterID: String) -> Bool {
        legend.caughtAt == nil && legend.waterID == waterID
    }

    /// Beißt sie unter diesen Bedingungen überhaupt?
    ///
    /// Alles muss stimmen: Zone, Tageszeit und Köder. Sonst schaut sie den
    /// Köder nicht einmal an — genau das macht die Suche aus.
    static func acceptsBite(_ legend: LegendaryFish,
                            habitat: Habitat,
                            timeOfDay: TimeOfDay,
                            baitID: String) -> Bool {
        legend.habitatID == habitat.rawValue
            && legend.timeOfDayID == timeOfDay.rawValue
            && legend.baitID == baitID
    }

    /// Der fertige Fisch am Haken.
    static func hookedFish(_ legend: LegendaryFish, habitat: Habitat) -> HookedFish? {
        guard let species = legend.species else { return nil }
        return HookedFish(species: species,
                          lengthCm: legend.lengthCm,
                          weightKg: legend.weightKg,
                          habitat: habitat,
                          baitID: legend.baitID,
                          legendName: legend.name)
    }
}
