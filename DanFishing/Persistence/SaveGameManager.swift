import Foundation

/// Lädt und speichert den Spielstand als JSON in den UserDefaults.
///
/// Bewusst kein SwiftData: Der Stand ist ein einzelnes kleines Objekt, das
/// komplett im Speicher liegt. Codable plus UserDefaults ist dafür der
/// einfachste Weg, der ohne Migrationsaufwand auskommt.
final class SaveGameManager {

    static let shared = SaveGameManager(defaults: .standard)

    private let defaults: UserDefaults
    private let key = "danfishing.save.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    var hasSave: Bool {
        defaults.data(forKey: key) != nil
    }

    /// Lädt den Stand. Ist nichts vorhanden oder das Format zu alt, kommt nil
    /// zurück — der Aufrufer startet dann ein neues Spiel.
    func load() -> SaveData? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            let save = try decoder.decode(SaveData.self, from: data)
            guard save.version == SaveData.currentVersion else { return nil }
            return save
        } catch {
            // Ein kaputter Stand darf das Spiel nicht blockieren.
            return nil
        }
    }

    func save(_ data: SaveData) {
        var copy = data
        copy.lastPlayed = Date()
        do {
            let encoded = try encoder.encode(copy)
            defaults.set(encoded, forKey: key)
        } catch {
            // Schlägt das Speichern fehl, läuft das Spiel weiter — der
            // Fortschritt dieser Sitzung geht dann allerdings verloren.
        }
    }

    func deleteSave() {
        defaults.removeObject(forKey: key)
    }
}
