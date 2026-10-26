import SpriteKit

/// Short generated sounds (see Tools/generate_audio.py). Pops rise in pitch with the combo.
final class SoundBank {
    static let shared = SoundBank()

    private var actions: [String: SKAction] = [:]

    private init() {
        let names = ["fire", "hit", "pickup", "clear", "over", "click", "armor", "lightning", "freeze", "shield", "block"]
            + (0..<8).map { "pop\($0)" }
        for name in names where Bundle.main.url(forResource: name, withExtension: "wav") != nil {
            actions[name] = SKAction.playSoundFileNamed("\(name).wav", waitForCompletion: false)
        }
    }

    func play(_ name: String, on node: SKNode) {
        guard Progress.shared.soundEnabled, let action = actions[name] else { return }
        node.run(action)
    }

    func pop(combo: Int, on node: SKNode) {
        play("pop\(min(max(combo - 1, 0), 7))", on: node)
    }
}
