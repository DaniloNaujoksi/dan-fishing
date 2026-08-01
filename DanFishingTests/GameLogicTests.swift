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

final class CatchMiniGameTests: XCTestCase {

    private func fish(_ id: String, length: Double) -> HookedFish {
        let species = FishCatalog.species(id: id)!
        return HookedFish(species: species,
                          lengthCm: length,
                          weightKg: species.weight(forLength: length),
                          habitat: species.habitats[0],
                          baitID: species.preferredBaitIDs[0])
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

    func testMissionsAreStableForTheSameDay() {
        let day = MissionSystem.dayStart(for: Date(timeIntervalSince1970: 1_700_000_000))
        let first = MissionSystem.missions(for: day, playerLevel: 3)
        let second = MissionSystem.missions(for: day, playerLevel: 3)

        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertFalse(first.isEmpty)
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

    func testNearestWaterLeavesLand() {
        let map = LakeMap.generate()
        let land = CGPoint(x: 20, y: 20)   // Ecke ist immer Ufer
        let rescued = map.nearestWater(from: land)
        XCTAssertFalse(map.isLand(at: rescued))
    }
}

final class BoatControllerTests: XCTestCase {

    func testBoatMovesWithInput() {
        let map = LakeMap.generate()
        var boat = BoatController(position: map.startPosition, heading: 0)
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
        var boat = BoatController(position: map.startPosition, heading: 0)

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
        let difference = BoatController.angleDifference(3.0, -3.0)
        XCTAssertLessThan(abs(difference), .pi)
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
