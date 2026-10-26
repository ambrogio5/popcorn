import SpriteKit
import UIKit

/// Draws and drives a `GameModel`. All gameplay rules live in the model; this file turns model
/// state into sprites and model events into sound, particles and shakes.
final class GameScene: BaseScene {
    private let model: GameModel
    private let gameMode: GameMode
    private let playerCount: Int
    private let city: City
    private let cityIndex: Int

    private var layout = GameLayout()
    private let background = SKSpriteNode()
    private let arenaFrame = SKShapeNode()
    private let worldNode = SKNode()
    private let staticNode = SKNode()
    private let dynamicNode = SKNode()
    private let effectsNode = SKNode()
    private let freezeTint = SKShapeNode()
    private let hud = HUDNode()
    private let controls = TouchControls()
    private let controllerInput = ControllerInput()
    private var overlay: SKNode?
    private var toast: SKNode?
    private var controlsHint: SKNode?

    private var bubbleNodes: [Int: SKSpriteNode] = [:]
    private var playerNodes: [SKSpriteNode] = []
    private var shieldNodes: [SKShapeNode] = []
    private var harpoonNodes: [Int: SKShapeNode] = [:]
    private var pickupNodes: [Int: SKSpriteNode] = [:]

    private var lastTime: TimeInterval = 0
    private var isGamePaused = false
    private var finished = false
    private var shake: CGFloat = 0

    init(size: CGSize, mode: GameMode, playerCount: Int) {
        gameMode = mode
        self.playerCount = playerCount
        let content = GameContent.shared
        switch mode {
        case .level(let level):
            cityIndex = min(max(level.city, 0), content.cities.count - 1)
        case .storm:
            cityIndex = Int.random(in: 0..<max(content.cities.count, 1))
        }
        city = content.cities[cityIndex]
        model = GameModel(mode: mode, layout: LayoutMode.forSize(width: Double(size.width), height: Double(size.height)), playerCount: playerCount)
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) { fatalError("Not supported") }

    // MARK: Setup and layout

    override func setUp() {
        background.anchorPoint = .zero
        background.zPosition = 0
        addChild(background)

        arenaFrame.zPosition = 1
        arenaFrame.fillColor = UIColor(white: 0, alpha: 0.28)
        arenaFrame.strokeColor = Palette.frame
        arenaFrame.lineWidth = 2
        addChild(arenaFrame)

        worldNode.zPosition = 2
        addChild(worldNode)
        worldNode.addChild(staticNode)
        dynamicNode.zPosition = 1
        worldNode.addChild(dynamicNode)
        effectsNode.zPosition = 2
        worldNode.addChild(effectsNode)
        freezeTint.zPosition = 3
        freezeTint.fillColor = UIColor(hex: "#BFEFFF").withAlphaComponent(0.16)
        freezeTint.strokeColor = .clear
        freezeTint.isHidden = true
        worldNode.addChild(freezeTint)

        switch gameMode {
        case .level(let level): hud.configure(title: "\(level.id) · \(level.name)")
        case .storm: hud.configure(title: String(localized: "Storm"))
        }
        addChild(hud)
        if !Progress.shared.hasSeenControlsHint {
            Progress.shared.hasSeenControlsHint = true
            showControlsHint()
        }
        controls.node.zPosition = 10
        addChild(controls.node)

        for _ in 0..<playerCount {
            let node = SKSpriteNode()
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            dynamicNode.addChild(node)
            playerNodes.append(node)
            let ring = SKShapeNode(circleOfRadius: 10)
            ring.strokeColor = Palette.pickup(.shield)
            ring.lineWidth = 3
            ring.glowWidth = 4
            ring.fillColor = Palette.pickup(.shield).withAlphaComponent(0.12)
            ring.isHidden = true
            dynamicNode.addChild(ring)
            shieldNodes.append(ring)
        }
    }

