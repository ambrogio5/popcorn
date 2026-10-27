import Foundation

enum BubbleSize: String, Codable, CaseIterable {
    case tiny
    case small
    case medium
    case large

    /// Radius in arena units.
    var radius: Double {
        switch self {
        case .large: return 1.4
        case .medium: return 0.95
        case .small: return 0.6
        case .tiny: return 0.35
        }
    }

    /// Constant horizontal speed, units per second. Small bubbles are quicker, as in Pang.
    var horizontalSpeed: Double {
        switch self {
        case .large: return 2.8
        case .medium: return 3.4
        case .small: return 4.0
        case .tiny: return 4.8
        }
    }

    /// How high a bounce from the floor reaches, as a fraction of arena height.
    var apexFraction: Double {
        switch self {
        case .large: return 0.82
        case .medium: return 0.64
        case .small: return 0.46
        case .tiny: return 0.30
        }
    }

    var points: Int {
        switch self {
        case .large: return 50
        case .medium: return 100
        case .small: return 150
        case .tiny: return 200
        }
    }

    /// The size a hit bubble splits into, or nil if it pops.
    var smaller: BubbleSize? {
        switch self {
        case .large: return .medium
        case .medium: return .small
        case .small: return .tiny
        case .tiny: return nil
        }
    }
}

enum BubbleKind: String, Codable, CaseIterable {
    case plain
    /// Needs two hits; the first only cracks it.
    case armored
    /// Hitting it also hits every bubble nearby.
    case lightning
    /// Falls upward and bounces on the ceiling. Its children stay flipped.
    case flipped
    /// Splits into three instead of two.
    case triple
    /// Always drops a power-up.
    case golden
}

struct LevelPlatform: Codable, Equatable {
    /// Left edge, top edge and width, all normalised 0...1.
    var x: Double
    var y: Double
    var w: Double
}

struct LevelLadder: Codable, Equatable {
    var x: Double
    var y0: Double
    var y1: Double
}

struct LevelBubble: Codable, Equatable {
    var x: Double
    var y: Double
    var size: BubbleSize
    var kind: BubbleKind
    /// Initial horizontal direction: -1 or 1 (0 is allowed for tests only).
    var dir: Int
}

struct Level: Codable, Equatable, Identifiable {
    var id: Int
    var name: String
    /// Index into the cities list.
    var city: Int
    /// Par time in seconds for the third star.
    var par: Double
    var platforms: [LevelPlatform]
    var ladders: [LevelLadder]
    var bubbles: [LevelBubble]

    /// Layout used by Storm mode. Bubbles are spawned by the model, not the level.
    static let storm = Level(
        id: 0,
        name: "Storm",
        city: 0,
        par: 0,
        platforms: [LevelPlatform(x: 0.0, y: 0.35, w: 0.3), LevelPlatform(x: 0.7, y: 0.35, w: 0.3)],
        ladders: [LevelLadder(x: 0.15, y0: 0, y1: 0.35), LevelLadder(x: 0.85, y0: 0, y1: 0.35)],
        bubbles: []
    )
}

struct City: Codable, Equatable {
    var name: String
    var skyTop: String
    var skyBottom: String
    var ground: String
    var accent: String
}

/// Checks a level against the rules the generator and the engine both rely on. Mirrored by
/// Tools/validate_levels.py so the content pipeline and the app agree.
enum LevelValidator {
    static let minPlatformWidth = 0.15
    static let minPlatformY = 0.2
    static let maxPlatformY = 0.78
    static let minVerticalGap = 0.2
    static let spawnClearance = 3.0

    static func problems(in level: Level) -> [String] {
        var problems: [String] = []
        let eps = 1e-6

        if level.name.isEmpty { problems.append("missing name") }
        if level.id != 0 && level.par <= 0 { problems.append("par must be positive") }
        if level.id != 0 && level.bubbles.isEmpty { problems.append("no bubbles") }

        for (i, p) in level.platforms.enumerated() {
            if p.x < -eps || p.x + p.w > 1 + eps { problems.append("platform \(i) leaves the arena") }
            if p.w < minPlatformWidth - eps { problems.append("platform \(i) is too narrow") }
            if p.y < minPlatformY - eps || p.y > maxPlatformY + eps { problems.append("platform \(i) height out of range") }
            for (j, q) in level.platforms.enumerated() where j > i {
                let overlapX = p.x < q.x + q.w - eps && p.x + p.w > q.x + eps
                if overlapX && abs(p.y - q.y) < minVerticalGap - eps {
                    problems.append("platforms \(i) and \(j) are too close")
                }
            }
        }

        func platformIndex(atY y: Double, containingX x: Double) -> Int? {
            level.platforms.firstIndex { abs($0.y - y) < eps && x >= $0.x - eps && x <= $0.x + $0.w + eps }
        }

        for (i, l) in level.ladders.enumerated() {
            if l.x < 0.02 || l.x > 0.98 { problems.append("ladder \(i) leaves the arena") }
            if l.y1 <= l.y0 + eps { problems.append("ladder \(i) has no height") }
            if platformIndex(atY: l.y1, containingX: l.x) == nil { problems.append("ladder \(i) top is not on a platform") }
            if abs(l.y0) > eps && platformIndex(atY: l.y0, containingX: l.x) == nil {
                problems.append("ladder \(i) bottom is neither the floor nor a platform")
            }
        }

        // Every platform must be reachable from the floor by a chain of ladders.
        var reachable = Set<Int>()
        var changed = true
        while changed {
            changed = false
            for l in level.ladders {
                let fromFloor = abs(l.y0) < eps
                let fromReachable = platformIndex(atY: l.y0, containingX: l.x).map { reachable.contains($0) } ?? false
                guard fromFloor || fromReachable, let top = platformIndex(atY: l.y1, containingX: l.x) else { continue }
                if !reachable.contains(top) {
                    reachable.insert(top)
                    changed = true
                }
            }
        }
        for i in level.platforms.indices where !reachable.contains(i) {
            problems.append("platform \(i) cannot be reached")
        }

        for (i, b) in level.bubbles.enumerated() {
            if b.dir != -1 && b.dir != 1 { problems.append("bubble \(i) has an invalid direction") }
            for mode in LayoutMode.allCases {
                let spec = ArenaSpec(mode: mode)
                let c = spec.point(nx: b.x, ny: b.y)
                let r = b.size.radius
                if c.x - r < -eps || c.x + r > spec.width + eps || c.y - r < -eps || c.y + r > spec.height + eps {
                    problems.append("bubble \(i) leaves the \(mode.rawValue) arena")
                }
                for (j, p) in level.platforms.enumerated() where spec.platformBox(p).overlapsCircle(center: c, radius: r + 0.1) {
                    problems.append("bubble \(i) starts inside platform \(j) in \(mode.rawValue) mode")
                }
                for (j, other) in level.bubbles.enumerated() where j > i {
                    let oc = spec.point(nx: other.x, ny: other.y)
                    if oc.distance(to: c) < r + other.size.radius {
                        problems.append("bubbles \(i) and \(j) overlap in \(mode.rawValue) mode")
                    }
                }
                for count in 1...2 {
                    for player in 0..<count {
                        let spawn = spec.spawnPoint(player: player, of: count)
                        let chest = Vec2(x: spawn.x, y: spawn.y + 0.7)
                        if chest.distance(to: c) < r + spawnClearance {
                            problems.append("bubble \(i) starts on top of a player in \(mode.rawValue) mode")
                        }
                    }
                }
            }
        }
        return problems
    }
}
