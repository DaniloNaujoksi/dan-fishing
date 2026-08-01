import CoreGraphics
import XCTest
@testable import DanFishing

/// Tests der Kernlogik. Alles hier läuft ohne SpriteKit und ohne Oberfläche —
/// genau dafür sind die Systeme von der Darstellung getrennt.
final class FishModelTests: XCTestCase {

    func testWeightGrowsWithLength() {
        let carp = FishCatalog.species(id: "carp")!
        let small = carp.weight(forLength: carp.minLength)
        let middle = carp.weight(forLength: (carp.minLength + carp.maxLength) / 2)
        let large = carp.weight(forLength: carp.maxLength)

        XCTAssertEqual(small, carp.minWeight, accuracy: 0.001)
        XCTAssertEqual(large, carp.maxWeight, accuracy: 0.001)
        XCTAssertTrue(middle > small && middle < large)
    }

    func testTrophyFactorStaysInRange() {
        for species in FishCatalog.all {
            XCTAssertEqual(species.trophyFactor(forLength: species.minLength - 50), 0, accuracy: 0.001)
            XCTAssertEqual(species.trophyFactor(forLength: species.maxLength + 50), 1, accuracy: 0.001)
        }
    }

    func testCatalogIDsAreUnique() {
        let ids = Set(FishCatalog.all.map(\.id))
        XCTAssertEqual(ids.count, FishCatalog.all.count)

        let baitIDs = Set(BaitCatalog.all.map(\.id))
        XCTAssertEqual(baitIDs.count, BaitCatalog.all.count)
    }

    func testBaitsAreSortedByLevelThenPrice() {
        // Die Reihenfolge im Katalog ist die Reihenfolge im Laden. Ein neuer
        // Köder an der falschen Stelle fällt sonst niemandem auf.
        for (previous, next) in zip(BaitCatalog.all, BaitCatalog.all.dropFirst()) {
            XCTAssertTrue(previous.unlockLevel < next.unlockLevel
                          || (previous.unlockLevel == next.unlockLevel && previous.price <= next.price),
                          "\(previous.name) (Stufe \(previous.unlockLevel), \(previous.price)) "
                          + "steht vor \(next.name) (Stufe \(next.unlockLevel), \(next.price))")
        }
    }

    func testPreferredBaitsExist() {
        // Ein Tippfehler in einer Köder-ID würde die Art unfangbar machen.
        for species in FishCatalog.all {
            for baitID in species.preferredBaitIDs {
                XCTAssertNotNil(BaitCatalog.bait(id: baitID),
                                "Unbekannter Köder \(baitID) bei \(species.name)")
            }
        }
    }
}

final class BaitSystemTests: XCTestCase {

    private func context(habitat: Habitat,
                         time: TimeOfDay,
                         level: Int = 10,
                         stats: EquipmentStats = EquipmentStats()) -> BaitSystem.Context {
        BaitSystem.Context(habitat: habitat,
                           timeOfDay: time,
                           depth: habitat.depthMeters,
                           playerLevel: level,
                           stats: stats)
    }

    func testBigBaitFishOnlyForLargeSpecies() {
        let big = BaitCatalog.bait(id: "big_minnow")!
        let ctx = context(habitat: .deep, time: .night, level: 12)

        // Kleine Räuber bekommen ihn gar nicht erst ins Maul.
        let perch = FishCatalog.species(id: "perch")!
        XCTAssertEqual(BaitSystem.attraction(species: perch, bait: big, context: ctx), 0)

        // Die Großen dagegen schon.
        for id in ["pike", "catfish", "sturgeon", "beluga", "salmon", "eel", "zander"] {
            let species = FishCatalog.species(id: id)!
            XCTAssertGreaterThanOrEqual(species.maxLength, 95,
                                        "\(species.name) sollte groß genug sein")
        }
    }

    func testPredatorsMoveIntoTheShallowsAtNight() {
        let zander = FishCatalog.species(id: "zander")!
        let minnow = BaitCatalog.bait(id: "minnow")!

        // Tagsüber steht der Zander tief — im Flachen ist er gar nicht da.
        let day = context(habitat: .shallows, time: .day, level: 12)
        XCTAssertEqual(BaitSystem.attraction(species: zander, bait: minnow, context: day), 0)

        // Nachts jagt er dort, und zwar nicht nur nebenbei.
        let night = context(habitat: .shallows, time: .night, level: 12)
        XCTAssertGreaterThan(BaitSystem.attraction(species: zander, bait: minnow, context: night), 0)

        // Sein Tagesplatz bleibt aber erhalten.
        let deepDay = context(habitat: .deep, time: .day, level: 12)
        XCTAssertGreaterThan(BaitSystem.attraction(species: zander, bait: minnow, context: deepDay), 0)
    }

    func testNightHabitatsAreExtraSpots() {
        // Ein Nachtplatz, der ohnehin schon Tagesplatz ist, wäre nur ein
        // versteckter Bonus — dann stimmt die Beschreibung im Fangbuch nicht.
        for species in FishCatalog.all {
            for habitat in species.nightHabitats {
                XCTAssertFalse(species.habitats.contains(habitat),
                               "\(species.name): \(habitat.rawValue) steht doppelt")
            }
        }
    }