    override func layoutDidChange() {
        let newMode = LayoutMode.forSize(width: Double(size.width), height: Double(size.height))
        if newMode != model.spec.mode {
            model.relayout(to: newMode)
            switch newMode {
            case .wide: showToast(String(localized: "Unfolded — wide arena"))
            case .upright: showToast(String(localized: "Unfolded — upright arena"))
            case .tall: showToast(String(localized: "Folded — tall arena"))
            }
        }
        layout = GameLayout.compute(size: size, insets: safeInsets, spec: model.spec, playerCount: playerCount)

        background.texture = TextureFactory.background(city: city, cityIndex: cityIndex, size: size)
        background.size = size

        let frameRect = layout.arenaRect.insetBy(dx: -4, dy: -4)
        arenaFrame.path = UIBezierPath(roundedRect: frameRect, cornerRadius: 10).cgPath
        worldNode.position = layout.arenaOrigin
        freezeTint.path = CGPath(rect: CGRect(origin: .zero, size: layout.arenaSize), transform: nil)

        rebuildStatic()
        bubbleNodes.values.forEach { $0.removeFromParent() }
        bubbleNodes.removeAll()
        harpoonNodes.values.forEach { $0.removeFromParent() }
        harpoonNodes.removeAll()
        pickupNodes.values.forEach { $0.removeFromParent() }
        pickupNodes.removeAll()
        for (i, node) in playerNodes.enumerated() {
            let h = CGFloat(Player.height) * layout.unit
            node.texture = TextureFactory.player(index: i, height: h)
            node.size = CGSize(width: CGFloat(Player.width) * layout.unit, height: h)
            let ring = shieldNodes[i]
            ring.path = CGPath(ellipseIn: CGRect(x: -h * 0.6, y: -h * 0.6, width: h * 1.2, height: h * 1.2), transform: nil)
        }

        hud.layout(rect: layout.hudRect)
        controls.layout(strip: layout.controlsRect, playerCount: playerCount, sceneSize: size)
        controls.reset()
        overlay?.position = CGPoint(x: size.width / 2, y: size.height / 2)
        toast?.position = CGPoint(x: size.width / 2, y: layout.hudRect.minY - 24)
        controlsHint?.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        sync()
    }

    private func rebuildStatic() {
        staticNode.removeAllChildren()
        for box in model.platforms {
            let rect = layout.rect(box)
            let node = SKShapeNode(rect: rect, cornerRadius: 3)
            node.fillColor = Palette.platform
            node.strokeColor = Palette.platformEdge
            node.lineWidth = 1.5
            staticNode.addChild(node)
        }
        for ladder in model.ladders {
            let path = CGMutablePath()
            let x = CGFloat(ladder.x) * layout.unit
            let bottom = CGFloat(ladder.bottom) * layout.unit
            let top = CGFloat(ladder.top) * layout.unit
            let half = 0.35 * layout.unit
            path.move(to: CGPoint(x: x - half, y: bottom))
            path.addLine(to: CGPoint(x: x - half, y: top))
            path.move(to: CGPoint(x: x + half, y: bottom))
            path.addLine(to: CGPoint(x: x + half, y: top))
            var y = bottom + 0.3 * layout.unit
            while y < top - 0.1 * layout.unit {
                path.move(to: CGPoint(x: x - half, y: y))
                path.addLine(to: CGPoint(x: x + half, y: y))
                y += 0.45 * layout.unit
            }
            let node = SKShapeNode(path: path)
            node.strokeColor = Palette.ladder
            node.lineWidth = max(2, layout.unit * 0.08)
            node.lineCap = .round
            node.zPosition = -0.5
            staticNode.addChild(node)
        }
    }

    // MARK: Loop

    override func update(_ currentTime: TimeInterval) {
        guard isSetUp else { return }
        let dt = lastTime > 0 ? min(currentTime - lastTime, 1.0 / 20) : 0
        lastTime = currentTime
        guard !isGamePaused else { return }

        for i in 0..<playerCount {
            model.setInput(controls.input(for: i).merged(with: controllerInput.input(for: i)), for: i)
        }
        model.update(dt: dt)
        sync()
        for event in model.drainEvents() { handle(event) }

        var hearts: Int?
        if case .storm = gameMode { hearts = model.hearts }
        let p0 = model.players[0]
        hud.update(score: model.score, combo: model.combo, time: model.elapsed, hearts: hearts,
                   weapon: p0.weapon, weaponTime: p0.weaponTimer, shield: p0.shield, frozen: model.freezeTimer)

        if shake > 0.2 {
            worldNode.position = CGPoint(x: layout.arenaOrigin.x + CGFloat.random(in: -shake...shake),
                                         y: layout.arenaOrigin.y + CGFloat.random(in: -shake...shake))
            shake *= 0.85
        } else if shake > 0 {
            shake = 0
            worldNode.position = layout.arenaOrigin
        }
    }

