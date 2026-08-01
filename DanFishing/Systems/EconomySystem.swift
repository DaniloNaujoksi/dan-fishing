import Foundation

/// Münzen und Erfahrung. Bewusst schlicht: Wert = Gewicht × Artpreis ×
/// Seltenheit, plus Zuschläge für Trophäen, neue Arten und Rekorde.
enum EconomySystem {

    /// Verkaufswert eines Fisches.
    static func coinValue(for fish: HookedFish) -> Int {
        let base = Double(fish.species.valuePerKilo) * max(0.08, fish.weightKg)
        let rarity = fish.species.rarity.valueMultiplier
        let trophy = 1.0 + fish.trophyFactor * 0.8
        return max(3, Int((base * rarity * trophy).rounded()))
    }

    /// Erfahrung für einen Fang.
    static func experience(for fish: HookedFish, isNewSpecies: Bool, isRecord: Bool) -> Int {
        var xp = 6 + (fish.species.rarity >= .rare ? 14 : 4)
        xp += Int(fish.trophyFactor * 14)
        if isNewSpecies { xp += 25 }
        if isRecord { xp += 10 }
        return xp
    }

    /// Ertrag beim Zurücksetzen: keine Münzen, dafür Erfahrung und Ansehen.
    ///
    /// Das Ansehen ist der eigentliche Grund, einen kapitalen Fisch wieder
    /// schwimmen zu lassen: Es erhöht dauerhaft die Chance auf seltene Arten
    /// und senkt die Preise im Laden. Wer verkauft, hat heute Geld; wer
    /// freilässt, fängt morgen besser.
    static func releaseReward(for fish: HookedFish) -> (coins: Int, experience: Int, reputation: Int) {
        let xp = 8 + Int(fish.trophyFactor * 26) + (fish.species.rarity >= .rare ? 12 : 0)

        // Große und seltene Exemplare bringen deutlich mehr Ansehen.
        var reputation = 2 + Int(fish.trophyFactor * 10)
        switch fish.species.rarity {
        case .common: break
        case .uncommon: reputation += 2
        case .rare: reputation += 5
        case .veryRare: reputation += 9
        case .legendary: reputation += 16
        }

        return (0, xp, reputation)
    }

    /// Ertrag, wenn ein Fisch als Trophäe behalten wird.
    ///
    /// Lohnt sich nur bei einem persönlichen Rekord — sonst liegt derselbe
    /// Fisch schon in der Sammlung, und Verkaufen ist die bessere Wahl.
    static func trophyReward(for fish: HookedFish, isFirstOfSpecies: Bool) -> (experience: Int, coins: Int) {
        let xp = 14 + Int(fish.trophyFactor * 30) + (isFirstOfSpecies ? 20 : 0)
        return (xp, 0)
    }

    /// Prämie, wenn alle Arten einer Seltenheitsstufe als Trophäe im Regal
    /// stehen. Das ist das Ziel hinter dem Behalten.
    static func collectionBonus(for rarity: Rarity) -> Int {
        switch rarity {
        case .common: return 250
        case .uncommon: return 500
        case .rare: return 1200
        case .veryRare: return 2500
        case .legendary: return 5000
        }
    }

    /// Vollständige Sammlungen prüfen und auszahlen.
    /// - Returns: Die Stufen, die durch diesen Fang vollständig wurden.
    static func completedCollections(in data: SaveData) -> [Rarity] {
        Rarity.allCases.filter { rarity in
            let species = FishCatalog.all.filter { $0.rarity == rarity }
            guard !species.isEmpty else { return false }
            return species.allSatisfy { data.trophySpeciesIDs.contains($0.id) }
        }
    }

    /// Wendet Erfahrung an und gibt zurück, wie viele Level dazugekommen sind.
    static func applyExperience(_ amount: Int, to data: inout SaveData) -> Int {
        guard amount > 0 else { return 0 }
        data.experience += amount

        var levelsGained = 0
        while data.experience >= SaveData.experienceForLevel(data.level) {
            data.experience -= SaveData.experienceForLevel(data.level)
            data.level += 1
            levelsGained += 1
            // Sicherheitsnetz gegen absurde Eingaben.
            if levelsGained > 50 { break }
        }
        return levelsGained
    }
}
