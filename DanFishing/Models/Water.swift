import CoreGraphics
import Foundation

/// Grundform eines Gewässers. Sie bestimmt, wie die Karte erzeugt wird.
enum WaterShape: String, Codable {
    /// Kleiner runder Teich, flach, viel Kraut.
    case pond
    /// Großer See mit tiefer Mitte und Inseln.
    case lake
    /// Langer Flusslauf mit Windungen, Kiesbänken und tiefen Gumpen.
    case river
    /// Schmaler Gebirgsbach mit Schwällen und Gumpen. Zu eng für ein Boot.
    case stream
}

/// Wie man sich an einem Gewässer fortbewegt.
enum WaterMovement: String, Codable {
    /// Im Ruderboot. Wasser ist frei, Land blockiert.
    case boat
    /// Zu Fuß. Land trägt, Wasser nur so tief, wie die Wathose reicht.
    case wading
}

/// Ein Gewässer, an dem geangelt wird.
///
/// Jedes bringt eigene Maße, einen eigenen Fischbestand und eine eigene
/// Stimmung mit. Ein neues Gewässer ist damit ein Eintrag im Katalog und keine
/// Änderung am Spielcode.
struct Water: Identifiable, Equatable {
    let id: String
    let name: String
    /// Kurzer Satz für die Auswahl.
    let subtitle: String
    /// Was den Ort ausmacht, in zwei bis drei Sätzen.
    let summary: String

    let shape: WaterShape
    /// Boot oder zu Fuß. Ein Bach ist zu eng zum Rudern.
    var movement: WaterMovement = .boat
    /// Startwert der Kartenerzeugung — gleicher Wert, gleiche Karte.
    let seed: UInt64
    let columns: Int
    let rows: Int
    let cellSize: CGFloat

    /// Ab welcher Spielerstufe das Gewässer offen ist.
    let requiredLevel: Int

    /// Strömung im Zufluss, in Punkten pro Sekunde. Auch ein stehender See hat
    /// dort Zug — der Bach schiebt das Wasser hinein.
    var inflowCurrent: Double = 0
    /// Strömung im übrigen Wasser. Nur fließende Gewässer haben sie.
    var ambientCurrent: Double = 0

    /// Welche Arten hier überhaupt vorkommen.
    let speciesIDs: [String]

    /// Farben für Wasser und Ufer, damit sich die Orte unterscheiden.
    let shallowColor: ColorSpec
    let deepColor: ColorSpec
    let shoreColor: ColorSpec

    static func == (lhs: Water, rhs: Water) -> Bool {
        lhs.id == rhs.id
    }

    /// Die Arten dieses Gewässers, aufgelöst aus dem Fischkatalog.
    var species: [FishSpecies] {
        FishCatalog.all.filter { speciesIDs.contains($0.id) }
    }

    /// Größter Fisch, den es hier gibt — für die Anzeige in der Auswahl.
    var biggestSpecies: FishSpecies? {
        species.max(by: { $0.maxLength < $1.maxLength })
    }
}
