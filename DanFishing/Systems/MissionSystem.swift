import Foundation

/// Tagesaufgaben. Die Missionen eines Tages werden aus dem Datum erzeugt —
/// dadurch braucht der Spielstand nur den Fortschritt, nicht die Aufgabe selbst,
/// und alle Geräte zeigen am selben Tag dieselben Aufgaben.
enum MissionSystem {

    static let missionsPerDay = 3

    /// Tagesbeginn als stabiler Schlüssel.
    static func dayStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    private static func seed(for day: Date) -> UInt64 {
        UInt64(bitPattern: Int64(day.timeIntervalSince1970.rounded())) &* 0x9E3779B9 &+ 17
    }

    /// Erzeugt die Missionen eines Tages, passend zum Spielerlevel.
    static func missions(for day: Date, playerLevel: Int) -> [Mission] {
        var rng = SeededGenerator(seed: seed(for: day))
        return buildMissions(rng: &rng, playerLevel: playerLevel, setIndex: 0)
    }

    /// Baut eine Staffel Aufgaben. Der Index geht in die Kennung ein, damit
    /// spätere Staffeln eigene Einträge im Spielstand bekommen.
    private static func buildMissions(rng: inout SeededGenerator,
                                      playerLevel: Int,
                                      setIndex: Int) -> [Mission] {
        var result: [Mission] = []
        var usedKinds = Set<Int>()

        let commonSpecies = FishCatalog.all.filter {
            $0.minPlayerLevel <= playerLevel && $0.rarity <= .uncommon
        }
        let starterBaits = BaitCatalog.all.filter { $0.price == 0 }

        var attempts = 0
        while result.count < missionsPerDay && attempts < 40 {
            attempts += 1
            let kind = rng.nextInt(in: 0...6)
            guard !usedKinds.contains(kind) else { continue }
            usedKinds.insert(kind)

            let index = result.count
            let id = "set\(setIndex)-\(kind)"

            switch kind {
            case 0:
                let count = rng.nextInt(in: 3...6)
                result.append(Mission(id: id,
                                      title: "Ruhiger Tag am See",
                                      detail: "Fange \(count) Fische.",
                                      goal: .catchAny(count),
                                      rewardCoins: 40 + count * 8,
                                      rewardXP: 15 + count * 3))

            case 1:
                guard !commonSpecies.isEmpty else { continue }
                let species = commonSpecies[rng.nextInt(in: 0...(commonSpecies.count - 1))]
                let count = rng.nextInt(in: 2...4)
                result.append(Mission(id: id,
                                      title: "Auf \(species.name)",
                                      detail: "Fange \(count) × \(species.name).",
                                      goal: .catchSpecies(species.id, count),
                                      rewardCoins: 60 + count * 12,
                                      rewardXP: 22 + count * 4))

            case 2:
                let length = Double(rng.nextInt(in: 4...7)) * 10.0
                result.append(Mission(id: id,
                                      title: "Ein ordentlicher Fisch",
                                      detail: "Fange einen Fisch über \(Int(length)) cm.",
                                      goal: .minLength(length),
                                      rewardCoins: 90,
                                      rewardXP: 30))

            case 3:
                guard !starterBaits.isEmpty else { continue }
                let bait = starterBaits[rng.nextInt(in: 0...(starterBaits.count - 1))]
                let count = rng.nextInt(in: 2...4)
                result.append(Mission(id: id,
                                      title: "Mit \(bait.name)",
                                      detail: "Fange \(count) Fische mit \(bait.name).",
                                      goal: .withBait(bait.id, count),
                                      rewardCoins: 55 + count * 10,
                                      rewardXP: 20 + count * 4))

            case 4:
                result.append(Mission(id: id,
                                      title: "Neuland",
                                      detail: "Entdecke eine neue Fischart.",
                                      goal: .discoverNew(1),
                                      rewardCoins: 120,
                                      rewardXP: 40))

            case 5:
                let phase: TimeOfDay = index % 2 == 0 ? .dusk : .dawn
                let count = rng.nextInt(in: 1...3)
                result.append(Mission(id: id,
                                      title: phase == .dusk ? "Im Abendrot" : "Im ersten Licht",
                                      detail: "Fange \(count) Fische während \(phase.displayName).",
                                      goal: .duringTime(phase, count),
                                      rewardCoins: 80 + count * 10,
                                      rewardXP: 28 + count * 5))

            default:
                result.append(Mission(id: id,
                                      title: "Persönliche Bestmarke",
                                      detail: "Stelle einen neuen persönlichen Rekord auf.",
                                      goal: .personalRecord(1),
                                      rewardCoins: 100,
                                      rewardXP: 35))
            }
        }

        return result
    }

    /// Missionen einer Staffel. Statt an echte Kalendertage gebunden zu sein,
    /// laufen die Aufgaben als Kette: Ist eine Staffel abgeholt, folgt sofort
    /// die nächste. Wer einen Abend durchspielen will, muss nicht auf
    /// Mitternacht warten.
    static func missions(forSet index: Int, playerLevel: Int) -> [Mission] {
        var rng = SeededGenerator(seed: UInt64(index &* 7919 &+ 13) &* 0x9E3779B9 &+ 17)
        return buildMissions(rng: &rng, playerLevel: playerLevel, setIndex: index)
    }

    /// Sorgt dafür, dass der Spielstand die aktuelle Staffel führt, und
    /// schaltet weiter, sobald alle Belohnungen abgeholt sind.
    @discardableResult
    static func refreshIfNeeded(data: inout SaveData, now: Date = Date()) -> [Mission] {
        var missions = self.missions(forSet: data.missionSet, playerLevel: data.level)

        // Eintraege anlegen, die noch fehlen.
        for mission in missions where !data.missions.contains(where: { $0.id == mission.id }) {
            data.missions.append(MissionProgress(id: mission.id))
        }

        // Alles abgeholt? Dann kommt die nächste Staffel — sofort.
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

    /// Trägt einen Fang in alle laufenden Missionen ein und gibt die
    /// Missionen zurück, die dadurch fertig geworden sind.
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

    /// Belohnung abholen. Gibt zurück, ob es geklappt hat.
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

    /// Fortschritt einer Mission im Spielstand.
    static func progress(for mission: Mission, in data: SaveData) -> MissionProgress {
        data.missions.first(where: { $0.id == mission.id }) ?? MissionProgress(id: mission.id)
    }
}
