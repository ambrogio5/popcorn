import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    private var skView: SKView { view as! SKView }

    override func loadView() {
        view = SKView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        skView.ignoresSiblingOrder = true
        skView.isMultipleTouchEnabled = true
        skView.preferredFramesPerSecond = 120
        #if DEBUG
        skView.showsFPS = false
        skView.showsNodeCount = false
        #endif
        Haptics.prepare()
        GameCenter.shared.authenticate(presentingFrom: self)
        let menu = MenuScene(size: view.bounds.size)
        menu.scaleMode = .resizeFill
        skView.presentScene(menu)
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    /// Regular iPhones (and a closed Duo) play portrait only; a wide screen (open Duo, iPad) may rotate freely.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        let bounds = view.window?.screen.bounds ?? view.bounds
        return LayoutMode.allowsRotation(screenWidth: Double(bounds.width), screenHeight: Double(bounds.height)) ? .all : .portrait
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // A fold or unfold changes the screen; re-evaluate which orientations make sense.
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        (skView.scene as? BaseScene)?.layoutDidChange()
    }

    func pauseForSystem() {
        (skView.scene as? GameScene)?.pauseFromSystem()
    }
}
