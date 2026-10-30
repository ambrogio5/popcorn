import SpriteKit
import UIKit

/// On-screen controls: a floating stick and a fire button per player, laid out along the bottom
/// edge. With two players the strip is split so each person gets their own corner of the screen.
final class TouchControls {
    let node = SKNode()

    private(set) var inputs: [PlayerInput] = [PlayerInput(), PlayerInput()]
    private var playerCount = 1
    private var stickZones: [CGRect] = []
    /// Where the stick base rests and where the fire button sits: near the thumbs, not necessarily
    /// in the middle of the touch zones.
    private var stickHomes: [CGPoint] = []
    private var fireHomes: [CGPoint] = []
    private var fireZones: [CGRect] = []
    private var stripRect: CGRect = .zero
    private var sceneSize: CGSize = .zero

    private var stickTouches: [ObjectIdentifier: (player: Int, origin: CGPoint)] = [:]
    private var fireTouches: [ObjectIdentifier: Int] = [:]

    private var stickBases: [SKShapeNode] = []
    private var stickKnobs: [SKShapeNode] = []
    private var fireButtons: [SKShapeNode] = []

    private static let deadZoneX: CGFloat = 10
    private static let deadZoneY: CGFloat = 18
    private static let stickReach: CGFloat = 46

    func input(for player: Int) -> PlayerInput { inputs[min(player, 1)] }

    func layout(strip: CGRect, playerCount: Int, sceneSize: CGSize) {
        self.playerCount = playerCount
        self.stripRect = strip
        self.sceneSize = sceneSize
        node.removeAllChildren()
        stickBases.removeAll()
        stickKnobs.removeAll()
        fireButtons.removeAll()
        stickZones.removeAll()
        fireZones.removeAll()

        if playerCount == 1 {
            let half = strip.width / 2
            stickZones = [CGRect(x: strip.minX, y: strip.minY, width: half, height: strip.height)]
            fireZones = [CGRect(x: strip.minX + half, y: strip.minY, width: half, height: strip.height)]
            // The zones are the two halves, but the hints stay within thumb reach of the edges on
            // a wide screen (110 pt in, like the two-player layout) instead of a quarter of the way.
            let reach = min(110, half / 2)
            stickHomes = [CGPoint(x: strip.minX + reach, y: strip.midY)]
            fireHomes = [CGPoint(x: strip.maxX - reach, y: strip.midY)]
        } else {
            let quarter = strip.width / 4
            stickZones = [CGRect(x: strip.minX, y: strip.minY, width: quarter, height: strip.height),
                          CGRect(x: strip.minX + 3 * quarter, y: strip.minY, width: quarter, height: strip.height)]
            fireZones = [CGRect(x: strip.minX + quarter, y: strip.minY, width: quarter, height: strip.height),
                         CGRect(x: strip.minX + 2 * quarter, y: strip.minY, width: quarter, height: strip.height)]
            stickHomes = stickZones.map { CGPoint(x: $0.midX, y: $0.midY) }
            fireHomes = fireZones.map { CGPoint(x: $0.midX, y: $0.midY) }
        }

        let divider = SKShapeNode(rect: CGRect(x: strip.minX, y: strip.maxY - 1, width: strip.width, height: 1))
        divider.fillColor = UIColor(white: 1, alpha: 0.12)
        divider.strokeColor = .clear
        node.addChild(divider)

        for p in 0..<playerCount {
            let tint = Palette.player(p)
            let baseRadius = min(44, strip.height * 0.3)
            let base = SKShapeNode(circleOfRadius: baseRadius)
            base.fillColor = UIColor(white: 1, alpha: 0.08)
            base.strokeColor = tint.withAlphaComponent(0.5)
            base.lineWidth = 2
            base.position = stickHomes[p]
            node.addChild(base)
            stickBases.append(base)

            let knob = SKShapeNode(circleOfRadius: baseRadius * 0.45)
            knob.fillColor = tint.withAlphaComponent(0.8)
            knob.strokeColor = .clear
            knob.position = base.position
            node.addChild(knob)
            stickKnobs.append(knob)

            let fire = SKShapeNode(circleOfRadius: baseRadius)
            fire.fillColor = tint.withAlphaComponent(0.22)
            fire.strokeColor = tint.withAlphaComponent(0.8)
            fire.lineWidth = 2
            fire.position = fireHomes[p]
            node.addChild(fire)
            fireButtons.append(fire)

            let label = SKLabelNode(fontNamed: Fonts.bold)
            label.text = String(localized: "FIRE")
            label.fontSize = baseRadius * 0.42
            label.fontColor = Palette.text
            label.verticalAlignmentMode = .center
            fire.addChild(label)

            if playerCount > 1 {
                let tag = SKLabelNode(fontNamed: Fonts.medium)
                tag.text = String(localized: "P\(p + 1)")
                tag.fontSize = 14
                tag.fontColor = tint
                tag.position = CGPoint(x: (stickZones[p].midX + fireZones[p].midX) / 2, y: strip.maxY - 16)
                node.addChild(tag)
            }
        }
    }