    func testRedOctoberOnlyReachesTheGiants() {
        let october = BaitCatalog.bait(id: "red_october")!
        let ctx = context(habitat: .deep, time: .night, level: 12)

        // Alles unter anderthalb Metern lässt das Blech in Ruhe — auch starke
        // Räuber wie Zander oder Lachs.
        for id in ["zander", "salmon", "perch", "carp", "barbel", "char"] {
            let species = FishCatalog.species(id: id)!
            XCTAssertEqual(BaitSystem.attraction(species: species, bait: october, context: ctx), 0,
                           "\(species.name) sollte den Roten Oktober nicht nehmen")
        }

        // Die Kapitalen dagegen schon.
        for id in ["beluga", "sturgeon", "catfish", "pike"] {
            let species = FishCatalog.species(id: id)!
            XCTAssertGreaterThan(BaitSystem.attraction(species: species, bait: october, context: ctx), 0,
                                 "\(species.name) sollte ihn nehmen")
        }
    }

    func testPickyFishRefuseEverythingOutsideTheirList() {
        let goby = FishCatalog.species(id: "goby")!
        let spoon = BaitCatalog.bait(id: "spoon")!
        let worm = BaitCatalog.bait(id: "worm")!
        let ctx = context(habitat: .shallows, time: .day)

        // Die Grundel gilt als Allesfresser, nimmt aber trotzdem keinen
        // Blinker — dafür sorgt ihre eigene Köderliste.
        XCTAssertEqual(BaitSystem.attraction(species: goby, bait: spoon, context: ctx), 0)
        XCTAssertGreaterThan(BaitSystem.attraction(species: goby, bait: worm, context: ctx), 0)
    }

    func testPeacefulFishIgnorePredatorBaits() {
        let carp = FishCatalog.species(id: "carp")!
        let spinner = BaitCatalog.bait(id: "spinner")!
        let corn = BaitCatalog.bait(id: "corn")!
        let ctx = context(habitat: .lilies, time: .day)

        // Ein Karpfen ist Friedfisch — ein Spinner ist für ihn kein Futter.
        XCTAssertEqual(BaitSystem.attraction(species: carp, bait: spinner, context: ctx), 0)
        XCTAssertGreaterThan(BaitSystem.attraction(species: carp, bait: corn, context: ctx), 0)
    }

    func testPredatorsIgnorePeacefulBaits() {
        let pike = FishCatalog.species(id: "pike")!
        let bread = BaitCatalog.bait(id: "bread")!
        let wobbler = BaitCatalog.bait(id: "wobbler")!
        let ctx = context(habitat: .sunkenLogs, time: .dawn)

        XCTAssertEqual(BaitSystem.attraction(species: pike, bait: bread, context: ctx), 0)
        XCTAssertGreaterThan(BaitSystem.attraction(species: pike, bait: wobbler, context: ctx), 0)
    }

    func testRedOctoberIsTheWayToTheMonster() {
        let ctx = context(habitat: .deep, time: .night, level: 12)
        let beluga = FishCatalog.species(id: "beluga")!
        let october = BaitCatalog.bait(id: "red_october")!
        let bundle = BaitCatalog.bait(id: "wormbundle")!

        let withOctober = BaitSystem.attraction(species: beluga, bait: october, context: ctx)
        let withBundle = BaitSystem.attraction(species: beluga, bait: bundle, context: ctx)

        // Deutlich besser, nicht nur ein bisschen: Der Köder ist für diesen
        // einen Fisch gemacht.
        XCTAssertGreaterThan(withOctober, withBundle * 2)
    }

    func testSpecialtyBaitBeatsOthers() {
        let ctx = context(habitat: .deep, time: .night, level: 10)
        let catfish = FishCatalog.species(id: "catfish")!
        let bundle = BaitCatalog.bait(id: "wormbundle")!
        let worm = BaitCatalog.bait(id: "worm")!

        XCTAssertGreaterThan(BaitSystem.attraction(species: catfish, bait: bundle, context: ctx),
                             BaitSystem.attraction(species: catfish, bait: worm, context: ctx))
    }

    func testWrongHabitatGivesNoAttraction() {
        let pike = FishCatalog.species(id: "pike")!
        let worm = BaitCatalog.bait(id: "worm")!
        // Hechte stehen nicht am Zufluss.
        let score = BaitSystem.attraction(species: pike,
                                          bait: worm,
                                          context: context(habitat: .inflow, time: .dawn))
        XCTAssertEqual(score, 0)
    }

    func testPreferredBaitBeatsRandomBait() {
        let pike = FishCatalog.species(id: "pike")!
        let wobbler = BaitCatalog.bait(id: "wobbler")!
        let bread = BaitCatalog.bait(id: "bread")!
        let ctx = context(habitat: .sunkenLogs, time: .dawn)

        let good = BaitSystem.attraction(species: pike, bait: wobbler, context: ctx)
        let bad = BaitSystem.attraction(species: pike, bait: bread, context: ctx)

        XCTAssertGreaterThan(good, bad)
    }

    func testLevelGateBlocksHighTierFish() {
        let catfish = FishCatalog.species(id: "catfish")!
        let minnow = BaitCatalog.bait(id: "minnow")!

        let low = BaitSystem.attraction(species: catfish, bait: minnow,
                                        context: context(habitat: .deep, time: .night, level: 1))
        let high = BaitSystem.attraction(species: catfish, bait: minnow,
                                         context: context(habitat: .deep, time: .night, level: 9))

        XCTAssertEqual(low, 0)
        XCTAssertGreaterThan(high, 0)
    }

