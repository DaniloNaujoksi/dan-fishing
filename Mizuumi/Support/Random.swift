import Foundation

/// Deterministischer Zufallsgenerator (xorshift64*). Wird für die Karte und für
/// Tagesmissionen gebraucht: gleicher Seed, gleiches Ergebnis — sonst sähe der
/// See nach jedem Start anders aus.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // 0 ist ein Fixpunkt von xorshift, deshalb hier ausgeschlossen.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }

    /// Gleichverteilt in [0, 1).
    mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextUnit() * (range.upperBound - range.lowerBound)
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        guard range.upperBound > range.lowerBound else { return range.lowerBound }
        let span = range.upperBound - range.lowerBound + 1
        return range.lowerBound + Int(next() % UInt64(span))
    }
}

/// Kleine Hilfsfunktionen, die an mehreren Stellen gebraucht werden.
enum RandomHelper {

    /// Zieht einen Index anhand von Gewichten. Gibt nil zurück, wenn alle
    /// Gewichte 0 sind — der Aufrufer entscheidet dann, was passiert.
    static func weightedIndex(_ weights: [Double], using generator: inout SeededGenerator) -> Int? {
        let total = weights.reduce(0, +)
        guard total > 0 else { return nil }
        var roll = generator.nextUnit() * total
        for (index, weight) in weights.enumerated() {
            roll -= weight
            if roll <= 0 { return index }
        }
        return weights.indices.last
    }

    /// Variante mit dem Systemgenerator für alles, was nicht reproduzierbar
    /// sein muss (Bisse, Fischgrößen im laufenden Spiel).
    static func weightedIndex(_ weights: [Double]) -> Int? {
        let total = weights.reduce(0, +)
        guard total > 0 else { return nil }
        var roll = Double.random(in: 0..<total)
        for (index, weight) in weights.enumerated() {
            roll -= weight
            if roll <= 0 { return index }
        }
        return weights.indices.last
    }

    /// Dreiecksverteilung: Werte um `peak` sind am wahrscheinlichsten. Damit
    /// entstehen viele mittlere und wenige sehr große Fische.
    static func triangular(min lower: Double, max upper: Double, peak: Double) -> Double {
        guard upper > lower else { return lower }
        let clampedPeak = Swift.min(Swift.max(peak, lower), upper)
        let u = Double.random(in: 0..<1)
        let split = (clampedPeak - lower) / (upper - lower)
        if u < split {
            return lower + ((upper - lower) * (clampedPeak - lower) * u).squareRoot()
        } else {
            return upper - ((upper - lower) * (upper - clampedPeak) * (1 - u)).squareRoot()
        }
    }
}