    // MARK: Touch routing

    func began(_ touch: UITouch, at p: CGPoint) {
        let key = ObjectIdentifier(touch)
        if let player = stickZones.firstIndex(where: { $0.contains(p) }) {
            stickTouches[key] = (player, p)
            stickBases[player].position = p
            stickKnobs[player].position = p
            return
        }
        if let player = fireZones.firstIndex(where: { $0.contains(p) }) {
            pressFire(player, key: key)
            return
        }
        // Anywhere else counts as fire for the player on that side, so you can play with a thumb
        // resting on the arena itself.
        let player = (playerCount > 1 && p.x > sceneSize.width / 2) ? 1 : 0
        pressFire(player, key: key)
    }

    private func pressFire(_ player: Int, key: ObjectIdentifier) {
        fireTouches[key] = player
        inputs[player].fire = true
        if fireButtons.indices.contains(player) {
            fireButtons[player].fillColor = Palette.player(player).withAlphaComponent(0.6)
        }
    }

    func moved(_ touch: UITouch, to p: CGPoint) {
        let key = ObjectIdentifier(touch)
        guard var stick = stickTouches[key] else { return }
        var d = CGPoint(x: p.x - stick.origin.x, y: p.y - stick.origin.y)
        let length = (d.x * d.x + d.y * d.y).squareRoot()
        if length > TouchControls.stickReach {
            // Drag the stick along so a change of direction is immediate.
            let scale = TouchControls.stickReach / length
            d = CGPoint(x: d.x * scale, y: d.y * scale)
            stick.origin = CGPoint(x: p.x - d.x, y: p.y - d.y)
            stickTouches[key] = stick
            stickBases[stick.player].position = stick.origin
        }
        inputs[stick.player].moveX = abs(d.x) > TouchControls.deadZoneX ? (d.x > 0 ? 1 : -1) : 0
        inputs[stick.player].moveY = abs(d.y) > TouchControls.deadZoneY ? (d.y > 0 ? 1 : -1) : 0
        stickKnobs[stick.player].position = CGPoint(x: stick.origin.x + d.x, y: stick.origin.y + d.y)
    }

    func ended(_ touch: UITouch) {
        let key = ObjectIdentifier(touch)
        if let stick = stickTouches.removeValue(forKey: key) {
            inputs[stick.player].moveX = 0
            inputs[stick.player].moveY = 0
            if stickHomes.indices.contains(stick.player) {
                let home = stickHomes[stick.player]
                stickBases[stick.player].run(.move(to: home, duration: 0.12))
                stickKnobs[stick.player].run(.move(to: home, duration: 0.12))
            }
        }
        if let player = fireTouches.removeValue(forKey: key) {
            if !fireTouches.values.contains(player) { inputs[player].fire = false }
            if fireButtons.indices.contains(player) {
                fireButtons[player].fillColor = Palette.player(player).withAlphaComponent(0.22)
            }
        }
    }

    func reset() {
        stickTouches.removeAll()
        fireTouches.removeAll()
        inputs = [PlayerInput(), PlayerInput()]
        for p in stickBases.indices {
            let home = stickHomes[p]
            stickBases[p].position = home
            stickKnobs[p].position = home
        }
    }
}
