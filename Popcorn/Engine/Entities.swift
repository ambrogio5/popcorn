import Foundation

enum GameMode: Equatable {
    case level(Level)
    case storm
}

struct PlayerInput: Equatable {
    /// -1, 0 or 1.
    var moveX: Double = 0
    /// -1, 0 or 1. Positive is up a ladder.
    var moveY: Double = 0
    var fire = false

    /// Combines touch and controller input: whichever is active wins.
    func merged(with other: PlayerInput) -> PlayerInput {
        PlayerInput(moveX: moveX != 0 ? moveX : other.moveX,
                    moveY: moveY != 0 ? moveY : other.moveY,
                    fire: fire || other.fire)
    }
}

enum Weapon: Equatable {
    case normal
    case double
    case sticky
    case rapid
}

enum PowerUpKind: String, CaseIterable, Codable {
    case doubleShot
    case sticky
    case rapid
    case shield
    case freeze

    var title: String {
        switch self {
        case .doubleShot: return String(localized: "Double shot")
        case .sticky: return String(localized: "Sticky line")
        case .rapid: return String(localized: "Rapid fire")
        case .shield: return String(localized: "Shield")
        case .freeze: return String(localized: "Freeze")
        }
    }
}

struct Player: Equatable {
    static let width = 0.9
    static let height = 1.4
    static let speed = 6.0
    static let climbSpeed = 4.0

    let index: Int
    /// Bottom centre.
    var pos: Vec2
    var vy = 0.0
    var facing = 1.0
    var onLadder = false
    var ladderIndex = 0
    var grounded = true
    var alive = true
    var respawnTimer = 0.0
    var invulnerable = 0.0
    /// Extra shield time already spent waiting for a bubble to move off the spawn (see
    /// `GameModel.overlapGraceCap`). Reset on every (re)spawn.
    var overlapGrace = 0.0
    var shield = false
    var weapon = Weapon.normal
    var weaponTimer = 0.0
    var fireCooldown = 0.0
    var fireHeld = false
    var input = PlayerInput()

    var box: Box {
        Box(minX: pos.x - Player.width / 2, minY: pos.y, maxX: pos.x + Player.width / 2, maxY: pos.y + Player.height)
    }
}

struct Bubble: Equatable, Identifiable {
    let id: Int
    var pos: Vec2
    var vel: Vec2
    var size: BubbleSize
    var kind: BubbleKind
    var hitsLeft: Int
    /// Seconds during which the bubble cannot hurt a player (fresh splits and spawns).
    var spawnGrace: Double

    var flipped: Bool { kind == .flipped }
    var radius: Double { size.radius }
}

struct Harpoon: Equatable, Identifiable {
    let id: Int
    let owner: Int
    var x: Double
    var bottom: Double
    var top: Double
    var speed: Double
    var sticky: Bool
    /// True once the line has reached the ceiling or a platform and is lingering.
    var stuck = false
    var stuckTimer = 0.0
}

struct Pickup: Equatable, Identifiable {
    static let radius = 0.45

    let id: Int
    let kind: PowerUpKind
    /// Centre.
    var pos: Vec2
    var vy: Double
    var ttl: Double
}

struct LevelResult: Equatable {
    var score: Int
    var time: Double
    var deaths: Int
    var par: Double

    var stars: Int { 1 + (deaths == 0 ? 1 : 0) + (time <= par ? 1 : 0) }
}

/// Things that happened during an update, for the scene to turn into sound, particles and shakes.
enum GameEvent: Equatable {
    case bubbleBounced(id: Int)
    case bubbleSplit(at: Vec2, size: BubbleSize, kind: BubbleKind, combo: Int)
    case bubblePopped(at: Vec2, size: BubbleSize, kind: BubbleKind, combo: Int)
    case armorCracked(at: Vec2)
    case lightning(from: Vec2, to: Vec2)
    case harpoonFired(player: Int)
    case harpoonBlocked(at: Vec2)
    case playerHit(player: Int, at: Vec2)
    case shieldBroken(player: Int, at: Vec2)
    case playerRespawned(player: Int)
    case pickupCollected(kind: PowerUpKind, player: Int, at: Vec2)
    case freezeStarted
    case finalPop(at: Vec2)
    case levelCleared(LevelResult)
    case gameOver(score: Int)
    case stormSpawn(id: Int)
}
