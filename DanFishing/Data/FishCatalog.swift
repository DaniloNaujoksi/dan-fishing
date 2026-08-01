import Foundation

/// Alle Fischarten des Spiels. Eine neue Art braucht nur einen weiteren Eintrag
/// in `all` — Spawner, Fangbuch, Missionen und Laden lesen daraus.
enum FishCatalog {

    static let all: [FishSpecies] = [
        FishSpecies(
            id: "roach",
            name: "Rotauge",
            summary: "Kleiner Schwarmfisch mit silbrigen Schuppen. Steht gern dicht am Ufer im flachen Wasser.",
            rarity: .common,
            minLength: 12, maxLength: 34,
            minWeight: 0.05, maxWeight: 0.9,
            habitats: [.shallows, .reeds],
            activeTimes: [.dawn, .day, .dusk],
            preferredBaitIDs: ["bread", "maggot", "worm"],
            fightStrength: 0.18,
            motion: .steady,
            valuePerKilo: 22,
            minPlayerLevel: 1,
            bodyColor: ColorSpec(0xB9C6CE), bellyColor: ColorSpec(0xEDF2F4), finColor: ColorSpec(0xC96A5A)
        ),
        FishSpecies(
            id: "perch",
            name: "Flussbarsch",
            summary: "Gestreifter Räuber, der in kleinen Gruppen an Totholz und Schilfkanten jagt.",
            rarity: .common,
            minLength: 15, maxLength: 48,
            minWeight: 0.08, maxWeight: 1.9,
            habitats: [.reeds, .sunkenLogs, .shallows],
            activeTimes: [.dawn, .day, .dusk],
            preferredBaitIDs: ["worm", "spinner", "minnow"],
            fightStrength: 0.34,
            motion: .darting,
            valuePerKilo: 34,
            minPlayerLevel: 1,
            bodyColor: ColorSpec(0x5E7A46), bellyColor: ColorSpec(0xE4E0C8), finColor: ColorSpec(0xD1743E)
        ),
        FishSpecies(
            id: "tench",
            name: "Schleie",
            summary: "Dunkelgrüner Bodenfisch mit samtiger Haut. Gründelt zwischen Seerosen im Schlamm.",
            rarity: .uncommon,
            minLength: 22, maxLength: 62,
            minWeight: 0.3, maxWeight: 3.6,
            habitats: [.lilies, .reeds],
            activeTimes: [.dawn, .dusk, .night],
            preferredBaitIDs: ["corn", "worm", "maggot"],
            fightStrength: 0.46,
            motion: .steady,
            valuePerKilo: 42,
            minPlayerLevel: 2,
            bodyColor: ColorSpec(0x3F5A3A), bellyColor: ColorSpec(0xC7C08A), finColor: ColorSpec(0x2E4230)
        ),
        FishSpecies(
            id: "carp",
            name: "Karpfen",
            summary: "Kräftiger Friedfisch. Zieht in Ruhe durch Seerosenfelder und wird sehr schwer.",
            rarity: .uncommon,
            minLength: 30, maxLength: 95,
            minWeight: 0.8, maxWeight: 16.0,
            habitats: [.lilies, .shallows, .deep],
            activeTimes: [.dawn, .day, .dusk],
            preferredBaitIDs: ["corn", "bread", "worm"],
            fightStrength: 0.62,
            motion: .diving,
            valuePerKilo: 38,
            minPlayerLevel: 2,
            bodyColor: ColorSpec(0x9A7A46), bellyColor: ColorSpec(0xE0CFA0), finColor: ColorSpec(0x6E5530)
        ),
        FishSpecies(
            id: "pike",
            name: "Hecht",
            summary: "Langer Ansitzräuber. Steht bewegungslos im Totholz und schießt aus dem Nichts hervor.",
            rarity: .rare,
            minLength: 40, maxLength: 128,
            minWeight: 0.6, maxWeight: 18.0,
            habitats: [.sunkenLogs, .reeds, .deep],
            activeTimes: [.dawn, .dusk],
            preferredBaitIDs: ["minnow", "wobbler", "softbait"],
            fightStrength: 0.78,
            motion: .thrashing,
            valuePerKilo: 55,
            minPlayerLevel: 3,
            bodyColor: ColorSpec(0x5C6B3A), bellyColor: ColorSpec(0xD9D6B0), finColor: ColorSpec(0x8A5B34)
        ),
        FishSpecies(
            id: "zander",
            name: "Zander",
            summary: "Dämmerungsjäger mit Glasauge. Hält sich an Kanten zum tiefen Wasser auf.",
            rarity: .rare,
            minLength: 35, maxLength: 105,
            minWeight: 0.5, maxWeight: 12.0,
            habitats: [.deep, .sunkenLogs],
            activeTimes: [.dusk, .night],
            preferredBaitIDs: ["softbait", "minnow", "spoon"],
            fightStrength: 0.7,
            motion: .diving,
            valuePerKilo: 62,
            minPlayerLevel: 4,
            bodyColor: ColorSpec(0x6E6B4C), bellyColor: ColorSpec(0xE6E2CC), finColor: ColorSpec(0x4A4632)
        ),
        FishSpecies(
            id: "rainbow_trout",
            name: "Regenbogenforelle",
            summary: "Schnelle Forelle mit rosa Band. Sucht kühles, sauerstoffreiches Wasser am Zufluss.",
            rarity: .uncommon,
            minLength: 22, maxLength: 66,
            minWeight: 0.2, maxWeight: 4.2,
            habitats: [.inflow, .deep],
            activeTimes: [.dawn, .day],
            preferredBaitIDs: ["fly", "spinner", "insect"],
            fightStrength: 0.55,
            motion: .darting,
            valuePerKilo: 58,
            minPlayerLevel: 2,
            bodyColor: ColorSpec(0x7E8C93), bellyColor: ColorSpec(0xF0EDE4), finColor: ColorSpec(0xC96F86)
        ),
        FishSpecies(
            id: "catfish",
            name: "Wels",
            summary: "Riesiger Grundfisch mit Barteln. Liegt tagsüber tief und wird nachts aktiv.",
            rarity: .veryRare,
            minLength: 60, maxLength: 210,
            minWeight: 2.0, maxWeight: 60.0,
            habitats: [.deep, .sunkenLogs],
            activeTimes: [.night],
            preferredBaitIDs: ["minnow", "worm", "softbait"],
            fightStrength: 0.95,
            motion: .diving,
            valuePerKilo: 48,
            minPlayerLevel: 6,
            bodyColor: ColorSpec(0x4B4438), bellyColor: ColorSpec(0xBFB49A), finColor: ColorSpec(0x342F27)
        ),
        FishSpecies(
            id: "koi",
            name: "Koi",
            summary: "Aus einem alten Teich entkommen. Ruhig, prächtig gezeichnet und erstaunlich stark.",
            rarity: .rare,
            minLength: 30, maxLength: 88,
            minWeight: 0.9, maxWeight: 11.0,
            habitats: [.lilies, .shallows],
            activeTimes: [.day, .dusk],
            preferredBaitIDs: ["bread", "corn", "insect"],
            fightStrength: 0.6,
            motion: .circling,
            valuePerKilo: 90,
            minPlayerLevel: 4,
            bodyColor: ColorSpec(0xF3EDE4), bellyColor: ColorSpec(0xFFFFFF), finColor: ColorSpec(0xD2553C)
        ),
        FishSpecies(
            id: "eel",
            name: "Aal",
            summary: "Schlangenförmig und zäh. Kommt nachts aus dem Schlamm und windet sich in die Schnur.",
            rarity: .rare,
            minLength: 40, maxLength: 130,
            minWeight: 0.3, maxWeight: 5.5,
            habitats: [.reeds, .sunkenLogs, .deep],
            activeTimes: [.night],
            preferredBaitIDs: ["worm", "minnow", "maggot"],
            fightStrength: 0.68,
            motion: .thrashing,
            valuePerKilo: 70,
            minPlayerLevel: 5,
            bodyColor: ColorSpec(0x3B3A32), bellyColor: ColorSpec(0xC9BE96), finColor: ColorSpec(0x2A2A24)
        ),
        FishSpecies(
            id: "golden_trout",
            name: "Goldforelle",
            summary: "Seltene helle Forellenform. Blitzt im Morgenlicht an der Mündung des Bachs auf.",
            rarity: .veryRare,
            minLength: 28, maxLength: 74,
            minWeight: 0.3, maxWeight: 5.0,
            habitats: [.inflow],
            activeTimes: [.dawn],
            preferredBaitIDs: ["fly", "insect", "spinner"],
            fightStrength: 0.66,
            motion: .circling,
            valuePerKilo: 130,
            minPlayerLevel: 5,
            bodyColor: ColorSpec(0xD9AE55), bellyColor: ColorSpec(0xF6ECC9), finColor: ColorSpec(0xB2762C)
        ),
        FishSpecies(
            id: "moon_carp",
            name: "Mondkarpfen",
            summary: "Bleicher Riese, der nur in klaren Nächten aus dem tiefsten Loch aufsteigt.",
            rarity: .legendary,
            minLength: 80, maxLength: 180,
            minWeight: 8.0, maxWeight: 42.0,
            habitats: [.deep],
            activeTimes: [.night],
            preferredBaitIDs: ["moonbait"],
            fightStrength: 1.0,
            motion: .circling,
            valuePerKilo: 210,
            minPlayerLevel: 8,
            bodyColor: ColorSpec(0xDCE4EC), bellyColor: ColorSpec(0xF7FAFF), finColor: ColorSpec(0x8FA6C4)
        )
    ]

    private static let index: [String: FishSpecies] = {
        var map: [String: FishSpecies] = [:]
        for species in all { map[species.id] = species }
        return map
    }()

    static func species(id: String) -> FishSpecies? {
        index[id]
    }

    /// Alle Arten, die in einer Zone überhaupt vorkommen können.
    static func species(in habitat: Habitat) -> [FishSpecies] {
        all.filter { $0.habitats.contains(habitat) }
    }
}
