import Foundation

/// Kategorie einer Ausrüstungsreihe. Bestimmt nur Sortierung und Symbol im Laden.
enum UpgradeCategory: String, Codable, CaseIterable {
    case rod
    case reel
    case line
    case hook
    case boat
    case special

    var displayName: String {
        switch self {
        case .rod: return "Ruten"
        case .reel: return "Rollen"
        case .line: return "Schnüre"
        case .hook: return "Haken"
        case .boat: return "Boot"
        case .special: return "Ausrüstung"
        }
    }

    var symbolName: String {
        switch self {
        case .rod: return "figure.fishing"
        case .reel: return "circle.dotted"
        case .line: return "line.diagonal"
        case .hook: return "link"
        case .boat: return "sailboat"
        case .special: return "sparkles"
        }
    }
}

/// Alle Werte, die Ausrüstung im Spiel beeinflusst. Systeme lesen ausschließlich
/// diese Struktur — sie wissen nicht, aus welchen Upgrades sie entstanden ist.
struct EquipmentStats: Equatable {
    /// Maximale Wurfweite in Punkten. Bewusst knapp gehalten: Ein Wurf über
    /// den halben See nimmt dem Suchen nach dem richtigen Platz den Sinn.
    var castRange: Double = 300
    /// 0…1 — Breite des Fangbereichs im Minispiel.
    var control: Double = 0.30
    /// Wie viel Spannung die Schnur aushält (1.0 = Grundschnur).
    var lineStrength: Double = 1.0
    /// Wie schnell der Fortschritt im Minispiel steigt.
    var reelSpeed: Double = 1.0
    /// Wie schnell die Spannung beim Loslassen wieder fällt.
    var brakeControl: Double = 1.0
    /// Multiplikator auf die Bisswahrscheinlichkeit.
    var biteChance: Double = 1.0
    /// 0…1 — Chance, dass der Fisch nach dem Anschlag hängen bleibt.
    var hookHold: Double = 0.72
    /// Bootsgeschwindigkeit in Punkten pro Sekunde.
    var boatSpeed: Double = 190
    /// Wendigkeit in Bogenmaß pro Sekunde.
    var boatTurnRate: Double = 2.1
    /// Multiplikator auf die Chance seltener Arten.
    var luck: Double = 1.0
    /// Sichtradius bei Nacht (0 = keine Laterne).
    var lanternRadius: Double = 0
    /// Zeigt Fischschwärme in der Nähe an.
    var hasFishFinder: Bool = false
    /// Größere Fische lassen sich überhaupt erst ab einer gewissen Rute fangen.
    var maxFishWeight: Double = 6.0

    mutating func apply(_ delta: EquipmentStatDelta) {
        castRange += delta.castRange
        control += delta.control
        lineStrength += delta.lineStrength
        reelSpeed += delta.reelSpeed
        brakeControl += delta.brakeControl
        biteChance += delta.biteChance
        hookHold += delta.hookHold
        boatSpeed += delta.boatSpeed
        boatTurnRate += delta.boatTurnRate
        luck += delta.luck
        lanternRadius += delta.lanternRadius
        maxFishWeight += delta.maxFishWeight
        if delta.enablesFishFinder { hasFishFinder = true }
    }
}

/// Additiver Zuwachs einer einzelnen Upgrade-Stufe.
struct EquipmentStatDelta: Equatable {
    var castRange: Double = 0
    var control: Double = 0
    var lineStrength: Double = 0
    var reelSpeed: Double = 0
    var brakeControl: Double = 0
    var biteChance: Double = 0
    var hookHold: Double = 0
    var boatSpeed: Double = 0
    var boatTurnRate: Double = 0
    var luck: Double = 0
    var lanternRadius: Double = 0
    var maxFishWeight: Double = 0
    var enablesFishFinder: Bool = false
}

/// Eine Stufe innerhalb einer Ausrüstungsreihe.
struct UpgradeLevel: Equatable {
    let title: String
    let effect: String
    let price: Int
    let delta: EquipmentStatDelta
}

/// Eine Ausrüstungsreihe, z. B. „Rute“. Stufe 0 ist die Grundausstattung und
/// immer vorhanden; `levels[0]` ist der erste kaufbare Ausbau.
struct UpgradeTrack: Identifiable, Equatable {
    let id: String
    let name: String
    let category: UpgradeCategory
    let summary: String
    let levels: [UpgradeLevel]

    var maxLevel: Int { levels.count }

    func level(at index: Int) -> UpgradeLevel? {
        guard index >= 0 && index < levels.count else { return nil }
        return levels[index]
    }

    /// Preis der nächsten Stufe, oder nil wenn bereits ausgebaut.
    func nextPrice(currentLevel: Int) -> Int? {
        guard currentLevel < levels.count else { return nil }
        return levels[currentLevel].price
    }

    static func == (lhs: UpgradeTrack, rhs: UpgradeTrack) -> Bool {
        lhs.id == rhs.id
    }
}
