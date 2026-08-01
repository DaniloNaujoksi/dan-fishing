import Combine
import CoreGraphics
import Foundation
import UIKit

/// Momentaufnahme des Fang-Minispiels für die Oberfläche. Die Oberfläche
/// bekommt bewusst nur Zahlen, keine Referenz auf die Logik.
struct MiniGameSnapshot: Equatable {
    var fishPosition: Double = 0.5
    var barLower: Double = 0.2
    var barUpper: Double = 0.4
    var tension: Double = 0
    var progress: Double = 0
    var isFishInBar: Bool = false
    var speciesName: String = ""
    var isTensionCritical: Bool = false
}

/// Kurzer Hinweis, der über dem Spielfeld eingeblendet wird.
struct GameToast: Equatable, Identifiable {
    let id = UUID()
    let text: String
    let emphasis: Bool
}

/// Bindeglied zwischen SpriteKit-Szene, Oberfläche und Spielstand.
///
/// Die Szene liest hier die Eingaben ab und meldet Ereignisse zurück; SwiftUI
/// beobachtet die veröffentlichten Werte. Dadurch kennt keine der beiden
/// Seiten die andere.
///
/// Alle Zugriffe passieren auf dem Hauptthread: SwiftUI arbeitet dort ohnehin,
/// und die SpriteKit-Schleife läuft ebenfalls auf dem Hauptthread.
final class GameSession: ObservableObject {

    // MARK: - Bildschirme

    enum Screen: Equatable {
        case intro
        case menu
        case playing
    }

    @Published var screen: Screen = .menu

    /// Vorspann beendet oder übersprungen.
    func finishIntro() {
        if !save.introSeen {
            save.introSeen = true
            persist()
        }
        screen = .menu
    }

    /// Vorspann noch einmal ansehen.
    func replayIntro() {
        screen = .intro
    }

    // MARK: - Spielstand

    @Published private(set) var save: SaveData
    @Published private(set) var stats: EquipmentStats
    @Published private(set) var missions: [Mission] = []

    private let saveManager: SaveGameManager

    // MARK: - Eingaben für die Szene

    /// Joystick, Länge 0…1.
    var joystick: CGVector = .zero
    /// Ziel für das Antippen-Rudern; die Szene setzt es zurück auf nil.
    var tapTarget: CGPoint?
    /// true, solange im Drill die Einholtaste gehalten wird.
    var isReeling = false

    // MARK: - Zustand für die Oberfläche

    @Published private(set) var fishingPhase: FishingSystem.Phase = .idle
    @Published private(set) var castPower: Double = 0
    @Published private(set) var timeOfDay: TimeOfDay = .day
    @Published private(set) var clockText: String = "07:00"
    @Published private(set) var depthText: String = "–"
    @Published private(set) var habitatText: String = "–"
    @Published private(set) var activityScore: Double = 0

    @Published private(set) var miniGame: MiniGameSnapshot?
    @Published private(set) var pendingCatch: CatchResult?

    /// Art, die gerade zum ersten Mal gefangen wurde. Trägt die Einblendung
    /// mit Fanfare; sie blendet sich nach kurzer Zeit selbst aus.
    @Published private(set) var discoveredSpecies: FishSpecies?
    /// Entdeckerbonus, der zu dieser Einblendung gehört.
    @Published private(set) var discoveryBonus: Int = 0
    /// Aktueller Tutorialschritt, oder nil wenn keiner läuft.
    @Published private(set) var tutorialStep: TutorialStep?

    /// Stand für die Minimap. Wird ein paar Mal pro Sekunde aufgefrischt —
    /// öfter wäre für eine Karte in Daumennagelgröße verschwendete Arbeit.
    @Published private(set) var minimap: MinimapState?
    /// Das Kartenbild selbst. Einmal erzeugt und danach unverändert, deshalb
    /// bewusst nicht veröffentlicht.
    private(set) var minimapImage: UIImage?

