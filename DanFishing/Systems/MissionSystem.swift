import Foundation

/// Die Aufgaben am See.
///
/// Sie laufen als Kette: Ist eine Staffel abgeholt, folgt sofort die nächste.
/// Die Aufgaben sind nicht zufällig zusammengewürfelt, sondern nach Kapiteln
/// geordnet — erst das Ufer, dann Schilf und Seerosen, dann Nacht und
/// Tiefwasser, zuletzt die Jagd auf das, wovon alle reden. Jede trägt einen
/// Satz, der sagt, warum man das tut.
enum MissionSystem {

    static let missionsPerSet = 3

    /// Kapitel, aus dem sich die Aufgaben einer Staffel speisen.
    private enum Chapter {
        case shore       // Staffel 1–2: ankommen, erste Fänge
        case weeds       // Staffel 3–4: Schilf, Seerosen, Geduld
        case night       // Staffel 5–7: Dämmerung, Nacht, Zufluss
        case depths      // ab Staffel 8: Tiefwasser, seltene Arten
        case legends     // ab Staffel 12: Rekorde und Ungeheuer

        static func forSet(_ index: Int) -> Chapter {
            switch index {
            case 0...1: return .shore
            case 2...3: return .weeds
            case 4...6: return .night
            case 7...11: return .depths
            default: return .legends
            }
        }

        var title: String {
            switch self {
            case .shore: return "Am Ufer"
            case .weeds: return "Im Kraut"
            case .night: return "Zwischen den Lichtern"
            case .depths: return "Über dem Grund"
            case .legends: return "Was man sich erzählt"
            }
        }
    }

    // MARK: - Erzeugung

    static func missions(forSet index: Int, playerLevel: Int) -> [Mission] {
        var rng = SeededGenerator(seed: UInt64(index &* 7919 &+ 13) &* 0x9E3779B9 &+ 17)
        let chapter = Chapter.forSet(index)
        let pool = templates(for: chapter, playerLevel: playerLevel)

        guard !pool.isEmpty else { return [] }

        // Aus dem Kapitelvorrat drei verschiedene ziehen.
        var remaining = pool
        var result: [Mission] = []

        for slot in 0..<min(missionsPerSet, remaining.count) {
            let pick = rng.nextInt(in: 0...(remaining.count - 1))
            let template = remaining.remove(at: pick)

            // Der Ertrag wächst mit der Staffel: Spätere Aufgaben verlangen
            // mehr und zahlen entsprechend.
            let scale = 1.0 + Double(index) * 0.12
            result.append(Mission(id: "set\(index)-\(slot)-\(template.key)",
                                  title: template.title,
                                  flavor: template.flavor,
                                  detail: template.detail,
                                  goal: template.goal,
                                  rewardCoins: Int(Double(template.coins) * scale),
                                  rewardXP: Int(Double(template.xp) * scale)))
        }

        return result
    }

    /// Kapitelüberschrift für die Anzeige.
    static func chapterTitle(forSet index: Int) -> String {
        Chapter.forSet(index).title
    }

    // MARK: - Vorlagen

    private struct Template {
        let key: String
        let title: String
        let flavor: String
        let detail: String
        let goal: MissionGoal
        let coins: Int
        let xp: Int
    }

