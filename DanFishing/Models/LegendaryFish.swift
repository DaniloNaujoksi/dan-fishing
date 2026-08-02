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

    /// Spieltag, an dem die Geschichte aufkam.
    var spawnedOnDay: Int = 0
    /// Wie viele Spieltage sie zu holen ist. Danach zieht der Fisch weiter.
    var lifetimeDays: Int = 3

    /// Wann er gefangen wurde. Nil, solange er noch draußen steht.
    var caughtAt: Date?

    /// Letzter Tag, an dem er noch dasteht.
    var lastDay: Int { spawnedOnDay + lifetimeDays - 1 }

    /// Verbleibende Tage an einem bestimmten Spieltag. 0 heißt: heute ist der
    /// letzte Tag, negativ heißt weitergezogen.
    func daysLeft(onDay day: Int) -> Int { lastDay - day }

    func hasExpired(onDay day: Int) -> Bool { day > lastDay }

    // MARK: - Laden

    /// Eigener Decoder, damit Spielstände von vor der Frist weiterlaufen.
    ///
    /// Swift setzt bei fehlenden Schlüsseln keine Standardwerte ein, sondern
    /// wirft — ein alter Eintrag ohne `spawnedOnDay` würde also den ganzen
    /// Spielstand unlesbar machen. Deshalb hier von Hand.
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(String.self, forKey: .id)
        name = try box.decode(String.self, forKey: .name)
        speciesID = try box.decode(String.self, forKey: .speciesID)
        waterID = try box.decode(String.self, forKey: .waterID)
        habitatID = try box.decode(String.self, forKey: .habitatID)
        timeOfDayID = try box.decode(String.self, forKey: .timeOfDayID)
        baitID = try box.decode(String.self, forKey: .baitID)
        lengthCm = try box.decode(Double.self, forKey: .lengthCm)

        spawnedOnDay = try box.decodeIfPresent(Int.self, forKey: .spawnedOnDay) ?? 0
        lifetimeDays = try box.decodeIfPresent(Int.self, forKey: .lifetimeDays) ?? 3
        caughtAt = try box.decodeIfPresent(Date.self, forKey: .caughtAt)
    }

    init(id: String,
         name: String,
         speciesID: String,
         waterID: String,
         habitatID: String,
         timeOfDayID: String,
         baitID: String,
         lengthCm: Double,
         spawnedOnDay: Int = 0,
         lifetimeDays: Int = 3,
         caughtAt: Date? = nil) {
        self.id = id
        self.name = name
        self.speciesID = speciesID
        self.waterID = waterID
        self.habitatID = habitatID
        self.timeOfDayID = timeOfDayID
        self.baitID = baitID
        self.lengthCm = lengthCm
        self.spawnedOnDay = spawnedOnDay
        self.lifetimeDays = lifetimeDays
        self.caughtAt = caughtAt
    }

    // MARK: - Aufgelöste Daten

    var species: FishSpecies? { FishCatalog.species(id: speciesID) }
    var water: Water? { WaterCatalog.water(id: waterID) }
    var habitat: Habitat? { Habitat(rawValue: habitatID) }
    var timeOfDay: TimeOfDay? { TimeOfDay(rawValue: timeOfDayID) }
    var bait: Bait? { BaitCatalog.bait(id: baitID) }

    /// Gewicht des Exemplars.
    ///
    /// Über dem Höchstmaß der Art rechnet die Kurve nicht weiter — dort wird
    /// das Mehr an Länge kubisch draufgeschlagen, wie es sich für einen Fisch
    /// gehört, den es laut Buch gar nicht geben dürfte.
    var weightKg: Double {
        guard let species else { return 0 }
        var weight = species.weight(forLength: lengthCm)
        if lengthCm > species.maxLength {
            let excess = lengthCm / species.maxLength
            weight *= excess * excess * excess
        }
        return (weight * 100).rounded() / 100
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
