import Foundation

/// Alle Köder. Reihenfolge = Reihenfolge in der Köderbox.
enum BaitCatalog {

    static let all: [Bait] = [
        Bait(id: "worm", name: "Wurm", summary: "Klassiker. Funktioniert fast überall, lockt aber selten die ganz großen Fische.",
             kind: .natural, price: 0, unlockLevel: 1,
             strongHabitats: [.shallows, .reeds, .lilies], strongTimes: [.dawn, .day, .dusk, .night],
             sizeBias: 0.30, rarityBias: 0.15, baseAppeal: 0.80, color: ColorSpec(0xB4705A)),

        Bait(id: "bread", name: "Brot", summary: "Weiche Flocke direkt unter der Oberfläche. Friedfische mögen es, Räuber ignorieren es.",
             kind: .natural, price: 0, unlockLevel: 1,
             strongHabitats: [.shallows, .lilies], strongTimes: [.day],
             sizeBias: 0.22, rarityBias: 0.10, baseAppeal: 0.72, color: ColorSpec(0xE6D3A8)),

        Bait(id: "corn", name: "Mais", summary: "Süßer Halt am Haken. Karpfen und Schleien stehen darauf.",
             kind: .natural, price: 0, unlockLevel: 1,
             strongHabitats: [.lilies, .shallows], strongTimes: [.dawn, .day, .dusk],
             sizeBias: 0.42, rarityBias: 0.18, baseAppeal: 0.70, color: ColorSpec(0xE3B94A)),

        Bait(id: "maggot", name: "Made", summary: "Winziger Happen für vorsichtige Fische. Viele Bisse, meist kleine Exemplare.",
             kind: .natural, price: 60, unlockLevel: 2,
             strongHabitats: [.shallows, .reeds], strongTimes: [.dawn, .day],
             sizeBias: 0.10, rarityBias: 0.08, baseAppeal: 0.95, color: ColorSpec(0xEFE6D2)),

        Bait(id: "insect", name: "Insektenköder", summary: "Nachbildung einer Eintagsfliege. Wirkt an warmen Abenden an der Oberfläche.",
             kind: .natural, price: 140, unlockLevel: 3,
             strongHabitats: [.inflow, .lilies], strongTimes: [.dusk, .dawn],
             sizeBias: 0.35, rarityBias: 0.30, baseAppeal: 0.65, color: ColorSpec(0x8C9A5B)),

        Bait(id: "minnow", name: "Köderfisch", summary: "Kleiner Weißfisch. Genau das, worauf große Räuber warten.",
             kind: .natural, price: 260, unlockLevel: 4,
             strongHabitats: [.sunkenLogs, .deep], strongTimes: [.dusk, .night],
             sizeBias: 0.75, rarityBias: 0.45, baseAppeal: 0.58, color: ColorSpec(0xBFC9CF)),

        Bait(id: "spinner", name: "Spinner", summary: "Rotierendes Blatt, das Druckwellen erzeugt. Gut im flachen, klaren Wasser.",
             kind: .artificial, price: 180, unlockLevel: 3,
             strongHabitats: [.inflow, .shallows, .reeds], strongTimes: [.day, .dawn],
             sizeBias: 0.50, rarityBias: 0.35, baseAppeal: 0.62, color: ColorSpec(0xC9B45E)),

        Bait(id: "spoon", name: "Blinker", summary: "Trudelndes Metall mit weitem Wurf. Sucht große Flächen schnell ab.",
             kind: .artificial, price: 240, unlockLevel: 4,
             strongHabitats: [.deep, .inflow], strongTimes: [.day, .dusk],
             sizeBias: 0.58, rarityBias: 0.38, baseAppeal: 0.56, color: ColorSpec(0xB9C4CA)),

        Bait(id: "wobbler", name: "Wobbler", summary: "Tauchschaufel und unruhiger Lauf. Reizt Hechte auch aus der Deckung heraus.",
             kind: .artificial, price: 340, unlockLevel: 5,
             strongHabitats: [.sunkenLogs, .deep], strongTimes: [.dawn, .dusk],
             sizeBias: 0.72, rarityBias: 0.50, baseAppeal: 0.54, color: ColorSpec(0xA05B45)),

        Bait(id: "softbait", name: "Gummifisch", summary: "Weicher Körper mit Schaufelschwanz, geführt dicht über Grund.",
             kind: .artificial, price: 300, unlockLevel: 5,
             strongHabitats: [.deep, .sunkenLogs], strongTimes: [.dusk, .night],
             sizeBias: 0.68, rarityBias: 0.48, baseAppeal: 0.58, color: ColorSpec(0x6B7F8E)),

        Bait(id: "fly", name: "Fliege", summary: "Fast gewichtslos. Verlangt ruhiges Wasser, bringt dafür feine Forellen.",
             kind: .artificial, price: 380, unlockLevel: 6,
             strongHabitats: [.inflow], strongTimes: [.dawn, .dusk],
             sizeBias: 0.45, rarityBias: 0.65, baseAppeal: 0.50, color: ColorSpec(0xD8CDB5)),

        Bait(id: "moonbait", name: "Mondköder", summary: "Blass schimmernde Perle aus dem alten Schrein. Nur in klaren Nächten wirksam.",
             kind: .special, price: 900, unlockLevel: 8,
             strongHabitats: [.deep], strongTimes: [.night],
             sizeBias: 0.92, rarityBias: 0.95, baseAppeal: 0.42, color: ColorSpec(0xE8EEF7))
    ]

    private static let index: [String: Bait] = {
        var map: [String: Bait] = [:]
        for bait in all { map[bait.id] = bait }
        return map
    }()

    static func bait(id: String) -> Bait? {
        index[id]
    }

    static var starterBaitIDs: [String] {
        all.filter { $0.price == 0 }.map { $0.id }
    }
}
