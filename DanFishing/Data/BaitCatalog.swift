import Foundation

/// Alle Köder, sortiert nach Freischaltstufe und innerhalb einer Stufe nach
/// Preis. Diese Reihenfolge ist auch die Reihenfolge in Köderbox und Laden —
/// man liest die Liste von oben nach unten wie einen Aufstiegsplan.
///
/// `targets` ist die harte Regel: Wer nicht in der Liste steht, beißt auf
/// diesen Köder gar nicht. `specialty` nennt die Art, für die der Köder
/// gemacht ist — dort steigt die Chance deutlich.
enum BaitCatalog {

    static let all: [Bait] = [

        // MARK: Stufe 1 — die Grundausstattung

        Bait(id: "worm", name: "Wurm",
             summary: "Der Klassiker. Funktioniert bei fast allem, holt aber selten die ganz großen Fische.",
             kind: .natural, targets: [.peaceful, .predator, .omnivore], specialty: "eel",
             price: 0, unlockLevel: 1,
             strongHabitats: [.shallows, .reeds, .lilies], strongTimes: [.dawn, .day, .dusk, .night],
             sizeBias: 0.30, rarityBias: 0.15, baseAppeal: 0.80, color: ColorSpec(0xB4705A)),

        Bait(id: "bread", name: "Brot",
             summary: "Weiche Flocke dicht unter der Oberfläche. Nur für Friedfische.",
             kind: .natural, targets: [.peaceful], specialty: nil,
             price: 0, unlockLevel: 1,
             strongHabitats: [.shallows, .lilies], strongTimes: [.day],
             sizeBias: 0.22, rarityBias: 0.10, baseAppeal: 0.72, color: ColorSpec(0xE6D3A8)),

        Bait(id: "corn", name: "Mais",
             summary: "Süßes Korn am Haken. Karpfen und Schleien stehen darauf.",
             kind: .natural, targets: [.peaceful], specialty: "carp",
             price: 0, unlockLevel: 1,
             strongHabitats: [.lilies, .shallows], strongTimes: [.dawn, .day, .dusk],
             sizeBias: 0.42, rarityBias: 0.18, baseAppeal: 0.70, color: ColorSpec(0xE3B94A)),

        // MARK: Stufe 2 bis 3 — die ersten Käufe

        Bait(id: "maggot", name: "Made",
             summary: "Winziger Happen für vorsichtige Fische. Viele Bisse, meist kleine Exemplare.",
             kind: .natural, targets: [.peaceful, .omnivore], specialty: "roach",
             price: 60, unlockLevel: 2,
             strongHabitats: [.shallows, .reeds], strongTimes: [.dawn, .day],
             sizeBias: 0.10, rarityBias: 0.08, baseAppeal: 0.95, color: ColorSpec(0xEFE6D2)),

        Bait(id: "insect", name: "Insektenköder",
             summary: "Nachbildung einer Eintagsfliege. Wirkt an warmen Abenden an der Oberfläche.",
             kind: .natural, targets: [.peaceful, .omnivore], specialty: nil,
             price: 140, unlockLevel: 3,
             strongHabitats: [.inflow, .lilies], strongTimes: [.dusk, .dawn],
             sizeBias: 0.35, rarityBias: 0.30, baseAppeal: 0.65, color: ColorSpec(0x8C9A5B)),

        Bait(id: "spinner", name: "Spinner",
             summary: "Rotierendes Blatt, das Druckwellen erzeugt. Reizt nur jagende Fische.",
             kind: .artificial, targets: [.predator, .omnivore], specialty: "perch",
             price: 180, unlockLevel: 3,
             strongHabitats: [.inflow, .shallows, .reeds], strongTimes: [.day, .dawn],
             sizeBias: 0.50, rarityBias: 0.35, baseAppeal: 0.62, color: ColorSpec(0xC9B45E)),

        // MARK: Stufe 4 bis 5 — Raubfischangeln

        Bait(id: "spoon", name: "Blinker",
             summary: "Trudelndes Metall mit weitem Wurf. Sucht große Flächen schnell ab.",
             kind: .artificial, targets: [.predator, .omnivore], specialty: "salmon",
             price: 240, unlockLevel: 4,
             strongHabitats: [.deep, .inflow], strongTimes: [.day, .dusk],
             sizeBias: 0.58, rarityBias: 0.38, baseAppeal: 0.56, color: ColorSpec(0xB9C4CA)),

        Bait(id: "minnow", name: "Kleiner Köderfisch",
             summary: "Fingerlanger Weißfisch am Haken. Räuber jeder Größe nehmen ihn — auch die mittleren.",
             kind: .natural, targets: [.predator, .omnivore], specialty: "zander",
             price: 260, unlockLevel: 4,
             strongHabitats: [.sunkenLogs, .deep], strongTimes: [.dusk, .night],
             sizeBias: 0.75, rarityBias: 0.45, baseAppeal: 0.58, color: ColorSpec(0xBFC9CF)),

        Bait(id: "softbait", name: "Gummifisch",
             summary: "Weicher Körper mit Schaufelschwanz, geführt dicht über Grund.",
             kind: .artificial, targets: [.predator, .omnivore], specialty: nil,
             price: 300, unlockLevel: 5,
             strongHabitats: [.deep, .sunkenLogs], strongTimes: [.dusk, .night],
             sizeBias: 0.68, rarityBias: 0.48, baseAppeal: 0.58, color: ColorSpec(0x6B7F8E)),

        Bait(id: "wormbundle", name: "Wurmbündel",
             summary: "Eine ganze Handvoll Tauwürmer am großen Haken. Der Wels sucht genau danach; Aal und Stör nehmen ihn ebenso gern, und schwere Friedfische lassen ihn auch nicht liegen.",
             kind: .natural, targets: [.omnivore, .predator, .peaceful], specialty: "catfish",
             price: 320, unlockLevel: 5,
             strongHabitats: [.deep, .sunkenLogs], strongTimes: [.dusk, .night],
             sizeBias: 0.82, rarityBias: 0.42, baseAppeal: 0.60, color: ColorSpec(0x8E5140)),

        Bait(id: "wobbler", name: "Wobbler",
             summary: "Tauchschaufel und unruhiger Lauf. Holt Hechte aus der Deckung.",
             // Auch der Wels nimmt einen Wobbler, deshalb stehen hier die
             // Allesfresser mit in der Liste.
             kind: .artificial, targets: [.predator, .omnivore], specialty: "pike",
             price: 340, unlockLevel: 5,
             strongHabitats: [.sunkenLogs, .deep], strongTimes: [.dawn, .dusk],
             sizeBias: 0.72, rarityBias: 0.50, baseAppeal: 0.54, color: ColorSpec(0xA05B45)),

        // MARK: Stufe 6 — Spezialisten

        Bait(id: "fly", name: "Fliege",
             summary: "Fast gewichtslos. Verlangt ruhiges Wasser, bringt dafür feine Forellen, Äschen — und mit Glück einen Lachs.",
             kind: .artificial, targets: [.peaceful, .omnivore, .predator], specialty: "grayling",
             price: 380, unlockLevel: 6,
             strongHabitats: [.inflow], strongTimes: [.dawn, .dusk],
             sizeBias: 0.45, rarityBias: 0.65, baseAppeal: 0.50, color: ColorSpec(0xD8CDB5)),

        Bait(id: "big_minnow", name: "Großer Köderfisch",
             summary: "Ein halbes Pfund Fisch am Doppelhaken. Was darauf beißt, hat ein Maul dafür — alles andere lässt ihn liegen.",
             kind: .natural, targets: [.predator, .omnivore], specialty: nil,
             // Nur Arten, die mindestens einen Meter erreichen können.
             minSpeciesLength: 95,
             price: 620, unlockLevel: 6,
             strongHabitats: [.deep, .sunkenLogs], strongTimes: [.dusk, .night],
             sizeBias: 0.94, rarityBias: 0.62, baseAppeal: 0.44, color: ColorSpec(0x9BA9B2)),

        // MARK: Stufe 8 und 9 — die beiden letzten Köder

        Bait(id: "moonbait", name: "Mondköder",
             summary: "Blass schimmernde Perle aus dem alten Schrein. Nur in klaren Nächten wirksam.",
             kind: .special, targets: [.peaceful, .predator, .omnivore], specialty: "moon_carp",
             price: 900, unlockLevel: 8,
             strongHabitats: [.deep], strongTimes: [.night],
             sizeBias: 0.92, rarityBias: 0.95, baseAppeal: 0.42, color: ColorSpec(0xE8EEF7)),

        Bait(id: "red_october", name: "Roter Oktober",
             summary: "Ein knallroter Riesenblinker aus Soviet-Zeiten und so schwer wie ein Türgriff. Unter Wasser blitzt er wie ein Leuchtturm. Kleinfische verziehen sich, die ganz Großen kommen schauen.",
             kind: .artificial, targets: [.predator, .omnivore], specialty: "beluga",
             // Der Köder ist für genau einen Fisch gebaut: Mit ihm ist der
             // Hausen überhaupt erst realistisch zu erwischen.
             specialtyBoost: 9.0,
             price: 1500, unlockLevel: 9,
             strongHabitats: [.deep, .sunkenLogs], strongTimes: [.dusk, .night],
             sizeBias: 0.98, rarityBias: 0.88, baseAppeal: 0.34, color: ColorSpec(0xB3261F))
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
