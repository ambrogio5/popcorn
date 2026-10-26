import Foundation

/// 2D vector in arena units.
struct Vec2: Equatable, Codable {
    var x: Double
    var y: Double

    static let zero = Vec2(x: 0, y: 0)

    var length: Double { (x * x + y * y).squareRoot() }

    func distance(to other: Vec2) -> Double { (self - other).length }

    static func + (lhs: Vec2, rhs: Vec2) -> Vec2 { Vec2(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    static func - (lhs: Vec2, rhs: Vec2) -> Vec2 { Vec2(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    static func * (lhs: Vec2, rhs: Double) -> Vec2 { Vec2(x: lhs.x * rhs, y: lhs.y * rhs) }
    static func += (lhs: inout Vec2, rhs: Vec2) { lhs = lhs + rhs }
}

/// Axis-aligned box in arena units.
struct Box: Equatable {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double

    var width: Double { maxX - minX }
    var height: Double { maxY - minY }
    var midX: Double { (minX + maxX) / 2 }
    var midY: Double { (minY + maxY) / 2 }

    func intersects(_ other: Box) -> Bool {
        minX < other.maxX && maxX > other.minX && minY < other.maxY && maxY > other.minY
    }

    func containsX(_ x: Double) -> Bool { x >= minX && x <= maxX }

    /// Closest point inside the box to `p`.
    func closestPoint(to p: Vec2) -> Vec2 {
        Vec2(x: min(max(p.x, minX), maxX), y: min(max(p.y, minY), maxY))
    }

    func overlapsCircle(center: Vec2, radius: Double) -> Bool {
        closestPoint(to: center).distance(to: center) < radius
    }
}

/// Small deterministic random generator so levels and tests are reproducible.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
