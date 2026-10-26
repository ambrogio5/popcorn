import Foundation

/// The whole game simulation, in arena units, with no SpriteKit in sight. `GameScene` feeds it
/// input, steps it, and reads back positions and events to draw.
final class GameModel {
    // MARK: Tunables

    static let gravity = 14.0
    static let harpoonSpeed = 20.0
    static let rapidHarpoonSpeed = 32.0
    static let stickyDuration = 3.0
    static let weaponDuration = 15.0
    static let freezeDuration = 4.0
    static let deathFreeze = 1.8
    static let respawnDelay = 1.6
    static let comboWindow = 1.5
    static let maxCombo = 8
    static let pickupLifetime = 8.0
    static let pickupDropChance = 0.06
    static let lightningRange = 3.5
    static let foldPause = 1.0
    static let celebration = 0.8
    static let celebrationTimeScale = 0.4
    static let fixedStep = 1.0 / 120.0
    static let maxStormBubbles = 14

    // MARK: State

    let mode: GameMode
    let level: Level
    let playerCount: Int

    private(set) var spec: ArenaSpec
    private(set) var platforms: [Box] = []
    private(set) var ladders: [LadderBody] = []
    private(set) var bubbles: [Bubble] = []
    private(set) var players: [Player] = []
    private(set) var harpoons: [Harpoon] = []
    private(set) var pickups: [Pickup] = []
    private(set) var events: [GameEvent] = []

    private(set) var score = 0
    private(set) var combo = 0
    private(set) var elapsed = 0.0
    private(set) var deaths = 0
    private(set) var hearts = 3
    private(set) var freezeTimer = 0.0
    /// Short pause after a fold/unfold so nobody dies while the arena reshapes.
    private(set) var transitionPause = 0.0
    private(set) var timeScale = 1.0
    private(set) var isOver = false

    private var comboTimer = 0.0
    private var celebrationTimer = 0.0
    private var clearTime = 0.0
    private var stormTimer = 3.0
    private var stormInterval = 6.0
    private var accumulator = 0.0
    private var nextID = 1
    private var rng: SplitMix64

    init(mode: GameMode, layout: LayoutMode, playerCount: Int, seed: UInt64 = UInt64(Date().timeIntervalSince1970)) {
        self.mode = mode
        self.playerCount = max(1, min(2, playerCount))
        self.rng = SplitMix64(seed: seed)
        switch mode {
        case .level(let level): self.level = level
        case .storm: self.level = Level.storm
        }
        spec = ArenaSpec(mode: layout)
        buildStatic()
        players = (0..<self.playerCount).map { index in
            var p = Player(index: index, pos: spec.spawnPoint(player: index, of: self.playerCount))
            p.invulnerable = 1.5
            return p
        }
        for b in level.bubbles {
            spawnBubble(at: spec.point(nx: b.x, ny: b.y), size: b.size, kind: b.kind,
                        vx: Double(b.dir) * b.size.horizontalSpeed, vy: 0, grace: 1.0)
        }
        if case .storm = mode {
            spawnStormBubble(size: .large, kind: .plain)
            spawnStormBubble(size: .large, kind: .plain)
        }
    }

    // MARK: Public API

    func setInput(_ input: PlayerInput, for player: Int) {
        guard players.indices.contains(player) else { return }
        players[player].input = input
    }

    func drainEvents() -> [GameEvent] {
        let drained = events
        events.removeAll(keepingCapacity: true)
        return drained
    }

    /// Advances the simulation. Runs in fixed sub-steps so fast bubbles never tunnel through platforms.
    func update(dt rawDt: Double) {
        guard !isOver else { return }
        let dt = min(max(rawDt, 0), 0.1)
        if transitionPause > 0 {
            transitionPause -= dt
            return
        }
        accumulator += dt * timeScale
        while accumulator >= GameModel.fixedStep {
            accumulator -= GameModel.fixedStep
            step(GameModel.fixedStep)
            if isOver { break }
        }
    }

