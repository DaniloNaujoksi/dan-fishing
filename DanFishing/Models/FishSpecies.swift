import Foundation

/// Eine Fischart. Reine Daten — alle Werte kommen aus `FishCatalog`, damit neue
/// Arten ohne Codeänderung an anderer Stelle ergänzt werden können.
struct FishSpecies: Identifiable, Equatable {
    let id: String
    let name: String
    let summary: String

    let rarity: Rarity

    /// Friedfisch, Raubfisch oder Allesfresser. Entscheidet mit darüber,
    /// welche Köder überhaupt in Frage kommen.
    let feeding: FeedingType

    /// Längenspanne in Zentimetern.
    let minLength: Double
    let maxLength: Double

    /// Gewichtsspanne in Kilogramm, passend zur Längenspanne.
    let minWeight: Double
    let maxWeight: Double

    let habitats: [Habitat]
    let activeTimes: [TimeOfDay]

    /// IDs bevorzugter Köder. Steht ein Köder hier, steigt die Bisschance stark.
    let preferredBaitIDs: [String]

    /// 0…1 — wie stark der Fisch im Minispiel zieht.
    let fightStrength: Double
    let motion: FightMotion

    /// Münzen pro Kilogramm, vor Seltenheits- und Größenbonus.
    let valuePerKilo: Int

    /// Ab diesem Spielerlevel kann die Art überhaupt beißen.
    let minPlayerLevel: Int

    let bodyColor: ColorSpec
    let bellyColor: ColorSpec
    let finColor: ColorSpec

    static func == (lhs: FishSpecies, rhs: FishSpecies) -> Bool {
        lhs.id == rhs.id
    }
}

extension FishSpecies {
    /// Gewicht passend zu einer Länge. Fische wachsen kubisch, deshalb wird
    /// die Länge relativ zur Spanne hoch drei genommen und in die
    /// Gewichtsspanne abgebildet.
    func weight(forLength length: Double) -> Double {
        let span = max(maxLength - minLength, 0.0001)
        let t = min(max((length - minLength) / span, 0), 1)
        let curved = pow(t, 2.6)
        return minWeight + (maxWeight - minWeight) * curved
    }

    /// 0…1 — wie außergewöhnlich ein Exemplar dieser Länge ist.
    func trophyFactor(forLength length: Double) -> Double {
        let span = max(maxLength - minLength, 0.0001)
        return min(max((length - minLength) / span, 0), 1)
    }
}

/// Ein konkret ausgewürfelter Fisch am Haken.
struct HookedFish: Equatable {
    let species: FishSpecies
    let lengthCm: Double
    let weightKg: Double
    let habitat: Habitat
    let baitID: String

    var trophyFactor: Double { species.trophyFactor(forLength: lengthCm) }

    /// Fisch, der deutlich über dem Durchschnitt liegt — wird im UI hervorgehoben.
    var isTrophy: Bool { trophyFactor > 0.82 }
}

/// Ergebnis eines abgeschlossenen Drills.
struct CatchResult: Equatable {
    let fish: HookedFish
    let coins: Int
    let experience: Int
    let isNewSpecies: Bool
    let isPersonalRecord: Bool
}
