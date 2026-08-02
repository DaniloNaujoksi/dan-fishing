import Foundation

/// Seltenheit einer Fischart. Bestimmt Fangchance, Wert und Darstellung im Fangbuch.
enum Rarity: String, Codable, CaseIterable, Comparable {
    case common
    case uncommon
    case rare
    case veryRare
    case legendary
    /// Eine Stufe über legendär: Fische, von denen es im ganzen See vielleicht
    /// einen gibt. Sie sind das Fernziel, nicht der nächste Fang.
    case monster

    var displayName: String {
        switch self {
        case .common: return "Gewöhnlich"
        case .uncommon: return "Ungewöhnlich"
        case .rare: return "Selten"
        case .veryRare: return "Sehr selten"
        case .legendary: return "Legendär"
        case .monster: return "Legendärer Monsterfisch"
        }
    }

    /// Grundgewicht beim Auswürfeln. Seltene Fische tauchen deutlich seltener auf.
    var spawnWeight: Double {
        switch self {
        case .common: return 1.0
        case .uncommon: return 0.55
        case .rare: return 0.22
        case .veryRare: return 0.08
        case .legendary: return 0.02
        case .monster: return 0.004
        }
    }

    /// Multiplikator auf den Verkaufswert.
    var valueMultiplier: Double {
        switch self {
        case .common: return 1.0
        case .uncommon: return 1.4
        case .rare: return 2.1
        case .veryRare: return 3.4
        case .legendary: return 6.0
        case .monster: return 11.0
        }
    }

    var sortIndex: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 2
        case .veryRare: return 3
        case .legendary: return 4
        case .monster: return 5
        }
    }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }
}

/// Gewässerzone. Jede Zelle der Karte gehört zu genau einer Zone.
enum Habitat: String, Codable, CaseIterable {
    case shallows      // flaches Ufer
    case reeds         // Schilf
    case lilies        // Seerosen
    case deep          // tiefes Wasser
    case inflow        // kühler Zufluss
    case sunkenLogs    // versunkene Baumstämme

    var displayName: String {
        switch self {
        case .shallows: return "Uferzone"
        case .reeds: return "Schilf"
        case .lilies: return "Seerosen"
        case .deep: return "Tiefwasser"
        case .inflow: return "Zufluss"
        case .sunkenLogs: return "Totholz"
        }
    }

    /// Grobe Wassertiefe der Zone in Metern — nur für Anzeige und Köderlogik.
    var depthMeters: Double {
        switch self {
        case .shallows: return 0.8
        case .reeds: return 1.2
        case .lilies: return 1.6
        case .sunkenLogs: return 2.8
        case .inflow: return 2.2
        case .deep: return 6.5
        }
    }
}

/// Tageszeit. Der `DayNightSystem` schaltet zwischen diesen Abschnitten um.
enum TimeOfDay: String, Codable, CaseIterable {
    case dawn
    case day
    case dusk
    case night

    var displayName: String {
        switch self {
        case .dawn: return "Morgengrauen"
        case .day: return "Tag"
        case .dusk: return "Abendrot"
        case .night: return "Nacht"
        }
    }
}

/// Ernährungsweise einer Fischart.
///
/// Das ist die wichtigste Regel im Ködersystem: Ein Karpfen nimmt keinen
/// Spinner, weil er Pflanzen und Kleintiere frisst und kein Beutefisch-Jäger
/// ist. Ohne diese Trennung fängt jeder Köder alles, und die Köderwahl wird
/// beliebig.
enum FeedingType: String, Codable, CaseIterable {
    /// Friedfisch: Pflanzen, Würmer, Larven, Körner.
    case peaceful
    /// Raubfisch: jagt Beutefische.
    case predator
    /// Nimmt beides — etwa Barsch oder Wels.
    case omnivore

    var displayName: String {
        switch self {
        case .peaceful: return "Friedfisch"
        case .predator: return "Raubfisch"
        case .omnivore: return "Allesfresser"
        }
    }
}

/// Bewegungsmuster eines Fisches im Fang-Minispiel.
enum FightMotion: String, Codable, CaseIterable {
    case steady      // ruhig, gleichmäßig
    case darting     // kurze schnelle Sprints
    case circling    // weiche Sinuskurve
    case diving      // zieht immer wieder in eine Ecke
    case thrashing   // unruhig, viele Richtungswechsel
    /// Kurze harte Grundflucht mit plötzlichen Ausbrüchen nach oben. Der Fisch
    /// steht nie still: kaum hat man ihn hoch, geht er wieder auf Grund.
    case plunging
    /// Nicht zu berechnen: lange Fluchten quer durch die Bahn, kurze Pausen,
    /// in denen scheinbar nichts passiert, dann wieder ein Ruck. Nur für die
    /// ganz Großen.
    case rampage

    var displayName: String {
        switch self {
        case .steady: return "Ruhig"
        case .darting: return "Fluchtartig"
        case .circling: return "Kreisend"
        case .diving: return "Abtauchend"
        case .thrashing: return "Wild"
        case .plunging: return "Ruckartig abtauchend"
        case .rampage: return "Nicht zu berechnen"
        }
    }
}

/// Farbwerte werden im Modell als Hexzahl gehalten, damit die Datenschicht
/// unabhängig von UIKit/SpriteKit bleibt und testbar ist. Die Umwandlung in
/// SKColor passiert in `ColorSpec+SpriteKit`.
struct ColorSpec: Equatable {
    let hex: UInt32

    init(_ hex: UInt32) {
        self.hex = hex
    }

    var red: Double { Double((hex >> 16) & 0xFF) / 255.0 }
    var green: Double { Double((hex >> 8) & 0xFF) / 255.0 }
    var blue: Double { Double(hex & 0xFF) / 255.0 }
}