    private func sync() {
        let frozen = model.freezeTimer > 0
        freezeTint.isHidden = !frozen

        var seen = Set<Int>()
        for b in model.bubbles {
            seen.insert(b.id)
            let node: SKSpriteNode
            if let existing = bubbleNodes[b.id] {
                node = existing
            } else {
                let d = CGFloat(b.radius * 2) * layout.unit
                node = SKSpriteNode(texture: TextureFactory.bubble(size: b.size, kind: b.kind, diameter: d))
                node.size = CGSize(width: d, height: d)
                node.setScale(0.6)
                node.run(.scale(to: 1, duration: 0.12))
                dynamicNode.addChild(node)
                bubbleNodes[b.id] = node
            }
            node.position = layout.point(b.pos)
            if frozen {
                node.color = UIColor(hex: "#BFEFFF")
                node.colorBlendFactor = 0.5
            } else if b.kind == .armored && b.hitsLeft == 1 {
                node.color = .white
                node.colorBlendFactor = 0.35
            } else {
                node.colorBlendFactor = 0
            }
        }
        for (id, node) in bubbleNodes where !seen.contains(id) {
            node.removeFromParent()
            bubbleNodes.removeValue(forKey: id)
        }

        for (i, p) in model.players.enumerated() where i < playerNodes.count {
            let node = playerNodes[i]
            node.position = layout.point(p.pos)
            node.xScale = p.facing >= 0 ? 1 : -1
            node.isHidden = !p.alive
            node.alpha = p.invulnerable > 0 && Int(p.invulnerable * 12) % 2 == 0 ? 0.35 : 1
            let ring = shieldNodes[i]
            ring.isHidden = !p.alive || !p.shield
            ring.position = CGPoint(x: node.position.x, y: node.position.y + node.size.height / 2)
        }

        var seenHarpoons = Set<Int>()
        for h in model.harpoons {
            seenHarpoons.insert(h.id)
            let node: SKShapeNode
            if let existing = harpoonNodes[h.id] {
                node = existing
            } else {
                node = SKShapeNode()
                node.strokeColor = h.sticky ? Palette.pickup(.sticky) : Palette.harpoon
                node.lineWidth = max(2, layout.unit * 0.09)
                node.glowWidth = 2
                node.lineCap = .round
                dynamicNode.addChild(node)
                harpoonNodes[h.id] = node
            }
            let path = CGMutablePath()
            let x = CGFloat(h.x) * layout.unit
            let bottom = CGFloat(h.bottom) * layout.unit
            let top = CGFloat(h.top) * layout.unit
            path.move(to: CGPoint(x: x, y: bottom))
            path.addLine(to: CGPoint(x: x, y: top))
            let tip = 0.22 * layout.unit
            path.move(to: CGPoint(x: x - tip, y: top - tip))
            path.addLine(to: CGPoint(x: x, y: top))
            path.addLine(to: CGPoint(x: x + tip, y: top - tip))
            node.path = path
            node.alpha = h.stuck ? 0.5 + 0.5 * CGFloat(h.stuckTimer / GameModel.stickyDuration) : 1
        }
        for (id, node) in harpoonNodes where !seenHarpoons.contains(id) {
            node.removeFromParent()
            harpoonNodes.removeValue(forKey: id)
        }

        var seenPickups = Set<Int>()
        for p in model.pickups {
            seenPickups.insert(p.id)
            let node: SKSpriteNode
            if let existing = pickupNodes[p.id] {
                node = existing
            } else {
                let d = CGFloat(Pickup.radius * 2) * layout.unit
                node = SKSpriteNode(texture: TextureFactory.pickup(kind: p.kind, diameter: d))
                node.size = CGSize(width: d, height: d)
                node.run(.repeatForever(.sequence([.rotate(byAngle: 0.12, duration: 0.5), .rotate(byAngle: -0.24, duration: 1), .rotate(byAngle: 0.12, duration: 0.5)])))
                dynamicNode.addChild(node)
                pickupNodes[p.id] = node
            }
            node.position = layout.point(p.pos)
            node.alpha = p.ttl < 2.5 && Int(p.ttl * 8) % 2 == 0 ? 0.35 : 1
        }
        for (id, node) in pickupNodes where !seenPickups.contains(id) {
            node.removeFromParent()
            pickupNodes.removeValue(forKey: id)
        }
    }

