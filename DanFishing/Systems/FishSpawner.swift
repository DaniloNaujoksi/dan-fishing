import Foundation

/// Würfelt aus, welcher Fisch beißt und wie groß er ist.
enum FishSpawner {

    /// Zieht eine Art anhand der Ködergewichte. Gibt nil zurück, wenn an
    /// diesem Platz mit diesem Köder gerade nichts beißt.
    static func rollSpecies(bait: Bait, context: BaitSystem.Context) -> FishSpecies? {
        let candidates = BaitSystem.candidates(bait: bait, context: context)
        guard !candidates.isEmpty else { return nil }

        let weights = candidates.map { $0.weight }
        guard let index = RandomHelper.weightedIndex(weights) else { return nil }
        return candidates[index].species
    }

    /// Länge eines Exemplars. Der Köder verschiebt den Schwerpunkt der
    /// Verteilung: mit Made kommen viele kleine, mit Köderfisch große Fische.
    static func rollLength(for species: FishSpecies, bait: Bait, stats: EquipmentStats) -> Double {
        let span = species.maxLength - species.minLength

        // Wo der wahrscheinlichste Wert liegt: Grundwert bei 32 % der Spanne,
        // verschoben durch Ködergröße und Rutenqualität.
        let rodBonus = min(max((stats.castRange - 520) / 500.0, 0), 0.25)
        let bias = 0.32 + bait.sizeBias * 0.34 + rodBonus
        let peak = species.minLength + span * min(bias, 0.86)

        let length = RandomHelper.triangular(min: species.minLength,
                                             max: species.maxLength,
                                             peak: peak)
        return (length * 10).rounded() / 10
    }

    /// Kompletter Fisch am Haken.
    static func rollFish(bait: Bait, context: BaitSystem.Context) -> HookedFish? {
        guard let species = rollSpecies(bait: bait, context: context) else { return nil }
        let length = rollLength(for: species, bait: bait, stats: context.stats)
        let weight = species.weight(forLength: length)

        return HookedFish(species: species,
                          lengthCm: length,
                          weightKg: (weight * 100).rounded() / 100,
                          habitat: context.habitat,
                          baitID: bait.id)
    }

    /// Wie viel Fisch gerade unter dem Boot steht — Grundlage für den
    /// Fischfinder und für die Dichte der sichtbaren Schwärme.
    static func activityScore(bait: Bait, context: BaitSystem.Context) -> Double {
        let total = BaitSystem.candidates(bait: bait, context: context)
            .reduce(0.0) { $0 + $1.weight }
        return min(1.0, total / 4.0)
    }
}