    func testBiteDelayShrinksWithBetterHook() {
        let worm = BaitCatalog.bait(id: "worm")!
        var better = EquipmentStats()
        better.biteChance = 2.0

        let slow = BaitSystem.averageBiteDelay(bait: worm,
                                               context: context(habitat: .shallows, time: .day))
        let fast = BaitSystem.averageBiteDelay(bait: worm,
                                               context: context(habitat: .shallows, time: .day, stats: better))
        XCTAssertLessThan(fast, slow)
    }
}

final class FishSpawnerTests: XCTestCase {

    func testRolledFishFitsHabitatAndSize() {
        let bait = BaitCatalog.bait(id: "worm")!
        let context = BaitSystem.Context(habitat: .shallows,
                                         timeOfDay: .day,
                                         depth: 1.0,
                                         playerLevel: 10,
                                         stats: EquipmentStats())

        for _ in 0..<200 {
            guard let fish = FishSpawner.rollFish(bait: bait, context: context) else { continue }
            XCTAssertTrue(fish.species.habitats.contains(.shallows))
            XCTAssertGreaterThanOrEqual(fish.lengthCm, fish.species.minLength - 0.05)
            XCTAssertLessThanOrEqual(fish.lengthCm, fish.species.maxLength + 0.05)
            XCTAssertGreaterThan(fish.weightKg, 0)
        }
    }

    func testBigBaitShiftsSizeUpward() {
        let species = FishCatalog.species(id: "pike")!
        let small = BaitCatalog.bait(id: "maggot")!
        let big = BaitCatalog.bait(id: "minnow")!
        let stats = EquipmentStats()

        func averageLength(bait: Bait) -> Double {
            var total = 0.0
            let runs = 400
            for _ in 0..<runs {
                total += FishSpawner.rollLength(for: species, bait: bait, stats: stats)
            }
            return total / Double(runs)
        }

        XCTAssertGreaterThan(averageLength(bait: big), averageLength(bait: small))
    }
}

final class FishAITests: XCTestCase {

    private func swimmer(at point: CGPoint, habitat: Habitat, heading: CGFloat) -> FishAI.Swimmer {
        let species = FishCatalog.species(id: "roach")!
        return FishAI.Swimmer(position: point,
                              heading: heading,
                              speed: 40,
                              habitat: habitat,
                              speciesID: species.id,
                              scale: 1,
                              turnTimer: 1,
                              traits: FishAI.Traits.random(for: species))
    }

    func testFishKeepsMovingAlongTheShore() {
        let map = LakeMap.generate()

        // Ein Fisch, der direkt aufs Ufer zuschwimmt, muss daran entlang
        // ausweichen. Früher hat er an der Kante nur noch hin und her gekippt.
        guard let start = FishAI.randomPosition(in: .shallows, map: map) else {
            return XCTFail("Keine Flachwasserzone gefunden")
        }

        for direction in stride(from: 0.0, to: 6.2, by: 0.7) {
            var fish = swimmer(at: start, habitat: .shallows, heading: CGFloat(direction))
            let from = fish.position

            var travelled: CGFloat = 0
            var previous = fish.position
            for _ in 0..<600 {
                FishAI.update(&fish, deltaTime: 1.0 / 60.0, map: map,
                              lure: nil, interest: 0, biteAllowed: false)
                travelled += hypot(fish.position.x - previous.x, fish.position.y - previous.y)
                previous = fish.position

                XCTAssertFalse(map.isLand(at: fish.position), "Fisch im Ufer gelandet")
            }

            // In zehn Sekunden legt selbst ein bummelnder Fisch eine deutliche
            // Strecke zurück — steht er fest, bleibt der Wert nahe null.
            XCTAssertGreaterThan(travelled, 60, "Fisch klebt fest (Start \(from))")
        }
    }

    func testTrappedFishGetsFreed() {
        let map = LakeMap.generate()

        // Ein Fisch mitten im Ufer — so etwas kann durch einen Rundungsfehler
        // entstehen. Er muss sich innerhalb weniger Sekunden befreien.
        var fish = swimmer(at: CGPoint(x: 30, y: 30), habitat: .shallows, heading: 0)
        for _ in 0..<300 {
            FishAI.update(&fish, deltaTime: 1.0 / 60.0, map: map,
                          lure: nil, interest: 0, biteAllowed: false)
        }

        XCTAssertFalse(map.isLand(at: fish.position))
    }
}

final class CatchMiniGameTests: XCTestCase {

    private func fish(_ id: String, length: Double) -> HookedFish {
        let species = FishCatalog.species(id: id)!
        return HookedFish(species: species,
                          lengthCm: length,
                          weightKg: species.weight(forLength: length),
                          habitat: species.habitats[0],
                          baitID: species.preferredBaitIDs[0])
    }

    func testBarNeverLeavesTheTrack() {
        // Rutscht der Fangbereich halb aus der Bahn, wird er dort heimlich
        // kleiner — dann steht der Fisch sichtbar daneben und zählt trotzdem.
        for reeling in [true, false] {
            var game = CatchMiniGame(fish: fish("pike", length: 100),
                                     stats: EquipmentStats(),
                                     randomSource: { 0.5 })

            for _ in 0..<1200 {
                game.update(deltaTime: 1.0 / 60.0, reeling: reeling)
                XCTAssertGreaterThanOrEqual(game.barLowerEdge, -0.0001)
                XCTAssertLessThanOrEqual(game.barUpperEdge, 1.0001)

                // Und er behält seine volle Höhe, oben wie unten.
                XCTAssertEqual(game.barUpperEdge - game.barLowerEdge,
                               game.barHeight, accuracy: 0.0001)
                if game.isFinished { break }
            }
        }
    }

