import Foundation

/// Which shape of screen we are drawing for. Decided from the view's size alone, so a folded Duo
/// and a regular iPhone both get `.tall`, an open Duo held sideways (or an iPad) gets `.wide`, and
/// an open Duo held upright gets `.upright`. Nothing here depends on a fold API; if Apple ships one
/// it can feed in as a hint later.
enum LayoutMode: String, Codable, CaseIterable {
    /// Phones in portrait: 9 × 16 units.
    case tall
    /// Landscape screens: 16 × 12 units, room for two players side by side.
    case wide
    /// Big portrait screens (open Duo upright, iPad portrait): 12 × 16 units.
    case upright

    /// Anything this squat (width / height) is landscape and therefore wide.
    static let landscapeAspect = 0.95
    /// Portrait screens squarer than this *and* at least `wideMinimumPoints` across are wide: an
    /// open Duo or an iPad. The Duo's cover screen is rumoured to be almost as square (~0.68) but
    /// much smaller, which is why size is part of the test. A regular iPhone sits near 0.46.
    static let portraitWideAspect = 0.6
    static let wideMinimumPoints = 600.0

    static func forSize(width: Double, height: Double) -> LayoutMode {
        guard width > 0, height > 0 else { return .tall }
        let aspect = width / height
        if aspect > landscapeAspect { return .wide }
        if aspect > portraitWideAspect && min(width, height) >= wideMinimumPoints { return .upright }
        return .tall
    }

    /// Whether a screen of this size should be allowed to rotate. Portrait-only screens keep the
    /// tall arena; a screen that is big enough for the upright arena may turn sideways into wide.
    static func allowsRotation(screenWidth: Double, screenHeight: Double) -> Bool {
        forSize(width: min(screenWidth, screenHeight), height: max(screenWidth, screenHeight)) != .tall
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
        case .upright:
            width = 12
            height = 16
        }
    }

    /// Horizontal speeds are tuned for the 9-unit-wide phone arena; wider arenas scale them up so
    /// a bubble (or the player) takes the same time to cross the screen whatever its shape.
    var horizontalScale: Double { width / 9 }

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