    // MARK: Events

    private func handle(_ event: GameEvent) {
        switch event {
        case .bubbleBounced(let id):
            if let node = bubbleNodes[id], node.action(forKey: "squash") == nil {
                let squash = SKAction.group([.scaleX(to: 1.14, duration: 0.07), .scaleY(to: 0.84, duration: 0.07)])
                let restore = SKAction.group([.scaleX(to: 1, duration: 0.12), .scaleY(to: 1, duration: 0.12)])
                node.run(.sequence([squash, restore]), withKey: "squash")
            }
        case .bubbleSplit(let at, let size, let kind, let combo):
            burst(at: layout.point(at), color: Palette.bubble(size, kind: kind), count: 10, speed: 60 + layout.unit * 2)
            SoundBank.shared.pop(combo: combo, on: self)
            Haptics.pop(size)
            if combo >= 3 { floatText("×\(combo)", at: layout.point(at), color: Palette.star) }
            if size == .large { shake = max(shake, 4) }
        case .bubblePopped(let at, let size, let kind, let combo):
            burst(at: layout.point(at), color: Palette.bubble(size, kind: kind), count: 14, speed: 90)
            SoundBank.shared.pop(combo: combo, on: self)
            Haptics.pop(size)
            if combo >= 3 { floatText("×\(combo)", at: layout.point(at), color: Palette.star) }
        case .armorCracked(let at):
            burst(at: layout.point(at), color: Palette.platformEdge, count: 6, speed: 50)
            SoundBank.shared.play("armor", on: self)
            Haptics.tap()
        case .lightning(let from, let to):
            let path = CGMutablePath()
            path.move(to: layout.point(from))
            path.addLine(to: layout.point(to))
            let bolt = SKShapeNode(path: path)
            bolt.strokeColor = Palette.bubble(.medium, kind: .lightning)
            bolt.lineWidth = 3
            bolt.glowWidth = 6
            effectsNode.addChild(bolt)
            bolt.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
            SoundBank.shared.play("lightning", on: self)
        case .harpoonFired:
            SoundBank.shared.play("fire", on: self)
        case .harpoonBlocked(let at):
            burst(at: layout.point(at), color: Palette.harpoon, count: 4, speed: 40)
            SoundBank.shared.play("block", on: self)
        case .playerHit(_, let at):
            burst(at: CGPoint(x: layout.point(at).x, y: layout.point(at).y + layout.unit * 0.7), color: .white, count: 18, speed: 110)
            flash(color: UIColor(hex: "#FF5E7E"), alpha: 0.35)
            shake = max(shake, 10)
            SoundBank.shared.play("hit", on: self)
            Haptics.hit()
        case .shieldBroken(_, let at):
            burst(at: layout.point(at), color: Palette.pickup(.shield), count: 16, speed: 100)
            SoundBank.shared.play("shield", on: self)
            Haptics.hit()
        case .playerRespawned(let player):
            if player < playerNodes.count {
                let p = playerNodes[player].position
                burst(at: CGPoint(x: p.x, y: p.y + layout.unit * 0.7), color: Palette.player(player), count: 12, speed: 70)
            }
        case .pickupCollected(let kind, _, let at):
            floatText(kind.title, at: layout.point(at), color: Palette.pickup(kind))
            burst(at: layout.point(at), color: Palette.pickup(kind), count: 10, speed: 70)
            SoundBank.shared.play("pickup", on: self)
            Haptics.tap()
        case .freezeStarted:
            SoundBank.shared.play("freeze", on: self)
            flash(color: UIColor(hex: "#BFEFFF"), alpha: 0.3)
        case .finalPop(let at):
            burst(at: layout.point(at), color: .white, count: 40, speed: 160)
            shake = max(shake, 8)
            flash(color: .white, alpha: 0.4)
        case .levelCleared(let result):
            finishLevel(with: result)
        case .gameOver(let score):
            finishStorm(score: score)
        case .stormSpawn:
            SoundBank.shared.play("click", on: self)
        }
    }