    func testHoldingReelEventuallyLandsFish() {
        var game = CatchMiniGame(fish: fish("roach", length: 20),
                                 stats: EquipmentStats(),
                                 randomSource: { 0.5 })

        // Der Spieler dosiert: halten, sobald der Fisch über dem Balken ist.
        for _ in 0..<3000 {
            let reeling = game.fishPosition > game.barPosition
            game.update(deltaTime: 1.0 / 60.0, reeling: reeling)
            if game.isFinished { break }
        }

        XCTAssertEqual(game.outcome, .landed)
    }

    func testPermanentReelingSnapsTheLine() {
        var game = CatchMiniGame(fish: fish("catfish", length: 180),
                                 stats: EquipmentStats(),
                                 randomSource: { 0.5 })

        for _ in 0..<3000 {
            game.update(deltaTime: 1.0 / 60.0, reeling: true)
            if game.isFinished { break }
        }

        XCTAssertEqual(game.outcome, .lineSnapped)
    }

    func testStrongerLineSurvivesLonger() {
        func snapTime(lineStrength: Double) -> Int {
            var stats = EquipmentStats()
            stats.lineStrength = lineStrength
            var game = CatchMiniGame(fish: fish("pike", length: 100),
                                     stats: stats,
                                     randomSource: { 0.5 })
            var steps = 0
            while !game.isFinished && steps < 6000 {
                game.update(deltaTime: 1.0 / 60.0, reeling: true)
                steps += 1
            }
            return steps
        }

        XCTAssertGreaterThan(snapTime(lineStrength: 2.0), snapTime(lineStrength: 1.0))
    }

    func testBarStaysInsideTrack() {
        var game = CatchMiniGame(fish: fish("perch", length: 30),
                                 stats: EquipmentStats(),
                                 randomSource: { 0.5 })

        for step in 0..<1200 {
            game.update(deltaTime: 1.0 / 60.0, reeling: step % 2 == 0)
            XCTAssertGreaterThanOrEqual(game.barPosition, 0)
            XCTAssertLessThanOrEqual(game.barPosition, 1)
            XCTAssertGreaterThanOrEqual(game.fishPosition, 0)
            XCTAssertLessThanOrEqual(game.fishPosition, 1)
        }
    }
}

final class EconomyTests: XCTestCase {

    func testRarerFishIsWorthMore() {
        let roach = FishCatalog.species(id: "roach")!
        let koi = FishCatalog.species(id: "koi")!

        let cheap = HookedFish(species: roach, lengthCm: 30, weightKg: 0.6,
                               habitat: .shallows, baitID: "worm")
        let precious = HookedFish(species: koi, lengthCm: 60, weightKg: 4.0,
                                  habitat: .lilies, baitID: "corn")

        XCTAssertGreaterThan(EconomySystem.coinValue(for: precious),
                             EconomySystem.coinValue(for: cheap))
    }

    func testExperienceRaisesLevel() {
        var data = SaveData.newGame()
        let needed = data.experienceForNextLevel

        let levels = EconomySystem.applyExperience(needed, to: &data)

        XCTAssertEqual(levels, 1)
        XCTAssertEqual(data.level, 2)
        XCTAssertEqual(data.experience, 0)
    }

    func testBonusForNewSpeciesAndRecords() {
        let species = FishCatalog.species(id: "pike")!
        let trophy = HookedFish(species: species, lengthCm: 126,
                                weightKg: species.weight(forLength: 126),
                                habitat: .sunkenLogs, baitID: "wobbler")

        let plain = CatchResult(fish: trophy, coins: 100, experience: 10,
                                isNewSpecies: false, isPersonalRecord: false)
        let special = CatchResult(fish: trophy, coins: 100, experience: 10,
                                  isNewSpecies: true, isPersonalRecord: true)

        // Ein Trophäenfisch bringt schon für sich einen Zuschlag; neue Art und
        // Rekord legen darauf.
        XCTAssertGreaterThan(EconomySystem.bonusCoins(for: special),
                             EconomySystem.bonusCoins(for: plain))
    }
}

final class UpgradeSystemTests: XCTestCase {

    func testPurchaseSpendsCoinsAndImprovesStats() {
        var data = SaveData.newGame()
        data.coins = 1000

        let before = UpgradeSystem.stats(for: data)
        let result = UpgradeSystem.purchase(trackID: "rod", data: &data)
        let after = UpgradeSystem.stats(for: data)

        switch result {
        case .success(let level):
            XCTAssertEqual(data.coins, 1000 - level.price)
            XCTAssertEqual(data.upgradeLevels["rod"], 1)
            XCTAssertGreaterThan(after.castRange, before.castRange)
        case .failure(let error):
            XCTFail("Kauf sollte klappen, war aber: \(error)")
        }
    }

    func testPurchaseFailsWithoutCoins() {
        var data = SaveData.newGame()
        data.coins = 0

        let result = UpgradeSystem.purchase(trackID: "rod", data: &data)

        if case .failure(let error) = result {
            XCTAssertEqual(error, .notEnoughCoins(missing: UpgradeCatalog.track(id: "rod")!.levels[0].price))
        } else {
            XCTFail("Kauf ohne Münzen darf nicht klappen")
        }
        XCTAssertNil(data.upgradeLevels["rod"])
    }