    /// The screen changed shape (fold, unfold, rotation). Everything is kept at the same
    /// normalised position so play continues where it left off.
    func relayout(to mode: LayoutMode) {
        guard mode != spec.mode else { return }
        let old = spec
        spec = ArenaSpec(mode: mode)
        buildStatic()
        let sy = spec.height / old.height
        for i in bubbles.indices {
            let n = old.normalized(bubbles[i].pos)
            var p = spec.point(nx: n.x, ny: n.y)
            let r = bubbles[i].radius
            p.x = min(max(p.x, r), spec.width - r)
            p.y = min(max(p.y, r), spec.height - r)
            bubbles[i].pos = p
            bubbles[i].vel.y *= sy
            bubbles[i].spawnGrace = max(bubbles[i].spawnGrace, 0.5)
        }
        for i in players.indices {
            let n = old.normalized(players[i].pos)
            players[i].pos = spec.point(nx: n.x, ny: n.y)
            players[i].onLadder = false
            players[i].vy = 0
            players[i].pos.y = groundLevel(x: players[i].pos.x, below: players[i].pos.y + 0.5)
            players[i].invulnerable = max(players[i].invulnerable, 1.5)
        }
        for i in pickups.indices {
            let n = old.normalized(pickups[i].pos)
            pickups[i].pos = spec.point(nx: n.x, ny: n.y)
            pickups[i].vy = 0
        }
        harpoons.removeAll()
        transitionPause = GameModel.foldPause
    }

    // MARK: Setup

    private func buildStatic() {
        platforms = level.platforms.map { spec.platformBox($0) }
        ladders = level.ladders.map { spec.ladderBody($0) }
    }

    private func takeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    private func randomUnit() -> Double { Double.random(in: 0..<1, using: &rng) }

    // MARK: Step

    private func step(_ dt: Double) {
        elapsed += dt
        if celebrationTimer > 0 {
            celebrationTimer -= dt
            for i in harpoons.indices { harpoons[i].top = max(harpoons[i].bottom, harpoons[i].top - 30 * dt) }
            if celebrationTimer <= 0 { finishLevel() }
            return
        }
        if comboTimer > 0 {
            comboTimer -= dt
            if comboTimer <= 0 { combo = 0 }
        }
        for i in players.indices { updatePlayer(at: i, dt: dt) }
        updateHarpoons(dt)
        if freezeTimer > 0 {
            freezeTimer -= dt
        } else {
            for i in bubbles.indices { updateBubble(at: i, dt: dt) }
        }
        for i in bubbles.indices where bubbles[i].spawnGrace > 0 { bubbles[i].spawnGrace -= dt }
        updatePickups(dt)
        resolveHarpoonHits()
        resolvePlayerCollisions()
        if case .storm = mode { updateStorm(dt) }
    }

    // MARK: Players

