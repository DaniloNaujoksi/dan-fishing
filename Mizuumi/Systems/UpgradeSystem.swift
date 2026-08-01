import Foundation

/// Rechnet gekaufte Upgrades in Spielwerte um und prüft Käufe.
enum UpgradeSystem {

    /// Ausrüstungswerte aus dem Spielstand. Grundwerte plus alle gekauften Stufen.
    static func stats(for data: SaveData) -> EquipmentStats {
        var stats = EquipmentStats()

        for track in UpgradeCatalog.all {
            let owned = data.upgradeLevels[track.id] ?? 0
            guard owned > 0 else { continue }
            for index in 0..<min(owned, track.levels.count) {
                stats.apply(track.levels[index].delta)
            }
        }
        return stats
    }

    enum PurchaseError: Error, Equatable {
        case unknownTrack
        case alreadyMaxed
        case notEnoughCoins(missing: Int)
    }

    /// Kauft die nächste Stufe einer Reihe. Verändert den Spielstand nur, wenn
    /// der Kauf wirklich möglich ist.
    @discardableResult
    static func purchase(trackID: String, data: inout SaveData) -> Result<UpgradeLevel, PurchaseError> {
        guard let track = UpgradeCatalog.track(id: trackID) else {
            return .failure(.unknownTrack)
        }
        let owned = data.upgradeLevels[trackID] ?? 0
        guard owned < track.levels.count else {
            return .failure(.alreadyMaxed)
        }
        let level = track.levels[owned]
        guard data.coins >= level.price else {
            return .failure(.notEnoughCoins(missing: level.price - data.coins))
        }

        data.coins -= level.price
        data.upgradeLevels[trackID] = owned + 1
        return .success(level)
    }

    /// Kauft einen Köder.
    @discardableResult
    static func buyBait(id: String, data: inout SaveData) -> Result<Bait, PurchaseError> {
        guard let bait = BaitCatalog.bait(id: id) else {
            return .failure(.unknownTrack)
        }
        guard !data.ownedBaitIDs.contains(id) else {
            return .failure(.alreadyMaxed)
        }
        guard data.coins >= bait.price else {
            return .failure(.notEnoughCoins(missing: bait.price - data.coins))
        }

        data.coins -= bait.price
        data.ownedBaitIDs.append(id)
        return .success(bait)
    }

    /// Köder, die im Laden sichtbar sind (Level erreicht und noch nicht gekauft).
    static func purchasableBaits(for data: SaveData) -> [Bait] {
        BaitCatalog.all.filter { bait in
            !data.ownedBaitIDs.contains(bait.id) && bait.unlockLevel <= data.level
        }
    }

    /// Köder in der Köderbox.
    static func ownedBaits(for data: SaveData) -> [Bait] {
        BaitCatalog.all.filter { data.ownedBaitIDs.contains($0.id) }
    }
}
