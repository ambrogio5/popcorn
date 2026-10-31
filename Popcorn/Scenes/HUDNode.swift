import SpriteKit

final class HUDNode: SKNode {
    private let titleLabel = SKLabelNode(fontNamed: Fonts.bold)
    private let subtitleLabel = SKLabelNode(fontNamed: Fonts.medium)
    private let scoreLabel = SKLabelNode(fontNamed: Fonts.title)
    private let comboLabel = SKLabelNode(fontNamed: Fonts.bold)
    private let statusLabel = SKLabelNode(fontNamed: Fonts.medium)
    private let pauseButton = SKShapeNode(circleOfRadius: 18)
    private var hearts: [SKSpriteNode] = []

    override init() {
        super.init()
        zPosition = 10
        titleLabel.fontSize = 16
        titleLabel.fontColor = Palette.text
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        addChild(titleLabel)

        subtitleLabel.fontSize = 13
        subtitleLabel.fontColor = Palette.dimText
        subtitleLabel.horizontalAlignmentMode = .left
        subtitleLabel.verticalAlignmentMode = .center
        addChild(subtitleLabel)

        scoreLabel.fontSize = 24
        scoreLabel.fontColor = Palette.text
        scoreLabel.verticalAlignmentMode = .center
        addChild(scoreLabel)

        comboLabel.fontSize = 13
        comboLabel.fontColor = Palette.star
        comboLabel.verticalAlignmentMode = .center
        addChild(comboLabel)

        statusLabel.fontSize = 12
        statusLabel.fontColor = Palette.dimText
        statusLabel.horizontalAlignmentMode = .right
        statusLabel.verticalAlignmentMode = .center
        addChild(statusLabel)

        pauseButton.fillColor = UIColor(white: 1, alpha: 0.14)
        pauseButton.strokeColor = UIColor(white: 1, alpha: 0.35)
        pauseButton.lineWidth = 1.5
        pauseButton.name = "btn.pause"
        if let icon = TextureFactory.pauseIcon {
            let glyph = SKSpriteNode(texture: icon)
            glyph.size = CGSize(width: 18, height: 18)
            glyph.color = Palette.text
            glyph.colorBlendFactor = 1
            glyph.name = "btn.pause"
            pauseButton.addChild(glyph)
        } else {
            let bars = SKShapeNode(path: {
                let p = CGMutablePath()
                p.addRect(CGRect(x: -6, y: -7, width: 4, height: 14))
                p.addRect(CGRect(x: 2, y: -7, width: 4, height: 14))
                return p
            }())
            bars.fillColor = Palette.text
            bars.strokeColor = .clear
            bars.name = "btn.pause"
            pauseButton.addChild(bars)
        }
        addChild(pauseButton)

        for _ in 0..<3 {
            let heart = SKSpriteNode(texture: TextureFactory.heart(size: 18))
            heart.size = CGSize(width: 18, height: 18)
            heart.isHidden = true
            addChild(heart)
            hearts.append(heart)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("Not supported") }

    func configure(title: String) {
        titleLabel.text = title
    }

    func layout(rect: CGRect) {
        titleLabel.position = CGPoint(x: rect.minX + 6, y: rect.midY + 8)
        subtitleLabel.position = CGPoint(x: rect.minX + 6, y: rect.midY - 10)
        scoreLabel.position = CGPoint(x: rect.midX, y: rect.midY + 6)
        comboLabel.position = CGPoint(x: rect.midX, y: rect.midY - 13)
        pauseButton.position = CGPoint(x: rect.maxX - 24, y: rect.midY)
        statusLabel.position = CGPoint(x: rect.maxX - 52, y: rect.midY)
        for (i, heart) in hearts.enumerated() {
            heart.position = CGPoint(x: rect.minX + 14 + CGFloat(i) * 22, y: rect.midY - 10)
        }
    }

    /// `frozen` is the remaining freeze power-up time; `knockedDown` is true while the player is
    /// getting back up after a hit (that pause has its own wording so it does not read as a pickup).
    func update(score: Int, combo: Int, time: Double, hearts heartCount: Int?, weapon: Weapon, weaponTime: Double, shield: Bool, frozen: Double, knockedDown: Bool) {
        scoreLabel.text = HUDNode.formatter.string(from: NSNumber(value: score)) ?? "\(score)"
        comboLabel.text = combo > 1 ? String(localized: "combo ×\(combo)") : ""
        if let heartCount = heartCount {
            subtitleLabel.text = ""
            for (i, heart) in hearts.enumerated() {
                heart.isHidden = false
                heart.alpha = i < heartCount ? 1 : 0.2
            }
        } else {
            subtitleLabel.text = String(format: "%.0fs", time)
            hearts.forEach { $0.isHidden = true }
        }
        var status: [String] = []
        let weaponSeconds = Int(ceil(weaponTime))
        switch weapon {
        case .normal: break
        case .double: status.append(String(localized: "Double \(weaponSeconds)s"))
        case .sticky: status.append(String(localized: "Sticky \(weaponSeconds)s"))
        case .rapid: status.append(String(localized: "Rapid \(weaponSeconds)s"))
        }
        if shield { status.append(String(localized: "Shield")) }
        if knockedDown { status.append(String(localized: "Knocked down")) }
        if frozen > 0 {
            let frozenSeconds = Int(ceil(frozen))
            status.append(String(localized: "Frozen \(frozenSeconds)s"))
        }
        statusLabel.text = status.joined(separator: " · ")
    }

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}
