import SpriteKit

final class MenuScene: BaseScene {
    private let background = SKSpriteNode()
    private let content = SKNode()
    private var settingsOverlay: SKNode?
    private var decorBubbles: [SKSpriteNode] = []

    override func setUp() {
        background.anchorPoint = .zero
        background.zPosition = 0
        addChild(background)
        content.zPosition = 5
        addChild(content)
        GameCenter.shared.onAuthenticationChange = { [weak self] in if self?.view != nil { self?.rebuildContent() } }
    }

    override func layoutDidChange() {
        let cities = GameContent.shared.cities
        background.texture = TextureFactory.background(city: cities[0], cityIndex: 0, size: size)
        background.size = size
        rebuildContent()
        if settingsOverlay != nil { showSettings() }
    }

    private func rebuildContent() {
        content.removeAllChildren()
        decorBubbles.removeAll()
        let insets = safeInsets
        let centerX = size.width / 2
        let usableTop = size.height - insets.top
        let usableBottom = insets.bottom
        let wide = LayoutMode.forSize(width: Double(size.width), height: Double(size.height)) != .tall

        // Floating bubbles behind the title
        for (i, bubbleSize) in [BubbleSize.large, .medium, .small, .tiny, .medium, .small].enumerated() {
            let d = CGFloat(bubbleSize.radius) * (wide ? 70 : 46)
            let sprite = SKSpriteNode(texture: TextureFactory.bubble(size: bubbleSize, kind: .plain, diameter: d))
            sprite.size = CGSize(width: d, height: d)
            let x = size.width * (0.12 + 0.76 * CGFloat(i) / 5)
            let y = usableBottom + (usableTop - usableBottom) * (0.25 + 0.5 * CGFloat((i * 7) % 5) / 4)
            sprite.position = CGPoint(x: x, y: y)
            sprite.alpha = 0.5
            let rise = SKAction.moveBy(x: 0, y: 18 + CGFloat(i * 5), duration: 1.4 + 0.2 * Double(i))
            rise.timingMode = .easeInEaseOut
            sprite.run(.repeatForever(.sequence([rise, rise.reversed()])))
            content.addChild(sprite)
            decorBubbles.append(sprite)
        }

        let title = makeLabel("POPCORN", size: wide ? 84 : 64, font: Fonts.title)
        title.position = CGPoint(x: centerX, y: usableTop - (wide ? 110 : 150))
        content.addChild(title)

        let subtitle = makeLabel(String(localized: "pop everything · buy nothing"), size: wide ? 22 : 18, color: Palette.dimText)
        subtitle.position = CGPoint(x: centerX, y: title.position.y - (wide ? 58 : 48))
        content.addChild(subtitle)

        let players = Progress.shared.playerCount
        let buttonWidth: CGFloat = min(300, size.width - 60)
        var y = title.position.y - (wide ? 160 : 150)
        let spacing: CGFloat = 62
        var buttons = [(String(localized: "Play"), "btn.play", true),
                       (String(localized: "Storm mode"), "btn.storm", false),
                       (String(localized: "Players: \(players)"), "btn.players", false),
                       (String(localized: "Settings"), "btn.settings", false)]
        if GameCenter.shared.isAuthenticated { buttons.insert((String(localized: "Leaderboards"), "btn.leaderboards", false), at: 3) }
        for (text, name, primary) in buttons {
            let button = makeButton(text, name: name, width: buttonWidth, height: 52, primary: primary)
            button.position = CGPoint(x: centerX, y: y)
            content.addChild(button)
            y -= spacing
        }

        let stars = Progress.shared.totalStars(levels: GameContent.shared.levels)
        let maxStars = GameContent.shared.levels.count * 3
        let stormBest = formatScore(Progress.shared.stormBest)
        let starsLabel = makeLabel(String(localized: "★ \(stars) / \(maxStars)   ·   Storm best \(stormBest)"), size: 15, color: Palette.dimText)
        starsLabel.position = CGPoint(x: centerX, y: y + 10)
        content.addChild(starsLabel)

        var hint = ""
        if players == 2 && !wide {
            hint = String(localized: "Two players: open your phone for the wide arena")
        } else if players == 2 {
            hint = String(localized: "Player 1 takes the left corner, player 2 the right")
        }
        if !hint.isEmpty {
            let hintLabel = makeLabel(hint, size: 14, color: Palette.dimText)
            hintLabel.position = CGPoint(x: centerX, y: usableBottom + 36)
            content.addChild(hintLabel)
        }
    }

    // MARK: Settings

    private func showSettings() {
        settingsOverlay?.removeFromParent()
        let p = Progress.shared
        let on = String(localized: "On")
        let off = String(localized: "Off")
        let sound = p.soundEnabled ? on : off
        let haptics = p.hapticsEnabled ? on : off
        let panel = makePanel(title: String(localized: "Settings"), lines: [String(localized: "Nothing to buy. Nothing to unlock. Just play.")], buttons: [
            (String(localized: "Sound: \(sound)"), "btn.sound", false),
            (String(localized: "Haptics: \(haptics)"), "btn.haptics", false),
            (String(localized: "Reset progress"), "btn.reset", false),
            (String(localized: "Close"), "btn.close", true),
        ])
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(panel)
        settingsOverlay = panel
    }

    private var resetArmed = false

    private func handle(_ name: String) {
        Haptics.tap()
        SoundBank.shared.play("click", on: self)
        switch name {
        case "btn.play":
            present(LevelSelectScene(size: size))
        case "btn.storm":
            present(GameScene(size: size, mode: .storm, playerCount: Progress.shared.playerCount))
        case "btn.players":
            Progress.shared.playerCount = Progress.shared.playerCount == 1 ? 2 : 1
            rebuildContent()
        case "btn.settings":
            showSettings()
        case "btn.leaderboards":
            GameCenter.shared.showLeaderboards(from: view?.window?.rootViewController)
        case "btn.sound":
            Progress.shared.soundEnabled.toggle()
            showSettings()
        case "btn.haptics":
            Progress.shared.hapticsEnabled.toggle()
            showSettings()
        case "btn.reset":
            if resetArmed {
                Progress.shared.resetAll()
                resetArmed = false
                settingsOverlay?.removeFromParent()
                settingsOverlay = nil
                rebuildContent()
            } else {
                resetArmed = true
                if let label = settingsOverlay?.childNode(withName: "btn.reset")?.children.compactMap({ $0 as? SKLabelNode }).first {
                    label.text = String(localized: "Tap again to confirm")
                }
            }
        case "btn.close", "btn.dim":
            resetArmed = false
            settingsOverlay?.removeFromParent()
            settingsOverlay = nil
            rebuildContent()
        default:
            break
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if let name = buttonName(at: touch.location(in: self)) { handle(name) }
    }
}
