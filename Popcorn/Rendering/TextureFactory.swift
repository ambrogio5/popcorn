import SpriteKit
import UIKit

/// Hands out every sprite the game needs. Real art wins: when `Assets.xcassets` has an image set
/// with the name `docs/ART_BRIEF.md` gives for an asset, that image is used. Otherwise the asset
/// is drawn with Core Graphics as a placeholder, so the project builds and plays without any
/// external art. The call sites never know which one they got.
enum TextureFactory {
    private static var cache: [String: SKTexture] = [:]
    private static var missingAssets: Set<String> = []

    /// The image set called `name`, or nil when the project does not have one (yet).
    static func asset(_ name: String) -> SKTexture? {
        let key = "asset.\(name)"
        if let t = cache[key] { return t }
        if missingAssets.contains(name) { return nil }
        guard let image = UIImage(named: name) else {
            missingAssets.insert(name)
            return nil
        }
        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    /// `"Hong Kong"` → `"hongkong"`, the way the brief names the skyline files.
    static func assetSlug(for city: City) -> String {
        city.name.lowercased().filter { !$0.isWhitespace }
    }

    private static func cached(_ key: String, size: CGSize, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let t = cache[key] { return t }
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in draw(ctx.cgContext, size) }
        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    static func clearCache() {
        cache.removeAll()
        missingAssets.removeAll()
    }

    // MARK: Bubbles

    static func bubble(size: BubbleSize, kind: BubbleKind, diameter: CGFloat) -> SKTexture {
        // Plain and flipped bubbles have one design per size; the special kinds have one design.
        let name = kind == .plain || kind == .flipped ? "bubble-\(kind.rawValue)-\(size.rawValue)" : "bubble-\(kind.rawValue)"
        if let art = asset(name) { return art }
        let d = max(8, diameter.rounded())
        return cached("bubble.\(size.rawValue).\(kind.rawValue).\(Int(d))", size: CGSize(width: d, height: d)) { cg, _ in
            let tint = Palette.bubble(size, kind: kind)
            let rect = CGRect(x: 0, y: 0, width: d, height: d).insetBy(dx: d * 0.03, dy: d * 0.03)
            let colors = [tint.lighter(0.55).cgColor, tint.cgColor, tint.darker(0.45).cgColor] as CFArray
            let locations: [CGFloat] = [0, 0.55, 1]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                cg.saveGState()
                cg.addEllipse(in: rect)
                cg.clip()
                cg.drawRadialGradient(gradient,
                                      startCenter: CGPoint(x: d * 0.38, y: d * 0.36), startRadius: 0,
                                      endCenter: CGPoint(x: d * 0.5, y: d * 0.5), endRadius: d * 0.52,
                                      options: .drawsAfterEndLocation)
                cg.restoreGState()
            }
            cg.setStrokeColor(tint.darker(0.55).withAlphaComponent(0.9).cgColor)
            cg.setLineWidth(max(1.5, d * 0.035))
            cg.strokeEllipse(in: rect)

            // Gloss
            cg.setFillColor(UIColor.white.withAlphaComponent(0.55).cgColor)
            cg.fillEllipse(in: CGRect(x: d * 0.22, y: d * 0.13, width: d * 0.30, height: d * 0.17))
            cg.setFillColor(UIColor.white.withAlphaComponent(0.25).cgColor)
            cg.fillEllipse(in: CGRect(x: d * 0.16, y: d * 0.30, width: d * 0.09, height: d * 0.09))

            drawKindMark(kind, in: cg, diameter: d)
        }
    }

