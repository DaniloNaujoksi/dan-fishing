import Foundation

/// Was eine Aufgabe verlangt.
///
/// Aufgaben werden aus dem Staffelindex erzeugt und nicht gespeichert — im
/// Spielstand liegt nur der Fortschritt.
enum MissionGoal: Equatable {
    case catchAny(Int)
    case catchSpecies(String, Int)
    case minLength(Double)
    case withBait(String, Int)
    case discoverNew(Int)
    case duringTime(TimeOfDay, Int)
    case rarityAtLeast(Rarity, Int)
    case personalRecord(Int)
    /// Fische aus einer bestimmten Zone.
    case inHabitat(Habitat, Int)
    /// Gesamtgewicht in Kilogramm. Intern in Hundert-Gramm-Schritten gezählt,
    /// damit der Fortschritt eine ganze Zahl bleiben kann.
    case totalWeight(Double)

    /// Wie viele Schritte bis zur Erfüllung.
    var target: Int {
        switch self {
        case .catchAny(let n): return n
        case .catchSpecies(_, let n): return n
        case .minLength: return 1
        case .withBait(_, let n): return n
        case .discoverNew(let n): return n
        case .duringTime(_, let n): return n
        case .rarityAtLeast(_, let n): return n
        case .personalRecord(let n): return n
        case .inHabitat(_, let n): return n
        case .totalWeight(let kilos): return Int((kilos * 10).rounded())
        }
    }

    /// Fortschritt, den ein einzelner Fang beisteuert.
    func progress(for result: CatchResult, timeOfDay: TimeOfDay) -> Int {
        switch self {
        case .catchAny:
            return 1
        case .catchSpecies(let speciesID, _):
            return result.fish.species.id == speciesID ? 1 : 0
        case .minLength(let cm):
            return result.fish.lengthCm >= cm ? 1 : 0
        case .withBait(let baitID, _):
            return result.fish.baitID == baitID ? 1 : 0
        case .discoverNew:
            return result.isNewSpecies ? 1 : 0
        case .duringTime(let phase, _):
            return timeOfDay == phase ? 1 : 0
        case .rarityAtLeast(let rarity, _):
            return result.fish.species.rarity >= rarity ? 1 : 0
        case .personalRecord:
            return result.isPersonalRecord ? 1 : 0
        case .inHabitat(let habitat, _):
            return result.fish.habitat == habitat ? 1 : 0
        case .totalWeight:
            return Int((result.fish.weightKg * 10).rounded())
        }
    }

    /// Fortschritt als Text. Gewicht liest sich in Kilogramm besser als in
    /// Zählschritten.
    func progressText(current: Int) -> String {
        switch self {
        case .totalWeight(let kilos):
            return String(format: "%.1f / %.1f kg", Double(min(current, target)) / 10, kilos)
        default:
            return "\(min(current, target)) / \(target)"
        }
    }
}

/// Eine konkrete Aufgabe.
struct Mission: Identifiable, Equatable {
    let id: String
    let title: String
    /// Stimmungssatz: warum diese Aufgabe, was daran reizt. Er trägt den Ton
    /// des Spiels — ohne ihn bleibt eine Aufgabe eine Zeile aus einer Liste.
    let flavor: String
    /// Was konkret zu tun ist.
    let detail: String
    let goal: MissionGoal
    let rewardCoins: Int
    let rewardXP: Int

    static func == (lhs: Mission, rhs: Mission) -> Bool {
        lhs.id == rhs.id
    }
}

/// Gespeicherter Fortschritt einer Aufgabe.
struct MissionProgress: Codable, Equatable, Identifiable {
    var id: String
    var progress: Int
    var claimed: Bool

    init(id: String, progress: Int = 0, claimed: Bool = false) {
        self.id = id
        self.progress = progress
        self.claimed = claimed
    }
}