    private func burst(at point: CGPoint, color: UIColor, count: Int, speed: CGFloat) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = TextureFactory.particle()
        emitter.numParticlesToEmit = count
        emitter.particleBirthRate = 4000
        emitter.particleLifetime = 0.5
        emitter.particleLifetimeRange = 0.25
        emitter.particleSpeed = speed
        emitter.particleSpeedRange = speed * 0.6
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.95
        emitter.particleAlphaSpeed = -1.8
        emitter.particleScale = max(0.25, layout.unit / 60)
        emitter.particleScaleRange = 0.15
        emitter.particleScaleSpeed = -0.5
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.yAcceleration = -120
        emitter.position = point
        effectsNode.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
    }

    private func floatText(_ text: String, at point: CGPoint, color: UIColor) {
        let label = SKLabelNode(fontNamed: Fonts.title)
        label.text = text
        label.fontSize = max(14, layout.unit * 0.7)
        label.fontColor = color
        label.position = CGPoint(x: point.x, y: point.y + layout.unit * 0.5)
        label.zPosition = 5
        effectsNode.addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: layout.unit * 1.6, duration: 0.7), .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.4)])]), .removeFromParent()]))
    }

    private func flash(color: UIColor, alpha: CGFloat) {
        let node = SKShapeNode(rect: CGRect(origin: .zero, size: layout.arenaSize))
        node.fillColor = color
        node.strokeColor = .clear
        node.alpha = alpha
        node.zPosition = 4
        worldNode.addChild(node)
        node.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    /// A one-time explanation of the controls, shown over the arena on the very first game.
    private func showControlsHint() {
        let lines = [String(localized: "Drag the left stick to run, up or down for ladders"),
                     String(localized: "Tap FIRE (or anywhere on the arena) to shoot"),
                     String(localized: "Split the bubbles until they pop. Don't get touched.")]
        let panel = SKShapeNode(rectOf: CGSize(width: min(340, size.width - 40), height: 112), cornerRadius: 18)
        panel.fillColor = Palette.panel
        panel.strokeColor = UIColor(white: 1, alpha: 0.18)
        panel.zPosition = 30
        panel.name = "btn.hint"
        for (i, line) in lines.enumerated() {
            let label = makeLabel(line, size: 13, color: i == 2 ? Palette.text : Palette.dimText)
            label.position = CGPoint(x: 0, y: 32 - CGFloat(i) * 28)
            label.name = "btn.hint"
            panel.addChild(label)
        }
        panel.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        panel.alpha = 0
        addChild(panel)
        panel.run(.sequence([.fadeIn(withDuration: 0.3), .wait(forDuration: 6), .fadeOut(withDuration: 0.4), .removeFromParent()]), withKey: "hint")
        controlsHint = panel
    }

    private func dismissControlsHint() {
        controlsHint?.removeAllActions()
        controlsHint?.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        controlsHint = nil
    }

    private func showToast(_ text: String) {
        toast?.removeFromParent()
        let label = makeLabel(text, size: 15, font: Fonts.bold)
        let panel = SKShapeNode(rectOf: CGSize(width: label.frame.width + 36, height: 34), cornerRadius: 17)
        panel.fillColor = Palette.panel
        panel.strokeColor = .clear
        panel.zPosition = 30
        panel.addChild(label)
        panel.position = CGPoint(x: size.width / 2, y: layout.hudRect.minY - 24)
        addChild(panel)
        panel.run(.sequence([.wait(forDuration: 1.6), .fadeOut(withDuration: 0.4), .removeFromParent()]))
        toast = panel
    }

    // MARK: Pause and results

    func pauseFromSystem() {
        guard !finished, !isGamePaused else { return }
        showPause()
    }

    private func showPause() {
        isGamePaused = true
        controls.reset()
        let panel = makePanel(title: String(localized: "Paused"), lines: [], buttons: [
            (String(localized: "Resume"), "btn.resume", true),
            (String(localized: "Restart"), "btn.restart", false),
            (String(localized: "Menu"), "btn.menu", false),
        ])
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(panel)
        overlay = panel
    }

    private func resume() {
        overlay?.removeFromParent()
        overlay = nil
        isGamePaused = false
        lastTime = 0
    }

    private func finishLevel(with result: LevelResult) {
        guard case .level(let level) = gameMode, !finished else { return }
        finished = true
        Progress.shared.record(result, for: level.id)
        GameCenter.shared.levelFinished(in: cityIndex)
        SoundBank.shared.play("clear", on: self)
        Haptics.success()
        controls.reset()

        let score = formatScore(result.score)
        let time = formatTime(result.time)
        let par = formatTime(result.par)
        let best = formatScore(Progress.shared.bestScore(for: level.id))
        var lines = [String(localized: "Score \(score)"),
                     String(localized: "Time \(time)  ·  par \(par)")]
        if result.deaths > 0 { lines.append(String(localized: "Knocked down \(result.deaths)×")) }
        lines.append(String(localized: "Best \(best)"))
        var buttons: [(title: String, name: String, primary: Bool)] = []
        if GameContent.shared.level(after: level) != nil { buttons.append((String(localized: "Next level"), "btn.next", true)) }
        buttons.append((String(localized: "Play again"), "btn.retry", buttons.isEmpty))
        buttons.append((String(localized: "Menu"), "btn.menu", false))
        let panel = makePanel(title: String(localized: "Level clear!"), lines: lines, stars: result.stars, buttons: buttons)
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        panel.alpha = 0
        panel.run(.sequence([.wait(forDuration: 0.3), .fadeIn(withDuration: 0.25)]))
        addChild(panel)
        overlay = panel
    }

    private func finishStorm(score: Int) {
        guard !finished else { return }
        finished = true
        let record = Progress.shared.recordStorm(score: score)
        GameCenter.shared.stormFinished(score: score)
        SoundBank.shared.play("over", on: self)
        Haptics.failure()
        controls.reset()
        let scoreText = formatScore(score)
        let best = formatScore(Progress.shared.stormBest)
        let survived = formatTime(model.elapsed)
        let lines = [String(localized: "Score \(scoreText)"),
                     record ? String(localized: "New record!") : String(localized: "Best \(best)"),
                     String(localized: "Survived \(survived)")]
        let panel = makePanel(title: String(localized: "Storm over"), lines: lines, buttons: [
            (String(localized: "Play again"), "btn.retry", true),
            (String(localized: "Menu"), "btn.menu", false),
        ])
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        panel.alpha = 0
        panel.run(.sequence([.wait(forDuration: 0.5), .fadeIn(withDuration: 0.25)]))
        addChild(panel)
        overlay = panel
    }

    private func handleButton(_ name: String) {
        Haptics.tap()
        SoundBank.shared.play("click", on: self)
        switch name {
        case "btn.hint":
            dismissControlsHint()
        case "btn.pause":
            if overlay == nil { showPause() }
        case "btn.resume":
            if !finished { resume() }
        case "btn.restart", "btn.retry":
            present(GameScene(size: size, mode: gameMode, playerCount: playerCount))
        case "btn.menu":
            present(MenuScene(size: size))
        case "btn.next":
            if case .level(let level) = gameMode, let next = GameContent.shared.level(after: level) {
                present(GameScene(size: size, mode: .level(next), playerCount: playerCount))
            }
        default:
            break
        }
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            if let name = buttonName(at: point), name != "btn.dim" {
                handleButton(name)
                continue
            }
            guard overlay == nil, !isGamePaused, !finished else { continue }
            controls.began(touch, at: point)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { controls.moved(touch, to: touch.location(in: self)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { controls.ended(touch) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { controls.ended(touch) }
    }
}
