import SpriteKit
import UIKit

/// Shared plumbing for every scene: safe-area aware layout, size-change handling (which is how a
/// fold or unfold reaches us), transitions, and simple button helpers.
class BaseScene: SKScene {
    private(set) var isSetUp = false

    var safeInsets: UIEdgeInsets { view?.safeAreaInsets ?? .zero }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = .black
        if !isSetUp {
            isSetUp = true
            setUp()
        }
        layoutDidChange()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard isSetUp, view != nil, size.width > 0, size.height > 0 else { return }
        layoutDidChange()
    }

    /// Build nodes once.
    func setUp() {}

    /// Position everything for the current `size` and `safeInsets`. Called after setup, after any
    /// size change, and when the safe area changes.
    func layoutDidChange() {}

    func present(_ scene: SKScene) {
        scene.scaleMode = .resizeFill
        view?.presentScene(scene, transition: SKTransition.fade(withDuration: 0.35))
    }

    // MARK: Buttons

    /// Buttons are named "btn.<id>"; `buttonName(at:)` finds the one under a touch.
    func makeButton(_ title: String, name: String, width: CGFloat, height: CGFloat = 50, primary: Bool = true, fontSize: CGFloat = 20) -> SKNode {
        let shape = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        shape.fillColor = primary ? Palette.button : Palette.secondaryButton
        shape.strokeColor = primary ? .clear : UIColor(white: 1, alpha: 0.3)
        shape.lineWidth = 1.5
        shape.name = name
        let label = SKLabelNode(fontNamed: Fonts.bold)
        label.text = title
        label.fontSize = fontSize
        label.fontColor = primary ? Palette.buttonText : Palette.text
        label.verticalAlignmentMode = .center
        label.name = name
        shape.addChild(label)
        return shape
    }

    func buttonName(at point: CGPoint) -> String? {
        let names = nodes(at: point).compactMap { $0.name }.filter { $0.hasPrefix("btn.") }
        // The dimming backdrop of a panel only counts if nothing on the panel was hit.
        return names.first { $0 != "btn.dim" } ?? names.first
    }

    func makeLabel(_ text: String, size: CGFloat, font: String = Fonts.medium, color: UIColor = Palette.text) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: font)
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.verticalAlignmentMode = .center
        return label
    }

    /// A centred modal panel. Position the returned node at the scene centre.
    func makePanel(title: String, lines: [String], stars: Int? = nil, buttons: [(title: String, name: String, primary: Bool)]) -> SKNode {
        let container = SKNode()
        container.zPosition = 50

        let dim = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000))
        dim.fillColor = UIColor(white: 0, alpha: 0.55)
        dim.strokeColor = .clear
        dim.name = "btn.dim"
        container.addChild(dim)

        let width: CGFloat = min(320, size.width - 40)
        let buttonHeight: CGFloat = 48
        let height: CGFloat = 70 + CGFloat(lines.count) * 26 + (stars == nil ? 0 : 56) + CGFloat(buttons.count) * (buttonHeight + 10) + 24
        let panel = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 22)
        panel.fillColor = Palette.panel
        panel.strokeColor = UIColor(white: 1, alpha: 0.18)
        panel.lineWidth = 1
        container.addChild(panel)

        var y = height / 2 - 40
        let titleLabel = makeLabel(title, size: 28, font: Fonts.title)
        titleLabel.position = CGPoint(x: 0, y: y)
        container.addChild(titleLabel)
        y -= 34

        if let stars = stars {
            let starSize: CGFloat = 40
            for i in 0..<3 {
                let star = SKSpriteNode(texture: TextureFactory.star(filled: i < stars, size: starSize))
                star.size = CGSize(width: starSize, height: starSize)
                star.position = CGPoint(x: CGFloat(i - 1) * (starSize + 10), y: y - 14)
                if i < stars {
                    star.setScale(0.1)
                    star.run(.sequence([.wait(forDuration: 0.25 + 0.2 * Double(i)), .scale(to: 1.25, duration: 0.18), .scale(to: 1, duration: 0.1)]))
                }
                container.addChild(star)
            }
            y -= 56
        }

        for line in lines {
            let label = makeLabel(line, size: 17, color: Palette.dimText)
            label.position = CGPoint(x: 0, y: y)
            container.addChild(label)
            y -= 26
        }

        y -= 10
        for button in buttons {
            let node = makeButton(button.title, name: button.name, width: width - 48, height: buttonHeight, primary: button.primary)
            node.position = CGPoint(x: 0, y: y - buttonHeight / 2)
            container.addChild(node)
            y -= buttonHeight + 10
        }
        return container
    }

    func formatScore(_ score: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: score)) ?? "\(score)"
    }

    func formatTime(_ t: Double) -> String {
        String(format: "%.1fs", t)
    }
}
