import SpriteKit
import SwiftUI

/// Brücke zwischen der Datenschicht (`ColorSpec`, nur Zahlen) und den beiden
/// Darstellungsschichten SpriteKit und SwiftUI.
extension ColorSpec {
    var skColor: SKColor {
        SKColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
    }

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue)
    }

    func skColor(alpha: CGFloat) -> SKColor {
        SKColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: alpha)
    }
}

/// Die Farbwelt des Spiels an einer Stelle. Gedämpfte Naturtöne, wie sie auf
/// gealtertem Papier wirken — kein reines Weiß und kein reines Schwarz.
enum Palette {
    static let paper = ColorSpec(0xF2EADB)
    static let paperDeep = ColorSpec(0xE4D8C3)
    static let ink = ColorSpec(0x2C2A26)
    static let inkSoft = ColorSpec(0x5B564C)
    static let vermilion = ColorSpec(0xBD5A3F)
    static let moss = ColorSpec(0x6B7C52)
    static let water = ColorSpec(0x5E8C9E)
    static let waterDeep = ColorSpec(0x2E5468)
    static let waterShallow = ColorSpec(0x8FB6BE)
    static let reed = ColorSpec(0x7C8B4E)
    static let lily = ColorSpec(0x557A50)
    static let sand = ColorSpec(0xD8C7A2)
    static let stone = ColorSpec(0x8E8B82)
    static let maple = ColorSpec(0xC4573A)
    static let pine = ColorSpec(0x4A6149)
    static let blossom = ColorSpec(0xE9BFC6)
    static let gold = ColorSpec(0xC8A24A)

    /// Papierfarbe für Flächen der Oberfläche.
    static var uiPaper: Color { paper.swiftUIColor }
    static var uiInk: Color { ink.swiftUIColor }
    static var uiAccent: Color { vermilion.swiftUIColor }
}

/// Farbe der Seltenheitsstufe — im Fangbuch und in der Fangkarte.
extension Rarity {
    var tint: Color {
        switch self {
        case .common: return Palette.inkSoft.swiftUIColor
        case .uncommon: return Palette.moss.swiftUIColor
        case .rare: return Palette.water.swiftUIColor
        case .veryRare: return Palette.vermilion.swiftUIColor
        case .legendary: return Palette.gold.swiftUIColor
        case .monster: return ColorSpec(0xA8382C).swiftUIColor
        }
    }
}
