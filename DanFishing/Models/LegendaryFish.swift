import Foundation

/// Ein legendärer Einzelfisch.
///
/// Kein eigener Fischtyp, sondern ein bestimmtes Exemplar einer vorhandenen
/// Art: ein Hecht, den es genau einmal gibt, mit Namen, festem Standplatz und
/// eigenen Regeln. Er steht sichtbar im Wasser, ist aber scheu und nimmt nur
/// seinen Köder — man muss ihn suchen, nicht ausbrüten.
struct LegendaryFish: Codable, Equatable, Identifiable {

    let id: String
    /// Zum Beispiel „Das Modernde Lieschen“.
    let name: String
    let speciesID: String

    /// Gewässer, Zone und Tageszeit, an denen er steht.
    let waterID: String
    let habitatID: String
    let timeOfDayID: String

    /// Der einzige Köder, auf den er geht.
    let baitID: String

    /// Länge dieses Exemplars — immer im obersten Bereich seiner Art.
    let lengthCm: Double

    /// Wann er gefangen wurde. Nil, solange er noch draußen steht.
    var caughtAt: Date?

    // MARK: - Aufgelöste Daten

    var species: FishSpecies? { FishCatalog.species(id: speciesID) }
    var water: Water? { WaterCatalog.water(id: waterID) }
    var habitat: Habitat? { Habitat(rawValue: habitatID) }
    var timeOfDay: TimeOfDay? { TimeOfDay(rawValue: timeOfDayID) }
    var bait: Bait? { BaitCatalog.bait(id: baitID) }

    var weightKg: Double {
        guard let species else { return 0 }
        return (species.weight(forLength: lengthCm) * 100).rounded() / 100
    }

    /// Der Hinweis, den der Spieler bekommt.
    ///
    /// Er nennt Ort, Zone, Zeit und Köder — alles, was man zum Suchen braucht,
    /// aber nicht die Art. Die soll man selbst sehen, wenn der Schein im
    /// Wasser steht.
    var hint: String {
        let place = water?.name ?? "irgendwo"
        let zone = habitat?.displayName ?? "im Wasser"
        let time = timeOfDay?.displayName ?? "irgendwann"
        let baitName = bait?.name ?? "irgendetwas"

        return "Am \(place) erzählt man sich von \(name). "
            + "Er steht im Bereich \(zone) und nimmt nur \(baitName) — "
            + "am ehesten \(timePhrase(time))."
    }

    private func timePhrase(_ time: String) -> String {
        switch timeOfDay {
        case .dawn: return "in der Morgendämmerung"
        case .day: return "am hellen Tag"
        case .dusk: return "in der Abenddämmerung"
        case .night: return "bei Nacht"
        case nil: return "irgendwann"
        }
    }

    /// Kurzform für Karten und Listen.
    var shortHint: String {
        let zone = habitat?.displayName ?? "–"
        let time = timeOfDay?.displayName ?? "–"
        return "\(zone) · \(time) · \(bait?.name ?? "–")"
    }

    /// Die Uhrzeit ist ein Vorteil, keine Bedingung — das muss die Anzeige
    /// auch sagen, sonst wartet man umsonst auf die Dämmerung.
    var timeAdvice: String {
        guard let timeOfDay else { return "" }
        return "Beißt am besten \(timePhrase(timeOfDay.displayName)), sonst schlechter."
    }
}