    private static func drawKindMark(_ kind: BubbleKind, in cg: CGContext, diameter d: CGFloat) {
        let c = CGPoint(x: d / 2, y: d / 2)
        let ink = UIColor(white: 0.1, alpha: 0.7).cgColor
        let paper = UIColor.white.withAlphaComponent(0.85).cgColor
        cg.setLineCap(.round)
        cg.setLineJoin(.round)
        switch kind {
        case .plain:
            break
        case .armored:
            // Rivet band
            cg.setStrokeColor(ink)
            cg.setLineWidth(max(2, d * 0.06))
            cg.strokeEllipse(in: CGRect(x: c.x - d * 0.34, y: c.y - d * 0.34, width: d * 0.68, height: d * 0.68))
            cg.setFillColor(paper)
            for i in 0..<6 {
                let a = CGFloat(i) / 6 * .pi * 2
                let p = CGPoint(x: c.x + cos(a) * d * 0.34, y: c.y + sin(a) * d * 0.34)
                cg.fillEllipse(in: CGRect(x: p.x - d * 0.045, y: p.y - d * 0.045, width: d * 0.09, height: d * 0.09))
            }
        case .lightning:
            let bolt = UIBezierPath()
            bolt.move(to: CGPoint(x: c.x + d * 0.08, y: c.y - d * 0.30))
            bolt.addLine(to: CGPoint(x: c.x - d * 0.12, y: c.y + d * 0.04))
            bolt.addLine(to: CGPoint(x: c.x + d * 0.02, y: c.y + d * 0.04))
            bolt.addLine(to: CGPoint(x: c.x - d * 0.08, y: c.y + d * 0.30))
            bolt.addLine(to: CGPoint(x: c.x + d * 0.14, y: c.y - d * 0.04))
            bolt.addLine(to: CGPoint(x: c.x, y: c.y - d * 0.04))
            bolt.close()
            cg.setFillColor(paper)
            cg.addPath(bolt.cgPath)
            cg.fillPath()
        case .flipped:
            // Arrow pointing up (UIKit y is down, so draw towards smaller y)
            cg.setStrokeColor(paper)
            cg.setLineWidth(max(2, d * 0.07))
            cg.move(to: CGPoint(x: c.x, y: c.y + d * 0.26))
            cg.addLine(to: CGPoint(x: c.x, y: c.y - d * 0.26))
            cg.move(to: CGPoint(x: c.x - d * 0.18, y: c.y - d * 0.06))
            cg.addLine(to: CGPoint(x: c.x, y: c.y - d * 0.26))
            cg.addLine(to: CGPoint(x: c.x + d * 0.18, y: c.y - d * 0.06))
            cg.strokePath()
        case .triple:
            cg.setFillColor(paper)
            for (dx, dy) in [(-0.2, 0.12), (0.2, 0.12), (0.0, -0.2)] {
                let p = CGPoint(x: c.x + d * CGFloat(dx), y: c.y + d * CGFloat(dy))
                cg.fillEllipse(in: CGRect(x: p.x - d * 0.08, y: p.y - d * 0.08, width: d * 0.16, height: d * 0.16))
            }
        case .golden:
            cg.setFillColor(paper)
            cg.addPath(starPath(center: c, outer: d * 0.3, inner: d * 0.13).cgPath)
            cg.fillPath()
        }
    }