    struct MinimapState: Equatable {
        var boat: CGPoint
        var heading: CGFloat
        var lure: CGPoint?
        var worldSize: CGSize
    }

    func setMinimapImage(_ image: UIImage, worldSize: CGSize) {
        minimapImage = image
        minimap = MinimapState(boat: .zero, heading: 0, lure: nil, worldSize: worldSize)
    }

    func updateMinimap(boat: CGPoint, heading: CGFloat, lure: CGPoint?) {
        guard var state = minimap else { return }
        state.boat = boat
        state.heading = heading
        state.lure = lure
        if state != minimap { minimap = state }
    }
    @Published private(set) var completedMissions: [Mission] = []
    @Published private(set) var toast: GameToast?

    /// Aktuell gewählter Köder.
    var selectedBait: Bait {
        BaitCatalog.bait(id: save.selectedBaitID)
            ?? BaitCatalog.bait(id: "worm")
            ?? BaitCatalog.all[0]
    }

    var ownedBaits: [Bait] { UpgradeSystem.ownedBaits(for: save) }

    // MARK: - Interne Systeme

    private var fight: CatchMiniGame?
    private var toastTimer: Timer?
    private var discoveryTimer: Timer?
    private var lastReelTick: Double = 0
    private var tutorial = TutorialSystem(active: false)

