import Foundation

/// Was eine Mission verlangt. Missionen werden aus dem Tagesdatum erzeugt,
/// deshalb muss der Typ selbst nicht gespeichert werden — nur der Fortschritt.
enum MissionGoal: Equatable {
    case catchAny(Int)
    case catchSpecies(String, Int)
    case minLength(Double)
    case withBait(String, Int)
    case discoverNew(Int)
    case duringTime(TimeOfDay, Int)
    case rarityAtLeast(Rarity, Int)
    case personalRecord(Int)

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
        }
    }
}

/// Eine konkrete Mission des Tages.
struct Mission: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let goal: MissionGoal
    let rewardCoins: Int
    let rewardXP: Int

    static func == (lhs: Mission, rhs: Mission) -> Bool {
        lhs.id == rhs.id
    }
}

/// Gespeicherter Fortschritt einer Mission.
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
