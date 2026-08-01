import Foundation

/// Sehr kleines Wertrauschen. Reicht völlig, um Uferlinien und Zonen weich
/// ausfransen zu lassen, und kommt ohne zusätzliche Abhängigkeit aus.
struct ValueNoise {
    private let seed: UInt64

    init(seed: UInt64) {
        self.seed = seed
    }

    private func hash(_ x: Int, _ y: Int) -> Double {
        var h = UInt64(bitPattern: Int64(x &* 374_761_393 &+ y &* 668_265_263))
        h ^= seed &* 0x9E3779B97F4A7C15
        h ^= h >> 13
        h = h &* 1_274_126_177
        h ^= h >> 16
        return Double(h & 0xFFFFFF) / Double(0xFFFFFF)
    }

    private func smooth(_ t: Double) -> Double {
        t * t * (3 - 2 * t)
    }

    /// Wert in [0, 1] an einer beliebigen Stelle.
    func value(_ x: Double, _ y: Double) -> Double {
        let xi = Int(floor(x))
        let yi = Int(floor(y))
        let xf = smooth(x - floor(x))
        let yf = smooth(y - floor(y))

        let v00 = hash(xi, yi)
        let v10 = hash(xi + 1, yi)
        let v01 = hash(xi, yi + 1)
        let v11 = hash(xi + 1, yi + 1)

        let top = v00 + (v10 - v00) * xf
        let bottom = v01 + (v11 - v01) * xf
        return top + (bottom - top) * yf
    }

    /// Mehrere Oktaven übereinander — gibt der Uferlinie feinere Details.
    func fractal(_ x: Double, _ y: Double, octaves: Int = 3) -> Double {
        var total = 0.0
        var amplitude = 1.0
        var frequency = 1.0
        var normalisation = 0.0

        for _ in 0..<max(1, octaves) {
            total += value(x * frequency, y * frequency) * amplitude
            normalisation += amplitude
            amplitude *= 0.5
            frequency *= 2.0
        }
        return total / max(normalisation, 0.0001)
    }
}