    func testTrackCannotExceedMaxLevel() {
        var data = SaveData.newGame()
        data.coins = 100_000
        let track = UpgradeCatalog.track(id: "reel")!

        for _ in 0..<track.maxLevel {
            _ = UpgradeSystem.purchase(trackID: track.id, data: &data)
        }
        let extra = UpgradeSystem.purchase(trackID: track.id, data: &data)

        XCTAssertEqual(data.upgradeLevels[track.id], track.maxLevel)
        if case .failure(let error) = extra {
            XCTAssertEqual(error, .alreadyMaxed)
        } else {
            XCTFail("Über die höchste Stufe hinaus darf nichts gekauft werden")
        }
    }

    func testBaitPurchase() {
        var data = SaveData.newGame()
        data.coins = 500
        data.level = 5

        let result = UpgradeSystem.buyBait(id: "minnow", data: &data)

        if case .failure(let error) = result {
            XCTFail("Köderkauf fehlgeschlagen: \(error)")
        }
        XCTAssertTrue(data.ownedBaitIDs.contains("minnow"))
    }
}

final class MissionSystemTests: XCTestCase {

    func testMissionsAreStableForTheSameSet() {
        let first = MissionSystem.missions(forSet: 3, playerLevel: 5)
        let second = MissionSystem.missions(forSet: 3, playerLevel: 5)

        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(first.count, MissionSystem.missionsPerSet)
        // Jede Aufgabe trägt einen Stimmungssatz — daran hängt der Ton.
        XCTAssertTrue(first.allSatisfy { !$0.flavor.isEmpty })
    }

    func testLaterChaptersDemandMoreAndPayMore() {
        let early = MissionSystem.missions(forSet: 0, playerLevel: 3)
        let late = MissionSystem.missions(forSet: 12, playerLevel: 12)

        let earlyCoins = early.map(\.rewardCoins).reduce(0, +)
        let lateCoins = late.map(\.rewardCoins).reduce(0, +)
        XCTAssertGreaterThan(lateCoins, earlyCoins * 3)
    }

    func testWeightGoalCountsInHundredGrams() {
        let goal = MissionGoal.totalWeight(5)
        XCTAssertEqual(goal.target, 50)

        let species = FishCatalog.species(id: "carp")!
        let fish = HookedFish(species: species, lengthCm: 60, weightKg: 2.5,
                              habitat: .lilies, baitID: "corn")
        let result = CatchResult(fish: fish, coins: 0, experience: 0,
                                 isNewSpecies: false, isPersonalRecord: false)

        XCTAssertEqual(goal.progress(for: result, timeOfDay: .day), 25)
        XCTAssertEqual(goal.progressText(current: 25), "2.5 / 5.0 kg")
    }

    func testHabitatGoalOnlyCountsMatchingCatches() {
        let goal = MissionGoal.inHabitat(.reeds, 3)
        let species = FishCatalog.species(id: "tench")!

        func result(in habitat: Habitat) -> CatchResult {
            let fish = HookedFish(species: species, lengthCm: 40, weightKg: 1.2,
                                  habitat: habitat, baitID: "corn")
            return CatchResult(fish: fish, coins: 0, experience: 0,
                               isNewSpecies: false, isPersonalRecord: false)
        }

        XCTAssertEqual(goal.progress(for: result(in: .reeds), timeOfDay: .day), 1)
        XCTAssertEqual(goal.progress(for: result(in: .deep), timeOfDay: .day), 0)
    }

    func testProgressAndClaim() {
        var data = SaveData.newGame()
        let missions = MissionSystem.refreshIfNeeded(data: &data)
        guard let mission = missions.first(where: {
            if case .catchAny = $0.goal { return true }
            return false
        }) else {
            // An diesem Tag gibt es keine „fange X Fische“-Aufgabe — dann ist
            // hier nichts zu prüfen.
            return
        }

        let species = FishCatalog.species(id: "roach")!
        let fish = HookedFish(species: species, lengthCm: 20, weightKg: 0.2,
                              habitat: .shallows, baitID: "worm")
        let result = CatchResult(fish: fish, coins: 10, experience: 5,
                                 isNewSpecies: true, isPersonalRecord: true)

        for _ in 0..<mission.goal.target {
            _ = MissionSystem.apply(result: result, timeOfDay: .day,
                                    missions: missions, data: &data)
        }

        let progress = MissionSystem.progress(for: mission, in: data)
        XCTAssertEqual(progress.progress, mission.goal.target)

        let coinsBefore = data.coins
        XCTAssertTrue(MissionSystem.claim(mission: mission, data: &data))
        XCTAssertEqual(data.coins, coinsBefore + mission.rewardCoins)
        XCTAssertFalse(MissionSystem.claim(mission: mission, data: &data), "Zweimal abholen darf nicht gehen")
    }
}

final class SaveGameTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "danfishing.tests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testRoundTrip() {
        let manager = SaveGameManager(defaults: defaults)
        var data = SaveData.newGame()
        data.coins = 777
        data.level = 4
        data.codex["carp"] = CodexEntry(count: 3, longestCm: 71.5, heaviestKg: 6.2,
                                        baitIDs: ["corn"], habitatIDs: ["lilies"],
                                        firstCaught: Date())

        manager.save(data)
        let loaded = manager.load()

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.coins, 777)
        XCTAssertEqual(loaded?.level, 4)
        XCTAssertEqual(loaded?.codex["carp"]?.count, 3)
    }

    func testMissingSaveReturnsNil() {
        let manager = SaveGameManager(defaults: defaults)
        XCTAssertFalse(manager.hasSave)
        XCTAssertNil(manager.load())
    }

    func testDeleteRemovesSave() {
        let manager = SaveGameManager(defaults: defaults)
        manager.save(SaveData.newGame())
        XCTAssertTrue(manager.hasSave)

        manager.deleteSave()
        XCTAssertFalse(manager.hasSave)
    }
}