    private static func templates(for chapter: Chapter, playerLevel: Int) -> [Template] {
        switch chapter {
        case .shore:
            return [
                Template(key: "firstcast",
                         title: "Der erste Wurf",
                         flavor: "Das Wasser liegt still da, als hätte es auf dich gewartet.",
                         detail: "Fange 4 Fische, ganz gleich welche.",
                         goal: .catchAny(4), coins: 70, xp: 25),

                Template(key: "shallows",
                         title: "Wo der Grund noch hell ist",
                         flavor: "In Ufernähe steht das kleine Zeug. Man sieht die Schatten, wenn man still hält.",
                         detail: "Fange 3 Fische in der Uferzone.",
                         goal: .inHabitat(.shallows, 3), coins: 90, xp: 30),

                Template(key: "wormday",
                         title: "Alter Freund Wurm",
                         flavor: "Kein Köder hat mehr Fische gesehen als der Wurm. Er wirkt langweilig, bis er wieder liefert.",
                         detail: "Fange 3 Fische mit dem Wurm.",
                         goal: .withBait("worm", 3), coins: 80, xp: 28),

                Template(key: "morning",
                         title: "Bevor die Sonne steht",
                         flavor: "Zwischen Nacht und Tag liegt eine Stunde, in der der See jemand anderes ist.",
                         detail: "Fange 2 Fische im Morgengrauen.",
                         goal: .duringTime(.dawn, 2), coins: 110, xp: 35),

                Template(key: "handspan",
                         title: "Eine Handspanne",
                         flavor: "Irgendwann reicht klein nicht mehr. Dann will man wissen, was da noch geht.",
                         detail: "Fange einen Fisch über 30 cm.",
                         goal: .minLength(30), coins: 100, xp: 32)
            ]

        case .weeds:
            return [
                Template(key: "reeds",
                         title: "Zwischen den Halmen",
                         flavor: "Im Schilf raschelt es, und es ist nicht immer der Wind.",
                         detail: "Fange 3 Fische im Schilf.",
                         goal: .inHabitat(.reeds, 3), coins: 130, xp: 40),

                Template(key: "lilies",
                         title: "Unter den Blättern",
                         flavor: "Karpfen ziehen dort ihre Runden, wo die Seerosen Schatten werfen. Geduld ist der halbe Fang.",
                         detail: "Fange 3 Fische im Seerosenfeld.",
                         goal: .inHabitat(.lilies, 3), coins: 140, xp: 42),

                Template(key: "cornday",
                         title: "Süßer Köder",
                         flavor: "Ein Korn Mais, mehr braucht es nicht. Der Rest ist Warten.",
                         detail: "Fange 3 Fische mit Mais.",
                         goal: .withBait("corn", 3), coins: 130, xp: 40),

                Template(key: "weight10",
                         title: "Volles Netz",
                         flavor: "Nicht jeder Tag bringt den einen Fisch. Manche bringen viele.",
                         detail: "Fange insgesamt 6 kg Fisch.",
                         goal: .totalWeight(6), coins: 170, xp: 50),

                Template(key: "newspecies",
                         title: "Noch nie gesehen",
                         flavor: "Das Fangbuch hat leere Seiten. Sie stören.",
                         detail: "Entdecke eine neue Art.",
                         goal: .discoverNew(1), coins: 180, xp: 55)
            ]

        case .night:
            return [
                Template(key: "dusk",
                         title: "Die blaue Stunde",
                         flavor: "Wenn das Licht geht, kommen die Räuber hoch. Jeder Angler kennt diese zwanzig Minuten.",
                         detail: "Fange 3 Fische im Abendrot.",
                         goal: .duringTime(.dusk, 3), coins: 200, xp: 60),

                Template(key: "night",
                         title: "Bei Laternenlicht",
                         flavor: "Nachts hört man den See mehr, als man ihn sieht. Und man spürt jeden Zupfer doppelt.",
                         detail: "Fange 3 Fische in der Nacht.",
                         goal: .duringTime(.night, 3), coins: 220, xp: 65),

                Template(key: "logs",
                         title: "Was im Totholz wartet",
                         flavor: "Versunkene Stämme sind Deckung. Wer dort steht, wartet auf etwas Ahnungsloses.",
                         detail: "Fange 2 Fische am Totholz.",
                         goal: .inHabitat(.sunkenLogs, 2), coins: 210, xp: 62),

                Template(key: "inflow",
                         title: "Wo das kalte Wasser kommt",
                         flavor: "Am Zufluss steht die Strömung voller Sauerstoff — und voller Forellen.",
                         detail: "Fange 2 Fische am Zufluss.",
                         goal: .inHabitat(.inflow, 2), coins: 210, xp: 62),

                Template(key: "rare",
                         title: "Nicht irgendeiner",
                         flavor: "Manche Fische zeigen sich nur, wenn alles stimmt: Platz, Zeit, Köder.",
                         detail: "Fange einen seltenen Fisch.",
                         goal: .rarityAtLeast(.rare, 1), coins: 260, xp: 75)
            ]

        case .depths:
            return [
                Template(key: "deep",
                         title: "Über dem Loch",
                         flavor: "Unter dem Boot fällt der Grund weg. Was da unten steht, sieht man nie ganz.",
                         detail: "Fange 3 Fische im Tiefwasser.",
                         goal: .inHabitat(.deep, 3), coins: 300, xp: 85),

                Template(key: "meter",
                         title: "Der Meterfisch",
                         flavor: "Es gibt eine Marke, über die jeder Angler redet. Sie ist rund und dreistellig.",
                         detail: "Fange einen Fisch über 100 cm.",
                         goal: .minLength(100), coins: 420, xp: 110),

                Template(key: "weight25",
                         title: "Schwerer Tag",
                         flavor: "Am Ende zählt nicht die Zahl der Fische, sondern was die Waage sagt.",
                         detail: "Fange insgesamt 20 kg Fisch.",
                         goal: .totalWeight(20), coins: 340, xp: 95),

                Template(key: "veryrare",
                         title: "Ein Gerücht vom Grund",
                         flavor: "Der Wirt am Steg schwört, er habe ihn gesehen. Der Wirt schwört viel.",
                         detail: "Fange einen sehr seltenen Fisch.",
                         goal: .rarityAtLeast(.veryRare, 1), coins: 520, xp: 130),

                Template(key: "bundle",
                         title: "Grobes Geschütz",
                         flavor: "Ein Bündel Tauwürmer am großen Haken. Damit fängt man nichts Kleines — oder gar nichts.",
                         detail: "Fange 2 Fische mit dem Tauwurm-Bündel.",
                         goal: .withBait("wormbundle", 2), coins: 380, xp: 100)
            ]

        case .legends:
            return [
                Template(key: "record",
                         title: "Die eigene Bestmarke",
                         flavor: "Irgendwann angelt man nicht mehr gegen den See, sondern gegen sich selbst.",
                         detail: "Stelle einen neuen persönlichen Rekord auf.",
                         goal: .personalRecord(1), coins: 500, xp: 140),

                Template(key: "legendary",
                         title: "Der Fisch aus den Geschichten",
                         flavor: "Jeder See hat einen. Man erkennt ihn daran, dass niemand ein Foto hat.",
                         detail: "Fange einen legendären Fisch.",
                         goal: .rarityAtLeast(.legendary, 1), coins: 900, xp: 220),

                Template(key: "weight60",
                         title: "Ein Boot voll",
                         flavor: "Der Kahn liegt tiefer im Wasser als heute Morgen. Gutes Zeichen.",
                         detail: "Fange insgesamt 50 kg Fisch.",
                         goal: .totalWeight(50), coins: 700, xp: 180),

                Template(key: "monster",
                         title: "Roter Oktober",
                         flavor: "Sie sagen, im tiefsten Loch liege etwas, das älter ist als der See. Man braucht den richtigen Blinker — und einen Nachmittag ohne Pläne.",
                         detail: "Fange den Hausen.",
                         goal: .catchSpecies("beluga", 1), coins: 2500, xp: 500),

                Template(key: "twometer",
                         title: "Zwei Meter",
                         flavor: "Ab dieser Länge glaubt es dir keiner mehr ohne Zeugen.",
                         detail: "Fange einen Fisch über 200 cm.",
                         goal: .minLength(200), coins: 1400, xp: 300)
            ]
        }
    }

