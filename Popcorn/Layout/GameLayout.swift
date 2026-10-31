import CoreGraphics
import UIKit

/// Where everything goes on screen for the current size and shape. Recomputed whenever the view
/// changes size, which is how a fold or unfold reaches the game.
struct GameLayout {
    static let hudHeight: CGFloat = 48
    static let margin: CGFloat = 8

    var sceneSize: CGSize = .zero
    var insets: UIEdgeInsets = .zero
    var mode: LayoutMode = .tall
    /// Points per arena unit.
    var unit: CGFloat = 1
    /// Bottom-left corner of the arena in scene coordinates.
    var arenaOrigin: CGPoint = .zero
    var arenaSize: CGSize = .zero
    var controlsRect: CGRect = .zero
    var hudRect: CGRect = .zero

    var arenaRect: CGRect { CGRect(origin: arenaOrigin, size: arenaSize) }

    static func controlsHeight(mode: LayoutMode, playerCount: Int) -> CGFloat {
        switch mode {
        case .tall, .upright: return 150
        case .wide: return playerCount > 1 ? 130 : 120
        }
    }

    /// A different shape has to fill this much more of the screen than the aspect-based default
    /// before it is chosen instead. Keeps phones on the tall arena while letting the squat Duo
    /// cover screen, where the tall arena would be a narrow strip, use the wide one.
    static let fillAdvantage: CGFloat = 1.4

    /// The arena shape to play in: the aspect-based default unless another shape makes a much
    /// bigger arena once the HUD, controls and safe areas have taken their share.
    static func bestMode(size: CGSize, insets: UIEdgeInsets, playerCount: Int) -> LayoutMode {
        let preferred = LayoutMode.forSize(width: Double(size.width), height: Double(size.height))
        func area(_ mode: LayoutMode) -> CGFloat {
            let layout = compute(size: size, insets: insets, spec: ArenaSpec(mode: mode), playerCount: playerCount)
            return layout.arenaSize.width * layout.arenaSize.height
        }
        let preferredArea = area(preferred)
        var best = preferred
        var bestArea = preferredArea
        for mode in LayoutMode.allCases where mode != preferred {
            let candidate = area(mode)
            if candidate > bestArea && candidate >= preferredArea * fillAdvantage {
                best = mode
                bestArea = candidate
            }
        }
        return best
    }

    static func compute(size: CGSize, insets: UIEdgeInsets, spec: ArenaSpec, playerCount: Int) -> GameLayout {
        var layout = GameLayout()
        layout.sceneSize = size
        layout.insets = insets
        layout.mode = spec.mode

        let controlsH = controlsHeight(mode: spec.mode, playerCount: playerCount)
        // Side insets are for the HUD only. The one screen that reports any is the Duo cover
        // screen, whose camera cut-out is a 40 pt circle in the top-right corner but comes back as
        // an 84 pt inset down the whole right edge; honouring it for the arena and the control
        // strip would give up a fifth of the width (and the wide arena with it). Phones never
        // rotate into a side inset, see `LayoutMode.allowsRotation`.
        let availW = max(1, size.width - 2 * margin)
        let availH = max(1, size.height - insets.top - insets.bottom - hudHeight - controlsH - 2 * margin)
        let unit = min(availW / CGFloat(spec.width), availH / CGFloat(spec.height))
        layout.unit = unit
        layout.arenaSize = CGSize(width: CGFloat(spec.width) * unit, height: CGFloat(spec.height) * unit)

        let arenaBottom = insets.bottom + controlsH + margin + (availH - layout.arenaSize.height) / 2
        layout.arenaOrigin = CGPoint(x: margin + (availW - layout.arenaSize.width) / 2, y: arenaBottom)
        layout.controlsRect = CGRect(x: 0, y: insets.bottom, width: size.width, height: controlsH)
        layout.hudRect = CGRect(x: insets.left + margin, y: size.height - insets.top - hudHeight,
                                width: size.width - insets.left - insets.right - 2 * margin, height: hudHeight)
        return layout
    }

    func point(_ v: Vec2) -> CGPoint {
        CGPoint(x: CGFloat(v.x) * unit, y: CGFloat(v.y) * unit)
    }

    func scenePoint(_ v: Vec2) -> CGPoint {
        CGPoint(x: arenaOrigin.x + CGFloat(v.x) * unit, y: arenaOrigin.y + CGFloat(v.y) * unit)
    }

    func rect(_ box: Box) -> CGRect {
        CGRect(x: CGFloat(box.minX) * unit, y: CGFloat(box.minY) * unit,
               width: CGFloat(box.width) * unit, height: CGFloat(box.height) * unit)
    }
}