final class LakeMapTests: XCTestCase {

    func testGenerationIsDeterministic() {
        let first = LakeMap.generate(seed: 42)
        let second = LakeMap.generate(seed: 42)

        XCTAssertEqual(first.cells.map(\.rawValue), second.cells.map(\.rawValue))
        XCTAssertEqual(first.startPosition, second.startPosition)
    }

    func testStartPositionIsOnWater() {
        let map = LakeMap.generate()
        XCTAssertFalse(map.isLand(at: map.startPosition))
    }

    func testOutsideTheGridCountsAsLand() {
        let map = LakeMap.generate()
        XCTAssertTrue(map.isLand(at: CGPoint(x: -50, y: -50)))
        XCTAssertTrue(map.isLand(at: CGPoint(x: map.worldSize.width + 10,
                                             y: map.worldSize.height + 10)))
    }

    func testMapContainsEveryHabitat() {
        let map = LakeMap.generate()
        var found = Set<String>()
        for cell in map.cells {
            if let habitat = cell.habitat { found.insert(habitat.rawValue) }
        }
        // Ohne alle Zonen wären ganze Fischarten unerreichbar.
        for habitat in Habitat.allCases {
            XCTAssertTrue(found.contains(habitat.rawValue), "Zone fehlt: \(habitat.rawValue)")
        }
    }

    func testCurrentOnlyRunsWhereThereIsWater() {
        let lake = WaterCatalog.water(id: "lake")!
        let map = LakeMap.generate(for: lake)

        var sawInflowCurrent = false
        for row in 0..<map.rows {
            for column in 0..<map.columns {
                let point = CGPoint(x: (Double(column) + 0.5) * Double(map.cellSize),
                                    y: (Double(row) + 0.5) * Double(map.cellSize))
                let flow = map.current(at: point)
                let cell = map.kind(column: column, row: row)

                switch cell {
                case .land:
                    XCTAssertEqual(hypot(flow.dx, flow.dy), 0, accuracy: 0.001)
                case .inflow:
                    XCTAssertGreaterThan(flow.dy, 0)
                    sawInflowCurrent = true
                default:
                    // Der See selbst steht still.
                    XCTAssertEqual(hypot(flow.dx, flow.dy), 0, accuracy: 0.001)
                }
            }
        }
        XCTAssertTrue(sawInflowCurrent, "Der See hat keinen ziehenden Zufluss")
    }

    func testRiverPullsEverywhere() {
        let river = WaterCatalog.water(id: "river")!
        let map = LakeMap.generate(for: river)

        // Im Fluss zieht auch das ruhige Wasser, nur schwächer als die Rinne.
        guard let deep = FishAI.randomPosition(in: .deep, map: map),
              let fast = FishAI.randomPosition(in: .inflow, map: map) else {
            return XCTFail("Flusszonen fehlen")
        }

        XCTAssertGreaterThan(map.current(at: deep).dy, 0)
        XCTAssertGreaterThan(map.current(at: fast).dy, map.current(at: deep).dy)
    }

    func testSmallZonesAreStillFound() {
        // Rein zufälliges Probieren verfehlt kleine Zonen. Gesucht wird
        // trotzdem etwas gefunden, sonst stünde dort nie ein Fisch.
        for water in WaterCatalog.all {
            let map = LakeMap.generate(for: water)
            for habitat in Habitat.allCases where map.cellCount(of: habitat) > 0 {
                XCTAssertNotNil(FishAI.randomPosition(in: habitat, map: map, attempts: 1),
                                "\(water.name): \(habitat.rawValue) nicht auffindbar")
            }
        }
    }

    func testNearestWaterLeavesLand() {
        let map = LakeMap.generate()
        let land = CGPoint(x: 20, y: 20)   // Ecke ist immer Ufer
        let rescued = map.nearestWater(from: land)
        XCTAssertFalse(map.isLand(at: rescued))
    }
}

final class MovementControllerTests: XCTestCase {

    func testBoatMovesWithInput() {
        let map = LakeMap.generate()
        var boat = MovementController(position: map.startPosition, heading: 0)
        let start = boat.position

        for _ in 0..<60 {
            boat.update(deltaTime: 1.0 / 60.0,
                        input: CGVector(dx: 1, dy: 0),
                        stats: EquipmentStats(),
                        map: map)
        }

        XCTAssertNotEqual(boat.position, start)
    }

    func testBoatNeverEntersLand() {
        let map = LakeMap.generate()
        var boat = MovementController(position: map.startPosition, heading: 0)

        // Vollgas in alle Richtungen — das Boot muss trotzdem im Wasser bleiben.
        let directions = [CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: 1),
                          CGVector(dx: -1, dy: 0), CGVector(dx: 0, dy: -1)]