    init(saveManager: SaveGameManager = .shared) {
        self.saveManager = saveManager
        let loaded = saveManager.load() ?? SaveData.newGame()
        self.save = loaded
        self.stats = UpgradeSystem.stats(for: loaded)
        refreshMissions()
        applySettingsToManagers()

        // Beim allerersten Start läuft der Vorspann.
        if !loaded.introSeen {
            screen = .intro
        }

        // Startschalter für automatisierte Läufe: Damit springt die App am
        // Menü vorbei direkt auf den See, sodass die Szene selbst geprüft
        // werden kann. Im normalen Betrieb ist das Argument nie gesetzt.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-autostart") {
            screen = .playing
        } else if arguments.contains("-showIntro") {
            screen = .intro
        }
    }

    var hasExistingSave: Bool { saveManager.hasSave }

    // MARK: - Spielstart

    func continueGame() {
        if let loaded = saveManager.load() {
            save = loaded
            stats = UpgradeSystem.stats(for: loaded)
        }
        refreshMissions()
        applySettingsToManagers()
        startTutorialIfNeeded()
        screen = .playing
    }

    func startNewGame() {
        save = SaveData.newGame()
        stats = UpgradeSystem.stats(for: save)
        saveManager.save(save)
        refreshMissions()
        applySettingsToManagers()
        startTutorialIfNeeded()
        screen = .playing
    }

    // MARK: - Tutorial

    private func startTutorialIfNeeded() {
        tutorial = TutorialSystem(active: !save.tutorialDone)
        tutorialStep = tutorial.step
    }

    /// Wird aus der Spielschleife aufgerufen.
    func updateTutorial(deltaTime: TimeInterval) {
        guard tutorial.isRunning else { return }
        tutorial.update(deltaTime: deltaTime)
        syncTutorial()
    }

    func reportTutorial(_ trigger: TutorialTrigger) {
        guard tutorial.isRunning else { return }
        tutorial.report(trigger)
        syncTutorial()
    }

    func skipTutorial() {
        tutorial.skip()
        syncTutorial()
    }

    private func syncTutorial() {
        if tutorialStep != tutorial.step {
            tutorialStep = tutorial.step

            // Durchgelaufen: nicht noch einmal zeigen.
            if tutorial.step == nil && !save.tutorialDone {
                save.tutorialDone = true
                persist()
            }
        }
    }

    func returnToMenu() {
        persist()
        screen = .menu
    }

    func persist() {
        saveManager.save(save)
    }

    // MARK: - Einstellungen

    func setMusic(_ enabled: Bool) {
        save.settings.music = enabled
        applySettingsToManagers()
        persist()
    }

    func setEffects(_ enabled: Bool) {
        save.settings.sfx = enabled
        applySettingsToManagers()
        persist()
    }

    func setHaptics(_ enabled: Bool) {
        save.settings.haptics = enabled
        applySettingsToManagers()
        persist()
    }

    func setDepthHint(_ enabled: Bool) {
        save.settings.showDepthHint = enabled
        persist()
    }

    private func applySettingsToManagers() {
        AudioManager.shared.apply(settings: save.settings)
        HapticManager.shared.apply(settings: save.settings)
    }

    // MARK: - Köder, Laden, Missionen

    func selectBait(_ bait: Bait) {
        guard save.ownedBaitIDs.contains(bait.id) else { return }
        save.selectedBaitID = bait.id
        HapticManager.shared.selection()
        AudioManager.shared.play(.uiTap)
        persist()
    }

    @discardableResult
    func buyBait(_ bait: Bait) -> Bool {
        switch UpgradeSystem.buyBait(id: bait.id, data: &save) {
        case .success:
            AudioManager.shared.play(.uiTap)
            HapticManager.shared.success()
            persist()
            return true
        case .failure:
            HapticManager.shared.failure()
            return false
        }
    }

    @discardableResult
    func buyUpgrade(_ track: UpgradeTrack) -> Bool {
        switch UpgradeSystem.purchase(trackID: track.id, data: &save) {
        case .success(let level):
            stats = UpgradeSystem.stats(for: save)
            AudioManager.shared.play(.uiTap)
            HapticManager.shared.success()
            showToast("\(track.name): \(level.title)")
            persist()
            return true
        case .failure:
            HapticManager.shared.failure()
            return false
        }
    }

    func upgradeLevel(for track: UpgradeTrack) -> Int {
        save.upgradeLevels[track.id] ?? 0
    }

    func refreshMissions() {
        missions = MissionSystem.refreshIfNeeded(data: &save)
    }

    func claim(mission: Mission) {
        guard MissionSystem.claim(mission: mission, data: &save) else { return }
        stats = UpgradeSystem.stats(for: save)
        AudioManager.shared.play(.catchSmall)
        HapticManager.shared.success()
        showToast("Belohnung erhalten: \(mission.rewardCoins) Münzen")

        // Waren das die letzten offenen Aufgaben, steht sofort die nächste
        // Staffel bereit — kein Warten auf den nächsten Tag.
        let previousSet = save.missionSet
        refreshMissions()
        if save.missionSet > previousSet {
            showToast("Neue Aufgaben verfügbar", emphasis: true)
        }
        persist()
    }

    func progress(for mission: Mission) -> MissionProgress {
        MissionSystem.progress(for: mission, in: save)
    }

    // MARK: - Anbindung der Szene

    /// Die Szene meldet jeden Frame ihre Umgebungswerte.
    func updateEnvironment(timeOfDay: TimeOfDay,
                           clock: String,
                           depth: Double,
                           habitat: Habitat?,
                           activity: Double) {
        if self.timeOfDay != timeOfDay { self.timeOfDay = timeOfDay }
        if clockText != clock { clockText = clock }

        let newDepth = depth > 0.05 ? String(format: "%.1f m", depth) : "–"
        if depthText != newDepth { depthText = newDepth }

        let newHabitat = habitat?.displayName ?? "Ufer"
        if habitatText != newHabitat { habitatText = newHabitat }

        if abs(activityScore - activity) > 0.02 { activityScore = activity }
    }

    func updateFishingState(phase: FishingSystem.Phase, castPower: Double) {
        if fishingPhase != phase { fishingPhase = phase }
        if abs(self.castPower - castPower) > 0.01 { self.castPower = castPower }
    }

    /// Ereignisse der Angel-Zustandsmaschine.
    func handle(event: FishingSystem.Event) {
        switch event {
        case .castLanded:
            AudioManager.shared.play(.splash)
            reportTutorial(.castLanded)
        case .castFailed:
            showToast("Da ist Land — flacher werfen.")
            HapticManager.shared.failure()
        case .nibble:
            AudioManager.shared.play(.reel)
            HapticManager.shared.reelTick()
        case .bite:
            AudioManager.shared.play(.bite)
            HapticManager.shared.bite()
            reportTutorial(.bite)
        case .missedStrike:
            showToast("Zu spät — der Köder ist weg.")
        case .slippedOff:
            showToast("Der Haken hat nicht gefasst.")
            HapticManager.shared.failure()
        case .hooked(let fish):
            reportTutorial(.hooked)
            beginFight(with: fish)
        case .reeledIn:
            break
        }
    }

    // MARK: - Drill

    private func beginFight(with fish: HookedFish) {
        fight = CatchMiniGame(fish: fish, stats: stats)
        miniGame = snapshot(from: fight)
        AudioManager.shared.play(.reel)
        HapticManager.shared.prepare()
    }

    /// Wird von der Szene im Takt der Spielschleife aufgerufen.
    /// - Returns: true, wenn der Drill noch läuft.
    @discardableResult
    func updateFight(deltaTime: Double) -> Bool {
        guard var current = fight else { return false }

        current.update(deltaTime: deltaTime, reeling: isReeling)
        fight = current
        miniGame = snapshot(from: current)

        if current.isTensionCritical {
            HapticManager.shared.tensionWarning()
        }

        // Leises Ticken der Rolle, solange Fortschritt entsteht.
        if current.isFishInBar {
            lastReelTick += deltaTime
            if lastReelTick > 0.35 {
                lastReelTick = 0
                AudioManager.shared.play(.reel)
            }
        }

        switch current.outcome {
        case .running:
            return true
        case .landed:
            finishFight(landed: true, fish: current.fish)
            return false
        case .lineSnapped:
            AudioManager.shared.play(.lineSnap)
            HapticManager.shared.failure()
            showToast("Die Schnur ist gerissen.")
            finishFight(landed: false, fish: current.fish)
            return false
        case .fishEscaped:
            HapticManager.shared.failure()
            showToast("Der Fisch ist ausgeschlitzt.")
            finishFight(landed: false, fish: current.fish)
            return false
        }
    }

    var isFightRunning: Bool { fight != nil }

    private func finishFight(landed: Bool, fish: HookedFish) {
        fight = nil
        miniGame = nil
        isReeling = false
        reportTutorial(landed ? .fishLanded : .lineLost)

        guard landed else { return }

        let result = registerCatch(fish)
        pendingCatch = result

        AudioManager.shared.play(fish.isTrophy || fish.species.rarity >= .rare ? .catchBig : .catchSmall)
        HapticManager.shared.success()
    }

    /// Trägt den Fang in Fangbuch, Missionen und Erfahrung ein. Münzen gibt es
    /// erst, wenn der Spieler sich für „verkaufen“ entscheidet.
    private func registerCatch(_ fish: HookedFish) -> CatchResult {
        let speciesID = fish.species.id
        var entry = save.codex[speciesID] ?? CodexEntry()
        let isNew = entry.count == 0
        let isRecord = fish.lengthCm > entry.longestCm

        entry.count += 1
        entry.longestCm = max(entry.longestCm, fish.lengthCm)
        entry.heaviestKg = max(entry.heaviestKg, fish.weightKg)
        if !entry.baitIDs.contains(fish.baitID) { entry.baitIDs.append(fish.baitID) }
        if !entry.habitatIDs.contains(fish.habitat.rawValue) { entry.habitatIDs.append(fish.habitat.rawValue) }
        if entry.firstCaught == nil { entry.firstCaught = Date() }
        save.codex[speciesID] = entry
        save.totalCatches += 1

        let xp = EconomySystem.experience(for: fish, isNewSpecies: isNew, isRecord: isRecord)

        // Erst den Grundwert, dann die Zuschläge für neue Art, Rekord und
        // Trophäengröße.
        var coins = EconomySystem.coinValue(for: fish)
        var result = CatchResult(fish: fish,
                                 coins: coins,
                                 experience: xp,
                                 isNewSpecies: isNew,
                                 isPersonalRecord: isRecord)
        coins += EconomySystem.bonusCoins(for: result)
        result = CatchResult(fish: fish,
                             coins: coins,
                             experience: xp,
                             isNewSpecies: isNew,
                             isPersonalRecord: isRecord)

        // Jeder Fang zahlt sofort aus. Vorher musste man erst zwischen drei
        // Knöpfen wählen, von denen zwei nichts bewirkten.
        save.coins += coins

        let levels = EconomySystem.applyExperience(xp, to: &save)
        if levels > 0 {
            showToast("Stufe \(save.level) erreicht", emphasis: true)
        }

        // Neue Art: eigene Einblendung mit Fanfare, bevor die Fangkarte
        // übernimmt.
        if isNew {
            celebrateDiscovery(of: fish.species)
        }

        completedMissions = MissionSystem.apply(result: result,
                                                timeOfDay: timeOfDay,
                                                missions: missions,
                                                data: &save)
        stats = UpgradeSystem.stats(for: save)
        persist()
        return result
    }

    /// Zeigt die Entdeckung einer Art und blendet sie nach knapp drei
    /// Sekunden wieder aus.
    private func celebrateDiscovery(of species: FishSpecies) {
        discoveredSpecies = species
        discoveryBonus = EconomySystem.newSpeciesBonus

        AudioManager.shared.play(.discovery)
        HapticManager.shared.success()

        discoveryTimer?.invalidate()
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: false) { [weak self] _ in
            self?.discoveredSpecies = nil
        }
    }

    // MARK: - Entscheidung nach dem Fang

    /// Karte wegtippen. Münzen und Erfahrung sind beim Fang bereits
    /// gutgeschrieben — die Karte zeigt nur noch, was es gab.
    func dismissCatch() {
        guard pendingCatch != nil else { return }
        pendingCatch = nil
        clearCompletedMissions()
        AudioManager.shared.play(.uiTap)
        persist()
    }

    // MARK: - Bootsposition

    func rememberBoatPosition(_ point: CGPoint) {
        save.setBoatPosition(point, for: currentWater.id)
    }

    var storedBoatPosition: CGPoint? {
        save.boatPosition(for: currentWater.id)
    }

    // MARK: - Gewässer

    /// Das Gewässer, an dem gerade geangelt wird.
    var currentWater: Water {
        WaterCatalog.water(id: save.currentWaterID) ?? WaterCatalog.starter
    }

    /// Gewässer, die der Spielstand freigeschaltet hat.
    var unlockedWaters: [Water] {
        WaterCatalog.unlocked(for: save.level)
    }

    /// Wechselt das Gewässer. Die Szene wird danach neu aufgebaut.
    func selectWater(_ water: Water) {
        guard water.requiredLevel <= save.level else { return }
        guard water.id != save.currentWaterID else { return }

        save.currentWaterID = water.id
        persist()
        HapticManager.shared.selection()
    }

    // MARK: - Hinweise

    func showToast(_ text: String, emphasis: Bool = false) {
        toast = GameToast(text: text, emphasis: emphasis)
        toastTimer?.invalidate()
        toastTimer = Timer.scheduledTimer(withTimeInterval: 2.4, repeats: false) { [weak self] _ in
            self?.toast = nil
        }
    }

    func clearCompletedMissions() {
        completedMissions = []
    }

    private func snapshot(from game: CatchMiniGame?) -> MiniGameSnapshot? {
        guard let game else { return nil }
        return MiniGameSnapshot(fishPosition: game.fishPosition,
                                barLower: game.barLowerEdge,
                                barUpper: game.barUpperEdge,
                                tension: game.tension,
                                progress: game.progress,
                                isFishInBar: game.isFishInBar,
                                speciesName: game.fish.species.name,
                                isTensionCritical: game.isTensionCritical)
    }
}