    private func updatePlayer(at i: Int, dt: Double) {
        var p = players[i]
        defer { players[i] = p }

        if !p.alive {
            p.respawnTimer -= dt
            if p.respawnTimer <= 0 {
                p.pos = spec.spawnPoint(player: i, of: playerCount)
                p.vy = 0
                p.alive = true
                p.grounded = true
                p.onLadder = false
                p.invulnerable = 2.0
                events.append(.playerRespawned(player: i))
            }
            return
        }

        p.invulnerable = max(0, p.invulnerable - dt)
        p.fireCooldown = max(0, p.fireCooldown - dt)
        if p.weapon != .normal {
            p.weaponTimer -= dt
            if p.weaponTimer <= 0 { p.weapon = .normal }
        }

        let input = p.input
        if input.moveX != 0 { p.facing = input.moveX > 0 ? 1 : -1 }

        if p.onLadder, ladders.indices.contains(p.ladderIndex) {
            let ladder = ladders[p.ladderIndex]
            p.pos.x = ladder.x
            p.pos.y += input.moveY * Player.climbSpeed * dt
            if p.pos.y >= ladder.top {
                p.pos.y = ladder.top
                p.onLadder = false
                p.grounded = true
            } else if p.pos.y <= ladder.bottom {
                p.pos.y = ladder.bottom
                p.onLadder = false
                p.grounded = true
            } else if abs(input.moveX) > 0.5 && (abs(p.pos.y - ladder.bottom) < 0.05 || abs(p.pos.y - ladder.top) < 0.05) {
                p.onLadder = false
            }
        } else {
            p.onLadder = false
            let prevY = p.pos.y
            p.pos.x += input.moveX * Player.speed * dt
            p.pos.x = min(max(p.pos.x, Player.width / 2), spec.width - Player.width / 2)

            if abs(input.moveY) > 0.5, p.grounded, let li = ladderIndex(near: p.pos, direction: input.moveY) {
                p.onLadder = true
                p.ladderIndex = li
                p.pos.x = ladders[li].x
                p.vy = 0
                // Take the first rung now so the top/bottom checks do not eject us immediately.
                p.pos.y += input.moveY * Player.climbSpeed * dt
            } else {
                p.vy -= GameModel.gravity * dt
                p.pos.y += p.vy * dt
                let ground = groundLevel(x: p.pos.x, below: prevY)
                if p.pos.y <= ground {
                    p.pos.y = ground
                    p.vy = 0
                    p.grounded = true
                } else {
                    p.grounded = false
                }
            }
        }

        // Firing. Normal weapons need a fresh press per shot; rapid fire can be held.
        let wantsFire = input.fire
        let repeats = p.weapon == .rapid
        if wantsFire && (!p.fireHeld || repeats) && p.fireCooldown <= 0 {
            if fireHarpoon(for: &p) {
                p.fireCooldown = repeats ? 0.18 : 0.12
            }
        }
        p.fireHeld = wantsFire
    }

    private func ladderIndex(near pos: Vec2, direction: Double) -> Int? {
        var best: Int?
        var bestDistance = 0.5
        for (i, l) in ladders.enumerated() {
            let dx = abs(l.x - pos.x)
            guard dx < bestDistance else { continue }
            let atBottom = abs(pos.y - l.bottom) < 0.1
            let atTop = abs(pos.y - l.top) < 0.1
            if (direction > 0 && atBottom) || (direction < 0 && atTop) {
                best = i
                bestDistance = dx
            }
        }
        return best
    }

    /// Highest standing surface under `x` that is not above `below`.
    private func groundLevel(x: Double, below: Double) -> Double {
        let half = Player.width * 0.35
        var ground = 0.0
        for box in platforms where box.maxX > x - half && box.minX < x + half && box.maxY <= below + 0.05 {
            ground = max(ground, box.maxY)
        }
        return ground
    }

    private func fireHarpoon(for p: inout Player) -> Bool {
        let active = harpoons.filter { $0.owner == p.index && !$0.stuck }.count
        let limit = p.weapon == .double ? 2 : 1
        guard active < limit else { return false }
        let speed = p.weapon == .rapid ? GameModel.rapidHarpoonSpeed : GameModel.harpoonSpeed
        harpoons.append(Harpoon(id: takeID(), owner: p.index, x: p.pos.x,
                                bottom: p.pos.y + 0.8, top: p.pos.y + Player.height,
                                speed: speed, sticky: p.weapon == .sticky))
        events.append(.harpoonFired(player: p.index))
        return true
    }

    // MARK: Harpoons

    private func updateHarpoons(_ dt: Double) {
        var kept: [Harpoon] = []
        kept.reserveCapacity(harpoons.count)
        for var h in harpoons {
            if h.stuck {
                h.stuckTimer -= dt
                if h.stuckTimer > 0 { kept.append(h) }
                continue
            }
            h.top += h.speed * dt
            var limit = spec.height
            for box in platforms where box.containsX(h.x) && box.minY >= h.bottom && box.minY < limit {
                limit = box.minY
            }
            if h.top >= limit {
                h.top = limit
                if h.sticky {
                    h.stuck = true
                    h.stuckTimer = GameModel.stickyDuration
                    kept.append(h)
                } else {
                    events.append(.harpoonBlocked(at: Vec2(x: h.x, y: limit)))
                }
            } else {
                kept.append(h)
            }
        }
        harpoons = kept
    }

