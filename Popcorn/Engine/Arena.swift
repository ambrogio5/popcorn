import Foundation

/// Which shape of screen we are drawing for. Decided purely from the view's aspect ratio, so a
/// folded Duo and a regular iPhone both get `.tall`, and an open Duo (or an iPad) gets `.wide`.
/// Nothing here depends on a fold API; if Apple ships one it can feed in as a hint later.
enum LayoutMode: String, Codable {
    case tall
    case wide

    /// Aspect ratios (width / height) above this are treated as wide. A closed Duo or a regular
    /// iPhone in portrait sits near 0.46; an open Duo is about 0.75 or 1.33 depending on how it is held.
    static let wideThreshold = 0.7

    static func forSize(width: Double, height: Double) -> LayoutMode {
        guard height > 0 else { return .tall }
        return width / height > wideThreshold ? .wide : .tall
    }
}

/// The logical playfield. Levels are authored in normalised 0...1 coordinates and mapped into
/// these unit sizes, so a single level definition serves both screen shapes.
struct ArenaSpec: Equatable {
    let mode: LayoutMode
    let width: Double
    let height: Double

    /// Thickness of a platform, in units.
    static let platformThickness = 0.4

    init(mode: LayoutMode) {
        self.mode = mode
        switch mode {
        case .tall:
            width = 9
            height = 16
        case .wide:
            width = 16
            height = 12
        }
    }

    func point(nx: Double, ny: Double) -> Vec2 { Vec2(x: nx * width, y: ny * height) }

    func normalized(_ p: Vec2) -> Vec2 { Vec2(x: p.x / width, y: p.y / height) }

    func platformBox(_ platform: LevelPlatform) -> Box {
        let top = platform.y * height
        return Box(minX: platform.x * width,
                   minY: top - ArenaSpec.platformThickness,
                   maxX: (platform.x + platform.w) * width,
                   maxY: top)
    }

    func ladderBody(_ ladder: LevelLadder) -> LadderBody {
        LadderBody(x: ladder.x * width, bottom: ladder.y0 * height, top: ladder.y1 * height)
    }

    /// Where player `index` of `count` players stands at the start and after a respawn.
    func spawnPoint(player index: Int, of count: Int) -> Vec2 {
        if count <= 1 { return Vec2(x: width / 2, y: 0) }
        return Vec2(x: width * (index == 0 ? 0.35 : 0.65), y: 0)
    }
}

struct LadderBody: Equatable {
    var x: Double
    var bottom: Double
    var top: Double
}
