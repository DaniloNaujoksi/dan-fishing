import SpriteKit

/// Ein sichtbarer Fisch im See. Unter Wasser sieht man ihn als weiche
/// Silhouette; je flacher das Wasser, desto deutlicher.
final class FishNode: SKNode {

    private(set) var swimmer: FishAI.Swimmer
    private let sprite = SKSpriteNode()
    private let ripple = SKShapeNode(circleOfRadius: 10)
    private var rippleTimer: CGFloat = 0

    init(swimmer: FishAI.Swimmer, species: FishSpecies) {
        self.swimmer = swimmer
        super.init()

        if let texture = TextureFactory.fishBody(body: species.bodyColor.skColor,
                                                 belly: species.bellyColor.skColor,
                                                 fin: species.finColor.skColor,
                                                 key: species.id) {
            sprite.texture = texture
            sprite.size = CGSize(width: 60 * swimmer.scale, height: 27 * swimmer.scale)
        }
        sprite.alpha = 0.55
        addChild(sprite)

        ripple.strokeColor = SKColor(white: 1, alpha: 0.35)
        ripple.fillColor = .clear
        ripple.lineWidth = 1.5
        ripple.alpha = 0
        ripple.zPosition = 1
        addChild(ripple)

        position = swimmer.position
        zRotation = swimmer.heading
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) wird nicht verwendet")
    }

    func update(deltaTime: CGFloat, map: LakeMap, lure: CGPoint?, interest: CGFloat) {
        FishAI.update(&swimmer, deltaTime: deltaTime, map: map, lure: lure, interest: interest)
        position = swimmer.position

        // Die Silhouette dreht sich weich mit, statt hart zu springen.
        zRotation = BoatController.turn(from: zRotation, to: swimmer.heading, maxStep: deltaTime * 3)

        // Flaches Wasser: besser zu sehen. Tiefes Wasser: nur ein Schemen.
        let depth = map.depth(at: swimmer.position)
        let visibility = max(0.18, 0.75 - CGFloat(depth) * 0.08)
        sprite.alpha = visibility + swimmer.attraction * 0.2

        // Ab und zu ein Ring an der Oberfläche.
        rippleTimer -= deltaTime
        if rippleTimer <= 0 {
            rippleTimer = CGFloat.random(in: 3...9)
            showRipple()
        }
    }

    private func showRipple() {
        ripple.removeAllActions()
        ripple.setScale(0.3)
        ripple.alpha = 0.45
        ripple.run(.group([
            .scale(to: 1.8, duration: 1.6),
            .fadeOut(withDuration: 1.6)
        ]))
    }
}