    private func resolveHarpoonHits() {
        var hitBubbles: [Int] = []
        var usedHarpoons = Set<Int>()
        for h in harpoons {
            for b in bubbles where abs(b.pos.x - h.x) < b.radius && b.pos.y + b.radius > h.bottom && b.pos.y - b.radius < h.top {
                hitBubbles.append(b.id)
                usedHarpoons.insert(h.id)
            }
        }
        guard !hitBubbles.isEmpty else { return }
        harpoons.removeAll { usedHarpoons.contains($0.id) }
        for id in hitBubbles { hitBubble(id: id) }
    }

    // MARK: Bubbles

    @discardableResult
    private func spawnBubble(at pos: Vec2, size: BubbleSize, kind: BubbleKind, vx: Double, vy: Double, grace: Double) -> Int {
        let id = takeID()
        bubbles.append(Bubble(id: id, pos: pos, vel: Vec2(x: vx, y: vy), size: size, kind: kind,
                              hitsLeft: kind == .armored ? 2 : 1, spawnGrace: grace))
        return id
    }

    /// Vertical speed that carries a bubble from a surface to its characteristic apex.
    func bounceSpeed(for size: BubbleSize) -> Double {
        let climb = max(size.apexFraction * spec.height - size.radius, 1.0)
        return (2 * GameModel.gravity * climb).squareRoot()
    }

    private func updateBubble(at i: Int, dt: Double) {
        var b = bubbles[i]
        let r = b.radius
        let g = GameModel.gravity * (b.flipped ? -1 : 1)
        b.vel.y -= g * dt
        b.pos += b.vel * dt

        if b.pos.x - r < 0 {
            b.pos.x = r
            b.vel.x = abs(b.vel.x)
        } else if b.pos.x + r > spec.width {
            b.pos.x = spec.width - r
            b.vel.x = -abs(b.vel.x)
        }
        if b.pos.y - r < 0 {
            b.pos.y = r
            b.vel.y = b.flipped ? abs(b.vel.y) : bounceSpeed(for: b.size)
            if !b.flipped { events.append(.bubbleBounced(id: b.id)) }
        } else if b.pos.y + r > spec.height {
            b.pos.y = spec.height - r
            b.vel.y = b.flipped ? -bounceSpeed(for: b.size) : -abs(b.vel.y)
            if b.flipped { events.append(.bubbleBounced(id: b.id)) }
        }

        for box in platforms where box.overlapsCircle(center: b.pos, radius: r) {
            let closest = box.closestPoint(to: b.pos)
            var n = b.pos - closest
            var distance = n.length
            if distance < 1e-6 {
                n = Vec2(x: 0, y: 1)
                distance = 0
            } else {
                n = n * (1 / distance)
            }
            let penetration = r - distance
            if abs(n.y) >= abs(n.x) {
                if n.y > 0 {
                    b.pos.y += penetration
                    b.vel.y = b.flipped ? abs(b.vel.y) : bounceSpeed(for: b.size)
                    if !b.flipped { events.append(.bubbleBounced(id: b.id)) }
                } else {
                    b.pos.y -= penetration
                    b.vel.y = b.flipped ? -bounceSpeed(for: b.size) : -abs(b.vel.y)
                    if b.flipped { events.append(.bubbleBounced(id: b.id)) }
                }
            } else {
                b.pos.x += n.x * penetration
                b.vel.x = n.x > 0 ? abs(b.vel.x) : -abs(b.vel.x)
            }
        }
        bubbles[i] = b
    }

