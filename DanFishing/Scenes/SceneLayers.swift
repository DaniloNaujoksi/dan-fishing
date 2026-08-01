import CoreGraphics

/// Die Zeichenreihenfolge der Szene an einer einzigen Stelle.
///
/// Vorher lag die Reihenfolge implizit darin, in welcher Reihenfolge die Knoten
/// angelegt wurden — dadurch schwammen Seerosen über dem Boot und über dem
/// Köder. Jetzt bekommt jede Ebene eine feste Höhe, und neue Inhalte ordnen
/// sich einfach dazwischen ein (die Abstände von 100 lassen Platz).
enum SceneLayer: CGFloat {
    /// Wasserfläche und Wellen.
    case water = 0
    /// Zonen: Ufer, Tiefe, Schilf- und Seerosenfelder als Farbflächen.
    case zones = 100
    /// Was unter Wasser liegt: versunkene Stämme, Kraut.
    case underwaterPlants = 200
    /// Die Fische selbst.
    case fish = 300
    /// Schatten auf der Wasseroberfläche — immer über den Fischen, unter allem,
    /// was schwimmt.
    case shadows = 400
    /// Schwimmblattpflanzen: Seerosen und Schilf.
    case floatingPlants = 500
    /// Das Boot mit Angler.
    case boat = 600
    /// Die Rute.
    case rod = 700
    /// Die Schnur zwischen Rutenspitze und Köder.
    case line = 800
    /// Der Köder — muss immer sichtbar bleiben.
    case lure = 900
    /// Ufer: Bäume, Steine, Schrein. Über dem Boot, damit Kronen überhängen.
    case shore = 1000
    /// Nebel, Blüten, Insekten.
    case weather = 1100
    /// Farbschleier für die Tageszeit, Laternenlicht.
    case atmosphere = 1200

    var z: CGFloat { rawValue }
}