    static func starPath(center c: CGPoint, outer: CGFloat, inner: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        for i in 0..<10 {
            let r = i % 2 == 0 ? outer : inner
            let a = CGFloat(i) / 10 * .pi * 2 - .pi / 2
            let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.close()
        return path
    }

    // MARK: Players

    /// The animation frames the art pack ships per player; the raw value is the image-set suffix.
    enum PlayerFrame: String {
        case stand = ""
        case walkA = "-walk-a"
        case walkB = "-walk-b"
        case climb = "-climb"
        case hit = "-hit"
        case cheer = "-cheer"
    }

    /// A round little bubble-buster. Anchor the sprite at (0.5, 0) so it stands on its position.
    /// Frames other than `stand` fall back to the standing frame when the art is missing.
    static func player(index: Int, frame: PlayerFrame = .stand, height: CGFloat) -> SKTexture {
        if let art = asset("player-\(index + 1)\(frame.rawValue)") { return art }
        if frame != .stand { return player(index: index, frame: .stand, height: height) }
        let h = max(12, height.rounded())
        let w = (h * CGFloat(Player.width / Player.height)).rounded()
        return cached("player.\(index).\(Int(h))", size: CGSize(width: w, height: h)) { cg, size in
            let tint = Palette.player(index)
            let skin = UIColor(hex: "#FFD9B3")
            let bodyRect = CGRect(x: size.width * 0.12, y: size.height * 0.42, width: size.width * 0.76, height: size.height * 0.56)
            cg.setFillColor(tint.cgColor)
            cg.addPath(UIBezierPath(roundedRect: bodyRect, cornerRadius: size.width * 0.25).cgPath)
            cg.fillPath()
            // Belt
            cg.setFillColor(tint.darker(0.4).cgColor)
            cg.fill(CGRect(x: bodyRect.minX, y: size.height * 0.72, width: bodyRect.width, height: size.height * 0.06))
            // Feet
            cg.setFillColor(UIColor(hex: "#2B2B3A").cgColor)
            cg.fillEllipse(in: CGRect(x: size.width * 0.08, y: size.height * 0.9, width: size.width * 0.38, height: size.height * 0.1))
            cg.fillEllipse(in: CGRect(x: size.width * 0.54, y: size.height * 0.9, width: size.width * 0.38, height: size.height * 0.1))
            // Head
            let headRect = CGRect(x: size.width * 0.14, y: size.height * 0.12, width: size.width * 0.72, height: size.width * 0.72)
            cg.setFillColor(skin.cgColor)
            cg.fillEllipse(in: headRect)
            // Cap
            cg.setFillColor(tint.darker(0.2).cgColor)
            cg.addPath(UIBezierPath(roundedRect: CGRect(x: headRect.minX - size.width * 0.04, y: headRect.minY - size.height * 0.03,
                                                        width: headRect.width + size.width * 0.08, height: headRect.height * 0.5),
                                    cornerRadius: size.width * 0.2).cgPath)
            cg.fillPath()
            cg.fill(CGRect(x: headRect.midX, y: headRect.minY + headRect.height * 0.38, width: headRect.width * 0.6, height: size.height * 0.05))
            // Eyes, looking right; the sprite is mirrored for the other direction
            cg.setFillColor(UIColor(hex: "#1B1B2F").cgColor)
            cg.fillEllipse(in: CGRect(x: headRect.midX + headRect.width * 0.05, y: headRect.midY + headRect.height * 0.02, width: size.width * 0.1, height: size.width * 0.12))
            cg.fillEllipse(in: CGRect(x: headRect.midX + headRect.width * 0.25, y: headRect.midY + headRect.height * 0.02, width: size.width * 0.1, height: size.width * 0.12))
        }
    }

    // MARK: Arena, controls and effects

    // These have no Core Graphics placeholder: the scenes keep drawing their own paths when
    // the image set is missing, so each is optional.
    static var platformTile: SKTexture? { asset("platform-tile") }
    static var ladderTile: SKTexture? { asset("ladder-tile") }
    static var harpoonTip: SKTexture? { asset("harpoon-tip") }
    static var harpoonLine: SKTexture? { asset("harpoon-line") }
    static var pauseIcon: SKTexture? { asset("icon-pause") }
    static var fireIcon: SKTexture? { asset("icon-fire") }
    static var stickBase: SKTexture? { asset("stick-base") }
    static var stickKnob: SKTexture? { asset("stick-knob") }

    /// The sharper particle for pops; the soft one when the pack is not there.
    static func spark() -> SKTexture { asset("particle-spark") ?? particle() }

    // MARK: Pickups and HUD

    static func pickup(kind: PowerUpKind, diameter: CGFloat) -> SKTexture {
        if let art = asset("pickup-\(kind == .doubleShot ? "double" : kind.rawValue)") { return art }
        let d = max(8, diameter.rounded())
        return cached("pickup.\(kind.rawValue).\(Int(d))", size: CGSize(width: d, height: d)) { cg, _ in
            let tint = Palette.pickup(kind)
            let rect = CGRect(x: d * 0.06, y: d * 0.06, width: d * 0.88, height: d * 0.88)
            cg.setFillColor(tint.cgColor)
            cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: d * 0.26).cgPath)
            cg.fillPath()
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            cg.setLineWidth(max(1.5, d * 0.06))
            cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: d * 0.26).cgPath)
            cg.strokePath()
            let ink = UIColor(hex: "#1B1B2F").cgColor
            cg.setStrokeColor(ink)
            cg.setFillColor(ink)
            cg.setLineWidth(max(2, d * 0.09))
            cg.setLineCap(.round)
            let c = CGPoint(x: d / 2, y: d / 2)
            switch kind {
            case .doubleShot:
                for dx in [-0.14, 0.14] {
                    cg.move(to: CGPoint(x: c.x + d * CGFloat(dx), y: c.y + d * 0.26))
                    cg.addLine(to: CGPoint(x: c.x + d * CGFloat(dx), y: c.y - d * 0.26))
                }
                cg.strokePath()
            case .sticky:
                cg.move(to: CGPoint(x: c.x, y: c.y + d * 0.28))
                cg.addLine(to: CGPoint(x: c.x, y: c.y - d * 0.16))
                cg.strokePath()
                cg.fillEllipse(in: CGRect(x: c.x - d * 0.14, y: c.y - d * 0.32, width: d * 0.28, height: d * 0.2))
            case .rapid:
                for dx in [-0.22, 0.0, 0.22] {
                    cg.move(to: CGPoint(x: c.x + d * CGFloat(dx), y: c.y + d * 0.24))
                    cg.addLine(to: CGPoint(x: c.x + d * CGFloat(dx), y: c.y - d * 0.24))
                }
                cg.strokePath()
            case .shield:
                let shield = UIBezierPath()
                shield.move(to: CGPoint(x: c.x, y: c.y - d * 0.3))
                shield.addLine(to: CGPoint(x: c.x + d * 0.26, y: c.y - d * 0.18))
                shield.addCurve(to: CGPoint(x: c.x, y: c.y + d * 0.3), controlPoint1: CGPoint(x: c.x + d * 0.26, y: c.y + d * 0.1), controlPoint2: CGPoint(x: c.x + d * 0.14, y: c.y + d * 0.26))
                shield.addCurve(to: CGPoint(x: c.x - d * 0.26, y: c.y - d * 0.18), controlPoint1: CGPoint(x: c.x - d * 0.14, y: c.y + d * 0.26), controlPoint2: CGPoint(x: c.x - d * 0.26, y: c.y + d * 0.1))
                shield.close()
                cg.addPath(shield.cgPath)
                cg.fillPath()
            case .freeze:
                for i in 0..<3 {
                    let a = CGFloat(i) / 3 * .pi
                    cg.move(to: CGPoint(x: c.x + cos(a) * d * 0.28, y: c.y + sin(a) * d * 0.28))
                    cg.addLine(to: CGPoint(x: c.x - cos(a) * d * 0.28, y: c.y - sin(a) * d * 0.28))
                }
                cg.strokePath()
            }
        }
    }

    static func particle(diameter: CGFloat = 16) -> SKTexture {
        if let art = asset("particle-soft") { return art }
        return cached("particle.\(Int(diameter))", size: CGSize(width: diameter, height: diameter)) { cg, size in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                cg.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: size.width / 2, options: [])
            }
        }
    }

    static func star(filled: Bool, size s: CGFloat) -> SKTexture {
        if let art = asset(filled ? "star-on" : "star-off") { return art }
        return cached("star.\(filled).\(Int(s))", size: CGSize(width: s, height: s)) { cg, size in
            let path = starPath(center: CGPoint(x: size.width / 2, y: size.height / 2), outer: s * 0.48, inner: s * 0.22)
            cg.setFillColor((filled ? Palette.star : Palette.starOff).cgColor)
            cg.addPath(path.cgPath)
            cg.fillPath()
        }
    }

    static func heart(size s: CGFloat) -> SKTexture {
        if let art = asset("heart") { return art }
        return cached("heart.\(Int(s))", size: CGSize(width: s, height: s)) { cg, size in
            let w = size.width, h = size.height
            let path = UIBezierPath()
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.9))
            path.addCurve(to: CGPoint(x: w * 0.05, y: h * 0.35), controlPoint1: CGPoint(x: w * 0.2, y: h * 0.72), controlPoint2: CGPoint(x: w * 0.05, y: h * 0.55))
            path.addArc(withCenter: CGPoint(x: w * 0.275, y: h * 0.3), radius: w * 0.225, startAngle: .pi, endAngle: 0, clockwise: true)
            path.addArc(withCenter: CGPoint(x: w * 0.725, y: h * 0.3), radius: w * 0.225, startAngle: .pi, endAngle: 0, clockwise: true)
            path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.9), controlPoint1: CGPoint(x: w * 0.95, y: h * 0.55), controlPoint2: CGPoint(x: w * 0.8, y: h * 0.72))
            path.close()
            cg.setFillColor(UIColor(hex: "#FF5E7E").cgColor)
            cg.addPath(path.cgPath)
            cg.fillPath()
        }
    }

    /// Vertical sky gradient from the city's two sky colours, with the city's skyline strip
    /// (`skyline-<city>`, tiled along the bottom) when the project has one, or a procedural
    /// skyline otherwise.
    static func background(city: City, cityIndex: Int, size: CGSize) -> SKTexture {
        let w = max(2, size.width.rounded()), h = max(2, size.height.rounded())
        let strip = UIImage(named: "skyline-\(assetSlug(for: city))")
        return cached("bg.\(cityIndex).\(Int(w))x\(Int(h))", size: CGSize(width: w, height: h)) { cg, _ in
            let top = UIColor(hex: city.skyTop), bottom = UIColor(hex: city.skyBottom)
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1]) {
                cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: h), options: [])
            }
            // Stars / lights in the upper sky
            var rng = SplitMix64(seed: UInt64(cityIndex + 1) * 7919)
            cg.setFillColor(UIColor.white.withAlphaComponent(0.35).cgColor)
            for _ in 0..<60 {
                let x = CGFloat(Double.random(in: 0..<1, using: &rng)) * w
                let y = CGFloat(Double.random(in: 0..<0.5, using: &rng)) * h
                let r = CGFloat(Double.random(in: 0.6..<1.8, using: &rng))
                cg.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
            let ground = UIColor(hex: city.ground)
            if let strip, strip.size.width > 0, strip.size.height > 0 {
                // Real skyline: a tileable strip, transparent above the rooftops. Scale it to
                // about a third of the screen height and repeat it across the bottom.
                cg.setFillColor(ground.cgColor)
                cg.fill(CGRect(x: 0, y: h - h * 0.06, width: w, height: h * 0.06))
                let tileH = (h * 0.3).rounded()
                let tileW = max(1, (tileH * strip.size.width / strip.size.height).rounded())
                var tx: CGFloat = 0
                while tx < w {
                    strip.draw(in: CGRect(x: tx, y: h - tileH, width: tileW, height: tileH))
                    tx += tileW
                }
                return
            }
            // Placeholder skyline: random blocks along the bottom
            cg.setFillColor(ground.withAlphaComponent(0.55).cgColor)
            var x: CGFloat = -10
            while x < w + 10 {
                let bw = CGFloat(Double.random(in: 18..<70, using: &rng))
                let bh = CGFloat(Double.random(in: 0.08..<0.3, using: &rng)) * h
                cg.fill(CGRect(x: x, y: h - bh, width: bw, height: bh))
                x += bw + CGFloat(Double.random(in: 2..<14, using: &rng))
            }
            cg.setFillColor(ground.cgColor)
            cg.fill(CGRect(x: 0, y: h - h * 0.06, width: w, height: h * 0.06))
        }
    }
}