    private func hitBubble(id: Int) {
        var work = [id]
        var visited = Set<Int>()
        while let current = work.popLast() {
            guard !visited.contains(current), let idx = bubbles.firstIndex(where: { $0.id == current }) else { continue }
            visited.insert(current)
            var b = bubbles[idx]

            if b.kind == .armored && b.hitsLeft > 1 {
                b.hitsLeft -= 1
                bubbles[idx] = b
                score += 20
                events.append(.armorCracked(at: b.pos))
                continue
            }

            bubbles.remove(at: idx)
            registerCombo()
            score += b.size.points * combo
            let childSize = b.size.smaller
            if childSize == nil {
                events.append(.bubblePopped(at: b.pos, size: b.size, kind: b.kind, combo: combo))
            } else {
                events.append(.bubbleSplit(at: b.pos, size: b.size, kind: b.kind, combo: combo))
            }

            if b.kind == .lightning {
                for other in bubbles where other.pos.distance(to: b.pos) < GameModel.lightningRange + other.radius {
                    events.append(.lightning(from: b.pos, to: other.pos))
                    work.append(other.id)
                }
            }
            if b.kind == .golden {
                spawnPickup(at: b.pos, kind: randomPowerUp())
            } else if childSize == nil && randomUnit() < GameModel.pickupDropChance {
                spawnPickup(at: b.pos, kind: randomPowerUp())
            }
            if let next = childSize { spawnChildren(of: b, size: next) }
        }

        if bubbles.isEmpty, case .level = mode, celebrationTimer <= 0 {
            celebrationTimer = GameModel.celebration
            clearTime = elapsed
            timeScale = GameModel.celebrationTimeScale
            if let last = events.last, case .bubblePopped(let at, _, _, _) = last {
                events.append(.finalPop(at: at))
            } else {
                events.append(.finalPop(at: Vec2(x: spec.width / 2, y: spec.height / 2)))
            }
        }
    }

    private func spawnChildren(of parent: Bubble, size: BubbleSize) {
        let kind: BubbleKind = parent.kind == .flipped ? .flipped : .plain
        let kick = 0.45 * bounceSpeed(for: size) * (parent.flipped ? -1 : 1)
        let s = size.horizontalSpeed
        let directions: [(Double, Double)] = parent.kind == .triple ? [(-s, kick), (0, kick * 1.3), (s, kick)] : [(-s, kick), (s, kick)]
        for (vx, vy) in directions {
            let offset = vx == 0 ? 0 : (vx > 0 ? 0.15 : -0.15)
            spawnBubble(at: Vec2(x: parent.pos.x + offset, y: parent.pos.y), size: size, kind: kind, vx: vx, vy: vy, grace: 0.35)
        }
    }

    private func registerCombo() {
        combo = min(combo + 1, GameModel.maxCombo)
        comboTimer = GameModel.comboWindow
    }

    // MARK: Pickups

    private func randomPowerUp() -> PowerUpKind {
        let all = PowerUpKind.allCases
        return all[Int(randomUnit() * Double(all.count)) % all.count]
    }

    private func spawnPickup(at pos: Vec2, kind: PowerUpKind) {
        var p = pos
        p.x = min(max(p.x, Pickup.radius), spec.width - Pickup.radius)
        pickups.append(Pickup(id: takeID(), kind: kind, pos: p, vy: 0, ttl: GameModel.pickupLifetime))
    }

    private func updatePickups(_ dt: Double) {
        for i in pickups.indices {
            var p = pickups[i]
            let prevBottom = p.pos.y - Pickup.radius
            p.vy -= GameModel.gravity * dt
            p.pos.y += p.vy * dt
            let ground = groundLevel(x: p.pos.x, below: prevBottom)
            if p.pos.y - Pickup.radius <= ground {
                p.pos.y = ground + Pickup.radius
                p.vy = 0
            }
            p.ttl -= dt
            pickups[i] = p
        }
        pickups.removeAll { $0.ttl <= 0 }
    }

