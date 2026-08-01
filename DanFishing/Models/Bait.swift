import Foundation

/// Ködergattung. Naturköder wirken ruhig, Kunstköder brauchen Bewegung.
enum BaitKind: String, Codable, CaseIterable {
    case natural
    case artificial
    case special

    var displayName: String {
        switch self {
        case .natural: return "Naturköder"
        case .artificial: return "Kunstköder"
        case .special: return "Besonderer Köder"
        }
    }
}

/// Ein Köder. Die Wirkung entsteht aus dem Zusammenspiel mehrerer Faktoren und
/// wird dem Spieler bewusst nicht als Zahlentabelle gezeigt.
struct Bait: Identifiable, Equatable {
    let id: String
    let name: String
    let summary: String
    let kind: BaitKind

    /// Welche Fischgruppen diesen Köder überhaupt nehmen.
    ///
    /// Ein Spinner steht nur für Raubfische und Allesfresser in der Liste;
    /// ein Karpfen taucht deshalb gar nicht erst als Kandidat auf. Der Wurm
    /// steht in allen drei — deswegen ist er der Anfängerköder.
    let targets: [FeedingType]

    /// Art, auf die dieser Köder besonders gut abgestimmt ist. Nicht jeder
    /// Köder hat eine.
    let specialty: String?

    /// Wie stark die Spezialität wirkt. Der Regelfall reicht, um einen Köder
    /// erkennbar besser zu machen; für Köder, die eigens für einen einzigen
    /// Fisch gebaut wurden, lässt sich der Wert anheben.
    var specialtyBoost: Double = 3.4

    /// Preis in Münzen. 0 = von Beginn an vorhanden.
    let price: Int
    /// Spielerlevel, ab dem der Köder im Laden auftaucht.
    let unlockLevel: Int

    /// Zonen, in denen der Köder besonders gut funktioniert.
    let strongHabitats: [Habitat]
    /// Tageszeiten, zu denen der Köder besonders gut funktioniert.
    let strongTimes: [TimeOfDay]

    /// 0…1 — wie stark der Köder größere Exemplare anzieht.
    let sizeBias: Double
    /// 0…1 — wie stark der Köder seltene Arten anzieht.
    let rarityBias: Double
    /// 0…1 — Grundattraktivität (wie viele Fische überhaupt neugierig werden).
    let baseAppeal: Double

    let color: ColorSpec

    static func == (lhs: Bait, rhs: Bait) -> Bool {
        lhs.id == rhs.id
    }
}
