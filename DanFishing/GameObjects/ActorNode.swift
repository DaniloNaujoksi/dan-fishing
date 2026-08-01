import SpriteKit

/// Die Spielfigur auf der Karte.
///
/// Am See sitzt Dan im Ruderboot, am Gebirgsbach steht er im Wasser. Für die
/// Szene ist beides dasselbe: etwas, das sich dreht, eine Rutenspitze hat und
/// sich je nach Anstrengung bewegt. Alles Weitere bleibt im jeweiligen Knoten.
protocol ActorNode: SKNode {

    /// Spitze der Rute in Weltkoordinaten — dort beginnt die Schnur.
    var rodTipPosition: CGPoint { get }

    /// Macht die gekaufte Ausrüstung sichtbar (Bootsausbau bzw. Wathose).
    func applyUpgrade(level: Int)

    /// Ein Frame.
    /// - Parameter effort: 0…1 — wie kräftig gerade gerudert oder gelaufen wird.
    func update(deltaTime: CGFloat, effort: CGFloat, speed: CGFloat)

    /// Haltung der Rute. `direction` zeigt in Weltkoordinaten dorthin, wo die
    /// Schnur hinläuft; nil ist Ruhestellung.
    func setCastPose(_ power: CGFloat?, direction: CGVector?, heading: CGFloat)
}