    private func apply(_ kind: PowerUpKind, to i: Int) {
        switch kind {
        case .doubleShot:
            players[i].weapon = .double
            players[i].weaponTimer = GameModel.weaponDuration
        case .sticky:
            players[i].weapon = .sticky
            players[i].weaponTimer = GameModel.weaponDuration
        case .rapid:
            players[i].weapon = .rapid
            players[i].weaponTimer = GameModel.weaponDuration
        case .shield:
            players[i].shield = true
        case .freeze:
            freezeTimer = GameModel.freezeDuration
            events.append(.freezeStarted)
        }
    }

    // MARK: Collisions with players

    private func resolvePlayerCollisions() {
        for i in players.indices where players[i].alive {
            let box = players[i].box

            if let pi = pickups.firstIndex(where: { box.overlapsCircle(center: $0.pos, radius: Pickup.radius) }) {
                let pickup = pickups.remove(at: pi)
                apply(pickup.kind, to: i)
                events.append(.pickupCollected(kind: pickup.kind, player: i, at: pickup.pos))
            }

            guard players[i].invulnerable <= 0 else { continue }
            guard let bi = bubbles.firstIndex(where: { $0.spawnGrace <= 0 && box.overlapsCircle(center: $0.pos, radius: $0.radius) }) else { continue }
            let bubble = bubbles[bi]
            if players[i].shield {
                players[i].shield = false
                players[i].invulnerable = 1.0
                events.append(.shieldBroken(player: i, at: bubble.pos))
                hitBubble(id: bubble.id)
            } else {
                killPlayer(at: i)
            }
        }
    }

    private func killPlayer(at i: Int) {
        players[i].alive = false
        players[i].respawnTimer = GameModel.respawnDelay
        players[i].weapon = .normal
        players[i].onLadder = false
        deaths += 1
        combo = 0
        comboTimer = 0
        harpoons.removeAll { $0.owner == i }
        events.append(.playerHit(player: i, at: players[i].pos))
        switch mode {
        case .level:
            // The room holds its breath while you get back up: no reset, no lost progress.
            freezeTimer = max(freezeTimer, GameModel.deathFreeze)
        case .storm:
            hearts -= 1
            if hearts <= 0 {
                isOver = true
                events.append(.gameOver(score: score))
            } else {
                freezeTimer = max(freezeTimer, GameModel.deathFreeze)
            }
        }
    }

    // MARK: Level end

    private func finishLevel() {
        isOver = true
        timeScale = 1
        let result = LevelResult(score: score, time: clearTime, deaths: deaths, par: level.par)
        events.append(.levelCleared(result))
    }

    // MARK: Storm

    private func updateStorm(_ dt: Double) {
        stormTimer -= dt
        guard stormTimer <= 0 else { return }
        stormInterval = max(2.5, 6.0 - elapsed / 60.0 * 1.2)
        stormTimer = stormInterval
        guard bubbles.count < GameModel.maxStormBubbles else { return }

        let sizeRoll = randomUnit()
        let size: BubbleSize = sizeRoll < 0.5 ? .large : (sizeRoll < 0.85 ? .medium : .small)
        var kind = BubbleKind.plain
        if elapsed > 30 {
            let roll = randomUnit()
            if roll < 0.12 { kind = .armored }
            else if roll < 0.20 { kind = .triple }
            else if roll < 0.28 { kind = .flipped }
            else if roll < 0.35 { kind = .lightning }
            else if roll < 0.40 { kind = .golden }
        }
        let id = spawnStormBubble(size: size, kind: kind)
        events.append(.stormSpawn(id: id))
    }

    @discardableResult
    private func spawnStormBubble(size: BubbleSize, kind: BubbleKind) -> Int {
        let r = size.radius
        let x = r + 0.5 + randomUnit() * (spec.width - 2 * r - 1.0)
        let y = kind == .flipped ? spec.height * 0.55 : spec.height - r - 0.1
        let dir: Double = randomUnit() < 0.5 ? -1 : 1
        return spawnBubble(at: Vec2(x: x, y: y), size: size, kind: kind, vx: dir * size.horizontalSpeed, vy: 0, grace: 1.0)
    }
}
