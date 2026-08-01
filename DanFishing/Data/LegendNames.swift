import Foundation

/// Namen für legendäre Fische.
///
/// Ein Name muss zur Art passen, sonst wirkt er beliebig: „Der Grimmige
/// Brassenfresser“ ist ein Hecht, „Der Dicke Oschi“ ein Karpfen. Deshalb hat
/// jede Art ihre eigenen Hauptwörter, dazu kommen ein Eigenschaftswort und
/// manchmal ein Ortszusatz aus der Zone. Aus wenigen Listen entstehen so
/// hunderte Namen, die trotzdem nie unsinnig klingen.
enum LegendNames {

    /// Ein Hauptwort mit seinem Artikel — nach bestimmtem Artikel endet das
    /// Eigenschaftswort in allen drei Geschlechtern auf „-e“, deshalb reicht
    /// diese eine Form.
    struct Noun {
        let article: String
        let word: String

        init(_ article: String, _ word: String) {
            self.article = article
            self.word = word
        }
    }

    private static let adjectives = [
        "alte", "grimmige", "listige", "uralte", "schlaue", "dicke", "narbige",
        "silberne", "schwarze", "sagenhafte", "zähe", "krumme", "goldene",
        "einäugige", "fette", "wilde", "stille", "störrische", "schwere"
    ]

    /// Hauptwörter je Art. Was hier nicht steht, bekommt eine Notfallliste aus
    /// dem Artnamen selbst.
    private static let nouns: [String: [Noun]] = [
        "pike": [Noun("Der", "Brassenfresser"), Noun("Der", "Schilfschreck"),
                 Noun("Der", "Zahnbrecher"), Noun("Das", "Grüne Gespenst"),
                 Noun("Der", "Hechtkönig"), Noun("Die", "Zange")],

        "catfish": [Noun("Der", "Grundkoloss"), Noun("Der", "Bartträger"),
                    Noun("Das", "Ungetüm"), Noun("Der", "Schlammdrache"),
                    Noun("Der", "Kolkherr")],

        "carp": [Noun("Der", "Oschi"), Noun("Der", "Schuppenberg"),
                 Noun("Das", "Schwergewicht"), Noun("Der", "Rüssel"),
                 Noun("Die", "Wanne")],

        "koi": [Noun("Der", "Tempelfisch"), Noun("Das", "Bunte Wunder"),
                Noun("Der", "Gartenkaiser")],

        "salmon": [Noun("Der", "Klopper"), Noun("Der", "Springer"),
                   Noun("Der", "Silberbarren"), Noun("Der", "Heimkehrer")],

        "zander": [Noun("Das", "Glasauge"), Noun("Der", "Kantenjäger"),
                   Noun("Der", "Nachtschatten"), Noun("Der", "Stachelrücken")],

        "perch": [Noun("Der", "Patrick"), Noun("Der", "Stachelritter"),
                  Noun("Der", "Streifenbandit"), Noun("Die", "Rotflosse")],

        "bleak": [Noun("Das", "Lieschen"), Noun("Das", "Silberblättchen"),
                  Noun("Der", "Winzling"), Noun("Das", "Blitzchen")],

        "roach": [Noun("Das", "Rotauge"), Noun("Der", "Plötzenfürst"),
                  Noun("Die", "Silbermünze")],

        "eel": [Noun("Die", "Schlange"), Noun("Der", "Nachtwurm"),
                Noun("Der", "Schlingel"), Noun("Das", "Schlammband")],

        "sturgeon": [Noun("Der", "Ritter"), Noun("Der", "Panzerträger"),
                     Noun("Das", "Urviech"), Noun("Der", "Knochenfisch")],

        "beluga": [Noun("Der", "Zar"), Noun("Das", "Ungeheuer"),
                   Noun("Der", "Riese vom Grund"), Noun("Die", "Legende")],

        "tench": [Noun("Der", "Schleimbeutel"), Noun("Die", "Grüne Dame"),
                  Noun("Der", "Doktorfisch")],

        "bream": [Noun("Der", "Klodeckel"), Noun("Der", "Teller"),
                  Noun("Das", "Blatt"), Noun("Der", "Schleimteller")],

        "barbel": [Noun("Der", "Kieskönig"), Noun("Der", "Strömungspflug"),
                   Noun("Der", "Bartel")],

        "grayling": [Noun("Die", "Fahne"), Noun("Die", "Äschenkönigin"),
                     Noun("Der", "Segler")],

        // „Puffmutter“, weil Forellenteiche unter Anglern Forellenpuff heißen.
        "rainbow_trout": [Noun("Die", "Puffmutter"), Noun("Der", "Regenbogen"),
                          Noun("Die", "Springerin"), Noun("Der", "Farbtupfer")],

        "golden_trout": [Noun("Der", "Goldschimmer"), Noun("Das", "Goldstück"),
                         Noun("Der", "Sonnenfisch")],

        "char": [Noun("Der", "Tiefenmönch"), Noun("Der", "Kaltwassergeist"),
                 Noun("Der", "Punktierte")],

        "crucian_carp": [Noun("Der", "Pfützenkönig"), Noun("Das", "Tellerchen"),
                         Noun("Der", "Zähe Bursche")],

        "goby": [Noun("Der", "Bodenkobold"), Noun("Das", "Gnomchen"),
                 Noun("Der", "Steinhocker")],

        "ruffe": [Noun("Der", "Rotzbengel"), Noun("Der", "Stachelzwerg"),
                  Noun("Das", "Kaulchen")],

        "moon_carp": [Noun("Der", "Mondscheinkarpfen"), Noun("Das", "Nachtgespenst"),
                      Noun("Die", "Perle des Sees")]
    ]

    /// Ortszusätze, damit ein Name nach einer bestimmten Ecke klingt.
    private static func places(for habitat: Habitat) -> [String] {
        switch habitat {
        case .shallows: return ["vom flachen Ufer", "von der Sandbank"]
        case .reeds: return ["aus dem Schilf", "vom Röhricht"]
        case .lilies: return ["aus den Seerosen", "vom Blattfeld"]
        case .deep: return ["vom Grund", "aus der Tiefe", "aus dem Loch"]
        case .inflow: return ["aus der Strömung", "vom Zufluss", "aus der Rinne"]
        case .sunkenLogs: return ["aus dem Totholz", "vom versunkenen Stamm"]
        }
    }

    /// Baut einen Namen. Gleicher Startwert, gleicher Name.
    static func name(for species: FishSpecies,
                     habitat: Habitat,
                     using rng: inout SeededGenerator) -> String {
        let pool = nouns[species.id] ?? fallbackNouns(for: species)
        let noun = pool[rng.nextInt(in: 0...(pool.count - 1))]
        let adjective = adjectives[rng.nextInt(in: 0...(adjectives.count - 1))]

        var name = "\(noun.article) \(adjective) \(noun.word)"

        // Nicht jeder Name bekommt einen Ortszusatz — sonst klingt jeder
        // gleich gebaut.
        if rng.nextUnit() < 0.45 {
            let options = places(for: habitat)
            name += " " + options[rng.nextInt(in: 0...(options.count - 1))]
        }
        return name
    }

    /// Für Arten ohne eigene Liste: der Artname selbst trägt den Namen.
    private static func fallbackNouns(for species: FishSpecies) -> [Noun] {
        [Noun("Der", species.name), Noun("Der", "\(species.name)könig")]
    }
}
