import SpriteKit
import XCTest
@testable import Popcorn

/// Renders the main scenes at phone and Duo sizes and attaches the frames to the test result, so a
/// CI run produces pictures of the game without anyone tapping through it. Run `xcodebuild test
/// -resultBundlePath Out.xcresult` then `xcrun xcresulttool export attachments`.
final class ScreenshotTests: XCTestCase {
    private struct Shape {
        let name: String
        let size: CGSize
        /// What the device reports, so the HUD and the arena land where they do on the device.
        let insets: UIEdgeInsets
    }

    // Phone insets are the usual Dynamic Island / home indicator pair. The Duo cover screen was
    // measured on the Xcode 27.1 simulator: no top inset, the home indicator, and an 84 pt camera
    // inset down the right edge. The inner display had no top inset either; its bottom is assumed.
    private static let phoneInsets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
    private static let duoClosedInsets = UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 84)
    private static let duoOpenInsets = UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0)

    private let shapes = [
        Shape(name: "iphone", size: CGSize(width: 393, height: 852), insets: phoneInsets),
        Shape(name: "duo-closed", size: CGSize(width: 466, height: 678), insets: duoClosedInsets),
        Shape(name: "duo-open", size: CGSize(width: 951, height: 669), insets: duoOpenInsets),
        Shape(name: "duo-open-upright", size: CGSize(width: 669, height: 951), insets: duoOpenInsets),
    ]

    private var window: UIWindow!
    private var skView: SKView!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        skView = SKView(frame: window.bounds)
        skView.ignoresSiblingOrder = true
        window.addSubview(skView)
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        skView.presentScene(nil)
        window.isHidden = true
        window = nil
        skView = nil
        super.tearDown()
    }

    private func present(_ scene: BaseScene, size: CGSize, insets: UIEdgeInsets) {
        scene.insetOverride = insets
        window.frame = CGRect(origin: .zero, size: size)
        skView.frame = window.bounds
        scene.scaleMode = .resizeFill
        scene.size = size
        skView.presentScene(scene)
        skView.layoutIfNeeded()
        // One pass through the scene's layout so nodes exist before we render.
        scene.layoutDidChange()
    }

    /// Advances the game scene's clock by hand so bubbles fall and the HUD fills in.
    private func advance(_ scene: GameScene, seconds: Double) {
        var t: TimeInterval = 1
        while t < 1 + seconds {
            scene.update(t)
            t += 1.0 / 60
        }
    }

    private func attach(_ scene: SKScene, name: String) {
        guard let texture = skView.texture(from: scene) else {
            return XCTFail("could not render \(name)")
        }
        let image = UIImage(cgImage: texture.cgImage())
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMenuAndLevelSelectRenderInEveryShape() {
        for shape in shapes {
            let menu = MenuScene(size: shape.size)
            present(menu, size: shape.size, insets: shape.insets)
            attach(menu, name: "menu-\(shape.name)")

            let select = LevelSelectScene(size: shape.size)
            present(select, size: shape.size, insets: shape.insets)
            attach(select, name: "levels-\(shape.name)")
        }
    }

    func testGameplayRendersInEveryShape() {
        let levels = GameContent.shared.levels
        let picks = [levels[0], levels[min(19, levels.count - 1)], levels[min(44, levels.count - 1)]]
        for shape in shapes {
            for (i, level) in picks.enumerated() {
                let players = shape.size.width > shape.size.height ? 2 : 1
                let scene = GameScene(size: shape.size, mode: .level(level), playerCount: players)
                present(scene, size: shape.size, insets: shape.insets)
                advance(scene, seconds: 1.3 + Double(i) * 0.4)
                attach(scene, name: "level\(level.id)-\(players)p-\(shape.name)")
            }
            let storm = GameScene(size: shape.size, mode: .storm, playerCount: 1)
            present(storm, size: shape.size, insets: shape.insets)
            advance(storm, seconds: 2.0)
            attach(storm, name: "storm-\(shape.name)")
        }
    }

    func testFoldingMidGameKeepsPlaying() {
        let level = GameContent.shared.levels[0]
        let scene = GameScene(size: CGSize(width: 466, height: 678), mode: .level(level), playerCount: 2)
        present(scene, size: CGSize(width: 466, height: 678), insets: Self.duoClosedInsets)
        advance(scene, seconds: 1.0)
        attach(scene, name: "fold-before-closed")

        // Unfold, held upright: the view grows to the inner display and the scene is told about it.
        // (With the cover screen's real insets it already plays the wide arena, so unfolding into
        // the landscape shape would change nothing; upright shows the relayout and the toast.)
        present(scene, size: CGSize(width: 669, height: 951), insets: Self.duoOpenInsets)
        advance(scene, seconds: 0.2)
        attach(scene, name: "fold-after-open")
        advance(scene, seconds: 1.5)
        attach(scene, name: "fold-after-open-resumed")
    }
}
