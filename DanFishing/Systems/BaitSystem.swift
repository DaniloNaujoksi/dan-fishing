import Foundation

/// Bewertet, wie interessant ein Köder für eine Fischart gerade ist.
///
/// Die Werte sind absichtlich mehrschichtig: Zone, Tageszeit, Vorliebe der Art,
/// Seltenheit und Ausrüstung greifen ineinander. Der Spieler sieht davon keine
/// Zahlen — er merkt nur, dass am Schilf mit Made ständig etwas beißt und der
/// Köderfisch im Tiefwasser die großen Räuber bringt.
enum BaitSystem {

    /// Bedingungen am Angelplatz.
    struct Context {
        let habitat: Habitat
        let timeOfDay: TimeOfDay
        let depth: Double
        let playerLevel: Int
        let stats: EquipmentStats
        /// Der Fischbestand dieses Gewässers. Im Teich steht hier eine kurze
        /// Liste, im See der ganze Katalog.
        var pool: [FishSpecies] = FishCatalog.all
    }

    /// Gewicht einer Art beim Auswürfeln. 0 = beißt hier gerade gar nicht.
    static func attraction(species: FishSpecies, bait: Bait, context: Context) -> Double {
        guard species.habitats.contains(context.habitat) else { return 0 }
        guard species.minPlayerLevel <= context.playerLevel else { return 0 }

        // Harte Regel vor allen Feinheiten: Ein Karpfen jagt keine Beutefische
        // und nimmt deshalb keinen Spinner, egal wie gut Platz und Uhrzeit
        // passen. Umgekehrt interessiert einen Hecht kein Maiskorn.
        guard bait.targets.contains(species.feeding) else { return 0 }

        // Manche Arten nehmen nur eine kurze Liste von Ködern, unabhängig von
        // ihrer Ernährungsgruppe.
        if let allowed = species.onlyBaitIDs, !allowed.contains(bait.id) { return 0 }

        // Zu großer Köder für zu kleines Maul.
        if let minimum = bait.minSpeciesLength, species.maxLength < minimum { return 0 }

        // Grundgewicht aus der Seltenheit, angehoben durch Glücksbringer und
        // die Seltenheitsneigung des Köders.
        let luckBoost = 1.0 + (context.stats.luck - 1.0) + bait.rarityBias * 0.8
        var score = species.rarity.spawnWeight * (species.rarity == .common ? 1.0 : luckBoost)

        // Tageszeit: außerhalb der aktiven Phase beißt kaum etwas.
        score *= species.activeTimes.contains(context.timeOfDay) ? 1.0 : 0.18

        // Der Köder ist genau auf diese Art abgestimmt — Fliege auf Äsche,
        // Köderfisch auf Zander, Wurmbündel auf Wels.
        if bait.specialty == species.id {
            score *= bait.specialtyBoost
        } else if species.preferredBaitIDs.contains(bait.id) {
            score *= 2.0
        } else if bait.kind == .artificial && species.feeding == .peaceful {
            // Friedfische nehmen Kunstköder allenfalls versehentlich.
            score *= 0.12
        } else {
            score *= 0.55
        }

        // Köder passt zur Zone bzw. zur Tageszeit.
        if bait.strongHabitats.contains(context.habitat) { score *= 1.35 }
        if bait.strongTimes.contains(context.timeOfDay) { score *= 1.20 }

        // Grundattraktivität des Köders.
        score *= 0.4 + bait.baseAppeal * 0.6

        // Fische, die schwerer sind, als die Rute tragen kann, zeigen sich
        // seltener — sonst reißt ständig die Schnur und das frustriert.
        if species.minWeight > context.stats.maxFishWeight {
            score *= 0.08
        }

        // Grobe Brocken schrecken Kleinfisch ab. Wer mit einem handtellergroßen
        // Blinker fischt, fängt keine Ukelei — dafür kommt vielleicht etwas,
        // das den halben Nachmittag kostet.
        if bait.sizeBias > 0.9 && species.maxLength < 70 {
            score *= 0.12
        }

        return max(0, score)
    }

    /// Alle Arten mit ihrem aktuellen Gewicht.
    static func candidates(bait: Bait, context: Context) -> [(species: FishSpecies, weight: Double)] {
        context.pool.compactMap { species in
            let weight = attraction(species: species, bait: bait, context: context)
            return weight > 0 ? (species, weight) : nil
        }
    }

    /// Wie lange es im Mittel bis zum Biss dauert (Sekunden). Guter Platz und
    /// guter Köder verkürzen die Wartezeit spürbar, aber nie auf null.
    static func averageBiteDelay(bait: Bait, context: Context) -> Double {
        let total = candidates(bait: bait, context: context)
            .reduce(0.0) { $0 + $1.weight }

        // Ohne passende Fische wartet man lange — das ist das Signal, den
        // Platz oder den Köder zu wechseln.
        guard total > 0 else { return 26 }

        let quality = min(total, 4.0) / 4.0
        let base = 15.0 - quality * 9.0
        return max(2.5, base / max(0.4, context.stats.biteChance))
    }
}
