import Foundation

/// Alle Gewässer des Spiels.
///
/// Die Reihenfolge ist die Reihenfolge in der Auswahl — vom Anfängerteich bis
/// zum Fluss. Ein weiteres Gewässer braucht nur einen Eintrag hier.
enum WaterCatalog {

    static let all: [Water] = [
        Water(
            id: "pond",
            name: "Dorfteich",
            subtitle: "Wo jeder anfängt",
            summary: "Hinter den Höfen liegt der alte Teich: flach, krautig, überschaubar. "
                + "Hier beißt fast immer etwas, und mehr als ein Karpfen oder ein Hecht "
                + "wird es nicht — genau richtig, um die Rute kennenzulernen.",
            shape: .pond,
            seed: 4_411_902,
            columns: 26,
            rows: 34,
            cellSize: 72,
            requiredLevel: 1,
            speciesIDs: ["bleak", "roach", "ruffe", "crucian_carp", "bream",
                         "tench", "carp", "koi", "perch", "pike"],
            shallowColor: ColorSpec(0x9FBFAE),
            deepColor: ColorSpec(0x47705E),
            shoreColor: ColorSpec(0xD3C69C)
        ),

        Water(
            id: "lake",
            name: "Großer See",
            subtitle: "Alles, was es gibt",
            summary: "Der Bergsee, mit dem alles anfing: Schilfgürtel, Seerosenfelder, "
                + "versunkene Stämme und ein Loch in der Mitte, dessen Grund niemand kennt. "
                + "Jede Art des Reviers kommt hier vor — auch die, von denen man nur erzählt.",
            shape: .lake,
            seed: 20_240_517,
            columns: 46,
            rows: 74,
            cellSize: 72,
            requiredLevel: 4,
            speciesIDs: FishCatalog.all.map { $0.id },
            shallowColor: ColorSpec(0x8FB6BE),
            deepColor: ColorSpec(0x2E5468),
            shoreColor: ColorSpec(0xD8C7A2)
        ),

        Water(
            id: "river",
            name: "Der Fluss",
            subtitle: "Strömung und Kies",
            summary: "Ein breiter Flusslauf mit Kiesbänken, tiefen Gumpen in den Kurven "
                + "und kaltem Wasser. Hier stehen die Fische der Strömung: Äschen, Barben, "
                + "Salmoniden — und unten im Kolk etwas, das viel älter ist.",
            shape: .river,
            seed: 77_310_244,
            columns: 34,
            rows: 96,
            cellSize: 72,
            requiredLevel: 8,
            speciesIDs: ["bleak", "goby", "ruffe", "bream", "grayling", "barbel",
                         "rainbow_trout", "char", "golden_trout", "salmon",
                         "perch", "zander", "eel", "catfish", "sturgeon", "beluga"],
            shallowColor: ColorSpec(0xA9C6C0),
            deepColor: ColorSpec(0x35606A),
            shoreColor: ColorSpec(0xCFC3A0)
        )
    ]

    private static let index: [String: Water] = {
        var map: [String: Water] = [:]
        for water in all { map[water.id] = water }
        return map
    }()

    static func water(id: String) -> Water? {
        index[id]
    }

    /// Das Gewässer, an dem ein neues Spiel beginnt.
    static var starter: Water { all[0] }

    /// Gewässer, die bei diesem Spielerstand offen sind.
    static func unlocked(for level: Int) -> [Water] {
        all.filter { $0.requiredLevel <= level }
    }
}