        for direction in directions {
            for _ in 0..<600 {
                boat.update(deltaTime: 1.0 / 60.0,
                            input: direction,
                            stats: EquipmentStats(),
                            map: map)
                XCTAssertFalse(map.isLand(at: boat.position))
            }
        }
    }

    func testAngleDifferenceWrapsAround() {
        let difference = MovementController.angleDifference(3.0, -3.0)
        XCTAssertLessThan(abs(difference), .pi)
    }

    func testWadingStaysOutOfDeepWater() {
        let stream = WaterCatalog.water(id: "stream")!
        let map = LakeMap.generate(for: stream)

        // Ohne Wathose kommt man über den Uferstreifen nicht hinaus.
        var angler = MovementController(position: map.startPosition, heading: 0)
        angler.mode = .wading(maxDepth: EquipmentStats().wadingDepth)

        let directions = [CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: 1),
                          CGVector(dx: -1, dy: 0), CGVector(dx: 0, dy: -1)]

        for direction in directions {
            for _ in 0..<600 {
                angler.update(deltaTime: 1.0 / 60.0,
                              input: direction,
                              stats: EquipmentStats(),
                              map: map)
                let depth = map.kind(at: angler.position).habitat?.depthMeters ?? 0
                XCTAssertLessThanOrEqual(depth, EquipmentStats().wadingDepth)
            }
        }
    }

    func testWadersOpenUpDeeperWater() {
        let stream = WaterCatalog.water(id: "stream")!
        let map = LakeMap.generate(for: stream)

        // Flachwasser (0,8 m) ist ohne Stiefel gesperrt und mit Stiefeln frei.
        guard let shallow = firstPoint(in: map, kind: .shallows) else {
            return XCTFail("Der Bach hat kein Flachwasser")
        }

        var barefoot = MovementController(position: map.startPosition)
        barefoot.mode = .wading(maxDepth: 0.35)
        XCTAssertTrue(barefoot.isBlocked(shallow, map: map))

        var booted = MovementController(position: map.startPosition)
        booted.mode = .wading(maxDepth: 0.85)
        XCTAssertFalse(booted.isBlocked(shallow, map: map))
    }

    /// Mittelpunkt der ersten Zelle einer Art, mit Abstand zu allem Tieferen —
    /// sonst schlägt der Umkreis der Kollisionsprüfung an.
    private func firstPoint(in map: LakeMap, kind target: CellKind) -> CGPoint? {
        for row in 1..<(map.rows - 1) {
            for column in 1..<(map.columns - 1) {
                guard map.kind(column: column, row: row) == target else { continue }

                var clean = true
                for dy in -1...1 where clean {
                    for dx in -1...1 {
                        let neighbour = map.kind(column: column + dx, row: row + dy)
                        let depth = neighbour.habitat?.depthMeters ?? 0
                        if depth > target.habitat!.depthMeters { clean = false; break }
                    }
                }
                guard clean else { continue }

                return CGPoint(x: (CGFloat(column) + 0.5) * map.cellSize,
                               y: (CGFloat(row) + 0.5) * map.cellSize)
            }
        }
        return nil
    }
}

final class LegendSystemTests: XCTestCase {

    private func roll(level: Int, seed: UInt64) -> LegendaryFish? {
        LegendSystem.roll(level: level,
                          ownedBaitIDs: ["worm", "bread", "corn"],
                          avoiding: [],
                          seed: seed)
    }

    func testNoLegendBeforeTheMinimumLevel() {
        for level in 1..<LegendSystem.minimumLevel {
            XCTAssertNil(roll(level: level, seed: 42))
        }
    }

    func testLegendIsAlwaysReachable() {
        // Jede Legende muss fangbar sein: Gewässer offen, Art dort vorhanden,
        // Zone auf der Karte, Köder erreichbar und passend.
        // Karten sind teuer zu erzeugen, deshalb einmal pro Gewässer.
        var maps: [String: LakeMap] = [:]

        for seed in UInt64(1)...25 {
            for level in [6, 9, 12, 16] {
                guard let legend = roll(level: level, seed: seed * 977) else {
                    return XCTFail("Keine Legende auf Stufe \(level)")
                }

                guard let species = legend.species,
                      let water = legend.water,
                      let habitat = legend.habitat,
                      let time = legend.timeOfDay,
                      let bait = legend.bait else {
                    return XCTFail("Legende mit unbekannten Daten: \(legend)")
                }

                XCTAssertLessThanOrEqual(water.requiredLevel, level)
                XCTAssertTrue(water.speciesIDs.contains(species.id),
                              "\(species.name) kommt im \(water.name) nicht vor")
                XCTAssertLessThanOrEqual(species.minPlayerLevel, level)
                XCTAssertLessThanOrEqual(bait.unlockLevel, level)

                // Der genannte Köder muss unter genau diesen Bedingungen auch
                // wirklich funktionieren.
                let context = BaitSystem.Context(habitat: habitat,
                                                 timeOfDay: time,
                                                 depth: habitat.depthMeters,
                                                 playerLevel: level,
                                                 stats: EquipmentStats(),
                                                 pool: [species])
                XCTAssertGreaterThan(BaitSystem.attraction(species: species,
                                                           bait: bait,
                                                           context: context), 0,
                                     "\(species.name) nimmt \(bait.name) nicht")

                // Und die Zone muss es im Gewässer geben.
                let map: LakeMap
                if let cached = maps[water.id] {
                    map = cached
                } else {
                    map = LakeMap.generate(for: water)
                    maps[water.id] = map
                }
                XCTAssertNotNil(FishAI.randomPosition(in: habitat, map: map, attempts: 400),
                                "\(water.name) hat keine Zone \(habitat.rawValue)")

                // Die Zone muss auch groß genug sein, dass man sie findet.
                XCTAssertGreaterThanOrEqual(map.cellCount(of: habitat), 10,
                                            "\(water.name): Zone \(habitat.rawValue) ist zu klein "
                                            + "für einen Hinweis")
            }
        }
    }

