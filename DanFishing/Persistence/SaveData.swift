import Foundation

/// Fangbucheintrag einer Art. Wird erst angelegt, wenn die Art einmal gefangen
/// wurde — vorher zeigt das Fangbuch nur eine Silhouette.
struct CodexEntry: Codable, Equatable {
    var count: Int = 0
    var longestCm: Double = 0
    var heaviestKg: Double = 0
    /// Köder, mit denen die Art schon gefangen wurde (Reihenfolge = Häufigkeit egal).
    var baitIDs: [String] = []
    /// Zonen, in denen die Art schon gefangen wurde.
    var habitatIDs: [String] = []
    var firstCaught: Date?

    /// Wie viel das Fangbuch preisgibt: ab drei Fängen stehen Köder und
    /// Fundorte, ab fünf auch die Aktivitätszeiten.
    var detailLevel: Int {
        if count >= 5 { return 2 }
        if count >= 3 { return 1 }
        return 0
    }
}

/// Einstellungen. Bewusst klein gehalten und Teil des Spielstands.
struct GameSettings: Codable, Equatable {
    var music: Bool = true
    var sfx: Bool = true
    var haptics: Bool = true
    var showDepthHint: Bool = true
}

/// Der komplette Spielstand. Alles Weitere (Fischarten, Köderwerte, Upgrades)
/// steht im Katalog und wird nie gespeichert — gespeichert werden nur IDs.
struct SaveData: Codable, Equatable {
    /// Wird bei Formatänderungen erhöht; `SaveGameManager` verwirft ältere Stände.
    static let currentVersion = 1

    var version: Int = SaveData.currentVersion
    var coins: Int = 120
    var level: Int = 1
    var experience: Int = 0

    /// Gekaufte Köder. Köder verbrauchen sich nicht — sie werden einmal gekauft
    /// und stehen dann dauerhaft zur Verfügung. Das hält den Loop ruhig.
    var ownedBaitIDs: [String] = ["worm", "bread", "corn"]
    var selectedBaitID: String = "worm"

    /// Upgrade-ID zu gekaufter Stufe (0 = Grundausstattung).
    var upgradeLevels: [String: Int] = [:]

    /// Fangbuch, Schlüssel ist die Art-ID.
    var codex: [String: CodexEntry] = [:]

    var missions: [MissionProgress] = []
    /// Tag, für den die aktuellen Missionen erzeugt wurden (Start des Tages).
    var missionDay: Date?
    /// Laufende Nummer der Aufgabenstaffel. Sie zählt hoch, sobald alle
    /// Belohnungen abgeholt sind — dadurch reihen sich die Aufgaben wie eine
    /// Kampagne aneinander, statt auf den nächsten Kalendertag zu warten.
    var missionSet: Int = 0

    var totalCatches: Int = 0
    var totalReleased: Int = 0

    /// Wurde das Tutorial schon einmal durchlaufen?
    var tutorialDone: Bool = false
    /// Wurde der Vorspann schon gezeigt?
    var introSeen: Bool = false
    var settings = GameSettings()
    var lastPlayed: Date = Date()

    /// Position des Bootes, damit ein fortgesetztes Spiel dort weitergeht.
    var boatX: Double = 0
    var boatY: Double = 0
    var hasBoatPosition: Bool = false

    /// Erfahrungspunkte bis zum nächsten Level.
    static func experienceForLevel(_ level: Int) -> Int {
        let l = max(1, level)
        return 60 + (l - 1) * 45
    }

    var experienceForNextLevel: Int {
        SaveData.experienceForLevel(level)
    }

    /// Neuer Spielstand mit Startausrüstung.
    static func newGame() -> SaveData {
        SaveData()
    }
}
