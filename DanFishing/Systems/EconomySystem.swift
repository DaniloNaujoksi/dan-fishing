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

    /// Zuschlag auf den Fang.
    ///
    /// Ein neuer Eintrag im Fangbuch und ein persönlicher Rekord zahlen extra —
    /// das sind die Momente, für die man weiterangelt.
    /// Entdeckerbonus für eine Art, die noch nie im Fangbuch stand.
    static let newSpeciesBonus = 120

    static func bonusCoins(for result: CatchResult) -> Int {
        var bonus = 0
        if result.isNewSpecies { bonus += newSpeciesBonus }
        if result.isPersonalRecord { bonus += 25 }
        if result.fish.isTrophy { bonus += 40 }
        return bonus
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
