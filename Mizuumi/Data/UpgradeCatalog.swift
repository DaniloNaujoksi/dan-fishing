import Foundation

/// Alle Ausrüstungsreihen. Preise steigen pro Stufe deutlich, damit der
/// Spieler zwischen Rute, Rolle, Schnur und Boot abwägen muss.
enum UpgradeCatalog {

    static let all: [UpgradeTrack] = [
        UpgradeTrack(
            id: "rod",
            name: "Angelrute",
            category: .rod,
            summary: "Längere Ruten werfen weiter und halten schwerere Fische aus.",
            levels: [
                UpgradeLevel(title: "Bambusrute", effect: "+90 Wurfweite, +2 kg Tragkraft", price: 150,
                             delta: EquipmentStatDelta(castRange: 90, control: 0.03, maxFishWeight: 2)),
                UpgradeLevel(title: "Zedernrute", effect: "+110 Wurfweite, bessere Kontrolle", price: 420,
                             delta: EquipmentStatDelta(castRange: 110, control: 0.04, maxFishWeight: 4)),
                UpgradeLevel(title: "Lackrute", effect: "+130 Wurfweite, +8 kg Tragkraft", price: 980,
                             delta: EquipmentStatDelta(castRange: 130, control: 0.05, maxFishWeight: 8)),
                UpgradeLevel(title: "Meisterrute", effect: "+160 Wurfweite, hält alles im See", price: 2200,
                             delta: EquipmentStatDelta(castRange: 160, control: 0.06, maxFishWeight: 40))
            ]
        ),

        UpgradeTrack(
            id: "reel",
            name: "Rolle",
            category: .reel,
            summary: "Schnelleres Einholen und eine feinere Bremse im Drill.",
            levels: [
                UpgradeLevel(title: "Holzrolle", effect: "+15 % Einholtempo", price: 130,
                             delta: EquipmentStatDelta(reelSpeed: 0.15, brakeControl: 0.1)),
                UpgradeLevel(title: "Messingrolle", effect: "+20 % Einholtempo, ruhigere Bremse", price: 380,
                             delta: EquipmentStatDelta(reelSpeed: 0.2, brakeControl: 0.2)),
                UpgradeLevel(title: "Präzisionsrolle", effect: "+25 % Einholtempo, sehr feine Bremse", price: 900,
                             delta: EquipmentStatDelta(reelSpeed: 0.25, brakeControl: 0.3))
            ]
        ),

        UpgradeTrack(
            id: "line",
            name: "Schnur",
            category: .line,
            summary: "Reißfestere und unauffälligere Schnur.",
            levels: [
                UpgradeLevel(title: "Geflochtene Schnur", effect: "+30 % Reißfestigkeit", price: 120,
                             delta: EquipmentStatDelta(lineStrength: 0.3)),
                UpgradeLevel(title: "Fluorocarbon", effect: "+35 % Reißfestigkeit, unsichtbarer", price: 350,
                             delta: EquipmentStatDelta(lineStrength: 0.35, biteChance: 0.1)),
                UpgradeLevel(title: "Seidenkern", effect: "+45 % Reißfestigkeit", price: 820,
                             delta: EquipmentStatDelta(lineStrength: 0.45, biteChance: 0.05))
            ]
        ),

        UpgradeTrack(
            id: "hook",
            name: "Haken",
            category: .hook,
            summary: "Mehr Bisse und weniger Aussteiger nach dem Anschlag.",
            levels: [
                UpgradeLevel(title: "Geschliffener Haken", effect: "+10 % Bisse, +8 % Haltekraft", price: 90,
                             delta: EquipmentStatDelta(biteChance: 0.10, hookHold: 0.08)),
                UpgradeLevel(title: "Widerhakenlos", effect: "+12 % Bisse, +10 % Haltekraft", price: 280,
                             delta: EquipmentStatDelta(biteChance: 0.12, hookHold: 0.10)),
                UpgradeLevel(title: "Schmiedehaken", effect: "+15 % Bisse, +12 % Haltekraft", price: 700,
                             delta: EquipmentStatDelta(biteChance: 0.15, hookHold: 0.12))
            ]
        ),

        UpgradeTrack(
            id: "boat",
            name: "Ruderboot",
            category: .boat,
            summary: "Schnelleres und wendigeres Boot.",
            levels: [
                UpgradeLevel(title: "Neue Riemen", effect: "+35 Tempo, wendiger", price: 160,
                             delta: EquipmentStatDelta(boatSpeed: 35, boatTurnRate: 0.3)),
                UpgradeLevel(title: "Leichter Rumpf", effect: "+45 Tempo, deutlich wendiger", price: 480,
                             delta: EquipmentStatDelta(boatSpeed: 45, boatTurnRate: 0.4)),
                UpgradeLevel(title: "Lackierte Barke", effect: "+55 Tempo, sehr wendig", price: 1100,
                             delta: EquipmentStatDelta(boatSpeed: 55, boatTurnRate: 0.5))
            ]
        ),

        UpgradeTrack(
            id: "lantern",
            name: "Laterne",
            category: .special,
            summary: "Papierlaterne für das Nachtangeln. Erhellt das Wasser rund um das Boot.",
            levels: [
                UpgradeLevel(title: "Kleine Laterne", effect: "Lichtkreis bei Nacht", price: 220,
                             delta: EquipmentStatDelta(biteChance: 0.05, lanternRadius: 260)),
                UpgradeLevel(title: "Große Laterne", effect: "Größerer Lichtkreis, mehr Nachtbisse", price: 620,
                             delta: EquipmentStatDelta(biteChance: 0.08, lanternRadius: 180))
            ]
        ),

        UpgradeTrack(
            id: "finder",
            name: "Fischfinder",
            category: .special,
            summary: "Zeigt an, wie viel Fisch gerade unter dem Boot steht.",
            levels: [
                UpgradeLevel(title: "Einfaches Lot", effect: "Fischdichte am Angelplatz sichtbar", price: 540,
                             delta: EquipmentStatDelta(enablesFishFinder: true))
            ]
        ),

        UpgradeTrack(
            id: "charm",
            name: "Glücksbringer",
            category: .special,
            summary: "Ein Omamori vom Schrein am Ufer. Seltene Fische zeigen sich häufiger.",
            levels: [
                UpgradeLevel(title: "Kleines Omamori", effect: "+20 % Chance auf seltene Arten", price: 400,
                             delta: EquipmentStatDelta(luck: 0.2)),
                UpgradeLevel(title: "Geweihtes Omamori", effect: "+30 % Chance auf seltene Arten", price: 1400,
                             delta: EquipmentStatDelta(luck: 0.3))
            ]
        )
    ]

    private static let index: [String: UpgradeTrack] = {
        var map: [String: UpgradeTrack] = [:]
        for track in all { map[track.id] = track }
        return map
    }()

    static func track(id: String) -> UpgradeTrack? {
        index[id]
    }

    static func tracks(in category: UpgradeCategory) -> [UpgradeTrack] {
        all.filter { $0.category == category }
    }
}
