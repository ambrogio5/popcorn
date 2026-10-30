import UIKit

extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }

    func lighter(_ amount: CGFloat) -> UIColor { blended(with: .white, amount: amount) }
    func darker(_ amount: CGFloat) -> UIColor { blended(with: .black, amount: amount) }

    func blended(with other: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = min(max(amount, 0), 1)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1)
    }
}

/// Fixed game colours. Bubble colours are per size so you can read the board at a glance; the
/// city only changes the sky.
enum Palette {
    static let text = UIColor.white
    static let dimText = UIColor(white: 1, alpha: 0.65)
    static let panel = UIColor(white: 0.05, alpha: 0.78)
    static let button = UIColor(hex: "#FFD166")
    static let buttonText = UIColor(hex: "#1B1B2F")
    /// Dark enough that the menu bubbles drifting behind a button no longer read through its label.
    static let secondaryButton = UIColor(white: 0.05, alpha: 0.55)
    static let harpoon = UIColor(hex: "#FFF3B0")
    static let platform = UIColor(hex: "#3E4A5E")
    static let platformEdge = UIColor(hex: "#9FB3C8")
    static let ladder = UIColor(hex: "#D9A066")
    static let frame = UIColor(white: 1, alpha: 0.22)
    static let player1 = UIColor(hex: "#3DD6D0")
    static let player2 = UIColor(hex: "#FF7A7A")
    static let star = UIColor(hex: "#FFD166")
    static let starOff = UIColor(white: 1, alpha: 0.2)

    static func bubble(_ size: BubbleSize) -> UIColor {
        switch size {
        case .large: return UIColor(hex: "#B084F5")
        case .medium: return UIColor(hex: "#5AA9FF")
        case .small: return UIColor(hex: "#5BE38A")
        case .tiny: return UIColor(hex: "#FFD84D")
        }
    }

    static func bubble(_ size: BubbleSize, kind: BubbleKind) -> UIColor {
        switch kind {
        case .plain: return bubble(size)
        case .armored: return UIColor(hex: "#9AA3AD")
        case .lightning: return UIColor(hex: "#5CE6FF")
        case .flipped: return bubble(size).darker(0.35)
        case .triple: return UIColor(hex: "#FF6FD8")
        case .golden: return UIColor(hex: "#FFC53D")
        }
    }

    static func pickup(_ kind: PowerUpKind) -> UIColor {
        switch kind {
        case .doubleShot: return UIColor(hex: "#FF9F43")
        case .sticky: return UIColor(hex: "#B8E986")
        case .rapid: return UIColor(hex: "#FF5E7E")
        case .shield: return UIColor(hex: "#6FC3FF")
        case .freeze: return UIColor(hex: "#CFF6FF")
        }
    }

    static func player(_ index: Int) -> UIColor { index == 0 ? player1 : player2 }
}

enum Fonts {
    static let title = "AvenirNext-Heavy"
    static let bold = "AvenirNext-Bold"
    static let medium = "AvenirNext-DemiBold"
}