    func testLegendIsAlwaysAnOutstandingSpecimen() {
        for seed in UInt64(1)...40 {
            guard let legend = roll(level: 14, seed: seed * 131),
                  let species = legend.species else { continue }
            XCTAssertGreaterThan(species.trophyFactor(forLength: legend.lengthCm), 0.9)
        }
    }

    func testEarlyLevelsStayAwayFromTheMonsters() {
        for seed in UInt64(1)...60 {
            guard let legend = roll(level: 6, seed: seed * 613),
                  let species = legend.species else { continue }
            XCTAssertLessThanOrEqual(species.rarity, .uncommon)
        }
    }

    func testBiteRulesRequireEverythingToMatch() {
        guard let legend = roll(level: 12, seed: 4711),
              let habitat = legend.habitat,
              let time = legend.timeOfDay else {
            return XCTFail("Keine Legende")
        }

        XCTAssertTrue(LegendSystem.acceptsBite(legend, habitat: habitat,
                                               timeOfDay: time, baitID: legend.baitID))

        let otherBait = legend.baitID == "worm" ? "corn" : "worm"
        XCTAssertFalse(LegendSystem.acceptsBite(legend, habitat: habitat,
                                                timeOfDay: time, baitID: otherBait))

        let otherTime: TimeOfDay = time == .night ? .day : .night
        XCTAssertFalse(LegendSystem.acceptsBite(legend, habitat: habitat,
                                                timeOfDay: otherTime, baitID: legend.baitID))

        let otherHabitat: Habitat = habitat == .deep ? .reeds : .deep
        XCTAssertFalse(LegendSystem.acceptsBite(legend, habitat: otherHabitat,
                                                timeOfDay: time, baitID: legend.baitID))
    }

    func testNamesAreStableAndReadable() {
        let pike = FishCatalog.species(id: "pike")!
        var first = SeededGenerator(seed: 99)
        var second = SeededGenerator(seed: 99)

        let a = LegendNames.name(for: pike, habitat: .reeds, using: &first)
        let b = LegendNames.name(for: pike, habitat: .reeds, using: &second)

        XCTAssertEqual(a, b)
        XCTAssertTrue(a.hasPrefix("Der ") || a.hasPrefix("Die ") || a.hasPrefix("Das "))
        XCTAssertGreaterThan(a.count, 8)
    }

    func testLegendaryFishFightsHarder() {
        let species = FishCatalog.species(id: "perch")!
        let normal = HookedFish(species: species, lengthCm: 40,
                                weightKg: species.weight(forLength: 40),
                                habitat: .reeds, baitID: "worm")
        let legend = HookedFish(species: species, lengthCm: 40,
                                weightKg: species.weight(forLength: 40),
                                habitat: .reeds, baitID: "worm",
                                legendName: "Der Stachelige Patrick")

        XCTAssertGreaterThan(legend.fightStrength, normal.fightStrength)
        XCTAssertTrue(legend.isLegendary)
        XCTAssertFalse(normal.isLegendary)
    }
}

final class WaterCatalogTests: XCTestCase {

    func testEveryWaterGeneratesFishableMap() {
        for water in WaterCatalog.all {
            let map = LakeMap.generate(for: water)

            XCTAssertEqual(map.columns, water.columns)
            XCTAssertEqual(map.rows, water.rows)

            // Jede Art des Gewässers braucht ihre Zone, sonst ist sie nicht
            // fangbar und der Fangbuch-Eintrag bleibt für immer leer.
            var found = Set<Habitat>()
            for cell in map.cells {
                if let habitat = cell.habitat { found.insert(habitat) }
            }
            for species in water.species {
                XCTAssertTrue(species.habitats.contains(where: found.contains),
                              "\(species.name) hat im \(water.name) keine Zone")
            }
        }
    }

    func testWadingWaterStartsOnLand() {
        for water in WaterCatalog.all where water.movement == .wading {
            let map = LakeMap.generate(for: water)
            XCTAssertTrue(map.isLand(at: map.startPosition),
                          "\(water.name): Start liegt im Wasser, aber es gibt kein Boot")
        }
    }

    func testSpeciesIDsExist() {
        for water in WaterCatalog.all {
            for id in water.speciesIDs {
                XCTAssertNotNil(FishCatalog.species(id: id),
                                "Unbekannte Art \(id) im \(water.name)")
            }
        }
    }
}

final class DayNightTests: XCTestCase {

    func testCycleReachesEveryPhase() {
        var system = DayNightSystem(startAt: 0)
        var seen = Set<String>()

        // Ein voller Tag in Schritten von einer Sekunde.
        for _ in 0..<Int(DayNightSystem.cycleLength) {
            system.update(deltaTime: 1)
            seen.insert(system.phase.rawValue)
        }

        for phase in TimeOfDay.allCases {
            XCTAssertTrue(seen.contains(phase.rawValue), "Phase fehlt: \(phase.rawValue)")
        }
    }

    func testDarknessStaysInRange() {
        var system = DayNightSystem(startAt: 0)
        for _ in 0..<600 {
            system.update(deltaTime: 1)
            XCTAssertGreaterThanOrEqual(system.darkness, 0)
            XCTAssertLessThanOrEqual(system.darkness, 1)
        }
    }
}
