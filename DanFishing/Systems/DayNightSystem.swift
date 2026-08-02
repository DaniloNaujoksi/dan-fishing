import Foundation

/// Tageszeit im Spiel. Ein voller Zyklus dauert acht Minuten — lang genug, um
/// eine Stimmung zu tragen, kurz genug, um Nachtfische nicht zu verstecken.
struct DayNightSystem {

    /// Länge eines kompletten Tages in Sekunden.
    static let cycleLength: Double = 480

    /// 0…1 über den Tag. 0 = Mitternacht, 0.25 = Morgen, 0.5 = Mittag.
    private(set) var normalizedTime: Double

    init(startAt normalized: Double = 0.22) {
        self.normalizedTime = min(max(normalized, 0), 1)
    }

    /// - Returns: true, wenn dabei ein neuer Tag angebrochen ist. Daran hängen
    ///   die Fristen der legendären Fische.
    @discardableResult
    mutating func update(deltaTime: Double) -> Bool {
        normalizedTime += deltaTime / DayNightSystem.cycleLength
        var wrapped = false
        while normalizedTime >= 1 {
            normalizedTime -= 1
            wrapped = true
        }
        return wrapped
    }

    /// Die Dämmerungen sind bewusst etwas länger als astronomisch richtig:
    /// Viele Fische beißen nur dann, und eine Minute pro Zyklus war zu wenig,
    /// um überhaupt einen Wurf anzubringen.
    var phase: TimeOfDay {
        switch normalizedTime {
        case 0.16..<0.32: return .dawn
        case 0.32..<0.66: return .day
        case 0.66..<0.82: return .dusk
        default: return .night
        }
    }

    /// 0 = taghell, 1 = tiefe Nacht. Die Szene legt damit ihren Farbschleier an.
    var darkness: Double {
        switch normalizedTime {
        case ..<0.16:
            return 1.0
        case 0.16..<0.32:
            return 1.0 - (normalizedTime - 0.16) / 0.16
        case 0.32..<0.66:
            return 0.0
        case 0.66..<0.82:
            return (normalizedTime - 0.66) / 0.16
        default:
            return 1.0
        }
    }

    /// Wärme des Lichts: 1 bei Sonnenauf- und -untergang, 0 sonst.
    var warmth: Double {
        switch phase {
        case .dawn, .dusk:
            return 1.0 - abs(darkness - 0.5) * 2.0
        default:
            return 0
        }
    }

    /// Uhrzeit als Text für die Anzeige.
    var clockText: String {
        let minutes = Int(normalizedTime * 24 * 60)
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// Farbe des Wassers zur aktuellen Zeit.
    var waterColor: ColorSpec {
        blend(from: ColorSpec(0x5E8C9E), to: ColorSpec(0x16283A), amount: darkness,
              warmTint: ColorSpec(0x9A8478), warmth: warmth)
    }

    /// Farbe des Himmels bzw. des Nebels über dem Wasser.
    var skyColor: ColorSpec {
        blend(from: ColorSpec(0xD9E4E2), to: ColorSpec(0x1E2C3E), amount: darkness,
              warmTint: ColorSpec(0xE8B48A), warmth: warmth)
    }

    private func blend(from light: ColorSpec, to dark: ColorSpec, amount: Double,
                       warmTint: ColorSpec, warmth: Double) -> ColorSpec {
        let t = min(max(amount, 0), 1)
        var r = light.red + (dark.red - light.red) * t
        var g = light.green + (dark.green - light.green) * t
        var b = light.blue + (dark.blue - light.blue) * t

        let w = min(max(warmth, 0), 1) * 0.45
        r += (warmTint.red - r) * w
        g += (warmTint.green - g) * w
        b += (warmTint.blue - b) * w

        let hex = (UInt32(min(max(r, 0), 1) * 255) << 16)
            | (UInt32(min(max(g, 0), 1) * 255) << 8)
            | UInt32(min(max(b, 0), 1) * 255)
        return ColorSpec(hex)
    }
}