    // MARK: - Fortschritt

    /// Sorgt dafür, dass der Spielstand die aktuelle Staffel führt, und
    /// schaltet weiter, sobald alle Belohnungen abgeholt sind.
    @discardableResult
    static func refreshIfNeeded(data: inout SaveData, now: Date = Date()) -> [Mission] {
        var missions = self.missions(forSet: data.missionSet, playerLevel: data.level)

        for mission in missions where !data.missions.contains(where: { $0.id == mission.id }) {
            data.missions.append(MissionProgress(id: mission.id))
        }

        let allClaimed = !missions.isEmpty && missions.allSatisfy { mission in
            data.missions.first(where: { $0.id == mission.id })?.claimed == true
        }

        if allClaimed {
            data.missionSet += 1
            data.missions.removeAll { entry in
                missions.contains(where: { $0.id == entry.id })
            }
            missions = self.missions(forSet: data.missionSet, playerLevel: data.level)
            for mission in missions {
                data.missions.append(MissionProgress(id: mission.id))
            }
        }

        return missions
    }

    /// Trägt einen Fang in alle laufenden Aufgaben ein und gibt zurück,
    /// welche dadurch fertig geworden sind.
    static func apply(result: CatchResult,
                      timeOfDay: TimeOfDay,
                      missions: [Mission],
                      data: inout SaveData) -> [Mission] {
        var completed: [Mission] = []

        for mission in missions {
            guard let index = data.missions.firstIndex(where: { $0.id == mission.id }) else { continue }
            var progress = data.missions[index]
            guard !progress.claimed, progress.progress < mission.goal.target else { continue }

            let step = mission.goal.progress(for: result, timeOfDay: timeOfDay)
            guard step > 0 else { continue }

            progress.progress = min(mission.goal.target, progress.progress + step)
            data.missions[index] = progress

            if progress.progress >= mission.goal.target {
                completed.append(mission)
            }
        }
        return completed
    }

    /// Belohnung abholen.
    @discardableResult
    static func claim(mission: Mission, data: inout SaveData) -> Bool {
        guard let index = data.missions.firstIndex(where: { $0.id == mission.id }) else { return false }
        var progress = data.missions[index]
        guard !progress.claimed, progress.progress >= mission.goal.target else { return false }

        progress.claimed = true
        data.missions[index] = progress
        data.coins += mission.rewardCoins
        _ = EconomySystem.applyExperience(mission.rewardXP, to: &data)
        return true
    }

    static func progress(for mission: Mission, in data: SaveData) -> MissionProgress {
        data.missions.first(where: { $0.id == mission.id }) ?? MissionProgress(id: mission.id)
    }
}
